import Foundation
import AppKit

/// Virtual image loader that maintains a sliding window of loaded images
/// to handle large photo collections efficiently with unlimited scalability
actor VirtualImageLoader {
    private var windowSize: Int
    private let imageLoader: ImageLoader
    private var loadedImages: [UUID: NSImage] = [:]
    private var loadingTasks: [UUID: Task<NSImage, Error>] = [:]
    private var maxMemoryUsage: Int // in MB
    private var settings: PerformanceSettings
    
    // Statistics for monitoring
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var totalLoads: Int = 0
    
    // Completion callback for UI integration
    private var onImageLoaded: ((UUID, NSImage) -> Void)?
    
    init(settings: PerformanceSettings = .default) {
        self.settings = settings
        self.windowSize = settings.memoryWindowSize
        self.maxMemoryUsage = settings.maxMemoryUsageMB
        self.imageLoader = ImageLoader()
        
        print("🗄️ VirtualImageLoader: Initialized with window size: \(windowSize), max memory: \(maxMemoryUsage)MB")
    }
    
    /// Set callback for when images finish loading
    func setImageLoadedCallback(_ callback: @escaping (UUID, NSImage) -> Void) {
        self.onImageLoaded = callback
    }
    
    /// Update performance settings at runtime
    func updateSettings(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
        self.windowSize = newSettings.memoryWindowSize
        self.maxMemoryUsage = newSettings.maxMemoryUsageMB
        
        print("🗄️ VirtualImageLoader: Settings updated - window: \(windowSize), memory: \(maxMemoryUsage)MB")
        
        // Adjust cache size if needed
        if getMemoryUsage() > maxMemoryUsage {
            Task {
                await handleMemoryPressure()
            }
        }
    }
    
    /// Load images within a window around the current index with smart sizing
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
        for (photoId, task) in loadingTasks {
            if !photosInWindow.contains(photoId) {
                task.cancel()
                loadingTasks.removeValue(forKey: photoId)
            }
        }
        
        // Remove loaded images outside the window (with some buffer)
        let bufferSize = windowSize * 2
        let bufferStart = max(0, index - bufferSize)
        let bufferEnd = min(photos.count - 1, index + bufferSize)
        let photosInBuffer = Set(photos[bufferStart...bufferEnd].map { $0.id })
        
        loadedImages = loadedImages.filter { photosInBuffer.contains($0.key) }
        
        // Load images in the window
        await withTaskGroup(of: Void.self) { group in
            for i in startIndex...endIndex {
                let photo = photos[i]
                
                // Skip if already loaded or loading
                if loadedImages[photo.id] != nil || loadingTasks[photo.id] != nil {
                    continue
                }
                
                group.addTask { [weak self] in
                    await self?.loadImage(photo: photo)
                }
            }
        }
    }
    
    /// Get a loaded image if available
    func getImage(for photoId: UUID) -> NSImage? {
        if let image = loadedImages[photoId] {
            cacheHits += 1
            return image
        } else {
            cacheMisses += 1
            return nil
        }
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
        
        let task = Task<NSImage, Error> {
            try await imageLoader.loadImage(from: photo.imageURL)
        }
        
        loadingTasks[photo.id] = task
        
        do {
            let image = try await task.value
            loadedImages[photo.id] = image
            loadingTasks.removeValue(forKey: photo.id)
            
            // Notify UI that image is loaded
            if let callback = onImageLoaded {
                Task { @MainActor in
                    callback(photo.id, image)
                }
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
                print("Failed to load image for photo \(photo.id): \(error)")
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
    
    /// Calculate effective window size based on collection size and settings
    private func calculateEffectiveWindowSize(collectionSize: Int) -> Int {
        switch collectionSize {
        case 0...100:
            return min(windowSize, collectionSize)
        case 101...1000:
            return min(windowSize, max(50, collectionSize / 10))
        case 1001...10000:
            return min(windowSize, max(100, collectionSize / 50))
        default:
            // For massive collections (10k+), use adaptive sizing
            let adaptiveSize = max(200, min(windowSize, collectionSize / 100))
            return adaptiveSize
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