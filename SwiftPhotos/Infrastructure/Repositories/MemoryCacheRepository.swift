import Foundation
import AppKit

/// 既存のImageCacheを新しいプロトコルでラップするMemoryCacheRepository
/// これにより段階的にアーキテクチャを移行できる
public actor MemoryCacheRepository: ImageCacheRepositoryProtocol {
    public typealias Key = ImageCacheKey
    public typealias Value = SendableImage
    
    // MARK: - Properties
    private let imageCache: ImageCache
    private var priorityMap: [ImageCacheKey: CachePriority] = [:]
    private var thumbnailCache: [String: SendableImage] = [:]
    private var qualityCache: [String: SendableImage] = [:]
    
    // MARK: - Statistics Tracking
    private var operationCount = 0
    private var lastAccessTime: [ImageCacheKey: Date] = [:]
    
    // MARK: - Initialization
    public init(imageCache: ImageCache? = nil, 
                countLimit: Int = 200,
                totalCostLimit: Int = 500_000_000) {
        self.imageCache = imageCache ?? ImageCache(countLimit: countLimit, totalCostLimit: totalCostLimit)
    }
    
    // MARK: - Basic Cache Operations
    
    public func get(_ key: ImageCacheKey) async -> SendableImage? {
        operationCount += 1
        lastAccessTime[key] = Date()
        
        // 品質とサイズに基づいてキャッシュから取得
        if let image = await getCachedImageForKey(key) {
            return image
        }
        
        // フォールバック: 従来のキャッシュから取得
        if let imageURL = try? ImageURL(key.url) {
            return await imageCache.getCachedImage(for: imageURL)
        }
        return nil
    }
    
    public func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        operationCount += 1
        lastAccessTime[key] = Date()
        
        // サイズ調整された画像を保存
        let processedImage = await processImageForQuality(value, quality: key.quality, targetSize: key.size)
        
        // 品質別キャッシュに保存
        await setCachedImageForKey(processedImage, key: key)
        
        // 従来のキャッシュにも保存（互換性のため）
        if let imageURL = try? ImageURL(key.url) {
            await imageCache.setCachedImage(processedImage, for: imageURL)
        }
    }
    
    public func remove(_ key: ImageCacheKey) async {
        await removeCachedImageForKey(key)
        
        // 従来のキャッシュからも削除
        if let imageURL = try? ImageURL(key.url) {
            // ImageCacheには直接削除メソッドがないため、統計を更新
            operationCount += 1
        }
    }
    
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
    
    public func removeMultiple(_ keys: [ImageCacheKey]) async {
        for key in keys {
            await remove(key)
        }
    }
    
    public func removeAll() async {
        await imageCache.clearCache()
        priorityMap.removeAll()
        thumbnailCache.removeAll()
        qualityCache.removeAll()
        lastAccessTime.removeAll()
        operationCount = 0
    }
    
    public func statistics() async -> CacheStatistics {
        let originalStats = await imageCache.getCacheStatistics()
        
        return CacheStatistics(
            hitCount: originalStats.hitCount,
            missCount: originalStats.missCount,
            totalCost: originalStats.totalCost + estimateAdditionalCacheSize(),
            currentCount: originalStats.currentCount + thumbnailCache.count + qualityCache.count
        )
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        // ImageCacheの制限を動的に変更する機能はないため、
        // 新しいインスタンスを作成するか、将来の実装で対応
        ProductionLogger.info("Cache limits update requested: count=\(countLimit?.description ?? "nil"), cost=\(totalCostLimit?.description ?? "nil")")
    }
    
    public func contains(_ key: ImageCacheKey) async -> Bool {
        return await get(key) != nil
    }
    
    public func allKeys() async -> [ImageCacheKey] {
        return Array(lastAccessTime.keys)
    }
    
    public func performCleanup(targetReduction: Double) async {
        let currentTime = Date()
        let cutoffTime = currentTime.addingTimeInterval(-3600) // 1時間前
        
        // 古いアクセス記録を削除
        let keysToRemove = lastAccessTime.compactMap { key, time in
            time < cutoffTime ? key : nil
        }
        
        for key in keysToRemove.prefix(Int(Double(keysToRemove.count) * targetReduction)) {
            await remove(key)
        }
        
        ProductionLogger.info("Cache cleanup completed: removed \(keysToRemove.count) items")
    }
    
    // MARK: - Image-Specific Operations
    
    public func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async {
        for (key, image) in images {
            await set(image, for: key, cost: nil)
            // プリロードされた画像は高優先度に設定
            priorityMap[key] = .high
        }
        
        ProductionLogger.info("Preloaded \(images.count) images")
    }
    
    public func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async {
        priorityMap[key] = priority
        lastAccessTime[key] = Date() // 優先度変更時にアクセス時刻を更新
    }
    
    public func cacheThumbnail(_ image: SendableImage, for originalKey: ImageCacheKey, size: CGSize) async {
        let thumbnailKey = generateThumbnailKey(originalKey: originalKey, size: size)
        let thumbnailImage = await processImageForSize(image, targetSize: size)
        thumbnailCache[thumbnailKey] = thumbnailImage
        
        ProductionLogger.debug("Cached thumbnail: \(thumbnailKey)")
    }
    
    public func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage? {
        let thumbnailKey = generateThumbnailKey(originalKey: key, size: size)
        return thumbnailCache[thumbnailKey]
    }
    
    public func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async {
        let qualityKey = generateQualityKey(key: key, quality: quality)
        let qualityImage = await processImageForQuality(image, quality: quality, targetSize: key.size)
        qualityCache[qualityKey] = qualityImage
        
        ProductionLogger.debug("Cached with quality \(quality.rawValue): \(qualityKey)")
    }
    
    public func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage? {
        let qualityKey = generateQualityKey(key: key, quality: quality)
        return qualityCache[qualityKey]
    }
    
    // MARK: - Private Helper Methods
    
    private func getCachedImageForKey(_ key: ImageCacheKey) async -> SendableImage? {
        // 1. 品質指定での取得を試行
        if let qualityImage = await getWithQuality(key, quality: key.quality) {
            return qualityImage
        }
        
        // 2. サムネイル取得を試行（サイズが指定されている場合）
        if let size = key.size,
           let thumbnail = await getThumbnail(for: key, size: size) {
            return thumbnail
        }
        
        return nil
    }
    
    private func setCachedImageForKey(_ image: SendableImage, key: ImageCacheKey) async {
        // 品質別キャッシュに保存
        await cacheWithQuality(image, for: key, quality: key.quality)
        
        // サムネイルとしても保存（サイズが指定されている場合）
        if let size = key.size {
            await cacheThumbnail(image, for: key, size: size)
        }
    }
    
    private func removeCachedImageForKey(_ key: ImageCacheKey) async {
        // 品質キャッシュから削除
        let qualityKey = generateQualityKey(key: key, quality: key.quality)
        qualityCache.removeValue(forKey: qualityKey)
        
        // サムネイルキャッシュから削除
        if let size = key.size {
            let thumbnailKey = generateThumbnailKey(originalKey: key, size: size)
            thumbnailCache.removeValue(forKey: thumbnailKey)
        }
        
        // メタデータ削除
        priorityMap.removeValue(forKey: key)
        lastAccessTime.removeValue(forKey: key)
    }
    
    private func processImageForQuality(_ image: SendableImage, quality: ImageQuality, targetSize: CGSize?) async -> SendableImage {
        var processedImage = image
        
        // サイズ調整
        if let targetSize = targetSize {
            processedImage = await processImageForSize(processedImage, targetSize: targetSize)
        }
        
        // 品質調整（圧縮）
        if quality != .original {
            processedImage = await compressImage(processedImage, quality: quality)
        }
        
        return processedImage
    }
    
    private func processImageForSize(_ image: SendableImage, targetSize: CGSize) async -> SendableImage {
        let originalSize = image.size
        
        // 既に適切なサイズの場合はそのまま返す
        if originalSize.width <= targetSize.width && originalSize.height <= targetSize.height {
            return image
        }
        
        // アスペクト比を保持してリサイズ
        let aspectRatio = originalSize.width / originalSize.height
        var newSize = targetSize
        
        if targetSize.width / targetSize.height > aspectRatio {
            newSize.width = targetSize.height * aspectRatio
        } else {
            newSize.height = targetSize.width / aspectRatio
        }
        
        // NSImageでリサイズ
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.nsImage.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return SendableImage(resizedImage)
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
    
    private func generateThumbnailKey(originalKey: ImageCacheKey, size: CGSize) -> String {
        return "\(originalKey.url.absoluteString)_thumb_\(Int(size.width))x\(Int(size.height))"
    }
    
    private func generateQualityKey(key: ImageCacheKey, quality: ImageQuality) -> String {
        var keyString = key.url.absoluteString
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
    
    private func estimateAdditionalCacheSize() -> Int {
        let thumbnailSize = thumbnailCache.values.reduce(0) { total, image in
            total + estimateImageMemorySize(image)
        }
        let qualitySize = qualityCache.values.reduce(0) { total, image in
            total + estimateImageMemorySize(image)
        }
        return thumbnailSize + qualitySize
    }
    
    private func estimateImageMemorySize(_ image: SendableImage) -> Int {
        let size = image.size
        let pixelCount = Int(size.width * size.height)
        let bytesPerPixel = 4 // RGBA
        return pixelCount * bytesPerPixel
    }
}

// MARK: - Cache Priority Extension
extension MemoryCacheRepository {
    /// 優先度に基づいてキャッシュエントリをソート
    public func getKeysSortedByPriority() async -> [ImageCacheKey] {
        return lastAccessTime.keys.sorted { key1, key2 in
            let priority1 = priorityMap[key1] ?? .normal
            let priority2 = priorityMap[key2] ?? .normal
            
            if priority1 != priority2 {
                return priority1 > priority2
            }
            
            // 優先度が同じ場合は最近のアクセス順
            let time1 = lastAccessTime[key1] ?? Date.distantPast
            let time2 = lastAccessTime[key2] ?? Date.distantPast
            return time1 > time2
        }
    }
    
    /// 低優先度のアイテムを優先的に削除
    public func cleanupLowPriorityItems(maxItemsToRemove: Int = 50) async {
        let sortedKeys = await getKeysSortedByPriority()
        let lowPriorityKeys = sortedKeys.reversed().prefix(maxItemsToRemove)
        
        for key in lowPriorityKeys {
            if priorityMap[key] == .low {
                await remove(key)
            }
        }
        
        ProductionLogger.info("Cleaned up \(lowPriorityKeys.count) low-priority cache items")
    }
}