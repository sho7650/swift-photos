import Foundation
import SwiftUI
import Observation

/// Central Facade for all Swift Photos services
/// Provides unified access to image loading, settings, UI management, and slideshow operations
/// Replaces direct instantiation of multiple service components
@Observable
@MainActor
public final class SwiftPhotosServiceFacade {
    
    // MARK: - Singleton Instance
    
    public static let shared = SwiftPhotosServiceFacade()
    
    // MARK: - Core Service Components
    
    /// Unified settings management
    public let settings: AppSettingsCoordinator
    
    /// Unified image loading and caching
    private let imageLoader: UnifiedImageLoader
    private let imageCache: UnifiedImageCacheBridge
    
    /// Repository layer access
    private let repositoryContainer: RepositoryContainer
    
    /// UI and interaction management
    public let visualEffects: VisualEffectsManager
    public let uiInteraction: UIInteractionManager
    
    /// File and security management
    private let fileAccess: SecureFileAccess
    
    /// Performance and monitoring
    private let performanceMonitor: PerformanceMetricsManager
    
    // MARK: - Facade State
    
    public var isInitialized = false
    public var lastError: Error?
    public var initializationTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        ProductionLogger.lifecycle("🏗️ SwiftPhotosServiceFacade: Initializing unified service facade")
        
        // Initialize core settings coordinator
        self.settings = AppSettingsCoordinator()
        
        // Initialize file access with security
        self.fileAccess = SecureFileAccess()
        
        // Initialize unified image services
        self.imageLoader = UnifiedImageLoader(settings: settings.performance.settings)
        self.imageCache = UnifiedImageCacheBridgeFactory.createForSlideshow()
        
        // Initialize repository container
        self.repositoryContainer = RepositoryContainer.shared
        
        // Initialize UI services
        self.visualEffects = VisualEffectsManager(
            transitionSettings: settings.transition,
            uiControlSettings: settings.uiControl
        )
        
        self.uiInteraction = UIInteractionManager(
            uiControlSettings: settings.uiControl
        )
        
        // Initialize performance monitoring
        self.performanceMonitor = PerformanceMetricsManager.shared
        
        // Setup inter-service coordination
        setupServiceCoordination()
        
        self.isInitialized = true
        self.initializationTime = Date()
        
        ProductionLogger.info("✅ SwiftPhotosServiceFacade: Initialization complete")
    }
    
    // MARK: - Service Coordination
    
    private func setupServiceCoordination() {
        // Connect settings changes to services
        Task {
            await setupImageLoaderCallbacks()
            await setupPerformanceMonitoring()
        }
        
        ProductionLogger.debug("🔗 SwiftPhotosServiceFacade: Service coordination established")
    }
    
    private func setupImageLoaderCallbacks() async {
        await imageLoader.setImageLoadedCallback { [weak self] photoId, image in
            Task { @MainActor [weak self] in
                self?.handleImageLoaded(photoId: photoId, image: image)
            }
        }
        
        await imageLoader.setImageLoadFailedCallback { [weak self] photoId, error in
            Task { @MainActor [weak self] in
                self?.handleImageLoadFailed(photoId: photoId, error: error)
            }
        }
    }
    
    private func setupPerformanceMonitoring() async {
        performanceMonitor.startMonitoring()
    }
    
    // MARK: - Public Facade API
    
    // MARK: Image Management
    
    /// Load image with unified loading strategy
    public func loadImage(from photo: Photo, context: LoadingContext? = nil) async throws -> SendableImage {
        let loadingContext = context ?? LoadingContext(
            collectionSize: 1,
            currentIndex: 0,
            priority: .normal
        )
        
        return try await imageLoader.loadImage(from: photo, context: loadingContext)
    }
    
    /// Load image window for large collections
    public func loadImageWindow(around currentIndex: Int, photos: [Photo], windowSize: Int? = nil) async -> [UUID: SendableImage] {
        return await imageLoader.loadImageWindow(around: currentIndex, photos: photos, windowSize: windowSize)
    }
    
    /// Get cached image if available
    public func getCachedImage(for imageURL: ImageURL) async -> SendableImage? {
        return await imageCache.getCachedImage(for: imageURL)
    }
    
    /// Cache image for future use
    public func cacheImage(_ image: SendableImage, for imageURL: ImageURL) async {
        await imageCache.setCachedImage(image, for: imageURL)
    }
    
    // MARK: Slideshow Management
    
    /// Create optimized slideshow ViewModel
    public func createSlideshowViewModel() -> UnifiedSlideshowViewModel {
        return UnifiedSlideshowViewModel(
            modernDomainService: repositoryContainer.modernDomainService(),
            repositoryContainer: repositoryContainer,
            fileAccess: fileAccess,
            settingsCoordinator: settings,
            timerManager: UnifiedTimerManager()
        )
    }
    
    // MARK: Settings Management
    
    /// Reset all settings to defaults
    public func resetAllSettings() {
        settings.resetAllToDefaults()
        ProductionLogger.userAction("🔄 SwiftPhotosServiceFacade: All settings reset to defaults")
    }
    
    /// Export settings to URL
    public func exportSettings(to url: URL) async throws {
        try await settings.exportSettings(to: url)
        ProductionLogger.userAction("📤 SwiftPhotosServiceFacade: Settings exported to \(url)")
    }
    
    /// Import settings from URL
    public func importSettings(from url: URL) async throws {
        try await settings.importSettings(from: url)
        ProductionLogger.userAction("📥 SwiftPhotosServiceFacade: Settings imported from \(url)")
    }
    
    // MARK: UI Management
    
    /// Get visual effects for overlay type
    public func getVisualEffect(for overlayType: VisualOverlayType) -> AnyView {
        return AnyView(visualEffects.blurEffect(for: overlayType))
    }
    
    /// Handle UI interaction
    public func handleUIInteraction(at location: CGPoint) {
        uiInteraction.handleMouseInteraction(at: location)
    }
    
    // MARK: File Management
    
    /// Select folder with security bookmarks
    public func selectFolder() async -> URL? {
        return await fileAccess.selectFolder()
    }
    
    /// Access file securely
    public func accessFile(at url: URL) -> Bool {
        return fileAccess.accessFile(at: url)
    }
    
    // MARK: Performance Management
    
    /// Get current performance statistics
    public func getPerformanceStats() -> UnifiedPerformanceStats? {
        return performanceMonitor.unifiedStats
    }
    
    /// Start performance operation tracking
    public func startPerformanceOperation(_ name: String) {
        performanceMonitor.startOperation(name)
    }
    
    /// End performance operation tracking
    public func endPerformanceOperation(_ name: String) {
        performanceMonitor.endOperation(name)
    }
    
    // MARK: - Event Handlers
    
    private func handleImageLoaded(photoId: UUID, image: SendableImage) {
        ProductionLogger.debug("🖼️ SwiftPhotosServiceFacade: Image loaded for photo \(photoId)")
        // Could trigger UI updates or notifications here
    }
    
    private func handleImageLoadFailed(photoId: UUID, error: Error) {
        ProductionLogger.error("❌ SwiftPhotosServiceFacade: Image load failed for photo \(photoId): \(error)")
        self.lastError = error
    }
    
    // MARK: - Cleanup
    
    deinit {
        ProductionLogger.lifecycle("SwiftPhotosServiceFacade deinitialized")
    }
}

// MARK: - Convenience Extensions

public extension SwiftPhotosServiceFacade {
    
    /// Quick access to performance settings
    var performanceSettings: PerformanceSettings {
        settings.performance.settings
    }
    
    /// Quick access to slideshow settings
    var slideshowSettings: SlideshowSettings {
        settings.slideshow.settings
    }
    
    /// Quick access to transition settings
    var transitionSettings: TransitionSettings {
        settings.transition.settings
    }
    
    /// Check if facade is ready for operations
    var isReady: Bool {
        isInitialized && lastError == nil
    }
    
    /// Get facade health status
    var healthStatus: String {
        if !isInitialized {
            return "⚠️ Not Initialized"
        } else if lastError != nil {
            return "❌ Error: \(lastError!.localizedDescription)"
        } else {
            return "✅ Ready"
        }
    }
}

// MARK: - Factory Methods

public extension SwiftPhotosServiceFacade {
    
    /// Create image display view with all dependencies
    func createImageDisplayView(
        viewModel: any SlideshowViewModelProtocol,
        enableDebugMode: Bool = false
    ) -> UnifiedImageDisplayView {
        return UnifiedImageDisplayView(
            viewModel: viewModel,
            transitionSettings: settings.transition,
            uiInteractionManager: uiInteraction,
            enableDebugMode: enableDebugMode,
            enablePerformanceMetrics: performanceSettings.enablePerformanceTracking
        )
    }
    
    /// Create settings view with all coordinators
    func createSettingsView() -> some View {
        // This would return a comprehensive settings view
        // using the AppSettingsCoordinator
        return Text("Settings View - To be implemented")
    }
}