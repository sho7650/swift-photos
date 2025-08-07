import Foundation
import AppKit

// MARK: - NSCache Strategy

/// Simple NSCache-based strategy (consolidates functionality from legacy ImageCache implementation)
public actor NSCacheStrategy: CacheStrategy {
    private let cache = NSCache<NSString, NSImage>()
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    
    private let configuration: UnifiedCacheConfiguration
    
    public init(configuration: UnifiedCacheConfiguration) {
        self.configuration = configuration
        cache.countLimit = configuration.countLimit
        cache.totalCostLimit = configuration.totalCostLimitMB * 1024 * 1024
        cache.name = "SwiftPhotos.UnifiedImageCache.NSCache"
    }
    
    public func store(_ image: SendableImage, for key: String, cost: Int) async {
        let nsKey = NSString(string: key)
        cache.setObject(image.nsImage, forKey: nsKey, cost: cost)
    }
    
    public func retrieve(for key: String) async -> SendableImage? {
        let nsKey = NSString(string: key)
        
        if let cachedImage = cache.object(forKey: nsKey) {
            hitCount += 1
            return SendableImage(cachedImage)
        } else {
            missCount += 1
            return nil
        }
    }
    
    public func remove(for key: String) async {
        let nsKey = NSString(string: key)
        cache.removeObject(forKey: nsKey)
    }
    
    public func clear() async {
        cache.removeAllObjects()
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    public func handleMemoryPressure() async {
        // NSCache handles memory pressure automatically, but we can be more aggressive
        let targetReduction = 0.5 // Remove 50% of items
        let currentCount = cache.countLimit
        cache.countLimit = max(10, Int(Double(currentCount) * (1.0 - targetReduction)))
        
        // Reset to original limit after cleanup
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        cache.countLimit = configuration.countLimit
        
        evictionCount += Int(Double(currentCount) * targetReduction)
    }
    
    public func getStatistics() async -> CacheStrategyStatistics {
        let memoryUsage = estimateMemoryUsage()
        return CacheStrategyStatistics(
            hitCount: hitCount,
            missCount: missCount,
            currentCount: cache.countLimit, // Approximation
            memoryUsageMB: memoryUsage / (1024 * 1024),
            evictionCount: evictionCount
        )
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        if let countLimit = countLimit {
            cache.countLimit = countLimit
        }
        if let totalCostLimit = totalCostLimit {
            cache.totalCostLimit = totalCostLimit * 1024 * 1024
        }
    }
    
    private func estimateMemoryUsage() -> Int {
        // NSCache doesn't provide direct memory usage, so we estimate
        return cache.totalCostLimit / 4 // Rough estimate
    }
}

// MARK: - LRU Strategy

/// LRU eviction strategy (consolidates functionality from legacy LRUImageCache implementation)
public actor LRUCacheStrategy: CacheStrategy {
    private var cache: [String: CacheNode] = [:]
    private var head: CacheNode?
    private var tail: CacheNode?
    private let maxSize: Int
    private var currentSize: Int = 0
    
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    
    private class CacheNode {
        let key: String
        let image: SendableImage
        let size: Int
        var prev: CacheNode?
        var next: CacheNode?
        
        init(key: String, image: SendableImage) {
            self.key = key
            self.image = image
            // Estimate size: width * height * 4 bytes per pixel
            let imageSize = image.size
            self.size = Int(imageSize.width * imageSize.height * 4)
        }
    }
    
    public init(configuration: UnifiedCacheConfiguration) {
        self.maxSize = configuration.totalCostLimitMB * 1024 * 1024
    }
    
    public func store(_ image: SendableImage, for key: String, cost: Int) async {
        // Remove existing node if present
        if let existingNode = cache[key] {
            removeNode(existingNode)
        }
        
        // Create new node
        let node = CacheNode(key: key, image: image)
        
        // Add to front
        addToFront(node: node)
        cache[key] = node
        currentSize += node.size
        
        // Evict if necessary
        while currentSize > maxSize && tail != nil {
            if let nodeToRemove = tail {
                removeNode(nodeToRemove)
                evictionCount += 1
            }
        }
    }
    
    public func retrieve(for key: String) async -> SendableImage? {
        guard let node = cache[key] else {
            missCount += 1
            return nil
        }
        
        // Move to front (mark as recently used)
        removeNode(node)
        addToFront(node: node)
        
        hitCount += 1
        return node.image
    }
    
    public func remove(for key: String) async {
        guard let node = cache[key] else { return }
        removeNode(node)
    }
    
    public func clear() async {
        cache.removeAll()
        head = nil
        tail = nil
        currentSize = 0
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    public func handleMemoryPressure() async {
        // Evict 25% of cache
        let targetSize = maxSize * 3 / 4
        
        while currentSize > targetSize && tail != nil {
            if let nodeToRemove = tail {
                removeNode(nodeToRemove)
                evictionCount += 1
            }
        }
    }
    
    public func getStatistics() async -> CacheStrategyStatistics {
        return CacheStrategyStatistics(
            hitCount: hitCount,
            missCount: missCount,
            currentCount: cache.count,
            memoryUsageMB: currentSize / (1024 * 1024),
            evictionCount: evictionCount
        )
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        // LRU strategy is primarily size-based, so we only handle totalCostLimit
        if let totalCostLimit = totalCostLimit {
            let newMaxSize = totalCostLimit * 1024 * 1024
            // If reducing size, trigger eviction
            if newMaxSize < maxSize {
                while currentSize > newMaxSize && tail != nil {
                    if let nodeToRemove = tail {
                        removeNode(nodeToRemove)
                        evictionCount += 1
                    }
                }
            }
        }
    }
    
    private func addToFront(node: CacheNode) {
        node.next = head
        node.prev = nil
        
        if let currentHead = head {
            currentHead.prev = node
        }
        
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: CacheNode) {
        cache.removeValue(forKey: node.key)
        currentSize -= node.size
        
        if node.prev != nil {
            node.prev?.next = node.next
        } else {
            head = node.next
        }
        
        if node.next != nil {
            node.next?.prev = node.prev
        } else {
            tail = node.prev
        }
    }
}

// MARK: - Hybrid Strategy

/// Hybrid strategy combining NSCache with LRU features
public actor HybridCacheStrategy: CacheStrategy {
    private let nsCache = NSCache<NSString, NSImage>()
    private var accessOrder: [String] = []
    private var accessCounts: [String: Int] = [:]
    private var lastAccess: [String: Date] = [:]
    
    private var hitCount = 0
    private var missCount = 0
    private var evictionCount = 0
    
    private let configuration: UnifiedCacheConfiguration
    private let maxAccessOrderSize: Int
    
    public init(configuration: UnifiedCacheConfiguration) {
        self.configuration = configuration
        self.maxAccessOrderSize = configuration.countLimit * 2
        
        nsCache.countLimit = configuration.countLimit
        nsCache.totalCostLimit = configuration.totalCostLimitMB * 1024 * 1024
        nsCache.name = "SwiftPhotos.UnifiedImageCache.Hybrid"
    }
    
    public func store(_ image: SendableImage, for key: String, cost: Int) async {
        let nsKey = NSString(string: key)
        nsCache.setObject(image.nsImage, forKey: nsKey, cost: cost)
        
        // Track access pattern
        updateAccessPattern(for: key)
    }
    
    public func retrieve(for key: String) async -> SendableImage? {
        let nsKey = NSString(string: key)
        
        if let cachedImage = nsCache.object(forKey: nsKey) {
            hitCount += 1
            updateAccessPattern(for: key)
            return SendableImage(cachedImage)
        } else {
            missCount += 1
            return nil
        }
    }
    
    public func remove(for key: String) async {
        let nsKey = NSString(string: key)
        nsCache.removeObject(forKey: nsKey)
        
        // Clean up tracking data
        accessCounts.removeValue(forKey: key)
        lastAccess.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    public func clear() async {
        nsCache.removeAllObjects()
        accessOrder.removeAll()
        accessCounts.removeAll()
        lastAccess.removeAll()
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    public func handleMemoryPressure() async {
        // Use access patterns to intelligently evict items
        let cutoffDate = Date().addingTimeInterval(-300) // 5 minutes ago
        let itemsToEvict = lastAccess.compactMap { key, date in
            date < cutoffDate ? key : nil
        }
        
        for key in itemsToEvict.prefix(configuration.countLimit / 4) {
            await remove(for: key)
            evictionCount += 1
        }
        
        // Also reduce NSCache limits temporarily
        let originalCount = nsCache.countLimit
        let originalCost = nsCache.totalCostLimit
        
        nsCache.countLimit = originalCount * 3 / 4
        nsCache.totalCostLimit = originalCost * 3 / 4
        
        // Restore limits after cleanup
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        nsCache.countLimit = originalCount
        nsCache.totalCostLimit = originalCost
    }
    
    public func getStatistics() async -> CacheStrategyStatistics {
        let memoryUsage = estimateMemoryUsage()
        return CacheStrategyStatistics(
            hitCount: hitCount,
            missCount: missCount,
            currentCount: accessCounts.count,
            memoryUsageMB: memoryUsage / (1024 * 1024),
            evictionCount: evictionCount
        )
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        if let countLimit = countLimit {
            nsCache.countLimit = countLimit
        }
        if let totalCostLimit = totalCostLimit {
            nsCache.totalCostLimit = totalCostLimit * 1024 * 1024
        }
    }
    
    private func updateAccessPattern(for key: String) {
        // Update access count
        accessCounts[key, default: 0] += 1
        lastAccess[key] = Date()
        
        // Update access order (LRU tracking)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        
        // Limit access order size
        if accessOrder.count > maxAccessOrderSize {
            let itemsToRemove = accessOrder.prefix(accessOrder.count - maxAccessOrderSize)
            for item in itemsToRemove {
                accessOrder.removeAll { $0 == item }
            }
        }
    }
    
    private func estimateMemoryUsage() -> Int {
        return nsCache.totalCostLimit / 3 // Conservative estimate
    }
}

// MARK: - Adaptive Strategy

/// Adaptive strategy that switches between different strategies based on memory pressure
public actor AdaptiveCacheStrategy: CacheStrategy {
    private let nsCacheStrategy: NSCacheStrategy
    private let lruStrategy: LRUCacheStrategy
    private let hybridStrategy: HybridCacheStrategy
    
    private var currentStrategy: CacheStrategy
    private var currentStrategyType: CacheStrategyType
    
    private let configuration: UnifiedCacheConfiguration
    private var memoryPressureLevel: MemoryPressureLevel = .normal
    
    public init(configuration: UnifiedCacheConfiguration) {
        self.configuration = configuration
        
        self.nsCacheStrategy = NSCacheStrategy(configuration: configuration)
        self.lruStrategy = LRUCacheStrategy(configuration: configuration)
        self.hybridStrategy = HybridCacheStrategy(configuration: configuration)
        
        // Start with hybrid strategy
        self.currentStrategy = hybridStrategy
        self.currentStrategyType = CacheStrategyType.hybrid
        
        // Start memory monitoring
        Task {
            await startMemoryMonitoring()
        }
    }
    
    public func store(_ image: SendableImage, for key: String, cost: Int) async {
        await adaptStrategyIfNeeded()
        await getCurrentStrategy().store(image, for: key, cost: cost)
    }
    
    public func retrieve(for key: String) async -> SendableImage? {
        await adaptStrategyIfNeeded()
        return await getCurrentStrategy().retrieve(for: key)
    }
    
    public func remove(for key: String) async {
        // Remove from all strategies to ensure consistency
        await nsCacheStrategy.remove(for: key)
        await lruStrategy.remove(for: key)
        await hybridStrategy.remove(for: key)
    }
    
    public func clear() async {
        await nsCacheStrategy.clear()
        await lruStrategy.clear()
        await hybridStrategy.clear()
    }
    
    public func handleMemoryPressure() async {
        memoryPressureLevel = .high
        await getCurrentStrategy().handleMemoryPressure()
        await adaptStrategyIfNeeded()
    }
    
    public func getStatistics() async -> CacheStrategyStatistics {
        return await getCurrentStrategy().getStatistics()
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        await nsCacheStrategy.setLimits(countLimit: countLimit, totalCostLimit: totalCostLimit)
        await lruStrategy.setLimits(countLimit: countLimit, totalCostLimit: totalCostLimit)
        await hybridStrategy.setLimits(countLimit: countLimit, totalCostLimit: totalCostLimit)
    }
    
    private func getCurrentStrategy() -> CacheStrategy {
        switch currentStrategyType {
        case .nsCache:
            return nsCacheStrategy
        case .lru:
            return lruStrategy
        case .hybrid, .adaptive:
            return hybridStrategy
        }
    }
    
    private func adaptStrategyIfNeeded() async {
        let newStrategyType = determineOptimalStrategy()
        
        if newStrategyType != currentStrategyType {
            ProductionLogger.info("AdaptiveCacheStrategy: Switching from \(currentStrategyType) to \(newStrategyType)")
            
            // Migration might be needed here in a real implementation
            // For now, we just switch strategies
            currentStrategyType = newStrategyType
            currentStrategy = getCurrentStrategy()
        }
    }
    
    private func determineOptimalStrategy() -> CacheStrategyType {
        switch memoryPressureLevel {
        case .low, .normal:
            return .hybrid  // Best overall performance
        case .high:
            return .lru     // Predictable memory management
        case .critical:
            return .nsCache // Minimal overhead
        }
    }
    
    private func startMemoryMonitoring() async {
        while !Task.isCancelled {
            await updateMemoryPressureLevel()
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
        }
    }
    
    private func updateMemoryPressureLevel() async {
        let memoryInfo = ProcessInfo.processInfo
        let physicalMemory = memoryInfo.physicalMemory
        
        // Get current memory usage (simplified)
        let stats = await getCurrentStrategy().getStatistics()
        let currentUsage = Double(stats.memoryUsageMB * 1024 * 1024)
        let memoryRatio = currentUsage / Double(physicalMemory)
        
        if memoryRatio > 0.9 {
            memoryPressureLevel = .critical
        } else if memoryRatio > 0.75 {
            memoryPressureLevel = .high
        } else if memoryRatio > 0.5 {
            memoryPressureLevel = .normal
        } else {
            memoryPressureLevel = .low
        }
    }
}