import Foundation

// MARK: - Common Repository Types

/// Repository層で共通して使用される型とユーティリティ

/// Repository操作の結果
public enum RepositoryResult<T> {
    case success(T)
    case failure(RepositoryError)
    
    /// 成功値を取得（失敗時はエラーをthrow）
    public func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    /// 値をマップする
    public func map<U>(_ transform: (T) throws -> U) rethrows -> RepositoryResult<U> {
        switch self {
        case .success(let value):
            return .success(try transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// エラーをマップする
    public func mapError(_ transform: (RepositoryError) -> RepositoryError) -> RepositoryResult<T> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
}

/// Repository層の共通エラー
public enum RepositoryError: LocalizedError, Sendable {
    case notFound(String)
    case accessDenied(String)
    case networkError(underlying: Error)
    case storageError(underlying: Error)
    case validationError(String)
    case serializationError(underlying: Error)
    case timeout(operation: String, duration: TimeInterval)
    case resourceExhausted(resource: String)
    case versionMismatch(expected: String, actual: String)
    case operationCancelled
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .accessDenied(let resource):
            return "Access denied to: \(resource)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serializationError(let error):
            return "Serialization error: \(error.localizedDescription)"
        case .timeout(let operation, let duration):
            return "Operation '\(operation)' timed out after \(duration) seconds"
        case .resourceExhausted(let resource):
            return "Resource exhausted: \(resource)"
        case .versionMismatch(let expected, let actual):
            return "Version mismatch: expected \(expected), got \(actual)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .notFound:
            return "The requested resource does not exist"
        case .accessDenied:
            return "Insufficient permissions to access the resource"
        case .networkError:
            return "A network-related error occurred"
        case .storageError:
            return "A storage-related error occurred"
        case .validationError:
            return "The data failed validation checks"
        case .serializationError:
            return "Failed to serialize or deserialize data"
        case .timeout:
            return "The operation took longer than expected"
        case .resourceExhausted:
            return "The system resource has been exhausted"
        case .versionMismatch:
            return "The data version is incompatible"
        case .operationCancelled:
            return "The operation was cancelled by the user or system"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
}

/// Repository操作のコンテキスト
public struct RepositoryContext: Sendable {
    public let operationId: UUID
    public let timestamp: Date
    public let userId: String?
    public let sessionId: String?
    public let timeout: TimeInterval?
    public let retryCount: Int
    public let metadata: [String: String]
    
    public init(
        operationId: UUID = UUID(),
        timestamp: Date = Date(),
        userId: String? = nil,
        sessionId: String? = nil,
        timeout: TimeInterval? = nil,
        retryCount: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.operationId = operationId
        self.timestamp = timestamp
        self.userId = userId
        self.sessionId = sessionId
        self.timeout = timeout
        self.retryCount = retryCount
        self.metadata = metadata
    }
    
    /// デフォルトコンテキスト
    public static let `default` = RepositoryContext()
    
    /// リトライ用の新しいコンテキスト
    public func withRetry() -> RepositoryContext {
        return RepositoryContext(
            operationId: operationId,
            timestamp: Date(),
            userId: userId,
            sessionId: sessionId,
            timeout: timeout,
            retryCount: retryCount + 1,
            metadata: metadata
        )
    }
}

/// Repository操作のオプション
public struct RepositoryOptions: Sendable {
    public let cachePolicy: CachePolicy
    public let timeout: TimeInterval?
    public let retryPolicy: RetryPolicy?
    public let priority: OperationPriority
    public let context: RepositoryContext
    
    public init(
        cachePolicy: CachePolicy = .default,
        timeout: TimeInterval? = nil,
        retryPolicy: RetryPolicy? = nil,
        priority: OperationPriority = .normal,
        context: RepositoryContext = .default
    ) {
        self.cachePolicy = cachePolicy
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.priority = priority
        self.context = context
    }
    
    /// デフォルトオプション
    public static let `default` = RepositoryOptions()
}

/// キャッシュポリシー
public enum CachePolicy: Sendable, Equatable {
    case never              // キャッシュを使用しない
    case always             // 常にキャッシュを使用
    case ifAvailable        // 利用可能ならキャッシュを使用
    case reloadIgnoringCache // キャッシュを無視して再読み込み
    case returnCacheElseLoad // キャッシュがあれば返す、なければ読み込み
    case custom(TimeInterval) // カスタムTTL
    
    /// デフォルトポリシー
    public static let `default` = CachePolicy.ifAvailable
}

/// リトライポリシー
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let backoffMultiplier: Double
    public let maxDelay: TimeInterval
    public let retryableErrors: [RepositoryError]
    
    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        retryableErrors: [RepositoryError] = []
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.retryableErrors = retryableErrors
    }
    
    /// デフォルトリトライポリシー
    public static let `default` = RetryPolicy()
    
    /// ネットワーク用リトライポリシー
    public static let network = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 10.0
    )
    
    /// 指定した試行回数での遅延時間を計算
    public func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}

/// 操作優先度
public enum OperationPriority: Int, Sendable, CaseIterable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    public static func < (lhs: OperationPriority, rhs: OperationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Repository メトリクス
public struct RepositoryMetrics: Sendable {
    public let operationCount: Int
    public let successCount: Int
    public let errorCount: Int
    public let averageResponseTime: TimeInterval
    public let cacheHitRate: Double
    public let totalDataTransferred: Int64
    public let lastOperation: Date?
    
    public init(
        operationCount: Int = 0,
        successCount: Int = 0,
        errorCount: Int = 0,
        averageResponseTime: TimeInterval = 0,
        cacheHitRate: Double = 0,
        totalDataTransferred: Int64 = 0,
        lastOperation: Date? = nil
    ) {
        self.operationCount = operationCount
        self.successCount = successCount
        self.errorCount = errorCount
        self.averageResponseTime = averageResponseTime
        self.cacheHitRate = cacheHitRate
        self.totalDataTransferred = totalDataTransferred
        self.lastOperation = lastOperation
    }
    
    /// 成功率
    public var successRate: Double {
        guard operationCount > 0 else { return 0.0 }
        return Double(successCount) / Double(operationCount)
    }
    
    /// エラー率
    public var errorRate: Double {
        guard operationCount > 0 else { return 0.0 }
        return Double(errorCount) / Double(operationCount)
    }
    
    /// データ転送量の文字列表現
    public var dataTransferredString: String {
        ByteCountFormatter.string(fromByteCount: totalDataTransferred, countStyle: .binary)
    }
    
    /// 空のメトリクス
    public static let empty = RepositoryMetrics()
}

/// Repository ヘルスチェック結果
public struct RepositoryHealth: Sendable {
    public let isHealthy: Bool
    public let status: HealthStatus
    public let lastCheck: Date
    public let responseTime: TimeInterval?
    public let errors: [RepositoryError]
    public let warnings: [String]
    public let details: [String: String]
    
    public init(
        isHealthy: Bool,
        status: HealthStatus,
        lastCheck: Date = Date(),
        responseTime: TimeInterval? = nil,
        errors: [RepositoryError] = [],
        warnings: [String] = [],
        details: [String: String] = [:]
    ) {
        self.isHealthy = isHealthy
        self.status = status
        self.lastCheck = lastCheck
        self.responseTime = responseTime
        self.errors = errors
        self.warnings = warnings
        self.details = details
    }
    
    public enum HealthStatus: String, Sendable, CaseIterable {
        case healthy = "healthy"
        case degraded = "degraded"
        case unhealthy = "unhealthy"
        case unknown = "unknown"
        
        /// ステータスの重要度
        public var severity: Int {
            switch self {
            case .healthy: return 0
            case .degraded: return 1
            case .unhealthy: return 2
            case .unknown: return 3
            }
        }
    }
}

/// Repository設定
public protocol RepositoryConfiguration: Sendable {
    var name: String { get }
    var version: String { get }
    var timeout: TimeInterval { get }
    var retryPolicy: RetryPolicy { get }
    var cachePolicy: CachePolicy { get }
    var enableMetrics: Bool { get }
    var enableHealthCheck: Bool { get }
    var healthCheckInterval: TimeInterval { get }
}

/// デフォルトRepository設定
public struct DefaultRepositoryConfiguration: RepositoryConfiguration {
    public let name: String
    public let version: String
    public let timeout: TimeInterval
    public let retryPolicy: RetryPolicy
    public let cachePolicy: CachePolicy
    public let enableMetrics: Bool
    public let enableHealthCheck: Bool
    public let healthCheckInterval: TimeInterval
    
    public init(
        name: String,
        version: String = "1.0",
        timeout: TimeInterval = 30.0,
        retryPolicy: RetryPolicy = .default,
        cachePolicy: CachePolicy = .default,
        enableMetrics: Bool = true,
        enableHealthCheck: Bool = true,
        healthCheckInterval: TimeInterval = 300.0
    ) {
        self.name = name
        self.version = version
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.cachePolicy = cachePolicy
        self.enableMetrics = enableMetrics
        self.enableHealthCheck = enableHealthCheck
        self.healthCheckInterval = healthCheckInterval
    }
}

/// Repository監視プロトコル
public protocol RepositoryMonitor: Sendable {
    /// メトリクスを記録
    func recordMetric(_ metric: RepositoryMetrics) async
    
    /// エラーを記録
    func recordError(_ error: RepositoryError, context: RepositoryContext) async
    
    /// ヘルスチェックを実行
    func performHealthCheck() async -> RepositoryHealth
    
    /// アラートを送信
    func sendAlert(_ message: String, severity: AlertSeverity) async
}

/// アラート重要度
public enum AlertSeverity: String, Sendable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    /// 重要度の数値
    public var level: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
}

/// Repository拡張プロトコル
public protocol RepositoryExtensions: Sendable {
    /// バッチ操作サポート
    func supportsBatchOperations() -> Bool
    
    /// トランザクションサポート
    func supportsTransactions() -> Bool
    
    /// バックアップサポート
    func supportsBackup() -> Bool
    
    /// 同期サポート
    func supportsSync() -> Bool
}

/// 共通ユーティリティ関数
public enum RepositoryUtils {
    /// 安全な非同期操作実行
    public static func safeExecute<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T,
        options: RepositoryOptions = .default
    ) async -> RepositoryResult<T> {
        var lastError: RepositoryError?
        let retryPolicy = options.retryPolicy ?? .default
        
        for attempt in 1...retryPolicy.maxAttempts {
            do {
                // タイムアウト処理
                if let timeout = options.timeout {
                    return try await withThrowingTaskGroup(of: T.self) { group in
                        group.addTask {
                            try await operation()
                        }
                        
                        group.addTask {
                            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                            throw RepositoryError.timeout(operation: "repository operation", duration: timeout)
                        }
                        
                        let result = try await group.next()!
                        group.cancelAll()
                        return .success(result)
                    }
                } else {
                    let result = try await operation()
                    return .success(result)
                }
            } catch let error as RepositoryError {
                lastError = error
                
                // リトライ可能なエラーかチェック
                if attempt < retryPolicy.maxAttempts &&
                   (retryPolicy.retryableErrors.isEmpty || retryPolicy.retryableErrors.contains { $0.localizedDescription == error.localizedDescription }) {
                    
                    let delay = retryPolicy.delay(for: attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                return .failure(error)
            } catch {
                lastError = .unknown(underlying: error)
                return .failure(lastError!)
            }
        }
        
        return .failure(lastError ?? .unknown(underlying: NSError(domain: "RepositoryUtils", code: -1)))
    }
}

// MARK: - Settings Validation Types

/// 設定の検証結果
public struct SettingsValidationResult: Sendable, Equatable {
    public let isValid: Bool
    public let warnings: [SettingsValidationWarning]
    public let errors: [SettingsValidationError]
    
    public init(
        isValid: Bool,
        warnings: [SettingsValidationWarning] = [],
        errors: [SettingsValidationError] = []
    ) {
        self.isValid = isValid
        self.warnings = warnings
        self.errors = errors
    }
    
    /// 成功の結果
    public static let valid = SettingsValidationResult(isValid: true)
    
    /// エラーがある結果を作成
    public static func invalid(errors: [SettingsValidationError]) -> SettingsValidationResult {
        return SettingsValidationResult(isValid: false, errors: errors)
    }
    
    /// 警告がある結果を作成
    public static func withWarnings(_ warnings: [SettingsValidationWarning]) -> SettingsValidationResult {
        return SettingsValidationResult(isValid: true, warnings: warnings)
    }
}

/// 設定検証警告
public struct SettingsValidationWarning: Sendable, Equatable {
    public let message: String
    public let field: String?
    public let code: String?
    
    public init(message: String, field: String? = nil, code: String? = nil) {
        self.message = message
        self.field = field
        self.code = code
    }
}

/// 設定検証エラー
public struct SettingsValidationError: Sendable, Equatable {
    public let message: String
    public let field: String?
    public let code: String?
    
    public init(message: String, field: String? = nil, code: String? = nil) {
        self.message = message
        self.field = field
        self.code = code
    }
}