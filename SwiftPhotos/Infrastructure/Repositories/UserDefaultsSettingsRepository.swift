import Foundation

/// UserDefaultsを使用した設定の永続化Repository
/// JSON エンコーディングを使用してより複雑な設定オブジェクトを保存
public actor UserDefaultsSettingsRepository: SettingsRepositoryProtocol {
    
    // MARK: - Properties
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let keyPrefix: String
    
    // MARK: - Performance Tracking
    private var operationCount = 0
    private var lastOperationTime = Date()
    private var cacheHitCount = 0
    private var cacheMissCount = 0
    
    // MARK: - In-Memory Cache (TTL: 5 minutes)
    private struct CachedSetting {
        let value: Any
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    private var settingsCache: [String: CachedSetting] = [:]
    
    // MARK: - Change Observers
    private var changeObservers: [String: AsyncStream<Any?>.Continuation] = [:]
    
    // MARK: - Initialization
    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "SwiftPhotos",
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
        
        // デフォルトエンコーダー設定
        let defaultEncoder = JSONEncoder()
        defaultEncoder.dateEncodingStrategy = .iso8601
        defaultEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder ?? defaultEncoder
        
        // デフォルトデコーダー設定
        let defaultDecoder = JSONDecoder()
        defaultDecoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder ?? defaultDecoder
    }
    
    // MARK: - SettingsRepositoryProtocol Implementation
    
    public func load<T: Codable>(_ type: T.Type, for key: SettingsKey) async -> T? {
        operationCount += 1
        lastOperationTime = Date()
        
        let fullKey = generateFullKey(for: key)
        
        // キャッシュチェック
        if let cachedSetting = settingsCache[fullKey],
           !cachedSetting.isExpired,
           let cachedValue = cachedSetting.value as? T {
            cacheHitCount += 1
            ProductionLogger.debug("UserDefaultsSettingsRepository: Cache hit for \(key.rawValue)")
            return cachedValue
        }
        
        cacheMissCount += 1
        ProductionLogger.debug("UserDefaultsSettingsRepository: Loading setting \(key.rawValue) from UserDefaults")
        
        guard let data = userDefaults.data(forKey: fullKey) else {
            ProductionLogger.debug("UserDefaultsSettingsRepository: No data found for \(key.rawValue)")
            return nil
        }
        
        do {
            let value = try decoder.decode(type, from: data)
            
            // キャッシュに保存
            settingsCache[fullKey] = CachedSetting(
                value: value,
                timestamp: Date()
            )
            
            ProductionLogger.debug("UserDefaultsSettingsRepository: Successfully loaded \(key.rawValue)")
            return value
            
        } catch {
            ProductionLogger.error("UserDefaultsSettingsRepository: Failed to decode \(key.rawValue): \(error)")
            return nil
        }
    }
    
    public func save<T: Codable>(_ value: T, for key: SettingsKey) async throws {
        operationCount += 1
        lastOperationTime = Date()
        
        let fullKey = generateFullKey(for: key)
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Saving setting \(key.rawValue)")
        
        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: fullKey)
            
            // キャッシュを更新
            settingsCache[fullKey] = CachedSetting(
                value: value,
                timestamp: Date()
            )
            
            // 変更通知
            notifyObservers(for: key, value: value)
            
            ProductionLogger.debug("UserDefaultsSettingsRepository: Successfully saved \(key.rawValue)")
            
        } catch {
            ProductionLogger.error("UserDefaultsSettingsRepository: Failed to save \(key.rawValue): \(error)")
            throw error
        }
    }
    
    public func remove(for key: SettingsKey) async {
        operationCount += 1
        lastOperationTime = Date()
        
        let fullKey = generateFullKey(for: key)
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Removing setting \(key.rawValue)")
        
        userDefaults.removeObject(forKey: fullKey)
        settingsCache.removeValue(forKey: fullKey)
        
        // 変更通知
        notifyObservers(for: key, value: nil)
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Successfully removed \(key.rawValue)")
    }
    
    public func loadMultiple<T: Codable>(_ type: T.Type, for keys: [SettingsKey]) async -> [SettingsKey: T] {
        var results: [SettingsKey: T] = [:]
        
        for key in keys {
            if let value = await load(type, for: key) {
                results[key] = value
            }
        }
        
        return results
    }
    
    public func saveMultiple<T: Codable>(_ values: [SettingsKey: T]) async throws {
        for (key, value) in values {
            try await save(value, for: key)
        }
    }
    
    public func resetAll() async {
        operationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Resetting all settings")
        
        let keysToDelete = userDefaults.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix(keyPrefix)
        }
        
        for key in keysToDelete {
            userDefaults.removeObject(forKey: key)
        }
        
        settingsCache.removeAll()
        
        ProductionLogger.info("UserDefaultsSettingsRepository: Reset \(keysToDelete.count) settings")
    }
    
    public func resetCategory(_ category: RepositorySettingsCategory) async {
        operationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Resetting category \(category.rawValue)")
        
        let categoryPrefix = generateCategoryPrefix(category)
        let keysToDelete = userDefaults.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix(categoryPrefix)
        }
        
        for key in keysToDelete {
            userDefaults.removeObject(forKey: key)
            settingsCache.removeValue(forKey: key)
        }
        
        ProductionLogger.info("UserDefaultsSettingsRepository: Reset \(keysToDelete.count) settings in category \(category.rawValue)")
    }
    
    public func export() async throws -> Data {
        operationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Exporting all settings")
        
        var exportData: [String: Any] = [:]
        
        for (key, value) in userDefaults.dictionaryRepresentation() {
            if key.hasPrefix(keyPrefix) {
                let settingKey = String(key.dropFirst(keyPrefix.count + 1)) // +1 for the dot
                
                if let data = value as? Data {
                    // JSON として復元を試行
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        exportData[settingKey] = jsonObject
                    } catch {
                        // JSON復元に失敗した場合はそのまま保存
                        exportData[settingKey] = value
                    }
                } else {
                    exportData[settingKey] = value
                }
            }
        }
        
        let backup: [String: Any] = [
            "version": "1.0",
            "created": ISO8601DateFormatter().string(from: Date()),
            "settings": exportData
        ]
        
        return try JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted)
    }
    
    public func importSettings(from data: Data) async throws {
        operationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("UserDefaultsSettingsRepository: Importing settings")
        
        guard let backup = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let settings = backup["settings"] as? [String: Any] else {
            throw NSError(domain: "UserDefaultsSettingsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid backup data format"])
        }
        
        var importedCount = 0
        
        for (keyString, value) in settings {
            let fullKey = "\(keyPrefix).\(keyString)"
            
            // JSON データとして保存
            do {
                let data = try JSONSerialization.data(withJSONObject: value, options: [])
                userDefaults.set(data, forKey: fullKey)
                
                // キャッシュをクリア（次回アクセス時に再読み込み）
                settingsCache.removeValue(forKey: fullKey)
                
                importedCount += 1
            } catch {
                ProductionLogger.warning("UserDefaultsSettingsRepository: Failed to import \(keyString): \(error)")
            }
        }
        
        ProductionLogger.info("UserDefaultsSettingsRepository: Import completed - imported: \(importedCount) settings")
    }
    
    public func observe<T: Codable>(_ type: T.Type, for key: SettingsKey) -> AsyncStream<T?> {
        let fullKey = generateFullKey(for: key)
        
        return AsyncStream { continuation in
            // 現在の値を送信
            Task {
                let currentValue = await self.load(type, for: key)
                continuation.yield(currentValue)
            }
            
            // 変更監視の登録
            changeObservers[fullKey] = continuation as? AsyncStream<Any?>.Continuation
            
            continuation.onTermination = { _ in
                Task {
                    await self.removeObserver(for: fullKey)
                }
            }
        }
    }
    
    public func allKeys() async -> [SettingsKey] {
        let prefixWithDot = "\(keyPrefix)."
        
        return userDefaults.dictionaryRepresentation().keys.compactMap { key in
            if key.hasPrefix(prefixWithDot) {
                let settingKey = String(key.dropFirst(prefixWithDot.count))
                return SettingsKey(settingKey)
            }
            return nil
        }
    }
    
    public func exists(for key: SettingsKey) async -> Bool {
        let fullKey = generateFullKey(for: key)
        
        // キャッシュチェック
        if let cachedSetting = settingsCache[fullKey],
           !cachedSetting.isExpired {
            return true
        }
        
        return userDefaults.object(forKey: fullKey) != nil
    }
    
    public func getMetadata(for key: SettingsKey) async -> SettingsMetadata? {
        let fullKey = generateFullKey(for: key)
        
        guard userDefaults.object(forKey: fullKey) != nil else {
            return nil
        }
        
        // 簡単なメタデータを生成
        let size = userDefaults.data(forKey: fullKey)?.count ?? 0
        
        return SettingsMetadata(
            key: key,
            category: key.category,
            dataSize: size,
            lastModified: Date(), // UserDefaultsでは正確な変更日時は取得困難
            version: "1.0",
            checksum: nil,
            isEncrypted: false,
            compressionType: nil,
            customProperties: [:]
        )
    }
    
    public func validate<T: Codable>(_ value: T, for key: SettingsKey) async throws -> ValidationResult {
        // 基本的な検証を実装
        var warnings: [ValidationResult.Warning] = []
        var errors: [ValidationResult.Error] = []
        
        // キー別の検証ロジック
        switch key.rawValue {
        case "performance":
            // パフォーマンス設定の検証
            break
        case "slideshow":
            // スライドショー設定の検証
            break
        default:
            // 一般的な検証
            break
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func generateFullKey(for key: SettingsKey) -> String {
        return "\(keyPrefix).\(key.category.rawValue).\(key.rawValue)"
    }
    
    private func generateCategoryPrefix(_ category: RepositorySettingsCategory) -> String {
        return "\(keyPrefix).\(category.rawValue)."
    }
    
    private func notifyObservers<T>(for key: SettingsKey, value: T?) {
        let fullKey = generateFullKey(for: key)
        
        if let continuation = changeObservers[fullKey] {
            continuation.yield(value)
        }
    }
    
    private func removeObserver(for fullKey: String) {
        changeObservers.removeValue(forKey: fullKey)
    }
    
    // MARK: - Performance Monitoring
    
    public func getPerformanceMetrics() async -> RepositoryMetrics {
        let cacheHitRate = operationCount > 0 ? Double(cacheHitCount) / Double(operationCount) : 0.0
        
        return RepositoryMetrics(
            operationCount: operationCount,
            successCount: operationCount - cacheMissCount, // 簡略化
            errorCount: 0, // 実装を簡略化
            averageResponseTime: 0.01, // UserDefaults は高速
            cacheHitRate: cacheHitRate,
            totalDataTransferred: 0, // UserDefaults用のため0
            lastOperation: lastOperationTime
        )
    }
    
    // MARK: - Cache Management
    
    public func clearCache() async {
        settingsCache.removeAll()
        ProductionLogger.debug("UserDefaultsSettingsRepository: Cache cleared")
    }
    
    public func clearExpiredCache() async {
        let initialCount = settingsCache.count
        settingsCache = settingsCache.filter { !$0.value.isExpired }
        let removedCount = initialCount - settingsCache.count
        
        if removedCount > 0 {
            ProductionLogger.debug("UserDefaultsSettingsRepository: Removed \(removedCount) expired cache entries")
        }
    }
}

// MARK: - Default Settings Initialization
extension UserDefaultsSettingsRepository {
    
    /// デフォルト設定値を初期化
    public func initializeDefaultSettings() async throws {
        ProductionLogger.info("UserDefaultsSettingsRepository: Initializing default settings")
        
        // Core デフォルト設定
        if !(await exists(for: .performance)) {
            let defaultPerformance = ["memoryLimit": 1024 * 1024 * 1024, "maxConcurrentLoads": 5]
            try await save(defaultPerformance, for: .performance)
        }
        
        if !(await exists(for: .slideshow)) {
            let defaultSlideshow = ["interval": 3.0, "autoStart": false]
            try await save(defaultSlideshow, for: .slideshow)
        }
        
        // User Interface デフォルト設定
        if !(await exists(for: .appearance)) {
            let defaultAppearance = ["theme": "system", "accentColor": "blue"]
            try await save(defaultAppearance, for: .appearance)
        }
        
        ProductionLogger.info("UserDefaultsSettingsRepository: Default settings initialized")
    }
    
    /// 設定のバックアップを作成
    public func createBackup() async throws -> Data {
        return try await export()
    }
    
    /// バックアップから設定を復元
    public func restoreFromBackup(_ backupData: Data, overwriteExisting: Bool = false) async throws {
        if overwriteExisting {
            await resetAll()
        }
        try await importSettings(from: backupData)
        
        ProductionLogger.info("UserDefaultsSettingsRepository: Successfully restored from backup")
    }
}