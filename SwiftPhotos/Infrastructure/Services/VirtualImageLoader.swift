import Foundation
import AppKit

/// Virtual image loader that maintains a sliding window of loaded images
/// to handle large photo collections efficiently with unlimited scalability
actor VirtualImageLoader {
    private var windowSize: Int
    private let imageLoader: ImageLoader
    private var loadedImages: [UUID: SendableImage] = [:]
    private var loadingTasks: [UUID: Task<SendableImage, Error>] = [:]
    private var maxMemoryUsage: Int // in MB
    private var settings: PerformanceSettings
    
    // Statistics for monitoring
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var totalLoads: Int = 0
    
    // Completion callbacks for UI integration
    private var onImageLoaded: (@MainActor (UUID, SendableImage) -> Void)?
    private var onImageLoadFailed: (@MainActor (UUID, Error) -> Void)?
    
    init(settings: PerformanceSettings = .default) {
        self.settings = settings
        self.windowSize = settings.memoryWindowSize
        self.maxMemoryUsage = settings.maxMemoryUsageMB
        self.imageLoader = ImageLoader()
        
        ProductionLogger.lifecycle("VirtualImageLoader: Initialized with window size: \(windowSize), max memory: \(maxMemoryUsage)MB")
    }
    
    /// Set callback for when images finish loading
    func setImageLoadedCallback(_ callback: @escaping @MainActor (UUID, SendableImage) -> Void) {
        self.onImageLoaded = callback
    }
    
    /// Set callback for when image loading fails
    func setImageLoadFailedCallback(_ callback: @escaping @MainActor (UUID, Error) -> Void) {
        self.onImageLoadFailed = callback
    }
    
    /// Update performance settings at runtime
    func updateSettings(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
        self.windowSize = newSettings.memoryWindowSize
        self.maxMemoryUsage = newSettings.maxMemoryUsageMB
        
        ProductionLogger.debug("VirtualImageLoader: Settings updated - window: \(windowSize), memory: \(maxMemoryUsage)MB")
        
        // Adjust cache size if needed
        if getMemoryUsage() > maxMemoryUsage {
            Task {
                await handleMemoryPressure()
            }
        }
    }
    
    /// Load images within a window around the current index with smart sizing - 並行処理対応版
    func loadImageWindow(around index: Int, photos: [Photo]) async {
        guard !photos.isEmpty else { return }
        
        // Smart window sizing for unlimited collections
        let effectiveWindowSize = calculateEffectiveWindowSize(collectionSize: photos.count)
        
        // Calculate the range of indices to load
        let startIndex = max(0, index - effectiveWindowSize / 2)
        let endIndex = min(photos.count - 1, index + effectiveWindowSize / 2)
        
        // Collect photo IDs that should be loaded
        let photosInWindow = Set(photos[startIndex...endIndex].map { $0.id })
        
        // Cancel loading tasks for photos outside the window
        await cancelOutOfWindowTasks(photosInWindow: photosInWindow)
        
        // Remove loaded images outside the window (with some buffer)
        cleanupOutOfWindowImages(currentIndex: index, photos: photos)
        
        // 並行ロード処理 - 中央の画像から外側に向かって優先的にロード
        await loadImageWindowConcurrently(
            centerIndex: index,
            startIndex: startIndex,
            endIndex: endIndex,
            photos: photos
        )
    }
    
    /// 新機能: 非同期ウィンドウロード - バックグラウンドでキャッシュを再構成
    func loadImageWindowAsync(around index: Int, photos: [Photo]) {
        Task {
            await loadImageWindow(around: index, photos: photos)
            ProductionLogger.debug("VirtualImageLoader: Background window reconstruction completed for index \(index)")
        }
    }
    
    /// 並行処理でウィンドウ内画像をロード
    private func loadImageWindowConcurrently(
        centerIndex: Int,
        startIndex: Int,
        endIndex: Int,
        photos: [Photo]
    ) async {
        // 中央から外側への距離ベースで優先度を決定
        let photosToLoad = (startIndex...endIndex).map { idx in
            let photo = photos[idx]
            let distance = abs(idx - centerIndex)
            return (photo: photo, distance: distance, index: idx)
        }
        .sorted { $0.distance < $1.distance } // 距離が近い順にソート
        
        // 最大並行数を設定（中央画像は即座、その他は段階的に）
        let maxConcurrent = min(settings.maxConcurrentLoads, photosToLoad.count)
        
        await withTaskGroup(of: Void.self) { group in
            var semaphore = 0
            
            for (photo, distance, _) in photosToLoad {
                // セマフォで並行数制御
                while semaphore >= maxConcurrent {
                    await group.next()
                    semaphore -= 1
                }
                
                // 中央画像（distance = 0）は最優先
                let priority: TaskPriority = distance == 0 ? .userInitiated : .utility
                
                group.addTask(priority: priority) { [weak self] in
                    await self?.loadImageIfNeeded(photo: photo)
                }
                semaphore += 1
            }
        }
    }
    
    /// ウィンドウ外のタスクをキャンセル
    private func cancelOutOfWindowTasks(photosInWindow: Set<UUID>) async {
        for (photoId, task) in loadingTasks {
            if !photosInWindow.contains(photoId) {
                task.cancel()
                loadingTasks.removeValue(forKey: photoId)
                ProductionLogger.debug("VirtualImageLoader: Cancelled out-of-window load for \(photoId)")
            }
        }
    }
    
    /// ウィンドウ外の画像をクリーンアップ
    private func cleanupOutOfWindowImages(currentIndex: Int, photos: [Photo]) {
        let bufferSize = windowSize * 2
        let bufferStart = max(0, currentIndex - bufferSize)
        let bufferEnd = min(photos.count - 1, currentIndex + bufferSize)
        let photosInBuffer = Set(photos[bufferStart...bufferEnd].map { $0.id })
        
        let beforeCount = loadedImages.count
        loadedImages = loadedImages.filter { photosInBuffer.contains($0.key) }
        let afterCount = loadedImages.count
        
        if beforeCount != afterCount {
            ProductionLogger.debug("VirtualImageLoader: Cleaned up \(beforeCount - afterCount) out-of-window images")
        }
    }
    
    /// 必要に応じて画像をロード（重複チェック付き）
    private func loadImageIfNeeded(photo: Photo) async {
        // すでにロード済みまたはロード中の場合はスキップ
        guard loadedImages[photo.id] == nil && loadingTasks[photo.id] == nil else {
            return
        }
        
        await loadImage(photo: photo)
    }
    
    /// Get a loaded image if available
    func getImage(for photoId: UUID) -> SendableImage? {
        if let image = loadedImages[photoId] {
            cacheHits += 1
            return image
        } else {
            cacheMisses += 1
            return nil
        }
    }
    
    /// プログレスバージャンプ専用: 全タスクをキャンセルして特定画像のロードを優先
    func cancelAllForProgressJump() async {
        let taskCount = loadingTasks.count
        if taskCount > 0 {
            ProductionLogger.debug("VirtualImageLoader: Cancelling \(taskCount) loading tasks")
            
            for (_, task) in loadingTasks {
                task.cancel()
            }
            loadingTasks.removeAll()
        }
    }
    
    /// 特定画像のロードタスクをキャンセル
    func cancelLoad(for photoId: UUID) async {
        if let task = loadingTasks[photoId] {
            task.cancel()
            loadingTasks.removeValue(forKey: photoId)
            print("🚫 VirtualImageLoader: Cancelled load for \(photoId)")
        }
    }
    
    /// 現在ロード中のタスク数を取得
    func getActiveTaskCount() -> Int {
        return loadingTasks.count
    }
    
    /// Check if an image is currently being loaded
    func isLoading(photoId: UUID) -> Bool {
        return loadingTasks[photoId] != nil
    }
    
    /// Clear all cached images
    func clearCache() {
        loadedImages.removeAll()
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
    }
    
    /// Get current memory usage estimate
    func getMemoryUsage() -> Int {
        var totalBytes = 0
        for image in loadedImages.values {
            // Estimate: width * height * 4 bytes per pixel
            totalBytes += Int(image.size.width * image.size.height * 4)
        }
        return totalBytes / (1024 * 1024) // Convert to MB
    }
    
    private func loadImage(photo: Photo) async {
        totalLoads += 1
        
        let task = Task<SendableImage, Error> {
            try await imageLoader.loadImage(from: photo.imageURL)
        }
        
        loadingTasks[photo.id] = task
        
        do {
            let image = try await task.value
            loadedImages[photo.id] = image
            loadingTasks.removeValue(forKey: photo.id)
            
            // Notify UI that image is loaded
            if let callback = onImageLoaded {
                await callback(photo.id, image)
            }
            
            // Check memory pressure
            let currentUsage = getMemoryUsage()
            if currentUsage > maxMemoryUsage {
                print("🗄️ VirtualImageLoader: Memory limit exceeded (\(currentUsage)MB > \(maxMemoryUsage)MB), cleaning up")
                await handleMemoryPressure()
            }
            
            // Periodic optimization
            if totalLoads % 50 == 0 {
                await optimizeCache()
            }
            
        } catch {
            loadingTasks.removeValue(forKey: photo.id)
            if !Task.isCancelled {
                ProductionLogger.error("Failed to load image for photo \(photo.id): \(error)")
                
                // Notify UI that image loading failed
                if let callback = onImageLoadFailed {
                    await callback(photo.id, error)
                }
            }
        }
    }
    
    private func handleMemoryPressure() async {
        let targetUsage = settings.aggressiveMemoryManagement ? 
            maxMemoryUsage / 2 : // 50% for aggressive mode
            maxMemoryUsage * 3 / 4 // 75% for normal mode
        
        // Remove oldest loaded images until under memory limit
        let sortedImages = loadedImages.sorted { first, second in
            // This is a simple implementation - could be improved with LRU
            return first.key.uuidString < second.key.uuidString
        }
        
        var currentUsage = getMemoryUsage()
        var removedCount = 0
        
        for (photoId, _) in sortedImages {
            if currentUsage <= targetUsage {
                break
            }
            
            loadedImages.removeValue(forKey: photoId)
            currentUsage = getMemoryUsage()
            removedCount += 1
        }
        
        if removedCount > 0 {
            print("🗄️ VirtualImageLoader: Memory pressure handled - removed \(removedCount) images, usage: \(currentUsage)MB")
        }
    }
    
    /// Calculate effective window size based on collection size, memory usage, and performance
    private func calculateEffectiveWindowSize(collectionSize: Int) -> Int {
        // Base calculation using collection size
        let baseSize = calculateBaseSizeForCollection(collectionSize)
        
        // Get current memory usage
        let currentMemoryMB = getMemoryUsage()
        let memoryPressure = Double(currentMemoryMB) / Double(maxMemoryUsage)
        
        // Get cache hit rate for performance feedback
        let stats = getCacheStatistics()
        let hitRateBonus = stats.hitRate > 0.8 ? 1.2 : (stats.hitRate < 0.5 ? 0.8 : 1.0)
        
        // Apply memory and performance adjustments
        var adjustedSize = Double(baseSize)
        
        // Reduce window size under memory pressure
        if memoryPressure > 0.8 {
            adjustedSize *= 0.6 // Aggressive reduction
        } else if memoryPressure > 0.6 {
            adjustedSize *= 0.8 // Moderate reduction
        }
        
        // Adjust based on cache performance
        adjustedSize *= hitRateBonus
        
        // Ensure minimum efficiency and respect limits
        let finalSize = max(10, min(windowSize, Int(adjustedSize)))
        
        ProductionLogger.debug("VirtualImageLoader: Window size calculation - base: \(baseSize), memory pressure: \(String(format: "%.2f", memoryPressure)), hit rate: \(String(format: "%.2f", stats.hitRate)), final: \(finalSize)")
        
        return finalSize
    }
    
    /// Calculate base window size for collection size
    private func calculateBaseSizeForCollection(_ collectionSize: Int) -> Int {
        switch collectionSize {
        case 0...100:
            return min(windowSize, collectionSize)
        case 101...500:
            // Small-medium collections: 10-20% window
            return min(windowSize, max(20, collectionSize / 5))
        case 501...2000:
            // Medium collections: 5-10% window
            return min(windowSize, max(50, collectionSize / 10))
        case 2001...10000:
            // Large collections: 2-5% window
            return min(windowSize, max(100, collectionSize / 25))
        case 10001...50000:
            // Very large collections: 1-2% window
            return min(windowSize, max(200, collectionSize / 75))
        default:
            // Massive collections (50k+): <1% window with logarithmic scaling
            let logScale = log10(Double(collectionSize))
            let dynamicSize = max(300, min(windowSize, Int(500 * logScale)))
            return dynamicSize
        }
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> (hits: Int, misses: Int, hitRate: Double, loadedCount: Int, memoryUsageMB: Int) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (
            hits: cacheHits,
            misses: cacheMisses,
            hitRate: hitRate,
            loadedCount: loadedImages.count,
            memoryUsageMB: getMemoryUsage()
        )
    }
    
    /// Optimize cache for current usage pattern
    func optimizeCache() async {
        let stats = getCacheStatistics()
        
        // If hit rate is low, consider adjusting window size
        if stats.hitRate < 0.7 && windowSize < settings.memoryWindowSize {
            let newWindowSize = min(settings.memoryWindowSize, windowSize + 10)
            print("🗄️ VirtualImageLoader: Low hit rate (\(String(format: "%.1f", stats.hitRate * 100))%), increasing window size to \(newWindowSize)")
            windowSize = newWindowSize
        }
        
        // If memory usage is consistently low, we can be more aggressive
        if stats.memoryUsageMB < maxMemoryUsage / 2 && windowSize < settings.memoryWindowSize {
            let newWindowSize = min(settings.memoryWindowSize, windowSize + 20)
            print("🗄️ VirtualImageLoader: Low memory usage, increasing window size to \(newWindowSize)")
            windowSize = newWindowSize
        }
    }
}