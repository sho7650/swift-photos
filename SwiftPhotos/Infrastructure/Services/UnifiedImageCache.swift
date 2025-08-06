import Foundation
import AppKit

/// Unified image cache that consolidates functionality from legacy ImageCache, LRUImageCache, and MemoryCacheRepository
/// Provides intelligent caching with multiple strategies, quality management, and advanced features
public actor UnifiedImageCache: UnifiedImageCacheProtocol {
    
    // MARK: - Properties
    
    private let cacheStrategy: CacheStrategy
    private let configuration: UnifiedCacheConfiguration
    private var eventDelegate: CacheEventDelegate?
    
    // MARK: - Quality and Thumbnail Management
    private var thumbnailCache: [String: SendableImage] = [:]
    private var qualityCache: [String: SendableImage] = [:]
    private var priorityMap: [String: CachePriority] = [:]
    private var lastAccessTime: [String: Date] = [:]
    
    // MARK: - Statistics
    private var totalOperations = 0
    private var cleanupOperations = 0
    
    // MARK: - Initialization
    
    public init(configuration: UnifiedCacheConfiguration = .default, eventDelegate: CacheEventDelegate? = nil) {
        self.configuration = configuration
        self.eventDelegate = eventDelegate
        
        // Create appropriate cache strategy
        switch configuration.strategy {
        case .nsCache:
            self.cacheStrategy = NSCacheStrategy(configuration: configuration)
        case .lru:
            self.cacheStrategy = LRUCacheStrategy(configuration: configuration)
        case .hybrid:
            self.cacheStrategy = HybridCacheStrategy(configuration: configuration)
        case .adaptive:
            self.cacheStrategy = AdaptiveCacheStrategy(configuration: configuration)
        }
        
        ProductionLogger.lifecycle("UnifiedImageCache: Initialized with \(configuration.strategy) strategy")
        
        // Start periodic cleanup if enabled
        if configuration.enableMemoryPressureHandling {
            Task {
                await startPeriodicCleanup()
            }
        }
    }
    
    // MARK: - Basic Cache Operations (PhotoCache compatibility)
    
    public func getCachedImage(for imageURL: ImageURL) async -> SendableImage? {
        let key = generateKey(from: imageURL)
        return await cacheStrategy.retrieve(for: key)
    }
    
    public func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) async {
        let key = generateKey(from: imageURL)
        let cost = estimateImageCost(image)
        await cacheStrategy.store(image, for: key, cost: cost)
        updateAccessTracking(for: key)
    }
    
    public func clearCache() async {
        await cacheStrategy.clear()
        thumbnailCache.removeAll()
        qualityCache.removeAll()
        priorityMap.removeAll()
        lastAccessTime.removeAll()
        totalOperations = 0
        cleanupOperations = 0
        
        ProductionLogger.info("UnifiedImageCache: Cache cleared")
    }
    
    public func getCacheStatistics() async -> CacheStatistics {
        let strategyStats = await cacheStrategy.getStatistics()
        let additionalMemory = estimateAdditionalCacheSize()
        
        return CacheStatistics(
            hitCount: strategyStats.hitCount,
            missCount: strategyStats.missCount,
            totalCost: strategyStats.memoryUsageMB * 1024 * 1024 + additionalMemory,
            currentCount: strategyStats.currentCount + thumbnailCache.count + qualityCache.count
        )
    }
    
    // MARK: - Repository-style Operations (ImageCacheRepositoryProtocol compatibility)
    
    public func get(_ key: ImageCacheKey) async -> SendableImage? {
        totalOperations += 1
        lastAccessTime[key.cacheKey] = Date()
        
        // Check quality-specific cache first
        if configuration.enableQualityBasedCaching,
           let qualityImage = await getWithQuality(key, quality: key.quality) {
            return qualityImage
        }
        
        // Check thumbnail cache
        if configuration.enableThumbnailCaching,
           let size = key.size,
           let thumbnail = await getThumbnail(for: key, size: size) {
            return thumbnail
        }
        
        // Fallback to main strategy
        return await cacheStrategy.retrieve(for: key.cacheKey)
    }
    
    public func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        totalOperations += 1
        lastAccessTime[key.cacheKey] = Date()
        
        let actualCost = cost ?? estimateImageCost(value)
        
        // Process image based on quality and size requirements
        let processedImage = await processImageForContext(value, key: key)
        
        // Store in appropriate caches
        if configuration.enableQualityBasedCaching {
            await cacheWithQuality(processedImage, for: key, quality: key.quality)
        }
        
        if configuration.enableThumbnailCaching, let size = key.size {
            await cacheThumbnail(processedImage, for: key, size: size)
        }
        
        // Store in main strategy
        await cacheStrategy.store(processedImage, for: key.cacheKey, cost: actualCost)
    }
    
    public func remove(_ key: ImageCacheKey) async {
        await cacheStrategy.remove(for: key.cacheKey)
        
        // Remove from additional caches
        let qualityKey = generateQualityKey(key: key, quality: key.quality)
        qualityCache.removeValue(forKey: qualityKey)
        
        if let size = key.size {
            let thumbnailKey = generateThumbnailKey(originalKey: key, size: size)
            thumbnailCache.removeValue(forKey: thumbnailKey)
        }
        
        // Clean up metadata
        priorityMap.removeValue(forKey: key.cacheKey)
        lastAccessTime.removeValue(forKey: key.cacheKey)
        
        if let delegate = eventDelegate {
            await delegate.cacheDidEvictItem(key: key.cacheKey, reason: .manual)
        }
    }
    
    public func removeAll() async {
        await clearCache()
    }
    
    public func contains(_ key: ImageCacheKey) async -> Bool {
        return await get(key) != nil
    }
    
    // MARK: - Batch Operations
    
    public func getMultiple(_ keys: [ImageCacheKey]) async -> [ImageCacheKey: SendableImage] {
        var results: [ImageCacheKey: SendableImage] = [:]
        
        // Process in batches to avoid overwhelming the system
        let batchSize = 10
        for batch in keys.chunked(into: batchSize) {
            await withTaskGroup(of: (ImageCacheKey, SendableImage?).self) { group in
                for key in batch {
                    group.addTask {
                        let image = await self.get(key)
                        return (key, image)
                    }
                }
                
                for await (key, image) in group {
                    if let image = image {
                        results[key] = image
                    }
                }
            }
        }
        
        return results
    }
    
    public func setMultiple(_ items: [(key: ImageCacheKey, value: SendableImage, cost: Int?)]) async {
        // Process in batches
        let batchSize = 5
        for batch in items.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask {
                        await self.set(item.value, for: item.key, cost: item.cost)
                    }
                }
            }
        }
    }
    
    public func removeMultiple(_ keys: [ImageCacheKey]) async {
        for key in keys {
            await remove(key)
        }
    }
    
    // MARK: - Advanced Features
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        await cacheStrategy.setLimits(countLimit: countLimit, totalCostLimit: totalCostLimit)
        ProductionLogger.info("UnifiedImageCache: Limits updated - count: \(countLimit?.description ?? "unchanged"), cost: \(totalCostLimit?.description ?? "unchanged")")
    }
    
    public func performCleanup(targetReduction: Double) async {
        let initialStats = await getCacheStatistics()
        let currentTime = Date()
        let cutoffTime = currentTime.addingTimeInterval(-3600) // 1 hour ago
        
        // Find items to remove based on access time and priority
        let itemsToRemove = lastAccessTime.compactMap { key, time -> (key: String, priority: CachePriority, age: TimeInterval)? in
            let priority = priorityMap[key] ?? .normal
            let age = currentTime.timeIntervalSince(time)
            return (key: key, priority: priority, age: age)
        }.sorted { first, second in
            // Sort by priority (low first) then by age (oldest first)
            if first.priority != second.priority {
                return first.priority < second.priority
            }
            return first.age > second.age
        }
        
        let targetCount = Int(Double(itemsToRemove.count) * targetReduction)
        let keysToRemove = Array(itemsToRemove.prefix(targetCount))
        
        for item in keysToRemove {
            // Create a dummy ImageCacheKey for removal
            if let url = URL(string: item.key) {
                let dummyKey = ImageCacheKey(url: url, size: nil, quality: .full, transformations: [])
                await remove(dummyKey)
            }
        }
        
        let finalStats = await getCacheStatistics()
        let itemsRemoved = initialStats.currentCount - finalStats.currentCount
        let memoryFreed = initialStats.totalCost - finalStats.totalCost
        
        cleanupOperations += 1
        
        if let delegate = eventDelegate {
            await delegate.cacheDidPerformCleanup(itemsRemoved: itemsRemoved, memoryFreed: memoryFreed)
        }
        
        ProductionLogger.info("UnifiedImageCache: Cleanup completed - removed \(itemsRemoved) items, freed \(memoryFreed / (1024 * 1024))MB")
    }
    
    public func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async {
        for (key, image) in images {
            await set(image, for: key, cost: nil)
            priorityMap[key.cacheKey] = .high // Preloaded images get high priority
        }
        
        ProductionLogger.info("UnifiedImageCache: Preloaded \(images.count) images")
    }
    
    public func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async {
        priorityMap[key.cacheKey] = priority
        lastAccessTime[key.cacheKey] = Date() // Update access time when priority changes
    }
    
    // MARK: - Quality and Size Management
    
    public func cacheThumbnail(_ image: SendableImage, for originalKey: ImageCacheKey, size: CGSize) async {
        guard configuration.enableThumbnailCaching else { return }
        
        let thumbnailKey = generateThumbnailKey(originalKey: originalKey, size: size)
        let thumbnailImage = await processImageForSize(image, targetSize: size)
        thumbnailCache[thumbnailKey] = thumbnailImage
        
        ProductionLogger.debug("UnifiedImageCache: Cached thumbnail - \(thumbnailKey)")
    }
    
    public func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage? {
        guard configuration.enableThumbnailCaching else { return nil }
        
        let thumbnailKey = generateThumbnailKey(originalKey: key, size: size)
        return thumbnailCache[thumbnailKey]
    }
    
    public func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async {
        guard configuration.enableQualityBasedCaching else { return }
        
        let qualityKey = generateQualityKey(key: key, quality: quality)
        let qualityImage = await processImageForQuality(image, quality: quality, targetSize: key.size)
        qualityCache[qualityKey] = qualityImage
        
        ProductionLogger.debug("UnifiedImageCache: Cached with quality \(quality.rawValue) - \(qualityKey)")
    }
    
    public func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage? {
        guard configuration.enableQualityBasedCaching else { return nil }
        
        let qualityKey = generateQualityKey(key: key, quality: quality)
        return qualityCache[qualityKey]
    }
    
    // MARK: - Memory Management
    
    public func handleMemoryPressure() async {
        let memoryLevel = await getMemoryPressureLevel()
        
        await cacheStrategy.handleMemoryPressure()
        
        // Additional cleanup for thumbnails and quality cache
        if memoryLevel == .high || memoryLevel == .critical {
            let reductionRatio = memoryLevel == .critical ? 0.75 : 0.5
            
            let thumbnailsToRemove = Int(Double(thumbnailCache.count) * reductionRatio)
            let thumbnailKeys = Array(thumbnailCache.keys.prefix(thumbnailsToRemove))
            for key in thumbnailKeys {
                thumbnailCache.removeValue(forKey: key)
            }
            
            let qualityToRemove = Int(Double(qualityCache.count) * reductionRatio)
            let qualityKeys = Array(qualityCache.keys.prefix(qualityToRemove))
            for key in qualityKeys {
                qualityCache.removeValue(forKey: key)
            }
        }
        
        if let delegate = eventDelegate {
            await delegate.cacheDidReachMemoryPressure(level: memoryLevel)
        }
        
        ProductionLogger.warning("UnifiedImageCache: Handled memory pressure level: \(memoryLevel)")
    }
    
    public func getCurrentMemoryUsage() async -> Int {
        let stats = await getCacheStatistics()
        return stats.totalCost
    }
    
    public func getMemoryPressureLevel() async -> MemoryPressureLevel {
        let currentUsage = await getCurrentMemoryUsage()
        let maxUsage = configuration.totalCostLimitMB * 1024 * 1024
        let usageRatio = Double(currentUsage) / Double(maxUsage)
        
        switch usageRatio {
        case 0..<0.5:
            return .low
        case 0.5..<configuration.memoryPressureThreshold:
            return .normal
        case configuration.memoryPressureThreshold..<0.9:
            return .high
        default:
            return .critical
        }
    }
    
    // MARK: - Private Methods
    
    private func generateKey(from imageURL: ImageURL) -> String {
        return imageURL.url.absoluteString
    }
    
    private func generateThumbnailKey(originalKey: ImageCacheKey, size: CGSize) -> String {
        return "\(originalKey.cacheKey)_thumb_\(Int(size.width))x\(Int(size.height))"
    }
    
    private func generateQualityKey(key: ImageCacheKey, quality: ImageQuality) -> String {
        var keyString = key.cacheKey
        keyString += "_quality_\(quality.rawValue)"
        
        if let size = key.size {
            keyString += "_\(Int(size.width))x\(Int(size.height))"
        }
        
        if !key.transformations.isEmpty {
            let transformString = key.transformations.map { $0.identifier }.joined(separator: "_")
            keyString += "_trans_\(transformString)"
        }
        
        return keyString
    }
    
    private func processImageForContext(_ image: SendableImage, key: ImageCacheKey) async -> SendableImage {
        var processedImage = image
        
        // Apply size transformation if needed
        if let targetSize = key.size {
            processedImage = await processImageForSize(processedImage, targetSize: targetSize)
        }
        
        // Apply quality transformation if needed
        if key.quality != .original {
            processedImage = await processImageForQuality(processedImage, quality: key.quality, targetSize: key.size)
        }
        
        return processedImage
    }
    
    private func processImageForSize(_ image: SendableImage, targetSize: CGSize) async -> SendableImage {
        let originalSize = image.size
        
        // Already appropriate size
        if originalSize.width <= targetSize.width && originalSize.height <= targetSize.height {
            return image
        }
        
        // Calculate aspect-preserving size
        let aspectRatio = originalSize.width / originalSize.height
        var newSize = targetSize
        
        if targetSize.width / targetSize.height > aspectRatio {
            newSize.width = targetSize.height * aspectRatio
        } else {
            newSize.height = targetSize.width / aspectRatio
        }
        
        // Resize using NSImage
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.nsImage.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return SendableImage(resizedImage)
    }
    
    private func processImageForQuality(_ image: SendableImage, quality: ImageQuality, targetSize: CGSize?) async -> SendableImage {
        var processedImage = image
        
        // Apply size first if needed
        if let targetSize = targetSize {
            processedImage = await processImageForSize(processedImage, targetSize: targetSize)
        }
        
        // Apply compression if not original quality
        if quality != .original {
            processedImage = await compressImage(processedImage, quality: quality)
        }
        
        return processedImage
    }
    
    private func compressImage(_ image: SendableImage, quality: ImageQuality) async -> SendableImage {
        guard let tiffData = image.nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return image
        }
        
        let compressionQuality = quality.compressionQuality
        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            NSBitmapImageRep.PropertyKey.compressionFactor: compressionQuality
        ]
        
        guard let compressedData = bitmap.representation(using: .jpeg, properties: properties),
              let compressedImage = NSImage(data: compressedData) else {
            return image
        }
        
        return SendableImage(compressedImage)
    }
    
    private func estimateImageCost(_ image: SendableImage) -> Int {
        let size = image.size
        let pixelCount = Int(size.width * size.height)
        let bytesPerPixel = 4 // RGBA
        return pixelCount * bytesPerPixel
    }
    
    private func estimateAdditionalCacheSize() -> Int {
        let thumbnailSize = thumbnailCache.values.reduce(0) { total, image in
            total + estimateImageCost(image)
        }
        let qualitySize = qualityCache.values.reduce(0) { total, image in
            total + estimateImageCost(image)
        }
        return thumbnailSize + qualitySize
    }
    
    private func updateAccessTracking(for key: String) {
        lastAccessTime[key] = Date()
    }
    
    private func startPeriodicCleanup() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(configuration.cleanupInterval * 1_000_000_000))
            
            let memoryLevel = await getMemoryPressureLevel()
            if memoryLevel == .high || memoryLevel == .critical {
                await performCleanup(targetReduction: 0.3)
            }
        }
    }
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension ImageCacheKey {
    var cacheKey: String {
        return url.absoluteString
    }
}