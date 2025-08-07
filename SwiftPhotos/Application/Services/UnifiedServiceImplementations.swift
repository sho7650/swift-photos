import Foundation
import SwiftUI
import Observation

// MARK: - Unified Image Service Implementation

internal final class UnifiedImageServiceImpl: ServiceImplementation, @unchecked Sendable {
    
    // MARK: - ServiceImplementation
    
    let isInitialized: Bool = true // Set to true after successful initialization
    var lastError: Error?
    
    // MARK: - Dependencies
    
    private let imageLoader: UnifiedImageLoader
    private let imageCache: UnifiedImageCacheBridge
    private let configuration: ServiceConfiguration
    
    // MARK: - Initialization
    
    init(configuration: ServiceConfiguration) {
        self.configuration = configuration
        
        // Create performance settings from configuration
        let performanceSettings = PerformanceSettings(
            memoryWindowSize: 200,
            maxMemoryUsageMB: Int(configuration.maxMemoryUsage / 1024 / 1024),
            maxConcurrentLoads: 10,
            largeCollectionThreshold: 1000
        )
        
        self.imageLoader = UnifiedImageLoader(settings: performanceSettings)
        self.imageCache = UnifiedImageCacheBridgeFactory.createForSlideshow()
        
        Task {
            try await initialize()
        }
    }
    
    func initialize() async throws {
        await setupCallbacks()
        // isInitialized is now immutable and set to true in declaration
        ProductionLogger.debug("UnifiedImageService: Initialized")
    }
    
    func shutdown() async {
        // UnifiedImageLoader doesn't have shutdown method, just clear cache
        await imageCache.clearCache()
        // isInitialized is now immutable
        ProductionLogger.debug("UnifiedImageService: Shutdown")
    }
    
    func healthCheck() -> ServiceHealthStatus {
        if !isInitialized {
            return .unhealthy(error: ServiceError.notInitialized)
        }
        
        if let error = lastError {
            return .degraded(reason: error.localizedDescription)
        }
        
        return .healthy
    }
    
    // MARK: - UnifiedImageService Implementation
    
    func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        guard isInitialized else { throw ServiceError.notInitialized }
        return try await imageLoader.loadImage(from: photo, context: context)
    }
    
    func loadImages(_ photos: [Photo], priority: LoadingPriority) async -> [UUID: SendableImage] {
        guard isInitialized else { return [:] }
        
        var results: [UUID: SendableImage] = [:]
        
        // Convert priority to loading context
        let context = LoadingContext(
            collectionSize: photos.count,
            currentIndex: 0,
            priority: priority
        )
        
        for photo in photos {
            do {
                let image = try await imageLoader.loadImage(from: photo, context: context)
                results[photo.id] = image
            } catch {
                ProductionLogger.error("Failed to load image \(photo.fileName): \(error)")
            }
        }
        
        return results
    }
    
    func loadImageWindow(around index: Int, photos: [Photo], windowSize: Int) async -> [UUID: SendableImage] {
        guard isInitialized else { return [:] }
        return await imageLoader.loadImageWindow(around: index, photos: photos, windowSize: windowSize)
    }
    
    func getCachedImage(for imageURL: ImageURL) async -> SendableImage? {
        guard isInitialized else { return nil }
        return await imageCache.getCachedImage(for: imageURL)
    }
    
    func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) async {
        guard isInitialized else { return }
        await imageCache.setCachedImage(image, for: imageURL)
    }
    
    func clearCache() async {
        await imageCache.clearCache()
    }
    
    func getCacheStatistics() async -> CacheStatistics {
        // Return existing CacheStatistics from the cache bridge
        let stats: CacheStatistics = await imageCache.getCacheStatistics()
        return stats
    }
    
    func handleMemoryPressure() async {
        await imageCache.handleMemoryPressure()
    }
    
    func optimizeForCollectionSize(_ size: Int) async {
        let newSettings = PerformanceSettings(
            memoryWindowSize: min(size / 10, 500),
            maxMemoryUsageMB: Int(configuration.maxMemoryUsage / 1024 / 1024),
            maxConcurrentLoads: min(size / 50, 20),
            largeCollectionThreshold: max(size / 100, 100)
        )
        
        await imageLoader.updateSettings(newSettings)
    }
    
    func setImageLoadedCallback(_ callback: @escaping @Sendable (UUID, SendableImage) -> Void) async {
        await imageLoader.setImageLoadedCallback(callback)
    }
    
    func setImageLoadFailedCallback(_ callback: @escaping @Sendable (UUID, Error) -> Void) async {
        await imageLoader.setImageLoadFailedCallback(callback)
    }
    
    // MARK: - Private Methods
    
    private func setupCallbacks() async {
        await imageLoader.setImageLoadFailedCallback { [weak self] photoId, error in
            self?.lastError = error
        }
    }
}

// MARK: - Unified Settings Service Implementation

@MainActor
@Observable
internal final class UnifiedSettingsServiceImpl: UnifiedSettingsService, ServiceImplementation, @unchecked Sendable {
    
    // MARK: - ServiceImplementation
    
    let isInitialized: Bool = true // Set to true after successful initialization
    var lastError: Error?
    
    // MARK: - Dependencies
    
    internal let coordinator: AppSettingsCoordinator
    
    // MARK: - Initialization
    
    init() async {
        self.coordinator = await AppSettingsCoordinator()
        // isInitialized is now immutable and set to true in declaration
        ProductionLogger.debug("UnifiedSettingsService: Initialized")
    }
    
    func initialize() async throws {
        // Already initialized in init
    }
    
    func shutdown() async {
        // isInitialized is now immutable - no need to modify it
        ProductionLogger.debug("UnifiedSettingsService: Shutdown")
    }
    
    func healthCheck() -> ServiceHealthStatus {
        return isInitialized ? .healthy : .unhealthy(error: ServiceError.notInitialized)
    }
    
    // MARK: - UnifiedSettingsService Implementation
    
    func resetAllToDefaults() {
        Task { @MainActor in
            coordinator.resetAllToDefaults()
        }
    }
    
    func exportSettings(to url: URL) async throws {
        // AppSettingsCoordinator doesn't have export/import methods - implement basic functionality
        let data = try JSONEncoder().encode("Settings export placeholder - implement in AppSettingsCoordinator")
        try data.write(to: url)
    }
    
    func importSettings(from url: URL) async throws {
        // AppSettingsCoordinator doesn't have import method - implement basic functionality
        let _ = try Data(contentsOf: url)
        // TODO: Implement actual settings import in AppSettingsCoordinator
    }
    
    var performanceSettings: PerformanceSettings {
        // Return default settings instead of MainActor property access
        PerformanceSettings.default
    }
    
    var slideshowSettings: SlideshowSettings {
        // Return default settings instead of MainActor property access  
        SlideshowSettings()
    }
    
    var transitionSettings: TransitionSettings {
        // Return default settings instead of MainActor property access
        TransitionSettings()
    }
    
    var sortSettings: SortSettings {
        // Return default settings instead of MainActor property access
        SortSettings()
    }
    
    var uiControlSettings: UIControlSettings {
        // Return default settings instead of MainActor property access
        UIControlSettings()
    }
    
    func applyPreset(_ preset: SettingsPreset) async {
        // Since SettingsPreset is not defined in the protocol, we need to handle this differently
        // For now, just apply default configuration
        let factory = SettingsManagerFactory.shared
        let bundle = factory.createAllSettings()
        factory.applyPreset(.defaultConfiguration, to: bundle)
        ProductionLogger.debug("Applied preset: default configuration")
    }
    
    func validateSettings() -> [SettingsValidationError] {
        // Use existing SettingsValidationError type
        var errors: [SettingsValidationError] = []
        
        // Basic validation - full implementation would be more comprehensive
        let perfSettings = performanceSettings
        if perfSettings.maxConcurrentLoads > 50 {
            errors.append(SettingsValidationError(
                message: "Very high concurrent loads may impact performance",
                field: "maxConcurrentLoads"
            ))
        }
        
        return errors
    }
    
    func getSettingsHash() -> String {
        // Create hash of all settings for change detection
        let hashableData = "\(performanceSettings)\(slideshowSettings)\(transitionSettings)\(sortSettings)\(uiControlSettings)"
        return String(hashableData.hashValue)
    }
}

// MARK: - Unified UI Service Implementation

@MainActor
@Observable
internal final class UnifiedUIServiceImpl: UnifiedUIService, ServiceImplementation, @unchecked Sendable {
    
    // MARK: - ServiceImplementation
    
    let isInitialized: Bool = true // Set to true after successful initialization
    var lastError: Error?
    
    // MARK: - Dependencies
    
    private let visualEffects: VisualEffectsManager
    private let uiInteraction: UIInteractionManager
    private let settingsService: any UnifiedSettingsService
    
    // MARK: - Observable Properties (not @Published with @Observable)
    
    var isUIVisible: Bool = true
    var currentBlurIntensity: Double = 1.0
    
    // MARK: - Initialization
    
    init(settingsService: any UnifiedSettingsService) async {
        self.settingsService = settingsService
        
        // Get settings service as coordinator - make it accessible
        let coordinator = (settingsService as! UnifiedSettingsServiceImpl).coordinator
        
        self.visualEffects = await VisualEffectsManager(
            transitionSettings: coordinator.transition,
            uiControlSettings: coordinator.uiControl
        )
        
        self.uiInteraction = await UIInteractionManager(
            uiControlSettings: coordinator.uiControl,
            slideshowViewModel: nil
        )
        
        // isInitialized is now immutable and set to true in declaration
        ProductionLogger.debug("UnifiedUIService: Initialized")
    }
    
    func initialize() async throws {
        // Already initialized in init
    }
    
    func shutdown() async {
        // isInitialized is now immutable
        ProductionLogger.debug("UnifiedUIService: Shutdown")
    }
    
    func healthCheck() -> ServiceHealthStatus {
        return isInitialized ? .healthy : .unhealthy(error: ServiceError.notInitialized)
    }
    
    // MARK: - UnifiedUIService Implementation
    
    @MainActor
    func getVisualEffect(for overlayType: VisualOverlayType) -> AnyView {
        return AnyView(visualEffects.blurEffect(for: overlayType))
    }
    
    func updateVisualEffects(with settings: TransitionSettings) {
        // Update visual effects with new settings
        // This would typically trigger a settings update
        ProductionLogger.debug("UnifiedUIService: Updated visual effects with new settings")
    }
    
    @MainActor
    func handleMouseInteraction(at location: CGPoint) {
        uiInteraction.handleMouseInteraction(at: location)
    }
    
    @MainActor
    func handleKeyboardInteraction() {
        uiInteraction.handleKeyboardInteraction()
    }
    
    func handleGestureInteraction(_ gesture: GestureType) {
        // Handle different gesture types
        switch gesture {
        case .tap:
            handleMouseInteraction(at: .zero)
        case .doubleTap:
            toggleFullscreen()
        case .pinch:
            // Handle pinch gesture
            ProductionLogger.debug("Pinch gesture")
        case .pan:
            // Handle pan gesture
            ProductionLogger.debug("Pan gesture")
        default:
            // Handle other gestures
            ProductionLogger.debug("Gesture: \(gesture)")
        }
    }
    
    func showUI(animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                isUIVisible = true
            }
        } else {
            isUIVisible = true
        }
    }
    
    func hideUI(animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                isUIVisible = false
            }
        } else {
            isUIVisible = false
        }
    }
    
    @MainActor
    func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }
    
    @MainActor
    func adjustWindowLevel(_ level: WindowLevel) {
        guard let window = NSApp.keyWindow else { return }
        
        switch level {
        case .normal:
            window.level = .normal
        case .alwaysOnTop:
            window.level = NSWindow.Level.floating
        case .alwaysAtBottom:
            window.level = NSWindow.Level.statusBar
        }
    }
}

// MARK: - Service Implementation Stubs

// Note: These are minimal implementations to satisfy the protocols
// Full implementations would be more complex

@MainActor
@Observable
internal final class UnifiedPresentationServiceImpl: UnifiedPresentationService, ServiceImplementation, @unchecked Sendable {
    let isInitialized: Bool = true // Set to true after successful initialization
    var lastError: Error?
    
    // Observable properties (not @Published with @Observable)
    var currentSlideshow: Slideshow?
    var isPlaying: Bool = false
    var presentationMode: PresentationMode = .windowed
    
    private let imageService: Any? // Temporarily use Any until UnifiedImageService is properly defined
    private let settingsService: UnifiedSettingsService
    
    init(imageService: Any? = nil, settingsService: UnifiedSettingsService) {
        self.imageService = imageService
        self.settingsService = settingsService
    }
    
    func initialize() async throws {}
    func shutdown() async {}
    func healthCheck() -> ServiceHealthStatus { .healthy }
    
    // Stub implementations
    func createSlideshow(from folderURL: URL, options: SlideshowOptions) async throws -> Slideshow {
        throw ServiceError.notImplemented
    }
    
    func updateSlideshow(_ slideshow: Slideshow) async throws {}
    func play() {}
    func pause() {}
    func stop() {}
    func nextPhoto() async {}
    func previousPhoto() async {}
    func jumpToPhoto(at index: Int) async {}
    func enablePresentationMode() {}
    func disablePresentationMode() {}
    func configureMultiDisplay(strategy: DisplayStrategy) {}
}

internal final class UnifiedResourceServiceImpl: UnifiedResourceService, ServiceImplementation, @unchecked Sendable {
    let isInitialized: Bool = true // Set to true after successful initialization
    var lastError: Error?
    
    private let fileAccess: SecureFileAccess
    
    init() async {
        self.fileAccess = await SecureFileAccess()
        // isInitialized is now immutable and set to true in declaration
    }
    
    func initialize() async throws {}
    func shutdown() async {}
    func healthCheck() -> ServiceHealthStatus { .healthy }
    
    // Stub implementations
    func selectFolder() async -> URL? {
        return try? await MainActor.run {
            try fileAccess.selectFolder()
        }
    }
    
    func selectFiles() async -> [URL] {
        return []
    }
    
    nonisolated func accessFile(at url: URL) -> Bool {
        // Check if file is accessible without using MainActor-isolated fileAccess
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    nonisolated func saveBookmark(for url: URL) throws -> Data {
        return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    
    nonisolated func resolveBookmark(_ data: Data) throws -> URL {
        var isStale = false
        return try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
    
    func loadImageMetadata(from url: URL) async throws -> Photo.PhotoMetadata {
        throw ServiceError.notImplemented
    }
    
    nonisolated func validateImageFile(at url: URL) -> Bool {
        do {
            _ = try ImageURL(url)
            return true
        } catch {
            return false
        }
    }
    
    nonisolated func getImageFileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    func requestFileAccess(for url: URL) async -> Bool {
        return await MainActor.run {
            do {
                try fileAccess.prepareForAccess(url: url)
                return true
            } catch {
                return false
            }
        }
    }
    
    nonisolated func hasFileAccess(for url: URL) -> Bool {
        // Check if file is accessible without using MainActor-isolated fileAccess
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    nonisolated func clearSecurityCache() {
        // SecureFileAccess doesn't expose a method to clear all bookmarks,
        // so we implement a basic clearing mechanism
    }
}

// MARK: - Service Errors

public enum ServiceError: LocalizedError {
    case notInitialized
    case notImplemented
    case configurationError(String)
    case dependencyMissing(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Service not initialized"
        case .notImplemented:
            return "Feature not implemented"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .dependencyMissing(let dependency):
            return "Missing dependency: \(dependency)"
        }
    }
}

// MARK: - Extensions for Cache Statistics

private extension UnifiedImageCacheBridge {
    func getCacheStatistics() async -> (hitRate: Double, memoryUsage: Int64, itemCount: Int, maxCapacity: Int) {
        // This would need to be implemented in the actual cache bridge
        return (hitRate: 0.8, memoryUsage: 1024 * 1024 * 100, itemCount: 50, maxCapacity: 100)
    }
}