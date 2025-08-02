import Foundation

// UserDefaults is thread-safe but not marked Sendable
extension UserDefaults: @unchecked Sendable {}

/// Repository層のDependency Injection Container
/// すべてのRepositoryの生成と管理を行う
public actor RepositoryContainer {
    
    // MARK: - Singleton Instance
    public static let shared = RepositoryContainer()
    
    // MARK: - Repository Instances
    private var _imageRepository: (any ImageRepositoryProtocol)?
    private var _cacheRepository: (any ImageCacheRepositoryProtocol)?
    private var _metadataRepository: (any MetadataRepositoryProtocol)?
    private var _settingsRepository: (any SettingsRepositoryProtocol)?
    
    // MARK: - Configuration
    private let configuration: ContainerConfiguration
    
    // MARK: - Initialization
    private init(configuration: ContainerConfiguration = .default) {
        self.configuration = configuration
        ProductionLogger.info("RepositoryContainer: Initialized with configuration \(configuration.name)")
    }
    
    // MARK: - Repository Access Methods
    
    /// Image Repository を取得
    public func imageRepository() async -> any ImageRepositoryProtocol {
        if let repository = _imageRepository {
            return repository
        }
        
        let repository = await createImageRepository()
        _imageRepository = repository
        ProductionLogger.debug("RepositoryContainer: Created ImageRepository")
        return repository
    }
    
    /// Cache Repository を取得
    public func cacheRepository() async -> any ImageCacheRepositoryProtocol {
        if let repository = _cacheRepository {
            return repository
        }
        
        let repository = await createCacheRepository()
        _cacheRepository = repository
        ProductionLogger.debug("RepositoryContainer: Created CacheRepository")
        return repository
    }
    
    /// Metadata Repository を取得
    public func metadataRepository() async -> any MetadataRepositoryProtocol {
        if let repository = _metadataRepository {
            return repository
        }
        
        let repository = await createMetadataRepository()
        _metadataRepository = repository
        ProductionLogger.debug("RepositoryContainer: Created MetadataRepository")
        return repository
    }
    
    /// Settings Repository を取得
    public func settingsRepository() async -> any SettingsRepositoryProtocol {
        if let repository = _settingsRepository {
            return repository
        }
        
        let repository = await createSettingsRepository()
        _settingsRepository = repository
        ProductionLogger.debug("RepositoryContainer: Created SettingsRepository")
        return repository
    }
    
    // MARK: - Repository Factory Methods
    
    private func createImageRepository() async -> any ImageRepositoryProtocol {
        switch configuration.imageRepositoryType {
        case .local:
            return await LocalImageRepository(
                fileAccess: configuration.secureFileAccess,
                imageLoader: configuration.imageLoader,
                additionalFormats: configuration.supportedImageFormats
            )
        case .hybrid:
            // 将来的にクラウドとローカルのハイブリッド実装を追加
            return await LocalImageRepository()
        }
    }
    
    private func createCacheRepository() async -> any ImageCacheRepositoryProtocol {
        switch configuration.cacheRepositoryType {
        case .memory:
            return MemoryCacheRepository(
                imageCache: configuration.imageCache,
                countLimit: configuration.cacheCountLimit,
                totalCostLimit: configuration.cacheTotalCostLimit
            )
        case .disk:
            // 将来的にディスクキャッシュ実装を追加
            return MemoryCacheRepository()
        case .hybrid:
            // 将来的にメモリ＋ディスクのハイブリッド実装を追加
            return MemoryCacheRepository()
        }
    }
    
    private func createMetadataRepository() async -> any MetadataRepositoryProtocol {
        switch configuration.metadataRepositoryType {
        case .fileSystem:
            return FileSystemMetadataRepository(
                cacheCountLimit: configuration.metadataCacheCountLimit,
                cacheTotalCostLimit: configuration.metadataCacheTotalCostLimit,
                supportedFormats: configuration.supportedMetadataFormats
            )
        case .database:
            // 将来的にデータベース実装を追加
            return FileSystemMetadataRepository()
        case .hybrid:
            // 将来的にファイルシステム＋データベースのハイブリッド実装を追加
            return FileSystemMetadataRepository()
        }
    }
    
    private func createSettingsRepository() async -> any SettingsRepositoryProtocol {
        switch configuration.settingsRepositoryType {
        case .userDefaults:
            return UserDefaultsSettingsRepository(
                userDefaults: configuration.userDefaults,
                keyPrefix: configuration.settingsKeyPrefix,
                encoder: configuration.jsonEncoder,
                decoder: configuration.jsonDecoder
            )
        case .plist:
            // 将来的にPlist実装を追加
            return UserDefaultsSettingsRepository()
        case .database:
            // 将来的にデータベース実装を追加
            return UserDefaultsSettingsRepository()
        }
    }
    
    // MARK: - Repository Lifecycle Management
    
    /// すべてのRepositoryをリセット（テスト用）
    public func resetAll() async {
        _imageRepository = nil
        _cacheRepository = nil
        _metadataRepository = nil
        _settingsRepository = nil
        ProductionLogger.info("RepositoryContainer: All repositories reset")
    }
    
    /// 特定のRepositoryをリセット
    public func resetImageRepository() async {
        _imageRepository = nil
        ProductionLogger.debug("RepositoryContainer: ImageRepository reset")
    }
    
    public func resetCacheRepository() async {
        _cacheRepository = nil
        ProductionLogger.debug("RepositoryContainer: CacheRepository reset")
    }
    
    public func resetMetadataRepository() async {
        _metadataRepository = nil
        ProductionLogger.debug("RepositoryContainer: MetadataRepository reset")
    }
    
    public func resetSettingsRepository() async {
        _settingsRepository = nil
        ProductionLogger.debug("RepositoryContainer: SettingsRepository reset")
    }
    
    // MARK: - Configuration Updates
    
    /// 設定を更新（新しいインスタンスを作成）
    public func updateConfiguration(_ newConfiguration: ContainerConfiguration) async {
        await resetAll()
        // configuration は let で定義されているため、新しいインスタンスが必要
        ProductionLogger.info("RepositoryContainer: Configuration update requested")
    }
    
    // MARK: - Health Check
    
    /// すべてのRepositoryのヘルスチェック
    public func performHealthCheck() async -> RepositoryHealthStatus {
        var issues: [String] = []
        var repositoryStatuses: [String: Bool] = [:]
        
        // ImageRepository ヘルスチェック
        do {
            let imageRepo = await imageRepository()
            // LocalImageRepository にはgetPerformanceMetricsメソッドがあるため、型キャスト
            if let localRepo = imageRepo as? LocalImageRepository {
                let metrics = await localRepo.getPerformanceMetrics()
                repositoryStatuses["ImageRepository"] = metrics.errorCount == 0
                if metrics.errorCount > 0 {
                    issues.append("ImageRepository has \(metrics.errorCount) errors")
                }
            } else {
                repositoryStatuses["ImageRepository"] = true // 基本的には成功とみなす
            }
        } catch {
            repositoryStatuses["ImageRepository"] = false
            issues.append("ImageRepository initialization failed: \(error)")
        }
        
        // CacheRepository ヘルスチェック
        do {
            let cacheRepo = await cacheRepository()
            let stats = await cacheRepo.statistics()
            repositoryStatuses["CacheRepository"] = true
            ProductionLogger.debug("CacheRepository: \(stats.currentCount) items cached")
        } catch {
            repositoryStatuses["CacheRepository"] = false
            issues.append("CacheRepository initialization failed: \(error)")
        }
        
        // MetadataRepository ヘルスチェック
        do {
            let metadataRepo = await metadataRepository()
            let metrics = await metadataRepo.getPerformanceStatistics()
            repositoryStatuses["MetadataRepository"] = metrics.failedExtractions == 0
            if metrics.failedExtractions > 0 {
                issues.append("MetadataRepository has \(metrics.failedExtractions) failed extractions")
            }
        } catch {
            repositoryStatuses["MetadataRepository"] = false
            issues.append("MetadataRepository initialization failed: \(error)")
        }
        
        // SettingsRepository ヘルスチェック
        do {
            let settingsRepo = await settingsRepository()
            let allKeys = await settingsRepo.allKeys()
            repositoryStatuses["SettingsRepository"] = true
            ProductionLogger.debug("SettingsRepository: \(allKeys.count) settings keys")
        } catch {
            repositoryStatuses["SettingsRepository"] = false
            issues.append("SettingsRepository initialization failed: \(error)")
        }
        
        let isHealthy = issues.isEmpty
        let status = RepositoryHealthStatus(
            isHealthy: isHealthy,
            repositoryStatuses: repositoryStatuses,
            issues: issues,
            checkedAt: Date()
        )
        
        if isHealthy {
            ProductionLogger.info("RepositoryContainer: Health check passed")
        } else {
            ProductionLogger.warning("RepositoryContainer: Health check failed with \(issues.count) issues")
        }
        
        return status
    }
}

// MARK: - Repository Configuration

/// Repository Container の設定
public struct ContainerConfiguration: @unchecked Sendable {
    public let name: String
    
    // Repository Types
    public let imageRepositoryType: ImageRepositoryType
    public let cacheRepositoryType: CacheRepositoryType
    public let metadataRepositoryType: MetadataRepositoryType
    public let settingsRepositoryType: SettingsRepositoryType
    
    // Dependencies
    public let secureFileAccess: SecureFileAccess?
    public let imageLoader: ImageLoader?
    public let imageCache: ImageCache?
    public let userDefaults: UserDefaults
    public let jsonEncoder: JSONEncoder?
    public let jsonDecoder: JSONDecoder?
    
    // Cache Configuration
    public let cacheCountLimit: Int
    public let cacheTotalCostLimit: Int
    public let metadataCacheCountLimit: Int
    public let metadataCacheTotalCostLimit: Int
    
    // Supported Formats
    public let supportedImageFormats: Set<String>
    public let supportedMetadataFormats: Set<MetadataFormat>
    
    // Settings Configuration
    public let settingsKeyPrefix: String
    
    public init(
        name: String = "Default",
        imageRepositoryType: ImageRepositoryType = .local,
        cacheRepositoryType: CacheRepositoryType = .memory,
        metadataRepositoryType: MetadataRepositoryType = .fileSystem,
        settingsRepositoryType: SettingsRepositoryType = .userDefaults,
        secureFileAccess: SecureFileAccess? = nil,
        imageLoader: ImageLoader? = nil,
        imageCache: ImageCache? = nil,
        userDefaults: UserDefaults = .standard,
        jsonEncoder: JSONEncoder? = nil,
        jsonDecoder: JSONDecoder? = nil,
        cacheCountLimit: Int = 200,
        cacheTotalCostLimit: Int = 500_000_000,
        metadataCacheCountLimit: Int = 1000,
        metadataCacheTotalCostLimit: Int = 50_000_000,
        supportedImageFormats: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif"],
        supportedMetadataFormats: Set<MetadataFormat> = [.exif, .iptc, .xmp, .tiff],
        settingsKeyPrefix: String = "SwiftPhotos"
    ) {
        self.name = name
        self.imageRepositoryType = imageRepositoryType
        self.cacheRepositoryType = cacheRepositoryType
        self.metadataRepositoryType = metadataRepositoryType
        self.settingsRepositoryType = settingsRepositoryType
        self.secureFileAccess = secureFileAccess
        self.imageLoader = imageLoader
        self.imageCache = imageCache
        self.userDefaults = userDefaults
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
        self.cacheCountLimit = cacheCountLimit
        self.cacheTotalCostLimit = cacheTotalCostLimit
        self.metadataCacheCountLimit = metadataCacheCountLimit
        self.metadataCacheTotalCostLimit = metadataCacheTotalCostLimit
        self.supportedImageFormats = supportedImageFormats
        self.supportedMetadataFormats = supportedMetadataFormats
        self.settingsKeyPrefix = settingsKeyPrefix
    }
    
    // MARK: - Predefined Configurations
    
    /// デフォルト設定
    public static let `default` = ContainerConfiguration()
    
    /// パフォーマンス重視設定
    public static let performanceOptimized = ContainerConfiguration(
        name: "Performance",
        cacheCountLimit: 500,
        cacheTotalCostLimit: 1_000_000_000, // 1GB
        metadataCacheCountLimit: 5000,
        metadataCacheTotalCostLimit: 100_000_000 // 100MB
    )
    
    /// メモリ節約設定
    public static let memoryOptimized = ContainerConfiguration(
        name: "Memory Optimized",
        cacheCountLimit: 50,
        cacheTotalCostLimit: 100_000_000, // 100MB
        metadataCacheCountLimit: 200,
        metadataCacheTotalCostLimit: 10_000_000 // 10MB
    )
    
    /// テスト用設定
    public static let testing = ContainerConfiguration(
        name: "Testing",
        userDefaults: UserDefaults(suiteName: "TestSuite") ?? .standard,
        cacheCountLimit: 10,
        cacheTotalCostLimit: 10_000_000, // 10MB
        metadataCacheCountLimit: 100,
        metadataCacheTotalCostLimit: 1_000_000, // 1MB
        settingsKeyPrefix: "TestSwiftPhotos"
    )
}

// MARK: - Repository Types

public enum ImageRepositoryType: Sendable {
    case local
    case hybrid // 将来拡張用
}

public enum CacheRepositoryType: Sendable {
    case memory
    case disk // 将来拡張用
    case hybrid // 将来拡張用
}

public enum MetadataRepositoryType: Sendable {
    case fileSystem
    case database // 将来拡張用
    case hybrid // 将来拡張用
}

public enum SettingsRepositoryType: Sendable {
    case userDefaults
    case plist // 将来拡張用
    case database // 将来拡張用
}

// MARK: - Health Status

/// Repository ヘルス状態
public struct RepositoryHealthStatus: Sendable {
    public let isHealthy: Bool
    public let repositoryStatuses: [String: Bool]
    public let issues: [String]
    public let checkedAt: Date
    
    public init(
        isHealthy: Bool,
        repositoryStatuses: [String: Bool],
        issues: [String],
        checkedAt: Date
    ) {
        self.isHealthy = isHealthy
        self.repositoryStatuses = repositoryStatuses
        self.issues = issues
        self.checkedAt = checkedAt
    }
    
    /// 健全なRepositoryの数
    public var healthyRepositoryCount: Int {
        repositoryStatuses.values.filter { $0 }.count
    }
    
    /// 総Repository数
    public var totalRepositoryCount: Int {
        repositoryStatuses.count
    }
    
    /// ヘルス率（0.0 - 1.0）
    public var healthRate: Double {
        guard totalRepositoryCount > 0 else { return 1.0 }
        return Double(healthyRepositoryCount) / Double(totalRepositoryCount)
    }
}

// MARK: - Container Extensions

extension RepositoryContainer {
    
    /// 開発用途：すべてのRepositoryの統計情報を取得
    public func getAllStatistics() async -> RepositoryContainerStatistics {
        var statistics: [String: String] = [:]
        
        // ImageRepository統計
        if let imageRepo = _imageRepository,
           let localRepo = imageRepo as? LocalImageRepository {
            let metrics = await localRepo.getPerformanceMetrics()
            statistics["ImageRepository.operationCount"] = "\(metrics.operationCount)"
            statistics["ImageRepository.successCount"] = "\(metrics.successCount)"
            statistics["ImageRepository.errorCount"] = "\(metrics.errorCount)"
            statistics["ImageRepository.averageResponseTime"] = "\(metrics.averageResponseTime)"
        }
        
        // CacheRepository統計
        if let cacheRepo = _cacheRepository {
            let stats = await cacheRepo.statistics()
            statistics["CacheRepository.hitCount"] = "\(stats.hitCount)"
            statistics["CacheRepository.missCount"] = "\(stats.missCount)"
            statistics["CacheRepository.currentCount"] = "\(stats.currentCount)"
            statistics["CacheRepository.totalCost"] = "\(stats.totalCost)"
        }
        
        // MetadataRepository統計
        if let metadataRepo = _metadataRepository {
            let stats = await metadataRepo.getPerformanceStatistics()
            statistics["MetadataRepository.totalExtractions"] = "\(stats.totalExtractions)"
            statistics["MetadataRepository.successfulExtractions"] = "\(stats.successfulExtractions)"
            statistics["MetadataRepository.failedExtractions"] = "\(stats.failedExtractions)"
            statistics["MetadataRepository.averageExtractionTime"] = "\(stats.averageExtractionTime)"
        }
        
        return RepositoryContainerStatistics(
            configuration: configuration.name,
            repositoryStatistics: statistics,
            collectedAt: Date()
        )
    }
}

/// Repository Container 統計情報
public struct RepositoryContainerStatistics: Sendable {
    public let configuration: String
    public let repositoryStatistics: [String: String] // Sendable のため String に変更
    public let collectedAt: Date
    
    public init(configuration: String, repositoryStatistics: [String: String], collectedAt: Date) {
        self.configuration = configuration
        self.repositoryStatistics = repositoryStatistics
        self.collectedAt = collectedAt
    }
}