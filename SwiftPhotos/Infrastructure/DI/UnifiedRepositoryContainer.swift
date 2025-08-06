//
//  UnifiedRepositoryContainer.swift
//  Swift Photos
//
//  Simplified repository container replacing the complex actor-based RepositoryContainer
//  Phase 4.1c: Repository Layer Consolidation - Simplified DI Container
//

import Foundation

/// Simplified dependency injection container for repositories
/// Replaces the complex actor-based RepositoryContainer with straightforward implementation
public final class UnifiedRepositoryContainer: @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// Shared instance holder with proper concurrency safety
    private static let sharedHolder = SharedHolder()
    
    private final class SharedHolder: @unchecked Sendable {
        private var _instance: UnifiedRepositoryContainer?
        private let lock = NSLock()
        
        var instance: UnifiedRepositoryContainer? {
            lock.withLock { _instance }
        }
        
        func setInstance(_ instance: UnifiedRepositoryContainer) {
            lock.withLock { _instance = instance }
        }
    }
    
    public static var shared: UnifiedRepositoryContainer {
        guard let instance = sharedHolder.instance else {
            fatalError("UnifiedRepositoryContainer: Must call configure(secureFileAccess:) before using shared instance")
        }
        return instance
    }
    
    /// Configure the shared instance with SecureFileAccess
    /// Must be called from @MainActor context due to SecureFileAccess requirements
    @MainActor
    public static func configure(secureFileAccess: SecureFileAccess) {
        let configuration = UnifiedRepositoryConfiguration.default(secureFileAccess: secureFileAccess)
        let container = UnifiedRepositoryContainer(configuration: configuration)
        sharedHolder.setInstance(container)
        ProductionLogger.info("UnifiedRepositoryContainer: Shared instance configured")
    }
    
    // MARK: - Repository Instances
    
    private var _imageRepository: UnifiedImageRepository?
    private var _cacheRepository: ImageCacheRepository?
    private var _settingsRepository: (any SettingsRepositoryProtocol)?
    
    // MARK: - Configuration
    
    private let configuration: UnifiedRepositoryConfiguration
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    private init(configuration: UnifiedRepositoryConfiguration) {
        self.configuration = configuration
        ProductionLogger.info("UnifiedRepositoryContainer: Initialized with configuration")
    }
    
    // MARK: - Repository Access
    
    /// Get the unified image repository
    public func imageRepository() -> UnifiedImageRepository {
        lock.lock()
        defer { lock.unlock() }
        
        if let repository = _imageRepository {
            return repository
        }
        
        let repository = createImageRepository()
        _imageRepository = repository
        ProductionLogger.debug("UnifiedRepositoryContainer: Created UnifiedImageRepository")
        return repository
    }
    
    /// Get the image cache repository
    public func cacheRepository() -> ImageCacheRepository {
        lock.lock()
        defer { lock.unlock() }
        
        if let repository = _cacheRepository {
            return repository
        }
        
        let repository = createCacheRepository()
        _cacheRepository = repository
        ProductionLogger.debug("UnifiedRepositoryContainer: Created ImageCacheRepository")
        return repository
    }
    
    /// Get the settings repository
    public func settingsRepository() -> any SettingsRepositoryProtocol {
        lock.lock()
        defer { lock.unlock() }
        
        if let repository = _settingsRepository {
            return repository
        }
        
        let repository = createSettingsRepository()
        _settingsRepository = repository
        ProductionLogger.debug("UnifiedRepositoryContainer: Created SettingsRepository")
        return repository
    }
    
    // MARK: - Factory Methods
    
    private func createImageRepository() -> UnifiedImageRepository {
        // SecureFileAccess must be provided in configuration due to @MainActor requirements
        guard let fileAccess = configuration.secureFileAccess else {
            fatalError("UnifiedRepositoryContainer: SecureFileAccess must be provided in configuration")
        }
        
        let imageLoader = configuration.imageLoader ?? ImageLoader()
        let cache = configuration.useImageCache ? cacheRepository() : nil
        
        return UnifiedFileSystemImageRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            cache: cache,
            localizationService: configuration.localizationService,
            supportedImageFormats: configuration.supportedImageFormats,
            maxConcurrentLoads: configuration.maxConcurrentLoads
        )
    }
    
    private func createCacheRepository() -> ImageCacheRepository {
        switch configuration.cacheType {
        case .memory:
            return UnifiedImageCacheRepository(
                countLimit: configuration.cacheCountLimit,
                totalCostLimit: configuration.cacheTotalCostLimit
            )
        case .optimized(let photoCount):
            return UnifiedImageCacheFactory.createForPhotoCount(photoCount)
        }
    }
    
    private func createSettingsRepository() -> any SettingsRepositoryProtocol {
        return UserDefaultsSettingsRepository(
            userDefaults: configuration.userDefaults,
            keyPrefix: configuration.settingsKeyPrefix,
            encoder: configuration.jsonEncoder,
            decoder: configuration.jsonDecoder
        )
    }
    
    // MARK: - Container Management
    
    /// Reset all repositories (useful for testing)
    public func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        
        _imageRepository = nil
        _cacheRepository = nil
        _settingsRepository = nil
        
        ProductionLogger.info("UnifiedRepositoryContainer: All repositories reset")
    }
    
    /// Reset specific repository
    public func resetImageRepository() {
        lock.lock()
        defer { lock.unlock() }
        
        _imageRepository = nil
        ProductionLogger.debug("UnifiedRepositoryContainer: ImageRepository reset")
    }
    
    public func resetCacheRepository() {
        lock.lock()
        defer { lock.unlock() }
        
        _cacheRepository = nil
        ProductionLogger.debug("UnifiedRepositoryContainer: CacheRepository reset")
    }
    
    public func resetSettingsRepository() {
        lock.lock()
        defer { lock.unlock() }
        
        _settingsRepository = nil
        ProductionLogger.debug("UnifiedRepositoryContainer: SettingsRepository reset")
    }
    
    // MARK: - Statistics (Simplified)
    
    /// Get basic statistics for all repositories
    public func getStatistics() -> UnifiedRepositoryStatistics {
        var imageMetrics: RepositoryMetrics?
        var cacheStatistics: CacheStatistics?
        
        // Get image repository metrics if available
        if let imageRepo = _imageRepository {
            Task {
                imageMetrics = await imageRepo.getMetrics()
            }
        }
        
        // Get cache statistics if available
        if let cacheRepo = _cacheRepository {
            Task {
                cacheStatistics = await cacheRepo.statistics()
            }
        }
        
        return UnifiedRepositoryStatistics(
            imageMetrics: imageMetrics,
            cacheStatistics: cacheStatistics,
            collectedAt: Date()
        )
    }
}

// MARK: - Configuration

/// Simplified repository configuration
public struct UnifiedRepositoryConfiguration: Sendable {
    
    // MARK: - Repository Configuration
    
    public let cacheType: CacheType
    public let useImageCache: Bool
    
    // MARK: - Dependencies
    
public let secureFileAccess: SecureFileAccess?
    public let imageLoader: ImageLoader?
    public let localizationService: LocalizationService?
    public let userDefaults: UserDefaults
    public let jsonEncoder: JSONEncoder?
    public let jsonDecoder: JSONDecoder?
    
    // MARK: - Cache Configuration
    
    public let cacheCountLimit: Int
    public let cacheTotalCostLimit: Int
    
    // MARK: - Performance Configuration
    
    public let maxConcurrentLoads: Int
    public let supportedImageFormats: Set<String>
    public let settingsKeyPrefix: String
    
    public init(
        cacheType: CacheType = .memory,
        useImageCache: Bool = true,
        secureFileAccess: SecureFileAccess,
        imageLoader: ImageLoader? = nil,
        localizationService: LocalizationService? = nil,
        userDefaults: UserDefaults = .standard,
        jsonEncoder: JSONEncoder? = nil,
        jsonDecoder: JSONDecoder? = nil,
        cacheCountLimit: Int = 200,
        cacheTotalCostLimit: Int = 500_000_000, // 500MB
        maxConcurrentLoads: Int = 10,
        supportedImageFormats: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "webp"],
        settingsKeyPrefix: String = "SwiftPhotos"
    ) {
        self.cacheType = cacheType
        self.useImageCache = useImageCache
        self.secureFileAccess = secureFileAccess
        self.imageLoader = imageLoader
        self.localizationService = localizationService
        self.userDefaults = userDefaults
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
        self.cacheCountLimit = cacheCountLimit
        self.cacheTotalCostLimit = cacheTotalCostLimit
        self.maxConcurrentLoads = maxConcurrentLoads
        self.supportedImageFormats = supportedImageFormats
        self.settingsKeyPrefix = settingsKeyPrefix
    }
    
    // MARK: - Cache Type
    
    public enum CacheType: Sendable {
        case memory
        case optimized(photoCount: Int)
    }
    
    // MARK: - Predefined Configurations
    
    
    
    
    
    /// Create default configuration with SecureFileAccess
    public static func `default`(secureFileAccess: SecureFileAccess) -> UnifiedRepositoryConfiguration {
        return UnifiedRepositoryConfiguration(secureFileAccess: secureFileAccess)
    }
    
    /// Create high performance configuration with SecureFileAccess
    public static func highPerformance(secureFileAccess: SecureFileAccess) -> UnifiedRepositoryConfiguration {
        return UnifiedRepositoryConfiguration(
            secureFileAccess: secureFileAccess,
            cacheCountLimit: 500,
            cacheTotalCostLimit: 1_000_000_000, // 1GB
            maxConcurrentLoads: 20
        )
    }
    
    /// Create memory optimized configuration with SecureFileAccess
    public static func memoryOptimized(secureFileAccess: SecureFileAccess) -> UnifiedRepositoryConfiguration {
        return UnifiedRepositoryConfiguration(
            secureFileAccess: secureFileAccess,
            cacheCountLimit: 50,
            cacheTotalCostLimit: 100_000_000, // 100MB
            maxConcurrentLoads: 5
        )
    }
    
    /// Create testing configuration with SecureFileAccess
    public static func testing(secureFileAccess: SecureFileAccess) -> UnifiedRepositoryConfiguration {
        return UnifiedRepositoryConfiguration(
            cacheType: .memory,
            useImageCache: false,
            secureFileAccess: secureFileAccess,
            userDefaults: UserDefaults(suiteName: "TestSuite") ?? .standard,
            cacheCountLimit: 10,
            cacheTotalCostLimit: 10_000_000, // 10MB
            maxConcurrentLoads: 2,
            settingsKeyPrefix: "TestSwiftPhotos"
        )
    }
    
    /// Configuration optimized for specific photo count
    public static func optimized(for photoCount: Int, secureFileAccess: SecureFileAccess) -> UnifiedRepositoryConfiguration {
        let cacheType: CacheType = .optimized(photoCount: photoCount)
        
        switch photoCount {
        case 0...100:
            return UnifiedRepositoryConfiguration(
                cacheType: cacheType,
                useImageCache: true,
                secureFileAccess: secureFileAccess,
                cacheCountLimit: 50,
                cacheTotalCostLimit: 100_000_000, // 100MB
                maxConcurrentLoads: 5
            )
        case 101...1000:
            return UnifiedRepositoryConfiguration(
                cacheType: cacheType,
                useImageCache: true,
                secureFileAccess: secureFileAccess,
                cacheCountLimit: 200,
                cacheTotalCostLimit: 500_000_000, // 500MB
                maxConcurrentLoads: 10
            )
        default:
            return UnifiedRepositoryConfiguration(
                cacheType: cacheType,
                useImageCache: true,
                secureFileAccess: secureFileAccess,
                cacheCountLimit: 1000,
                cacheTotalCostLimit: 2_000_000_000, // 2GB
                maxConcurrentLoads: 20
            )
        }
    }
}

// MARK: - Statistics

/// Simplified repository statistics
public struct UnifiedRepositoryStatistics: Sendable {
    public let imageMetrics: RepositoryMetrics?
    public let cacheStatistics: CacheStatistics?
    public let collectedAt: Date
    
    public init(
        imageMetrics: RepositoryMetrics?,
        cacheStatistics: CacheStatistics?,
        collectedAt: Date
    ) {
        self.imageMetrics = imageMetrics
        self.cacheStatistics = cacheStatistics
        self.collectedAt = collectedAt
    }
    
    /// Overall health indicator
    public var isHealthy: Bool {
        // Simple health check - no repositories with high error rates
        if let metrics = imageMetrics {
            return metrics.errorRate < 0.1 // Less than 10% error rate
        }
        return true
    }
    
    /// Summary statistics
    public var summary: [String: String] {
        var summary: [String: String] = [:]
        summary["collectedAt"] = ISO8601DateFormatter().string(from: collectedAt)
        
        if let metrics = imageMetrics {
            summary["image.operations"] = "\(metrics.operationCount)"
            summary["image.successRate"] = String(format: "%.1f%%", metrics.successRate * 100)
            summary["image.avgResponseTime"] = String(format: "%.3fs", metrics.averageResponseTime)
        }
        
        if let cache = cacheStatistics {
            summary["cache.hitRate"] = String(format: "%.1f%%", cache.hitRate * 100)
            summary["cache.currentCount"] = "\(cache.currentCount)"
        }
        
        return summary
    }
}

// MARK: - Factory Extensions

public extension UnifiedRepositoryContainer {
    
    /// Create a container configured for a specific photo count
    static func create(for photoCount: Int, secureFileAccess: SecureFileAccess) -> UnifiedRepositoryContainer {
        let configuration = UnifiedRepositoryConfiguration.optimized(for: photoCount, secureFileAccess: secureFileAccess)
        return UnifiedRepositoryContainer(configuration: configuration)
    }
    
    /// Create a container with custom configuration
    static func create(configuration: UnifiedRepositoryConfiguration) -> UnifiedRepositoryContainer {
        return UnifiedRepositoryContainer(configuration: configuration)
    }
}

// MARK: - Migration Support

/// Migration helper for transitioning from old RepositoryContainer
public extension UnifiedRepositoryContainer {
    
    /// Create unified container from legacy configuration
    static func migrate(from legacyContainer: RepositoryContainer, secureFileAccess: SecureFileAccess) async -> UnifiedRepositoryContainer {
        // Note: This would require accessing the old container's configuration
        // For now, we create a default unified container
        ProductionLogger.info("UnifiedRepositoryContainer: Migrating from legacy RepositoryContainer")
        let configuration = UnifiedRepositoryConfiguration.default(secureFileAccess: secureFileAccess)
        return UnifiedRepositoryContainer(configuration: configuration)
    }
}

// MARK: - Thread Safety Extensions

private extension NSLock {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}