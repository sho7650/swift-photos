import Foundation
import AppKit

// MARK: - Unified Cache Protocol

/// Unified protocol that consolidates functionality from PhotoCache, ImageCacheRepositoryProtocol, and LRU features
public protocol UnifiedImageCacheProtocol: Sendable {
    // MARK: - Basic Cache Operations (from PhotoCache)
    func getCachedImage(for imageURL: ImageURL) async -> SendableImage?
    func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) async
    func clearCache() async
    func getCacheStatistics() async -> CacheStatistics
    
    // MARK: - Repository-style Operations (from ImageCacheRepositoryProtocol)
    func get(_ key: ImageCacheKey) async -> SendableImage?
    func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async
    func remove(_ key: ImageCacheKey) async
    func removeAll() async
    func contains(_ key: ImageCacheKey) async -> Bool
    
    // MARK: - Batch Operations
    func getMultiple(_ keys: [ImageCacheKey]) async -> [ImageCacheKey: SendableImage]
    func setMultiple(_ items: [(key: ImageCacheKey, value: SendableImage, cost: Int?)]) async
    func removeMultiple(_ keys: [ImageCacheKey]) async
    
    // MARK: - Advanced Features
    func setLimits(countLimit: Int?, totalCostLimit: Int?) async
    func performCleanup(targetReduction: Double) async
    func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async
    func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async
    
    // MARK: - Quality and Size Management
    func cacheThumbnail(_ image: SendableImage, for originalKey: ImageCacheKey, size: CGSize) async
    func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage?
    func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async
    func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage?
    
    // MARK: - Memory Management
    func handleMemoryPressure() async
    func getCurrentMemoryUsage() async -> Int
    func getMemoryPressureLevel() async -> MemoryPressureLevel
}

// MARK: - Cache Strategy Protocol

/// Strategy for different caching approaches (NSCache, LRU, Hybrid)
public protocol CacheStrategy: Sendable {
    func store(_ image: SendableImage, for key: String, cost: Int) async
    func retrieve(for key: String) async -> SendableImage?
    func remove(for key: String) async
    func clear() async
    func handleMemoryPressure() async
    func getStatistics() async -> CacheStrategyStatistics
    func setLimits(countLimit: Int?, totalCostLimit: Int?) async
}

// MARK: - Supporting Types

public struct CacheStrategyStatistics: Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let currentCount: Int
    public let memoryUsageMB: Int
    public let evictionCount: Int
    
    public var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
    
    public init(hitCount: Int, missCount: Int, currentCount: Int, memoryUsageMB: Int, evictionCount: Int = 0) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.currentCount = currentCount
        self.memoryUsageMB = memoryUsageMB
        self.evictionCount = evictionCount
    }
}

public enum CacheStrategyType: Sendable {
    case nsCache           // Simple NSCache-based (good for basic needs)
    case lru              // LRU eviction (predictable memory management)
    case hybrid           // Combines NSCache with LRU features
    case adaptive         // Switches strategy based on memory pressure
}

/// Extended cache management configuration for UnifiedImageCache
public struct UnifiedCacheConfiguration: Sendable {
    public let strategy: CacheStrategyType
    public let countLimit: Int
    public let totalCostLimitMB: Int
    public let enableMemoryPressureHandling: Bool
    public let memoryPressureThreshold: Double
    public let cleanupInterval: TimeInterval
    public let enableQualityBasedCaching: Bool
    public let enableThumbnailCaching: Bool
    
    public static let `default` = UnifiedCacheConfiguration(
        strategy: .hybrid,
        countLimit: 200,
        totalCostLimitMB: 500,
        enableMemoryPressureHandling: true,
        memoryPressureThreshold: 0.75,
        cleanupInterval: 30.0,
        enableQualityBasedCaching: true,
        enableThumbnailCaching: true
    )
    
    public static let performance = UnifiedCacheConfiguration(
        strategy: .adaptive,
        countLimit: 500,
        totalCostLimitMB: 1000,
        enableMemoryPressureHandling: true,
        memoryPressureThreshold: 0.85,
        cleanupInterval: 15.0,
        enableQualityBasedCaching: true,
        enableThumbnailCaching: true
    )
    
    public static let minimal = UnifiedCacheConfiguration(
        strategy: .nsCache,
        countLimit: 50,
        totalCostLimitMB: 100,
        enableMemoryPressureHandling: true,
        memoryPressureThreshold: 0.5,
        cleanupInterval: 60.0,
        enableQualityBasedCaching: false,
        enableThumbnailCaching: false
    )
    
    public init(
        strategy: CacheStrategyType = .hybrid,
        countLimit: Int = 200,
        totalCostLimitMB: Int = 500,
        enableMemoryPressureHandling: Bool = true,
        memoryPressureThreshold: Double = 0.75,
        cleanupInterval: TimeInterval = 30.0,
        enableQualityBasedCaching: Bool = true,
        enableThumbnailCaching: Bool = true
    ) {
        self.strategy = strategy
        self.countLimit = countLimit
        self.totalCostLimitMB = totalCostLimitMB
        self.enableMemoryPressureHandling = enableMemoryPressureHandling
        self.memoryPressureThreshold = memoryPressureThreshold
        self.cleanupInterval = cleanupInterval
        self.enableQualityBasedCaching = enableQualityBasedCaching
        self.enableThumbnailCaching = enableThumbnailCaching
    }
}

/// Cache operation context
public struct CacheContext: Sendable {
    public let priority: CachePriority
    public let quality: ImageQuality
    public let targetSize: CGSize?
    public let transformations: [ImageTransformation]
    public let isPreload: Bool
    public let isThumbnail: Bool
    
    public init(
        priority: CachePriority = .normal,
        quality: ImageQuality = .full,
        targetSize: CGSize? = nil,
        transformations: [ImageTransformation] = [],
        isPreload: Bool = false,
        isThumbnail: Bool = false
    ) {
        self.priority = priority
        self.quality = quality
        self.targetSize = targetSize
        self.transformations = transformations
        self.isPreload = isPreload
        self.isThumbnail = isThumbnail
    }
}

// MARK: - Cache Event Protocol

/// Protocol for cache event notifications
public protocol CacheEventDelegate: Sendable {
    func cacheDidEvictItem(key: String, reason: CacheEvictionReason) async
    func cacheDidReachMemoryPressure(level: MemoryPressureLevel) async
    func cacheDidPerformCleanup(itemsRemoved: Int, memoryFreed: Int) async
}

public enum CacheEvictionReason: Sendable {
    case memoryPressure
    case capacityLimit
    case expiration
    case manual
    case lowPriority
}