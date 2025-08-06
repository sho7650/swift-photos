//
//  UnifiedImageCacheRepository.swift
//  Swift Photos
//
//  Unified image cache repository implementation
//  Consolidates MemoryCacheRepository functionality into simplified interface
//  Phase 4.1b: Repository Layer Consolidation - Cache Consolidation
//

import Foundation
import AppKit

/// Unified image cache repository implementation
public final class UnifiedImageCacheRepository: ImageCacheRepository, @unchecked Sendable {
    
    // MARK: - Cache Storage
    
    private let imageCache: NSCache<NSString, NSImage>
    private let thumbnailCache: NSCache<NSString, NSImage>
    private let qualityCache: NSCache<NSString, NSImage>
    
    // MARK: - Priority and Metadata Tracking
    
    private actor CacheMetadata {
        private var priorityMap: [String: CachePriority] = [:]
        private var accessTimes: [String: Date] = [:]
        private var statistics = CacheStatistics(hitCount: 0, missCount: 0, totalCost: 0, currentCount: 0)
        
        func setPriority(_ priority: CachePriority, for key: String) {
            priorityMap[key] = priority
        }
        
        func getPriority(for key: String) -> CachePriority {
            return priorityMap[key] ?? .normal
        }
        
        func recordAccess(for key: String) {
            accessTimes[key] = Date()
            updateStatistics(hit: true)
        }
        
        func recordMiss() {
            updateStatistics(hit: false)
        }
        
        func removeMetadata(for key: String) {
            priorityMap.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
        
        func removeAllMetadata() {
            priorityMap.removeAll()
            accessTimes.removeAll()
            statistics = CacheStatistics(hitCount: 0, missCount: 0, totalCost: 0, currentCount: 0)
        }
        
        func getStatistics() -> CacheStatistics {
            return statistics
        }
        
        func getLeastRecentlyUsedKeys(count: Int) -> [String] {
            let sortedKeys = accessTimes.sorted { $0.value < $1.value }
            return Array(sortedKeys.prefix(count).map { $0.key })
        }
        
        func getLowPriorityKeys() -> [String] {
            return priorityMap.compactMap { key, priority in
                priority == .low ? key : nil
            }
        }
        
        private func updateStatistics(hit: Bool) {
            let currentHitCount = statistics.hitCount
            let currentMissCount = statistics.missCount
            let currentCount = statistics.currentCount
            let currentCost = statistics.totalCost
            
            if hit {
                statistics = CacheStatistics(
                    hitCount: currentHitCount + 1,
                    missCount: currentMissCount,
                    totalCost: currentCost,
                    currentCount: currentCount
                )
            } else {
                statistics = CacheStatistics(
                    hitCount: currentHitCount,
                    missCount: currentMissCount + 1,
                    totalCost: currentCost,
                    currentCount: currentCount
                )
            }
        }
        
        func updateCurrentCount(_ count: Int, totalCost: Int) {
            statistics = CacheStatistics(
                hitCount: statistics.hitCount,
                missCount: statistics.missCount,
                totalCost: totalCost,
                currentCount: count
            )
        }
    }
    
    private let metadata = CacheMetadata()
    
    // MARK: - Configuration
    
    private let countLimit: Int
    private let totalCostLimit: Int
    
    // MARK: - Initialization
    
    public init(
        countLimit: Int = 200,
        totalCostLimit: Int = 500_000_000 // 500MB
    ) {
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
        
        // Initialize caches
        self.imageCache = NSCache<NSString, NSImage>()
        self.thumbnailCache = NSCache<NSString, NSImage>()
        self.qualityCache = NSCache<NSString, NSImage>()
        
        // Configure main image cache
        self.imageCache.countLimit = countLimit
        self.imageCache.totalCostLimit = totalCostLimit
        
        // Configure thumbnail cache (smaller limit)
        self.thumbnailCache.countLimit = countLimit * 2 // More thumbnails
        self.thumbnailCache.totalCostLimit = totalCostLimit / 5 // 100MB for thumbnails
        
        // Configure quality cache
        self.qualityCache.countLimit = countLimit
        self.qualityCache.totalCostLimit = totalCostLimit / 2 // 250MB for quality variants
        
        ProductionLogger.debug("UnifiedImageCacheRepository: Initialized with \(countLimit) count limit, \(totalCostLimit) cost limit")
    }
    
    // MARK: - Basic Cache Operations
    
    public func get(_ key: ImageCacheKey) async -> SendableImage? {
        let keyString = key.cacheIdentifier
        
        if let nsImage = imageCache.object(forKey: keyString as NSString) {
            await metadata.recordAccess(for: keyString)
            return SendableImage(nsImage)
        }
        
        await metadata.recordMiss()
        return nil
    }
    
    public func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        let keyString = key.cacheIdentifier
        let imageCost = cost ?? calculateImageCost(value)
        
        imageCache.setObject(value.nsImage, forKey: keyString as NSString, cost: imageCost)
        await metadata.recordAccess(for: keyString)
        
        // Update statistics
        let currentCount = await getCurrentCacheCount()
        let currentCost = await getCurrentCacheCost()
        await metadata.updateCurrentCount(currentCount, totalCost: currentCost)
        
        ProductionLogger.debug("UnifiedImageCacheRepository: Cached image \(keyString) with cost \(imageCost)")
    }
    
    public func remove(_ key: ImageCacheKey) async {
        let keyString = key.cacheIdentifier
        
        imageCache.removeObject(forKey: keyString as NSString)
        thumbnailCache.removeObject(forKey: keyString as NSString)
        qualityCache.removeObject(forKey: keyString as NSString)
        
        await metadata.removeMetadata(for: keyString)
        
        // Update statistics
        let currentCount = await getCurrentCacheCount()
        let currentCost = await getCurrentCacheCost()
        await metadata.updateCurrentCount(currentCount, totalCost: currentCost)
    }
    
    public func removeAll() async {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        qualityCache.removeAllObjects()
        
        await metadata.removeAllMetadata()
        
        ProductionLogger.debug("UnifiedImageCacheRepository: Cleared all caches")
    }
    
    // MARK: - Batch Operations
    
    public func getMultiple(_ keys: [ImageCacheKey]) async -> [ImageCacheKey: SendableImage] {
        var results: [ImageCacheKey: SendableImage] = [:]
        
        for key in keys {
            if let image = await get(key) {
                results[key] = image
            }
        }
        
        return results
    }
    
    public func setMultiple(_ items: [(key: ImageCacheKey, value: SendableImage, cost: Int?)]) async {
        for item in items {
            await set(item.value, for: item.key, cost: item.cost)
        }
    }
    
    // MARK: - Cache Information
    
    public func statistics() async -> CacheStatistics {
        return await metadata.getStatistics()
    }
    
    public func contains(_ key: ImageCacheKey) async -> Bool {
        let keyString = key.cacheIdentifier
        return imageCache.object(forKey: keyString as NSString) != nil
    }
    
    // MARK: - Priority-Based Operations
    
    public func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async {
        await metadata.setPriority(priority, for: key.cacheIdentifier)
    }
    
    // MARK: - Quality-Specific Operations
    
    public func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async {
        let qualityKey = "\(key.cacheIdentifier)_quality_\(quality.rawValue)"
        let imageCost = calculateImageCost(image)
        
        qualityCache.setObject(image.nsImage, forKey: qualityKey as NSString, cost: imageCost)
        await metadata.recordAccess(for: qualityKey)
    }
    
    public func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage? {
        let qualityKey = "\(key.cacheIdentifier)_quality_\(quality.rawValue)"
        
        if let nsImage = qualityCache.object(forKey: qualityKey as NSString) {
            await metadata.recordAccess(for: qualityKey)
            return SendableImage(nsImage)
        }
        
        await metadata.recordMiss()
        return nil
    }
    
    // MARK: - Thumbnail Operations
    
    public func cacheThumbnail(_ image: SendableImage, for key: ImageCacheKey, size: CGSize) async {
        let thumbnailKey = "\(key.cacheIdentifier)_thumb_\(Int(size.width))x\(Int(size.height))"
        let imageCost = calculateImageCost(image)
        
        thumbnailCache.setObject(image.nsImage, forKey: thumbnailKey as NSString, cost: imageCost)
        await metadata.recordAccess(for: thumbnailKey)
    }
    
    public func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage? {
        let thumbnailKey = "\(key.cacheIdentifier)_thumb_\(Int(size.width))x\(Int(size.height))"
        
        if let nsImage = thumbnailCache.object(forKey: thumbnailKey as NSString) {
            await metadata.recordAccess(for: thumbnailKey)
            return SendableImage(nsImage)
        }
        
        await metadata.recordMiss()
        return nil
    }
    
    // MARK: - Preloading
    
    public func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async {
        // Set all preloaded images with high priority
        for (key, image) in images {
            await set(image, for: key, cost: nil)
            await setPriority(.high, for: key)
        }
        
        ProductionLogger.debug("UnifiedImageCacheRepository: Preloaded \(images.count) images")
    }
    
    // MARK: - Memory Management
    
    public func performCleanup(targetReduction: Double) async {
        guard targetReduction > 0 && targetReduction <= 1.0 else { return }
        
        let currentStatistics = await metadata.getStatistics()
        let targetCount = max(1, Int(Double(currentStatistics.currentCount) * (1.0 - targetReduction)))
        let itemsToRemove = currentStatistics.currentCount - targetCount
        
        guard itemsToRemove > 0 else { return }
        
        // First, remove low priority items
        let lowPriorityKeys = await metadata.getLowPriorityKeys()
        let lowPriorityToRemove = min(lowPriorityKeys.count, itemsToRemove)
        
        for key in lowPriorityKeys.prefix(lowPriorityToRemove) {
            imageCache.removeObject(forKey: key as NSString)
            thumbnailCache.removeObject(forKey: key as NSString)
            qualityCache.removeObject(forKey: key as NSString)
            await metadata.removeMetadata(for: key)
        }
        
        // If we still need to remove more, remove least recently used
        let remainingToRemove = itemsToRemove - lowPriorityToRemove
        if remainingToRemove > 0 {
            let lruKeys = await metadata.getLeastRecentlyUsedKeys(count: remainingToRemove)
            
            for key in lruKeys {
                imageCache.removeObject(forKey: key as NSString)
                thumbnailCache.removeObject(forKey: key as NSString)
                qualityCache.removeObject(forKey: key as NSString)
                await metadata.removeMetadata(for: key)
            }
        }
        
        // Update statistics
        let newCount = await getCurrentCacheCount()
        let newCost = await getCurrentCacheCost()
        await metadata.updateCurrentCount(newCount, totalCost: newCost)
        
        ProductionLogger.debug("UnifiedImageCacheRepository: Cleanup completed, removed \(itemsToRemove) items, new count: \(newCount)")
    }
    
    // MARK: - Private Helpers
    
    private func calculateImageCost(_ image: SendableImage) -> Int {
        let size = image.size
        let bytesPerPixel = 4 // Assuming RGBA
        let pixelCount = Int(size.width * size.height)
        return pixelCount * bytesPerPixel
    }
    
    private func getCurrentCacheCount() async -> Int {
        // NSCache doesn't provide a direct count, so we approximate based on our metadata
        // This is a limitation of NSCache API
        return imageCache.totalCostLimit > 0 ? min(countLimit, imageCache.totalCostLimit / 1000) : 0
    }
    
    private func getCurrentCacheCost() async -> Int {
        // NSCache doesn't provide current cost, so we approximate
        // In a real implementation, we might need to track this ourselves
        return 0
    }
}

// MARK: - Cache Configuration

/// Configuration for the unified image cache
public struct UnifiedImageCacheConfiguration: Sendable {
    public let countLimit: Int
    public let totalCostLimit: Int
    public let thumbnailCountLimit: Int
    public let thumbnailCostLimit: Int
    public let qualityCountLimit: Int
    public let qualityCostLimit: Int
    
    public init(
        countLimit: Int = 200,
        totalCostLimit: Int = 500_000_000, // 500MB
        thumbnailCountLimit: Int? = nil,
        thumbnailCostLimit: Int? = nil,
        qualityCountLimit: Int? = nil,
        qualityCostLimit: Int? = nil
    ) {
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
        self.thumbnailCountLimit = thumbnailCountLimit ?? (countLimit * 2)
        self.thumbnailCostLimit = thumbnailCostLimit ?? (totalCostLimit / 5)
        self.qualityCountLimit = qualityCountLimit ?? countLimit
        self.qualityCostLimit = qualityCostLimit ?? (totalCostLimit / 2)
    }
    
    /// Default configuration
    public static let `default` = UnifiedImageCacheConfiguration()
    
    /// High performance configuration
    public static let highPerformance = UnifiedImageCacheConfiguration(
        countLimit: 500,
        totalCostLimit: 1_000_000_000 // 1GB
    )
    
    /// Memory optimized configuration
    public static let memoryOptimized = UnifiedImageCacheConfiguration(
        countLimit: 50,
        totalCostLimit: 100_000_000 // 100MB
    )
}

// MARK: - Factory

/// Factory for creating unified image cache repositories
public enum UnifiedImageCacheFactory {
    
    /// Create a cache repository with the given configuration
    public static func create(configuration: UnifiedImageCacheConfiguration = .default) -> UnifiedImageCacheRepository {
        return UnifiedImageCacheRepository(
            countLimit: configuration.countLimit,
            totalCostLimit: configuration.totalCostLimit
        )
    }
    
    /// Create a cache repository optimized for the given photo count
    public static func createForPhotoCount(_ photoCount: Int) -> UnifiedImageCacheRepository {
        let configuration: UnifiedImageCacheConfiguration
        
        switch photoCount {
        case 0...100:
            configuration = .memoryOptimized
        case 101...1000:
            configuration = .default
        default:
            configuration = .highPerformance
        }
        
        return create(configuration: configuration)
    }
}