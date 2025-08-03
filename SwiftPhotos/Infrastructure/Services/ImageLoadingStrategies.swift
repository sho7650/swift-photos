import Foundation
import AppKit

// MARK: - Basic Image Loading Strategy

/// Basic strategy for small to medium collections (< 1000 photos)
/// Consolidates functionality from the original ImageLoader
actor BasicImageLoadingStrategy: ImageLoadingStrategy {
    private var activeOperations: Set<String> = []
    private let maxConcurrentOperations: Int
    private let maxImageSize: CGFloat
    private var settings: PerformanceSettings
    
    // Statistics
    private var totalLoads: Int = 0
    private var successfulLoads: Int = 0
    private var failedLoads: Int = 0
    private var loadTimes: [TimeInterval] = []
    
    init(settings: PerformanceSettings) {
        self.settings = settings
        self.maxConcurrentOperations = settings.maxConcurrentLoads
        self.maxImageSize = 2048
        ProductionLogger.lifecycle("BasicImageLoadingStrategy: Initialized")
    }
    
    func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        let key = photo.imageURL.url.absoluteString
        
        // Prevent duplicate operations
        guard !activeOperations.contains(key) else {
            while activeOperations.contains(key) {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            return try await loadImage(from: photo, context: context)
        }
        
        // Respect concurrency limits
        while activeOperations.count >= maxConcurrentOperations {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        
        activeOperations.insert(key)
        defer { activeOperations.remove(key) }
        
        let startTime = Date()
        totalLoads += 1
        
        do {
            let image = try await loadAndOptimizeImage(from: photo.imageURL.url)
            let loadTime = Date().timeIntervalSince(startTime)
            
            successfulLoads += 1
            recordLoadTime(loadTime)
            
            return SendableImage(image)
        } catch {
            failedLoads += 1
            throw SlideshowError.loadingFailed(underlying: error)
        }
    }
    
    func loadImages(photos: [Photo], context: LoadingContext) async -> [UUID: SendableImage] {
        await withTaskGroup(of: (UUID, SendableImage?).self) { group in
            var results: [UUID: SendableImage] = [:]
            
            for photo in photos.prefix(maxConcurrentOperations) {
                group.addTask(priority: context.priority.taskPriority) {
                    do {
                        let image = try await self.loadImage(from: photo, context: context)
                        return (photo.id, image)
                    } catch {
                        return (photo.id, nil)
                    }
                }
            }
            
            for await (photoId, image) in group {
                if let image = image {
                    results[photoId] = image
                }
            }
            
            return results
        }
    }
    
    func updateSettings(_ settings: PerformanceSettings) async {
        self.settings = settings
    }
    
    func getStatistics() async -> LoadingStatistics {
        let averageLoadTime = loadTimes.isEmpty ? 0 : loadTimes.reduce(0, +) / Double(loadTimes.count)
        
        return LoadingStatistics(
            totalLoads: totalLoads,
            successfulLoads: successfulLoads,
            failedLoads: failedLoads,
            averageLoadTime: averageLoadTime,
            memoryUsageMB: 0, // Basic strategy doesn't cache
            cacheHitRate: 0,
            activeTaskCount: activeOperations.count
        )
    }
    
    func cancelOperations(for photoIds: Set<UUID>) async {
        // Basic strategy doesn't maintain photo-specific operations
        // Individual operations will check Task.isCancelled
    }
    
    func cleanup() async {
        activeOperations.removeAll()
        loadTimes.removeAll()
    }
    
    private func loadAndOptimizeImage(from url: URL) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                        continuation.resume(throwing: SlideshowError.loadingFailed(underlying: CocoaError(.fileReadCorruptFile)))
                        return
                    }
                    
                    let options: [CFString: Any] = [
                        kCGImageSourceThumbnailMaxPixelSize: self.maxImageSize,
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true
                    ]
                    
                    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                        continuation.resume(throwing: SlideshowError.loadingFailed(underlying: CocoaError(.fileReadCorruptFile)))
                        return
                    }
                    
                    let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: nsImage)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func recordLoadTime(_ time: TimeInterval) {
        loadTimes.append(time)
        if loadTimes.count > 100 {
            loadTimes.removeFirst()
        }
    }
}

// MARK: - Virtual Image Loading Strategy

/// Strategy for large collections with sliding window approach
/// Consolidates functionality from VirtualImageLoader
actor VirtualImageLoadingStrategy: ImageLoadingStrategy {
    private var windowSize: Int
    private let imageLoader: BasicImageLoadingStrategy
    private var loadedImages: [UUID: SendableImage] = [:]
    private var loadingTasks: [UUID: Task<SendableImage, Error>] = [:]
    private var settings: PerformanceSettings
    
    // Statistics
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var totalLoads: Int = 0
    
    init(settings: PerformanceSettings) {
        self.settings = settings
        self.windowSize = settings.memoryWindowSize
        self.imageLoader = BasicImageLoadingStrategy(settings: settings)
        ProductionLogger.lifecycle("VirtualImageLoadingStrategy: Initialized with window size: \(windowSize)")
    }
    
    func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        // Check if already loaded
        if let cachedImage = loadedImages[photo.id] {
            cacheHits += 1
            return cachedImage
        }
        
        cacheMisses += 1
        
        // Check if already loading
        if let existingTask = loadingTasks[photo.id] {
            return try await existingTask.value
        }
        
        // Create loading task
        let task = Task<SendableImage, Error> {
            try await imageLoader.loadImage(from: photo, context: context)
        }
        
        loadingTasks[photo.id] = task
        
        do {
            let image = try await task.value
            loadedImages[photo.id] = image
            loadingTasks.removeValue(forKey: photo.id)
            totalLoads += 1
            
            // Check memory pressure and cleanup if needed
            await handleMemoryPressure()
            
            return image
        } catch {
            loadingTasks.removeValue(forKey: photo.id)
            throw error
        }
    }
    
    func loadImages(photos: [Photo], context: LoadingContext) async -> [UUID: SendableImage] {
        let effectiveWindowSize = calculateEffectiveWindowSize(collectionSize: context.collectionSize)
        let currentIndex = context.currentIndex
        
        let startIndex = max(0, currentIndex - effectiveWindowSize / 2)
        let endIndex = min(photos.count - 1, currentIndex + effectiveWindowSize / 2)
        
        let photosInWindow = Set(photos[startIndex...endIndex].map { $0.id })
        
        // Cancel out-of-window tasks
        await cancelOutOfWindowTasks(photosInWindow: photosInWindow)
        
        // Load window images concurrently
        return await loadImageWindowConcurrently(
            centerIndex: currentIndex,
            startIndex: startIndex,
            endIndex: endIndex,
            photos: photos,
            context: context
        )
    }
    
    func updateSettings(_ settings: PerformanceSettings) async {
        self.settings = settings
        self.windowSize = settings.memoryWindowSize
        await imageLoader.updateSettings(settings)
    }
    
    func getStatistics() async -> LoadingStatistics {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        let memoryUsage = estimateMemoryUsage()
        
        return LoadingStatistics(
            totalLoads: totalLoads,
            successfulLoads: loadedImages.count,
            failedLoads: totalLoads - loadedImages.count,
            averageLoadTime: 0, // Would need to track individual load times
            memoryUsageMB: memoryUsage,
            cacheHitRate: hitRate,
            activeTaskCount: loadingTasks.count
        )
    }
    
    func cancelOperations(for photoIds: Set<UUID>) async {
        for photoId in photoIds {
            if let task = loadingTasks[photoId] {
                task.cancel()
                loadingTasks.removeValue(forKey: photoId)
            }
        }
    }
    
    func cleanup() async {
        loadedImages.removeAll()
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
        await imageLoader.cleanup()
    }
    
    func getImage(for photoId: UUID) -> SendableImage? {
        return loadedImages[photoId]
    }
    
    private func calculateEffectiveWindowSize(collectionSize: Int) -> Int {
        switch collectionSize {
        case 0...100:
            return min(windowSize, collectionSize)
        case 101...500:
            return min(windowSize, max(20, collectionSize / 5))
        case 501...2000:
            return min(windowSize, max(50, collectionSize / 10))
        case 2001...10000:
            return min(windowSize, max(100, collectionSize / 25))
        default:
            return min(windowSize, max(200, collectionSize / 100))
        }
    }
    
    private func cancelOutOfWindowTasks(photosInWindow: Set<UUID>) async {
        for (photoId, task) in loadingTasks {
            if !photosInWindow.contains(photoId) {
                task.cancel()
                loadingTasks.removeValue(forKey: photoId)
            }
        }
    }
    
    private func loadImageWindowConcurrently(
        centerIndex: Int,
        startIndex: Int,
        endIndex: Int,
        photos: [Photo],
        context: LoadingContext
    ) async -> [UUID: SendableImage] {
        let photosToLoad = (startIndex...endIndex).map { idx in
            let photo = photos[idx]
            let distance = abs(idx - centerIndex)
            return (photo: photo, distance: distance)
        }.sorted { $0.distance < $1.distance }
        
        let maxConcurrent = min(settings.maxConcurrentLoads, photosToLoad.count)
        
        return await withTaskGroup(of: (UUID, SendableImage?).self) { group in
            var results: [UUID: SendableImage] = [:]
            var semaphore = 0
            
            for (photo, distance) in photosToLoad {
                while semaphore >= maxConcurrent {
                    if let (photoId, image) = await group.next() {
                        if let image = image {
                            results[photoId] = image
                        }
                        semaphore -= 1
                    }
                }
                
                let priority: TaskPriority = distance == 0 ? .userInitiated : .utility
                
                group.addTask(priority: priority) {
                    do {
                        let image = try await self.loadImage(from: photo, context: context)
                        return (photo.id, image)
                    } catch {
                        return (photo.id, nil)
                    }
                }
                semaphore += 1
            }
            
            // Collect remaining results
            while semaphore > 0 {
                if let (photoId, image) = await group.next() {
                    if let image = image {
                        results[photoId] = image
                    }
                    semaphore -= 1
                }
            }
            
            return results
        }
    }
    
    private func handleMemoryPressure() async {
        let maxMemory = settings.maxMemoryUsageMB
        let currentUsage = estimateMemoryUsage()
        
        if currentUsage > maxMemory {
            let targetUsage = settings.aggressiveMemoryManagement ? maxMemory / 2 : maxMemory * 3 / 4
            await evictImagesUntilUnder(targetUsage: targetUsage)
        }
    }
    
    private func evictImagesUntilUnder(targetUsage: Int) async {
        let sortedImages = loadedImages.sorted { $0.key.uuidString < $1.key.uuidString }
        var currentUsage = estimateMemoryUsage()
        
        for (photoId, _) in sortedImages {
            if currentUsage <= targetUsage {
                break
            }
            loadedImages.removeValue(forKey: photoId)
            currentUsage = estimateMemoryUsage()
        }
    }
    
    private func estimateMemoryUsage() -> Int {
        var totalBytes = 0
        for image in loadedImages.values {
            totalBytes += Int(image.size.width * image.size.height * 4)
        }
        return totalBytes / (1024 * 1024) // Convert to MB
    }
}

// MARK: - Emergency Image Loading Strategy

/// Strategy for immediate loading (progress bar jumps, UI responsiveness)
/// Consolidates functionality from TargetImageLoader
actor EmergencyImageLoadingStrategy: ImageLoadingStrategy {
    private let imageLoader: BasicImageLoadingStrategy
    private var emergencyTasks: [UUID: Task<SendableImage, Error>] = [:]
    private var settings: PerformanceSettings
    
    // Statistics
    private var emergencyLoads: Int = 0
    private var emergencyLoadTimes: [TimeInterval] = []
    
    init(settings: PerformanceSettings) {
        self.settings = settings
        self.imageLoader = BasicImageLoadingStrategy(settings: settings)
        ProductionLogger.lifecycle("EmergencyImageLoadingStrategy: Initialized")
    }
    
    func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        let startTime = Date()
        emergencyLoads += 1
        
        // Cancel any existing emergency loads (new request takes priority)
        await cancelPreviousEmergencyLoads()
        
        let task = Task<SendableImage, Error> {
            try await imageLoader.loadImage(from: photo, context: context)
        }
        
        emergencyTasks[photo.id] = task
        
        do {
            let image = try await task.value
            let loadTime = Date().timeIntervalSince(startTime)
            recordEmergencyLoadTime(loadTime)
            
            emergencyTasks.removeValue(forKey: photo.id)
            ProductionLogger.performance("EmergencyImageLoadingStrategy: Emergency load completed in \(String(format: "%.2f", loadTime * 1000))ms")
            
            return image
        } catch {
            emergencyTasks.removeValue(forKey: photo.id)
            throw error
        }
    }
    
    func loadImages(photos: [Photo], context: LoadingContext) async -> [UUID: SendableImage] {
        // For emergency strategy, load with highest priority
        return await withTaskGroup(of: (UUID, SendableImage?).self) { group in
            var results: [UUID: SendableImage] = [:]
            
            for photo in photos {
                group.addTask(priority: .userInitiated) {
                    do {
                        let image = try await self.loadImage(from: photo, context: context)
                        return (photo.id, image)
                    } catch {
                        return (photo.id, nil)
                    }
                }
            }
            
            for await (photoId, image) in group {
                if let image = image {
                    results[photoId] = image
                }
            }
            
            return results
        }
    }
    
    func updateSettings(_ settings: PerformanceSettings) async {
        self.settings = settings
        await imageLoader.updateSettings(settings)
    }
    
    func getStatistics() async -> LoadingStatistics {
        let averageTime = emergencyLoadTimes.isEmpty ? 0 : emergencyLoadTimes.reduce(0, +) / Double(emergencyLoadTimes.count)
        
        return LoadingStatistics(
            totalLoads: emergencyLoads,
            successfulLoads: emergencyLoads - emergencyTasks.count,
            failedLoads: 0, // Tracked elsewhere
            averageLoadTime: averageTime,
            memoryUsageMB: 0,
            cacheHitRate: 0,
            activeTaskCount: emergencyTasks.count
        )
    }
    
    func cancelOperations(for photoIds: Set<UUID>) async {
        for photoId in photoIds {
            if let task = emergencyTasks[photoId] {
                task.cancel()
                emergencyTasks.removeValue(forKey: photoId)
            }
        }
    }
    
    func cleanup() async {
        await cancelPreviousEmergencyLoads()
        emergencyLoadTimes.removeAll()
        await imageLoader.cleanup()
    }
    
    private func cancelPreviousEmergencyLoads() async {
        for task in emergencyTasks.values {
            task.cancel()
        }
        emergencyTasks.removeAll()
    }
    
    private func recordEmergencyLoadTime(_ time: TimeInterval) {
        emergencyLoadTimes.append(time)
        if emergencyLoadTimes.count > 10 {
            emergencyLoadTimes.removeFirst()
        }
    }
}

// MARK: - Preload Image Loading Strategy

/// Strategy for background preloading based on navigation patterns
/// Consolidates functionality from BackgroundPreloader
actor PreloadImageLoadingStrategy: ImageLoadingStrategy {
    private let imageLoader: BasicImageLoadingStrategy
    private var preloadTasks: [UUID: Task<Void, Never>] = [:]
    private var settings: PerformanceSettings
    
    // Navigation tracking
    private var navigationHistory: [Int] = []
    private var lastNavigationTime: Date = Date()
    private var navigationDirection: NavigationDirection = .unknown
    
    // Statistics
    private var totalPreloads: Int = 0
    private var successfulPreloads: Int = 0
    
    init(settings: PerformanceSettings) {
        self.settings = settings
        self.imageLoader = BasicImageLoadingStrategy(settings: settings)
        ProductionLogger.lifecycle("PreloadImageLoadingStrategy: Initialized")
    }
    
    func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        return try await imageLoader.loadImage(from: photo, context: context)
    }
    
    func loadImages(photos: [Photo], context: LoadingContext) async -> [UUID: SendableImage] {
        updateNavigationHistory(currentIndex: context.currentIndex)
        
        let effectiveWindowSize = min(settings.preloadDistance, photos.count > 10000 ? 100 : settings.preloadDistance)
        let (startIndex, endIndex) = calculateIntelligentPreloadRange(
            currentIndex: context.currentIndex,
            photos: photos,
            maxScope: effectiveWindowSize
        )
        
        await schedulePreloadTasks(photos: photos, startIndex: startIndex, endIndex: endIndex, context: context)
        
        return [:] // Preload strategy doesn't return immediate results
    }
    
    func updateSettings(_ settings: PerformanceSettings) async {
        self.settings = settings
        await imageLoader.updateSettings(settings)
    }
    
    func getStatistics() async -> LoadingStatistics {
        return LoadingStatistics(
            totalLoads: totalPreloads,
            successfulLoads: successfulPreloads,
            failedLoads: totalPreloads - successfulPreloads,
            averageLoadTime: 0,
            memoryUsageMB: 0,
            cacheHitRate: 0,
            activeTaskCount: preloadTasks.count
        )
    }
    
    func cancelOperations(for photoIds: Set<UUID>) async {
        for photoId in photoIds {
            if let task = preloadTasks[photoId] {
                task.cancel()
                preloadTasks.removeValue(forKey: photoId)
            }
        }
    }
    
    func cleanup() async {
        for task in preloadTasks.values {
            task.cancel()
        }
        preloadTasks.removeAll()
        await imageLoader.cleanup()
    }
    
    private func updateNavigationHistory(currentIndex: Int) {
        navigationHistory.append(currentIndex)
        if navigationHistory.count > 10 {
            navigationHistory.removeFirst()
        }
        
        // Detect navigation direction
        if navigationHistory.count >= 2 {
            let recent = navigationHistory.suffix(3)
            let isForward = recent.allSatisfy { recent.first! <= $0 }
            let isBackward = recent.allSatisfy { recent.first! >= $0 }
            
            if isForward {
                navigationDirection = .forward
            } else if isBackward {
                navigationDirection = .backward
            } else {
                navigationDirection = .unknown
            }
        }
    }
    
    private func calculateIntelligentPreloadRange(
        currentIndex: Int,
        photos: [Photo],
        maxScope: Int
    ) -> (Int, Int) {
        let asymmetricRange: (Int, Int)
        
        switch navigationDirection {
        case .forward:
            asymmetricRange = (currentIndex - maxScope / 4, currentIndex + maxScope * 3 / 4)
        case .backward:
            asymmetricRange = (currentIndex - maxScope * 3 / 4, currentIndex + maxScope / 4)
        case .unknown:
            asymmetricRange = (currentIndex - maxScope / 2, currentIndex + maxScope / 2)
        }
        
        return (
            max(0, asymmetricRange.0),
            min(photos.count - 1, asymmetricRange.1)
        )
    }
    
    private func schedulePreloadTasks(
        photos: [Photo],
        startIndex: Int,
        endIndex: Int,
        context: LoadingContext
    ) async {
        // Cancel existing tasks
        for task in preloadTasks.values {
            task.cancel()
        }
        preloadTasks.removeAll()
        
        let availableSlots = min(settings.maxConcurrentLoads, endIndex - startIndex + 1)
        
        for i in 0..<availableSlots {
            let index = startIndex + i
            guard index <= endIndex else { break }
            
            let photo = photos[index]
            
            let task = Task {
                do {
                    _ = try await self.imageLoader.loadImage(from: photo, context: context)
                    self.successfulPreloads += 1
                } catch {
                    // Preload failures are not critical
                }
                self.totalPreloads += 1
                self.preloadTasks.removeValue(forKey: photo.id)
            }
            
            preloadTasks[photo.id] = task
        }
    }
}