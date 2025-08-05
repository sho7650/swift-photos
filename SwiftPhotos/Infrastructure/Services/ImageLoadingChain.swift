import Foundation
import AppKit

/// Chain of Responsibility pattern for image loading with flexible handler composition
/// Reduces complexity by providing a unified interface to multiple loading strategies
@MainActor
public class ImageLoadingChain {
    
    // MARK: - Chain Management
    
    private let chainManager: ImageHandlerChain
    private let settings: PerformanceSettings
    
    // MARK: - Statistics
    
    private var loadStatistics: ImageLoadingStatistics
    
    // MARK: - Initialization
    
    public init(settings: PerformanceSettings = .default) {
        self.settings = settings
        self.loadStatistics = ImageLoadingStatistics()
        
        // Create handler chain with optimized order
        self.chainManager = ImageHandlerChain(settings: settings)
        
        ProductionLogger.lifecycle("ImageLoadingChain: Initialized with Chain of Responsibility pattern")
    }
    
    // MARK: - Public Interface
    
    /// Load a single image using the most appropriate handler in the chain
    public func loadImage(from photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        let startTime = Date()
        
        do {
            let image = try await chainManager.handleImageLoad(photo: photo, context: context)
            
            let loadTime = Date().timeIntervalSince(startTime)
            await updateStatistics(success: true, loadTime: loadTime)
            
            ProductionLogger.performance("ImageLoadingChain: Image loaded in \(String(format: "%.2f", loadTime * 1000))ms")
            return image
            
        } catch {
            let loadTime = Date().timeIntervalSince(startTime)
            await updateStatistics(success: false, loadTime: loadTime)
            
            ProductionLogger.error("ImageLoadingChain: Load failed after \(String(format: "%.2f", loadTime * 1000))ms: \(error)")
            throw error
        }
    }
    
    /// Load multiple images using appropriate handlers
    public func loadImages(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        let startTime = Date()
        let results = await chainManager.handleBatchImageLoad(photos: photos, context: context)
        
        let totalTime = Date().timeIntervalSince(startTime)
        ProductionLogger.performance("ImageLoadingChain: Batch loaded \(results.count)/\(photos.count) images in \(String(format: "%.2f", totalTime * 1000))ms")
        
        return results
    }
    
    /// Emergency load for immediate response (progress jumps)
    public func loadImageEmergency(photo: Photo, completion: @escaping (Result<SendableImage, Error>) -> Void) {
        Task {
            let context = ImageLoadingContext(priority: .urgent, isEmergency: true)
            do {
                let image = try await loadImage(from: photo, context: context)
                await MainActor.run {
                    completion(.success(image))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Update performance settings for all handlers
    public func updateSettings(_ newSettings: PerformanceSettings) {
        Task {
            await chainManager.updateSettings(newSettings)
        }
        ProductionLogger.debug("ImageLoadingChain: Settings updated across all handlers")
    }
    
    /// Get comprehensive loading statistics
    public func getStatistics() -> ImageLoadingStatistics {
        return loadStatistics
    }
    
    /// Cancel operations for specific photos
    public func cancelOperations(for photoIds: Set<UUID>) async {
        await chainManager.cancelOperations(for: photoIds)
    }
    
    /// Cancel all operations
    public func cancelAllOperations() async {
        await chainManager.cancelAllOperations()
    }
    
    /// Cleanup resources
    public func cleanup() async {
        await chainManager.cleanup()
        loadStatistics = ImageLoadingStatistics()
        ProductionLogger.lifecycle("ImageLoadingChain: Cleanup completed")
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics(success: Bool, loadTime: TimeInterval) async {
        loadStatistics = ImageLoadingStatistics(
            totalLoads: loadStatistics.totalLoads + 1,
            successfulLoads: loadStatistics.successfulLoads + (success ? 1 : 0),
            failedLoads: loadStatistics.failedLoads + (success ? 0 : 1),
            averageLoadTime: calculateNewAverageLoadTime(currentAverage: loadStatistics.averageLoadTime, 
                                                       totalLoads: loadStatistics.totalLoads, 
                                                       newTime: loadTime),
            memoryUsageMB: loadStatistics.memoryUsageMB,
            cacheHitRate: loadStatistics.cacheHitRate
        )
    }
    
    private func calculateNewAverageLoadTime(currentAverage: TimeInterval, totalLoads: Int, newTime: TimeInterval) -> TimeInterval {
        let totalTime = currentAverage * Double(totalLoads) + newTime
        return totalTime / Double(totalLoads + 1)
    }
}

// MARK: - Chain Handler Management

/// Manages the chain of image loading handlers
actor ImageHandlerChain {
    
    // MARK: - Handler Chain
    
    private let cacheHandler: CacheImageHandler
    private let emergencyHandler: EmergencyImageHandler
    private let virtualHandler: VirtualImageHandler
    private let basicHandler: BasicImageHandler
    
    private var settings: PerformanceSettings
    
    // MARK: - Initialization
    
    init(settings: PerformanceSettings) {
        self.settings = settings
        
        // Create handlers
        self.basicHandler = BasicImageHandler(settings: settings)
        self.virtualHandler = VirtualImageHandler(settings: settings)
        self.emergencyHandler = EmergencyImageHandler(settings: settings)
        self.cacheHandler = CacheImageHandler(settings: settings)
        
        // Build chain: Cache -> Emergency -> Virtual -> Basic
        Task {
            await cacheHandler.setNext(emergencyHandler)
            await emergencyHandler.setNext(virtualHandler)
            await virtualHandler.setNext(basicHandler)
        }
        
        ProductionLogger.lifecycle("ImageHandlerChain: Initialized handler chain")
    }
    
    // MARK: - Chain Operations
    
    func handleImageLoad(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        return try await cacheHandler.handle(photo: photo, context: context)
    }
    
    func handleBatchImageLoad(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        return await cacheHandler.handleBatch(photos: photos, context: context)
    }
    
    func updateSettings(_ newSettings: PerformanceSettings) async {
        self.settings = newSettings
        
        await cacheHandler.updateSettingsHandler(newSettings)
        await emergencyHandler.updateSettingsHandler(newSettings)
        await virtualHandler.updateSettingsHandler(newSettings)
        await basicHandler.updateSettingsHandler(newSettings)
    }
    
    func cancelOperations(for photoIds: Set<UUID>) async {
        await cacheHandler.cancelOperationsHandler(for: photoIds)
        await emergencyHandler.cancelOperationsHandler(for: photoIds)
        await virtualHandler.cancelOperationsHandler(for: photoIds)
        await basicHandler.cancelOperationsHandler(for: photoIds)
    }
    
    func cancelAllOperations() async {
        await cacheHandler.cancelAllOperationsHandler()
        await emergencyHandler.cancelAllOperationsHandler()
        await virtualHandler.cancelAllOperationsHandler()
        await basicHandler.cancelAllOperationsHandler()
    }
    
    func cleanup() async {
        await cacheHandler.cleanupHandler()
        await emergencyHandler.cleanupHandler()
        await virtualHandler.cleanupHandler()
        await basicHandler.cleanupHandler()
    }
}

// MARK: - Abstract Handler Base Class

/// Protocol for image loading handlers implementing Chain of Responsibility
protocol ImageLoadingHandlerProtocol: Actor {
    func setNext(_ handler: any ImageLoadingHandlerProtocol)
    func handle(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage
    func handleBatch(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage]
    func canHandle(photo: Photo, context: ImageLoadingContext) async -> Bool
    func processImage(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage
    func updateSettingsHandler(_ newSettings: PerformanceSettings)
    func cancelOperationsHandler(for photoIds: Set<UUID>) async
    func cancelAllOperationsHandler() async
    func cleanupHandler() async
}

/// Base implementation for image loading handlers
actor BaseImageLoadingHandler: ImageLoadingHandlerProtocol {
    
    // MARK: - Chain Properties
    
    private var nextHandler: (any ImageLoadingHandlerProtocol)?
    var settings: PerformanceSettings
    
    // MARK: - Statistics
    
    var handlerStatistics: HandlerStatistics
    
    // MARK: - Initialization
    
    init(settings: PerformanceSettings) {
        self.settings = settings
        self.handlerStatistics = HandlerStatistics()
    }
    
    // MARK: - Chain Management
    
    func setNext(_ handler: any ImageLoadingHandlerProtocol) {
        self.nextHandler = handler
    }
    
    // MARK: - Template Methods
    
    func handle(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        if await canHandle(photo: photo, context: context) {
            return try await processImage(photo: photo, context: context)
        } else if let next = nextHandler {
            return try await next.handle(photo: photo, context: context)
        } else {
            throw ImageLoadingError.noSuitableHandler
        }
    }
    
    func handleBatch(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        var results: [UUID: SendableImage] = [:]
        
        // Try to handle photos that this handler can process
        for photo in photos {
            if await canHandle(photo: photo, context: context) {
                do {
                    let image = try await processImage(photo: photo, context: context)
                    results[photo.id] = image
                } catch {
                    ProductionLogger.error("Handler \(type(of: self)): Failed to process \(photo.id): \(error)")
                }
            }
        }
        
        // Pass unhandled photos to next handler
        let unhandledPhotos = photos.filter { !results.keys.contains($0.id) }
        if !unhandledPhotos.isEmpty, let next = nextHandler {
            let nextResults = await next.handleBatch(photos: unhandledPhotos, context: context)
            results.merge(nextResults) { _, new in new }
        }
        
        return results
    }
    
    // MARK: - Abstract Methods (Override in Subclasses)
    
    func canHandle(photo: Photo, context: ImageLoadingContext) async -> Bool {
        return false // Default: cannot handle
    }
    
    func processImage(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        throw ImageLoadingError.notImplemented
    }
    
    // MARK: - Common Functionality
    
    func updateSettingsHandler(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
    }
    
    func cancelOperationsHandler(for photoIds: Set<UUID>) async {
        // Default implementation - override in subclasses
    }
    
    func cancelAllOperationsHandler() async {
        // Default implementation - override in subclasses
    }
    
    func cleanupHandler() async {
        // Default implementation - override in subclasses
    }
    
    func getStatistics() -> HandlerStatistics {
        return handlerStatistics
    }
}

// MARK: - Concrete Handler Implementations

/// Cache-first handler for immediate responses
actor CacheImageHandler: ImageLoadingHandlerProtocol {
    
    private let imageCache: ImageCache
    private var nextHandler: (any ImageLoadingHandlerProtocol)?
    var settings: PerformanceSettings
    var handlerStatistics: HandlerStatistics
    
    init(settings: PerformanceSettings) {
        self.imageCache = ImageCache()
        self.settings = settings
        self.handlerStatistics = HandlerStatistics()
        ProductionLogger.lifecycle("CacheImageHandler: Initialized")
    }
    
    func setNext(_ handler: any ImageLoadingHandlerProtocol) {
        self.nextHandler = handler
    }
    
    func handle(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        if await canHandle(photo: photo, context: context) {
            return try await processImage(photo: photo, context: context)
        } else if let next = nextHandler {
            return try await next.handle(photo: photo, context: context)
        } else {
            throw ImageLoadingError.noSuitableHandler
        }
    }
    
    func handleBatch(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        var results: [UUID: SendableImage] = [:]
        
        for photo in photos {
            if await canHandle(photo: photo, context: context) {
                do {
                    let image = try await processImage(photo: photo, context: context)
                    results[photo.id] = image
                } catch {
                    ProductionLogger.error("CacheImageHandler: Failed to process \(photo.id): \(error)")
                }
            }
        }
        
        let unhandledPhotos = photos.filter { !results.keys.contains($0.id) }
        if !unhandledPhotos.isEmpty, let next = nextHandler {
            let nextResults = await next.handleBatch(photos: unhandledPhotos, context: context)
            results.merge(nextResults) { _, new in new }
        }
        
        return results
    }
    
    func canHandle(photo: Photo, context: ImageLoadingContext) async -> Bool {
        return await imageCache.image(for: photo.imageURL) != nil
    }
    
    func processImage(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        guard let cachedImage = await imageCache.image(for: photo.imageURL) else {
            throw ImageLoadingError.notInCache
        }
        
        handlerStatistics.incrementCacheHits()
        ProductionLogger.debug("CacheImageHandler: Cache hit for \(photo.fileName)")
        return cachedImage
    }
    
    func updateSettingsHandler(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
    }
    
    func cancelOperationsHandler(for photoIds: Set<UUID>) async {}
    func cancelAllOperationsHandler() async {}
    func cleanupHandler() async {}
}

/// Emergency handler for high-priority immediate loads
actor EmergencyImageHandler: ImageLoadingHandlerProtocol {
    
    private let imageLoader: ImageLoader
    private var emergencyTasks: [UUID: Task<SendableImage, Error>] = [:]
    private var nextHandler: (any ImageLoadingHandlerProtocol)?
    var settings: PerformanceSettings
    var handlerStatistics: HandlerStatistics
    
    init(settings: PerformanceSettings) {
        self.imageLoader = ImageLoader(maxConcurrentOperations: settings.maxConcurrentLoads)
        self.settings = settings
        self.handlerStatistics = HandlerStatistics()
        ProductionLogger.lifecycle("EmergencyImageHandler: Initialized")
    }
    
    func setNext(_ handler: any ImageLoadingHandlerProtocol) {
        self.nextHandler = handler
    }
    
    func handle(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        if await canHandle(photo: photo, context: context) {
            return try await processImage(photo: photo, context: context)
        } else if let next = nextHandler {
            return try await next.handle(photo: photo, context: context)
        } else {
            throw ImageLoadingError.noSuitableHandler
        }
    }
    
    func handleBatch(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        var results: [UUID: SendableImage] = [:]
        
        for photo in photos {
            if await canHandle(photo: photo, context: context) {
                do {
                    let image = try await processImage(photo: photo, context: context)
                    results[photo.id] = image
                } catch {
                    ProductionLogger.error("EmergencyImageHandler: Failed to process \(photo.id): \(error)")
                }
            }
        }
        
        let unhandledPhotos = photos.filter { !results.keys.contains($0.id) }
        if !unhandledPhotos.isEmpty, let next = nextHandler {
            let nextResults = await next.handleBatch(photos: unhandledPhotos, context: context)
            results.merge(nextResults) { _, new in new }
        }
        
        return results
    }
    
    func canHandle(photo: Photo, context: ImageLoadingContext) async -> Bool {
        return context.isEmergency || context.priority == .urgent
    }
    
    func processImage(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        await cancelPreviousEmergencyTasks()
        
        let task = Task<SendableImage, Error> {
            try await imageLoader.loadImage(from: photo.imageURL)
        }
        
        emergencyTasks[photo.id] = task
        defer { emergencyTasks.removeValue(forKey: photo.id) }
        
        let image = try await task.value
        handlerStatistics.incrementProcessedImages()
        ProductionLogger.debug("EmergencyImageHandler: Emergency load completed for \(photo.fileName)")
        return image
    }
    
    func updateSettingsHandler(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
    }
    
    func cancelOperationsHandler(for photoIds: Set<UUID>) async {
        for photoId in photoIds {
            if let task = emergencyTasks[photoId] {
                task.cancel()
                emergencyTasks.removeValue(forKey: photoId)
            }
        }
    }
    
    func cancelAllOperationsHandler() async {
        for task in emergencyTasks.values {
            task.cancel()
        }
        emergencyTasks.removeAll()
    }
    
    func cleanupHandler() async {
        await cancelAllOperationsHandler()
    }
    
    private func cancelPreviousEmergencyTasks() async {
        await cancelAllOperationsHandler()
    }
}

/// Virtual handler for sliding window management
actor VirtualImageHandler: ImageLoadingHandlerProtocol {
    
    private let virtualLoader: VirtualImageLoader
    private var nextHandler: (any ImageLoadingHandlerProtocol)?
    var settings: PerformanceSettings
    var handlerStatistics: HandlerStatistics
    
    init(settings: PerformanceSettings) {
        self.virtualLoader = VirtualImageLoader(settings: settings)
        self.settings = settings
        self.handlerStatistics = HandlerStatistics()
        ProductionLogger.lifecycle("VirtualImageHandler: Initialized")
    }
    
    func setNext(_ handler: any ImageLoadingHandlerProtocol) {
        self.nextHandler = handler
    }
    
    func handle(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        if await canHandle(photo: photo, context: context) {
            return try await processImage(photo: photo, context: context)
        } else if let next = nextHandler {
            return try await next.handle(photo: photo, context: context)
        } else {
            throw ImageLoadingError.noSuitableHandler
        }
    }
    
    func handleBatch(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        var results: [UUID: SendableImage] = [:]
        
        for photo in photos {
            if await canHandle(photo: photo, context: context) {
                do {
                    let image = try await processImage(photo: photo, context: context)
                    results[photo.id] = image
                } catch {
                    ProductionLogger.error("VirtualImageHandler: Failed to process \(photo.id): \(error)")
                }
            }
        }
        
        let unhandledPhotos = photos.filter { !results.keys.contains($0.id) }
        if !unhandledPhotos.isEmpty, let next = nextHandler {
            let nextResults = await next.handleBatch(photos: unhandledPhotos, context: context)
            results.merge(nextResults) { _, new in new }
        }
        
        return results
    }
    
    func canHandle(photo: Photo, context: ImageLoadingContext) async -> Bool {
        return context.collectionSize > 100 || context.windowSize != nil
    }
    
    func processImage(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        if let cachedImage = await virtualLoader.getImage(for: photo.id) {
            handlerStatistics.incrementCacheHits()
            return cachedImage
        }
        
        if let photos = context.allPhotos, let currentIndex = context.currentIndex {
            await virtualLoader.loadImageWindow(around: currentIndex, photos: photos)
            
            if let image = await virtualLoader.getImage(for: photo.id) {
                handlerStatistics.incrementProcessedImages()
                return image
            }
        }
        
        throw ImageLoadingError.virtualLoadFailed
    }
    
    func updateSettingsHandler(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
        Task {
            await virtualLoader.updateSettings(newSettings)
        }
    }
    
    func cancelOperationsHandler(for photoIds: Set<UUID>) async {
        for photoId in photoIds {
            await virtualLoader.cancelLoad(for: photoId)
        }
    }
    
    func cancelAllOperationsHandler() async {
        await virtualLoader.clearCache()
    }
    
    func cleanupHandler() async {
        await virtualLoader.clearCache()
    }
}

/// Basic handler for standard image loading
actor BasicImageHandler: ImageLoadingHandlerProtocol {
    
    private let imageLoader: ImageLoader
    private var nextHandler: (any ImageLoadingHandlerProtocol)?
    var settings: PerformanceSettings
    var handlerStatistics: HandlerStatistics
    
    init(settings: PerformanceSettings) {
        self.imageLoader = ImageLoader(maxConcurrentOperations: settings.maxConcurrentLoads)
        self.settings = settings
        self.handlerStatistics = HandlerStatistics()
        ProductionLogger.lifecycle("BasicImageHandler: Initialized")
    }
    
    func setNext(_ handler: any ImageLoadingHandlerProtocol) {
        self.nextHandler = handler
    }
    
    func handle(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        if await canHandle(photo: photo, context: context) {
            return try await processImage(photo: photo, context: context)
        } else if let next = nextHandler {
            return try await next.handle(photo: photo, context: context)
        } else {
            throw ImageLoadingError.noSuitableHandler
        }
    }
    
    func handleBatch(photos: [Photo], context: ImageLoadingContext) async -> [UUID: SendableImage] {
        var results: [UUID: SendableImage] = [:]
        
        for photo in photos {
            if await canHandle(photo: photo, context: context) {
                do {
                    let image = try await processImage(photo: photo, context: context)
                    results[photo.id] = image
                } catch {
                    ProductionLogger.error("BasicImageHandler: Failed to process \(photo.id): \(error)")
                }
            }
        }
        
        let unhandledPhotos = photos.filter { !results.keys.contains($0.id) }
        if !unhandledPhotos.isEmpty, let next = nextHandler {
            let nextResults = await next.handleBatch(photos: unhandledPhotos, context: context)
            results.merge(nextResults) { _, new in new }
        }
        
        return results
    }
    
    func canHandle(photo: Photo, context: ImageLoadingContext) async -> Bool {
        return true // Basic handler can handle any image
    }
    
    func processImage(photo: Photo, context: ImageLoadingContext) async throws -> SendableImage {
        let image = try await imageLoader.loadImage(from: photo.imageURL)
        handlerStatistics.incrementProcessedImages()
        ProductionLogger.debug("BasicImageHandler: Basic load completed for \(photo.fileName)")
        return image
    }
    
    func updateSettingsHandler(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
    }
    
    func cancelOperationsHandler(for photoIds: Set<UUID>) async {}
    func cancelAllOperationsHandler() async {}
    func cleanupHandler() async {}
}

// MARK: - Supporting Types

/// Loading context for handlers
public struct ImageLoadingContext: Sendable {
    let collectionSize: Int
    let currentIndex: Int?
    let priority: ImageLoadingPriority
    let isEmergency: Bool
    let windowSize: Int?
    let allPhotos: [Photo]?
    
    public init(
        collectionSize: Int = 1,
        currentIndex: Int? = nil,
        priority: ImageLoadingPriority = .normal,
        isEmergency: Bool = false,
        windowSize: Int? = nil,
        allPhotos: [Photo]? = nil
    ) {
        self.collectionSize = collectionSize
        self.currentIndex = currentIndex
        self.priority = priority
        self.isEmergency = isEmergency
        self.windowSize = windowSize
        self.allPhotos = allPhotos
    }
}

/// Image loading priority levels
public enum ImageLoadingPriority: Sendable {
    case urgent
    case high
    case normal
    case background
}

/// Image loading statistics
public struct ImageLoadingStatistics {
    let totalLoads: Int
    let successfulLoads: Int
    let failedLoads: Int
    let averageLoadTime: TimeInterval
    let memoryUsageMB: Int
    let cacheHitRate: Double
    
    public init(
        totalLoads: Int = 0,
        successfulLoads: Int = 0,
        failedLoads: Int = 0,
        averageLoadTime: TimeInterval = 0,
        memoryUsageMB: Int = 0,
        cacheHitRate: Double = 0
    ) {
        self.totalLoads = totalLoads
        self.successfulLoads = successfulLoads
        self.failedLoads = failedLoads
        self.averageLoadTime = averageLoadTime
        self.memoryUsageMB = memoryUsageMB
        self.cacheHitRate = cacheHitRate
    }
}

/// Handler-specific statistics
struct HandlerStatistics {
    private(set) var processedImages: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var failures: Int = 0
    
    mutating func incrementProcessedImages() {
        processedImages += 1
    }
    
    mutating func incrementCacheHits() {
        cacheHits += 1
    }
    
    mutating func incrementFailures() {
        failures += 1
    }
}

/// Image loading errors
public enum ImageLoadingError: LocalizedError {
    case noSuitableHandler
    case notImplemented
    case notInCache
    case virtualLoadFailed
    
    public var errorDescription: String? {
        switch self {
        case .noSuitableHandler:
            return "No suitable handler found in the chain"
        case .notImplemented:
            return "Handler method not implemented"
        case .notInCache:
            return "Image not found in cache"
        case .virtualLoadFailed:
            return "Virtual loader failed to load image"
        }
    }
}

// MARK: - ImageCache Extension

extension ImageCache {
    /// Get image from cache
    func image(for url: ImageURL) async -> SendableImage? {
        return getCachedImage(for: url)
    }
}