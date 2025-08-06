//
//  UnifiedImageCacheBridge.swift
//  Swift Photos
//
//  Bridge adapter to make UnifiedImageCacheRepository compatible with legacy PhotoCache protocol
//  Phase 4.2a: Service Layer Simplification - Cache Consolidation Bridge
//

import Foundation
import AppKit

/// Bridge adapter that makes UnifiedImageCacheRepository compatible with PhotoCache protocol
/// This allows gradual migration from legacy ImageCache to UnifiedImageCacheRepository
public final class UnifiedImageCacheBridge: PhotoCache, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let unifiedCache: UnifiedImageCacheRepository
    
    // MARK: - Initialization
    
    public init(configuration: UnifiedImageCacheConfiguration = .default) {
        self.unifiedCache = UnifiedImageCacheRepository(
            countLimit: configuration.countLimit,
            totalCostLimit: configuration.totalCostLimit
        )
        ProductionLogger.lifecycle("UnifiedImageCacheBridge: Initialized as PhotoCache adapter")
    }
    
    public convenience init(countLimit: Int = 50, totalCostLimit: Int = 100_000_000) {
        let config = UnifiedImageCacheConfiguration(
            countLimit: countLimit,
            totalCostLimit: totalCostLimit
        )
        self.init(configuration: config)
    }
    
    // MARK: - PhotoCache Protocol Implementation
    
    public func getCachedImage(for imageURL: ImageURL) async -> SendableImage? {
        // Convert ImageURL to ImageCacheKey for UnifiedImageCacheRepository
        let cacheKey = ImageCacheKey(
            url: imageURL.url,
            size: nil,
            quality: .full,
            transformations: []
        )
        
        return await unifiedCache.get(cacheKey)
    }
    
    public func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) async {
        // Convert ImageURL to ImageCacheKey for UnifiedImageCacheRepository
        let cacheKey = ImageCacheKey(
            url: imageURL.url,
            size: nil,
            quality: .full,
            transformations: []
        )
        
        await unifiedCache.set(image, for: cacheKey, cost: nil)
    }
    
    public func clearCache() async {
        await unifiedCache.removeAll()
    }
    
    public func getCacheStatistics() async -> CacheStatistics {
        let unifiedStats = await unifiedCache.statistics()
        
        // Convert UnifiedImageCacheStatistics to CacheStatistics
        return CacheStatistics(
            hitCount: unifiedStats.hitCount,
            missCount: unifiedStats.missCount,
            totalCost: unifiedStats.totalCost,
            currentCount: unifiedStats.currentCount
        )
    }
    
    // MARK: - Advanced Features (Optional)
    
    /// Access to the underlying unified cache for advanced operations
    public var advancedCache: UnifiedImageCacheRepository {
        return unifiedCache
    }
    
    /// Perform memory cleanup
    public func performCleanup(targetReduction: Double = 0.3) async {
        await unifiedCache.performCleanup(targetReduction: targetReduction)
    }
    
    /// Handle memory pressure (alias for performCleanup)
    public func handleMemoryPressure() async {
        await performCleanup(targetReduction: 0.5)
    }
}

// MARK: - Factory for Creating Bridge Instances

/// Factory for creating UnifiedImageCacheBridge instances with common configurations
public enum UnifiedImageCacheBridgeFactory {
    
    /// Create a bridge with default PhotoCache-compatible settings
    public static func createDefault() -> UnifiedImageCacheBridge {
        return UnifiedImageCacheBridge(
            countLimit: 50,
            totalCostLimit: 100_000_000
        )
    }
    
    /// Create a bridge optimized for slideshow performance
    public static func createForSlideshow() -> UnifiedImageCacheBridge {
        let config = UnifiedImageCacheConfiguration(
            countLimit: 200,
            totalCostLimit: 500_000_000 // 500MB
        )
        return UnifiedImageCacheBridge(configuration: config)
    }
    
    /// Create a bridge optimized for low memory usage
    public static func createMemoryOptimized() -> UnifiedImageCacheBridge {
        let config = UnifiedImageCacheConfiguration(
            countLimit: 25,
            totalCostLimit: 50_000_000 // 50MB
        )
        return UnifiedImageCacheBridge(configuration: config)
    }
    
    /// Create a bridge with high performance settings
    public static func createHighPerformance() -> UnifiedImageCacheBridge {
        let config = UnifiedImageCacheConfiguration(
            countLimit: 500,
            totalCostLimit: 1_000_000_000 // 1GB
        )
        return UnifiedImageCacheBridge(configuration: config)
    }
}

