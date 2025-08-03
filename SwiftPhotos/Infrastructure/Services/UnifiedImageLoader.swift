import Foundation
import AppKit

/// Unified image loader that adaptively selects the best loading strategy
/// based on collection size, memory pressure, and operational context
/// Consolidates functionality from ImageLoader, VirtualImageLoader, 
/// TargetImageLoader, and BackgroundPreloader
public actor UnifiedImageLoader {
    
    // MARK: - Dependencies
    private let strategySelector: LoadingStrategySelector
    private let basicStrategy: BasicImageLoadingStrategy
    private let virtualStrategy: VirtualImageLoadingStrategy
    private let emergencyStrategy: EmergencyImageLoadingStrategy
    private let preloadStrategy: PreloadImageLoadingStrategy
    
    // MARK: - State
    private var currentSettings: PerformanceSettings
    private var globalStatistics: LoadingStatistics
    private var activeOperations: [UUID: LoadOperation] = [:]
    
    // MARK: - Callbacks
    private var onImageLoaded: (@MainActor (UUID, SendableImage) -> Void)?
    private var onImageLoadFailed: (@MainActor (UUID, Error) -> Void)?
    
    // MARK: - Initialization
    
    public init(settings: PerformanceSettings = .default) {
        self.currentSettings = settings
        
        // Initialize strategy implementations
        self.basicStrategy = BasicImageLoadingStrategy(settings: settings)
        self.virtualStrategy = VirtualImageLoadingStrategy(settings: settings)
        self.emergencyStrategy = EmergencyImageLoadingStrategy(settings: settings)
        self.preloadStrategy = PreloadImageLoadingStrategy(settings: settings)
        
        // Initialize strategy selector
        self.strategySelector = DefaultLoadingStrategySelector(
            basicStrategy: basicStrategy,
            virtualStrategy: virtualStrategy,
            emergencyStrategy: emergencyStrategy,
            preloadStrategy: preloadStrategy
        )
        
        // Initialize statistics
        self.globalStatistics = LoadingStatistics(
            totalLoads: 0,
            successfulLoads: 0,
            failedLoads: 0,
            averageLoadTime: 0,
            memoryUsageMB: 0,
            cacheHitRate: 0,
            activeTaskCount: 0
        )
        
        ProductionLogger.lifecycle("UnifiedImageLoader: Initialized with adaptive strategy selection")
    }
    
    // MARK: - Public Interface
    
    /// Load a single image using the most appropriate strategy
    public func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        let operation = LoadOperation(photo: photo, context: context, strategy: "auto")
        activeOperations[photo.id] = operation
        
        defer {
            activeOperations.removeValue(forKey: photo.id)
        }
        
        do {
            let strategy = await strategySelector.selectStrategy(for: context)
            let image = try await strategy.loadImage(from: photo, context: context)
            
            // Update statistics
            await updateStatistics(for: operation, success: true, image: image)
            
            // Notify UI if callback is set
            if let callback = onImageLoaded {
                await callback(photo.id, image)
            }
            
            return image
            
        } catch {
            await updateStatistics(for: operation, success: false, image: nil)
            
            // Notify UI of failure if callback is set
            if let callback = onImageLoadFailed {
                await callback(photo.id, error)
            }
            
            throw error
        }
    }
    
    /// Load multiple images using window-based strategy
    public func loadImageWindow(
        around centerIndex: Int,
        photos: [Photo],
        windowSize: Int? = nil
    ) async -> [UUID: SendableImage] {
        let context = LoadingContext(
            collectionSize: photos.count,
            currentIndex: centerIndex,
            priority: .normal,
            memoryPressure: await calculateMemoryPressure()
        )
        
        let strategy = await strategySelector.selectStrategy(for: context)
        let loadedImages = await strategy.loadImages(photos: photos, context: context)
        
        // Trigger callbacks for each loaded image
        for (photoId, image) in loadedImages {
            if let callback = onImageLoaded {
                await callback(photoId, image)
            }
        }
        
        return loadedImages
    }
    
    /// Emergency load for immediate UI response (progress bar jumps)
    public func loadImageEmergency(
        photo: Photo,
        completion: @escaping @MainActor (Result<SendableImage, Error>) -> Void
    ) {
        Task {
            let context = LoadingContext(
                collectionSize: 1,
                currentIndex: 0,
                priority: .emergency,
                isEmergency: true
            )
            
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
    
    /// Schedule background preloading
    public func schedulePreload(
        photos: [Photo],
        currentIndex: Int,
        navigationDirection: NavigationDirection? = nil
    ) async {
        let context = LoadingContext(
            collectionSize: photos.count,
            currentIndex: currentIndex,
            priority: .background,
            navigationDirection: navigationDirection
        )
        
        let strategy = await strategySelector.selectStrategy(for: context)
        _ = await strategy.loadImages(photos: photos, context: context)
    }
    
    /// Update performance settings for all strategies
    public func updateSettings(_ newSettings: PerformanceSettings) async {
        self.currentSettings = newSettings
        
        await basicStrategy.updateSettings(newSettings)
        await virtualStrategy.updateSettings(newSettings)
        await emergencyStrategy.updateSettings(newSettings)
        await preloadStrategy.updateSettings(newSettings)
        
        ProductionLogger.debug("UnifiedImageLoader: Settings updated across all strategies")
    }
    
    /// Set callback for successful image loads
    public func setImageLoadedCallback(_ callback: @escaping @MainActor (UUID, SendableImage) -> Void) {
        self.onImageLoaded = callback
    }
    
    /// Set callback for failed image loads
    public func setImageLoadFailedCallback(_ callback: @escaping @MainActor (UUID, Error) -> Void) {
        self.onImageLoadFailed = callback
    }
    
    /// Cancel operations for specific photos
    public func cancelOperations(for photoIds: Set<UUID>) async {
        await basicStrategy.cancelOperations(for: photoIds)
        await virtualStrategy.cancelOperations(for: photoIds)
        await emergencyStrategy.cancelOperations(for: photoIds)
        await preloadStrategy.cancelOperations(for: photoIds)
        
        // Remove from active operations
        for photoId in photoIds {
            activeOperations.removeValue(forKey: photoId)
        }
    }
    
    /// Cancel all operations
    public func cancelAllOperations() async {
        let allPhotoIds = Set(activeOperations.keys)
        await cancelOperations(for: allPhotoIds)
    }
    
    /// Get comprehensive statistics from all strategies
    public func getStatistics() async -> LoadingStatistics {
        let basicStats = await basicStrategy.getStatistics()
        let virtualStats = await virtualStrategy.getStatistics()
        let emergencyStats = await emergencyStrategy.getStatistics()
        let preloadStats = await preloadStrategy.getStatistics()
        
        return LoadingStatistics(
            totalLoads: basicStats.totalLoads + virtualStats.totalLoads + emergencyStats.totalLoads + preloadStats.totalLoads,
            successfulLoads: basicStats.successfulLoads + virtualStats.successfulLoads + emergencyStats.successfulLoads + preloadStats.successfulLoads,
            failedLoads: basicStats.failedLoads + virtualStats.failedLoads + emergencyStats.failedLoads + preloadStats.failedLoads,
            averageLoadTime: (basicStats.averageLoadTime + virtualStats.averageLoadTime + emergencyStats.averageLoadTime + preloadStats.averageLoadTime) / 4,
            memoryUsageMB: max(basicStats.memoryUsageMB, virtualStats.memoryUsageMB, emergencyStats.memoryUsageMB, preloadStats.memoryUsageMB),
            cacheHitRate: (basicStats.cacheHitRate + virtualStats.cacheHitRate + emergencyStats.cacheHitRate + preloadStats.cacheHitRate) / 4,
            activeTaskCount: activeOperations.count
        )
    }
    
    /// Cleanup resources from all strategies
    public func cleanup() async {
        await basicStrategy.cleanup()
        await virtualStrategy.cleanup()
        await emergencyStrategy.cleanup()
        await preloadStrategy.cleanup()
        
        activeOperations.removeAll()
        ProductionLogger.lifecycle("UnifiedImageLoader: Cleanup completed")
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics(for operation: LoadOperation, success: Bool, image: SendableImage?) async {
        let loadTime = Date().timeIntervalSince(operation.startTime)
        
        // Update global statistics
        let newTotalLoads = globalStatistics.totalLoads + 1
        let newSuccessfulLoads = globalStatistics.successfulLoads + (success ? 1 : 0)
        let newFailedLoads = globalStatistics.failedLoads + (success ? 0 : 1)
        
        // Calculate new average load time
        let totalTime = globalStatistics.averageLoadTime * Double(globalStatistics.totalLoads) + loadTime
        let newAverageLoadTime = totalTime / Double(newTotalLoads)
        
        globalStatistics = LoadingStatistics(
            totalLoads: newTotalLoads,
            successfulLoads: newSuccessfulLoads,
            failedLoads: newFailedLoads,
            averageLoadTime: newAverageLoadTime,
            memoryUsageMB: globalStatistics.memoryUsageMB,
            cacheHitRate: globalStatistics.cacheHitRate,
            activeTaskCount: activeOperations.count
        )
        
        ProductionLogger.performance("UnifiedImageLoader: Load completed in \(String(format: "%.2f", loadTime * 1000))ms using \(operation.strategy) strategy")
    }
    
    private func calculateMemoryPressure() async -> MemoryPressureLevel {
        let stats = await getStatistics()
        let memoryUsage = stats.memoryUsageMB
        let maxMemory = currentSettings.maxMemoryUsageMB
        
        let pressure = Double(memoryUsage) / Double(maxMemory)
        
        switch pressure {
        case 0..<0.5:
            return .low
        case 0.5..<0.75:
            return .normal
        case 0.75..<0.9:
            return .high
        default:
            return .critical
        }
    }
}

// MARK: - Compatibility Extensions

extension UnifiedImageLoader {
    /// Legacy compatibility: Simple image loading
    public func loadImage(from imageURL: ImageURL) async throws -> SendableImage {
        let photo = Photo(
            id: UUID(),
            imageURL: imageURL
        )
        
        let context = LoadingContext(collectionSize: 1, priority: .normal)
        return try await loadImage(from: photo, context: context)
    }
    
    /// Legacy compatibility: Get image for photo ID (from VirtualImageLoader)
    public func getImage(for photoId: UUID) async -> SendableImage? {
        return await virtualStrategy.getImage(for: photoId)
    }
    
    /// Legacy compatibility: Check if loading (from TargetImageLoader)
    public func isLoading(photoId: UUID) -> Bool {
        return activeOperations[photoId] != nil
    }
}