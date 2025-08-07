import Foundation
import SwiftUI

// MARK: - Required imports for unified services
// Note: Import will be resolved through proper file organization
// Forward declarations and typealiases for now to resolve compilation

// MARK: - Loading Strategy Configuration

/// Strategy for different image loading approaches
public enum LoadingStrategy: String, Sendable, CaseIterable {
    case basic = "basic"           // Direct image loading
    case virtual = "virtual"       // Window-based loading for large collections  
    case emergency = "emergency"   // Simplified loading for low memory
    case preload = "preload"      // Aggressive preloading
    case adaptive = "adaptive"    // Selects strategy based on context
    
    public var displayName: String {
        switch self {
        case .basic:
            return "Basic Loading"
        case .virtual:
            return "Virtual Loading"
        case .emergency:
            return "Emergency Mode"
        case .preload:
            return "Preload Strategy"
        case .adaptive:
            return "Adaptive Loading"
        }
    }
}

// MARK: - Core Service Protocols

// MARK: - TEMPORARY STUB FOR BUILD STABILIZATION
// TODO: Re-implement with proper import dependencies

/// Temporary minimal protocol to satisfy build requirements
public protocol UnifiedImageService: Sendable {
    // Minimal interface for compilation
    func initialize() async throws
    func shutdown() async
}

/// Temporary stub implementation for UnifiedImageService
internal struct StubImageService: UnifiedImageService {
    func initialize() async throws {}
    func shutdown() async {}
}

/// Temporary stub implementation for UnifiedSettingsService
@MainActor
internal final class UnifiedSettingsServiceStub: UnifiedSettingsService {
    func resetAllToDefaults() {}
    func exportSettings(to url: URL) async throws {}
    func importSettings(from url: URL) async throws {}
    var performanceSettings: PerformanceSettings { PerformanceSettings.default }
    var slideshowSettings: SlideshowSettings { SlideshowSettings() }
    var transitionSettings: TransitionSettings { TransitionSettings() }
    var sortSettings: SortSettings { SortSettings() }
    var uiControlSettings: UIControlSettings { UIControlSettings() }
    func applyPreset(_ preset: SettingsPreset) async {}
    func validateSettings() -> [SettingsValidationError] { [] }
    func getSettingsHash() -> String { "" }
}

/// Temporary stub implementation for UnifiedUIService  
@MainActor
internal final class UnifiedUIServiceStub: UnifiedUIService {
    init(settingsService: Any) {}
    func getVisualEffect(for overlayType: VisualOverlayType) -> AnyView { AnyView(EmptyView()) }
    func updateVisualEffects(with settings: TransitionSettings) {}
    func handleMouseInteraction(at location: CGPoint) {}
    func handleKeyboardInteraction() {}
    func handleGestureInteraction(_ gesture: GestureType) {}
    var isUIVisible: Bool = true
    var currentBlurIntensity: Double = 1.0
    func showUI(animated: Bool) {}
    func hideUI(animated: Bool) {}
    func toggleFullscreen() {}
    func adjustWindowLevel(_ level: WindowLevel) {}
}

/// Temporary stub implementation for UnifiedResourceService
internal struct StubResourceService: UnifiedResourceService {
    func selectFolder() async -> URL? { nil }
    func selectFiles() async -> [URL] { [] }
    func accessFile(at url: URL) -> Bool { false }
    func saveBookmark(for url: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> URL { URL(fileURLWithPath: "/") }
    func loadImageMetadata(from url: URL) async throws -> Photo.PhotoMetadata { 
        Photo.PhotoMetadata(fileSize: 0, dimensions: CGSize(width: 0, height: 0), creationDate: nil, colorSpace: nil) 
    }
    func validateImageFile(at url: URL) -> Bool { false }
    func getImageFileSize(at url: URL) -> Int64? { nil }
    func requestFileAccess(for url: URL) async -> Bool { false }
    func hasFileAccess(for url: URL) -> Bool { false }
    func clearSecurityCache() {}
}

/// Unified protocol for settings management services
/// Consolidates all SettingsManagerProtocol variants
@MainActor
public protocol UnifiedSettingsService: ObservableObject {
    // Settings Operations
    func resetAllToDefaults()
    func exportSettings(to url: URL) async throws
    func importSettings(from url: URL) async throws
    
    // Specific Settings Access
    var performanceSettings: PerformanceSettings { get }
    var slideshowSettings: SlideshowSettings { get }
    var transitionSettings: TransitionSettings { get }
    var sortSettings: SortSettings { get }
    var uiControlSettings: UIControlSettings { get }
    
    // Settings Coordination
    func applyPreset(_ preset: SettingsPreset) async
    func validateSettings() -> [SettingsValidationError]
    func getSettingsHash() -> String
}

/// Unified protocol for UI and interaction services
/// Consolidates UIInteractionProtocol, VisualEffectsProtocol
@MainActor
public protocol UnifiedUIService: ObservableObject {
    // Visual Effects
    func getVisualEffect(for overlayType: VisualOverlayType) -> AnyView
    func updateVisualEffects(with settings: TransitionSettings)
    
    // Interaction Management
    func handleMouseInteraction(at location: CGPoint)
    func handleKeyboardInteraction()
    func handleGestureInteraction(_ gesture: GestureType)
    
    // UI State Management
    var isUIVisible: Bool { get }
    var currentBlurIntensity: Double { get }
    func showUI(animated: Bool)
    func hideUI(animated: Bool)
    
    // Window Management
    func toggleFullscreen()
    func adjustWindowLevel(_ level: WindowLevel)
}

/// Unified protocol for slideshow and presentation services
/// Consolidates SlideshowServiceProtocol, PresentationServiceProtocol
@MainActor
public protocol UnifiedPresentationService: ObservableObject {
    // Slideshow Management
    func createSlideshow(from folderURL: URL, options: SlideshowOptions) async throws -> Slideshow
    func updateSlideshow(_ slideshow: Slideshow) async throws
    
    // Playback Control
    func play()
    func pause()
    func stop()
    func nextPhoto() async
    func previousPhoto() async
    func jumpToPhoto(at index: Int) async
    
    // Presentation Features
    func enablePresentationMode()
    func disablePresentationMode()
    func configureMultiDisplay(strategy: DisplayStrategy)
    
    // State Management
    var currentSlideshow: Slideshow? { get }
    var isPlaying: Bool { get }
    var presentationMode: PresentationMode { get }
}

/// Unified protocol for file and resource management
/// Consolidates FileAccessProtocol, SecurityProtocol, ResourceProtocol
public protocol UnifiedResourceService: Sendable {
    // File Access
    func selectFolder() async -> URL?
    func selectFiles() async -> [URL]
    func accessFile(at url: URL) -> Bool
    func saveBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> URL
    
    // Resource Management
    func loadImageMetadata(from url: URL) async throws -> Photo.PhotoMetadata
    func validateImageFile(at url: URL) -> Bool
    func getImageFileSize(at url: URL) -> Int64?
    
    // Security
    func requestFileAccess(for url: URL) async -> Bool
    func hasFileAccess(for url: URL) -> Bool
    func clearSecurityCache()
}

// MARK: - Service Configuration

/// Configuration for service initialization
public struct ServiceConfiguration {
    public let enablePerformanceMonitoring: Bool
    public let enableDebugLogging: Bool
    public let maxMemoryUsage: Int64
    public let cacheStrategy: CacheStrategyType
    public let loadingStrategy: LoadingStrategy
    
    public init(
        enablePerformanceMonitoring: Bool = true,
        enableDebugLogging: Bool = false,
        maxMemoryUsage: Int64 = 1024 * 1024 * 1024, // 1GB
        cacheStrategy: CacheStrategyType = .hybrid,
        loadingStrategy: LoadingStrategy = .adaptive
    ) {
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.enableDebugLogging = enableDebugLogging
        self.maxMemoryUsage = maxMemoryUsage
        self.cacheStrategy = cacheStrategy
        self.loadingStrategy = loadingStrategy
    }
}

// MARK: - Service Factory Protocol

/// Protocol for creating and configuring services
public protocol ServiceFactory {
    func createImageService(configuration: ServiceConfiguration) -> any UnifiedImageService
    func createSettingsService() -> any UnifiedSettingsService
    @MainActor func createUIService(settingsService: any UnifiedSettingsService) -> any UnifiedUIService
    @MainActor func createPresentationService(
        imageService: any UnifiedImageService,
        settingsService: any UnifiedSettingsService
    ) -> any UnifiedPresentationService
    func createResourceService() -> any UnifiedResourceService
}

// MARK: - Service Registry

/// Central registry for service instances
@MainActor
public final class ServiceRegistry {
    public static let shared = ServiceRegistry()
    
    private var services: [String: Any] = [:]
    private let factory: ServiceFactory
    
    private init() {
        self.factory = DefaultServiceFactory()
    }
    
    /// Register a service instance
    public func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
        ProductionLogger.debug("ServiceRegistry: Registered \(key)")
    }
    
    /// Resolve a service instance
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
    
    /// Create and register all core services
    public func initializeCoreServices(configuration: ServiceConfiguration = ServiceConfiguration()) {
        let imageService = factory.createImageService(configuration: configuration)
        let settingsService = factory.createSettingsService()
        let uiService = factory.createUIService(settingsService: settingsService)
        let presentationService = factory.createPresentationService(
            imageService: imageService,
            settingsService: settingsService
        )
        let resourceService = factory.createResourceService()
        
        register(imageService, for: (any UnifiedImageService).self)
        register(settingsService, for: (any UnifiedSettingsService).self)
        register(uiService, for: (any UnifiedUIService).self)
        register(presentationService, for: (any UnifiedPresentationService).self)
        register(resourceService, for: (any UnifiedResourceService).self)
        
        ProductionLogger.info("ServiceRegistry: All core services initialized")
    }
}

// MARK: - Default Service Factory

/// Default implementation of ServiceFactory
internal struct DefaultServiceFactory: ServiceFactory {
    
    func createImageService(configuration: ServiceConfiguration) -> any UnifiedImageService {
        // Return a stub implementation for now
        return StubImageService()
    }
    
    func createSettingsService() -> any UnifiedSettingsService {
        // Create settings service synchronously with a workaround
        let settingsService = MainActor.assumeIsolated {
            // Synchronously create the service, but init must be done asynchronously later
            return UnifiedSettingsServiceStub()
        }
        return settingsService
    }
    
    @MainActor
    func createUIService(settingsService: any UnifiedSettingsService) -> any UnifiedUIService {
        // Since UnifiedSettingsService is @MainActor, we can safely return the stub
        return UnifiedUIServiceStub(settingsService: settingsService as Any)
    }
    
    @MainActor
    func createPresentationService(
        imageService: any UnifiedImageService,
        settingsService: any UnifiedSettingsService
    ) -> any UnifiedPresentationService {
        // Since UnifiedPresentationService is @MainActor, we can safely return the impl
        return UnifiedPresentationServiceImpl(
            imageService: nil,
            settingsService: settingsService
        )
    }
    
    func createResourceService() -> any UnifiedResourceService {
        // Return a stub since UnifiedResourceServiceImpl requires async init
        return StubResourceService()
    }
}

// MARK: - Service Implementation Protocols

/// Base protocol for all service implementations
@MainActor
internal protocol ServiceImplementation {
    var isInitialized: Bool { get }
    var lastError: Error? { get }
    
    func initialize() async throws
    func shutdown() async
    func healthCheck() -> ServiceHealthStatus
}

/// Health status for service monitoring
public enum ServiceHealthStatus {
    case healthy
    case degraded(reason: String)
    case unhealthy(error: Error)
    
    public var isHealthy: Bool {
        switch self {
        case .healthy:
            return true
        case .degraded, .unhealthy:
            return false
        }
    }
}

// MARK: - Supporting Types

// Note: GestureType already exists in InteractionTypes.swift

public enum DisplayStrategy {
    case primary
    case extended
    case mirrored
    case custom(configuration: DisplayConfiguration)
}

public enum PresentationMode {
    case windowed
    case fullscreen
    case presentation
}

public struct DisplayConfiguration {
    public let screens: [NSScreen]
    public let layout: DisplayLayout
    
    public enum DisplayLayout {
        case horizontal
        case vertical
        case grid(columns: Int, rows: Int)
    }
}

public struct SlideshowOptions: Sendable {
    public let interval: TimeInterval
    public let mode: Slideshow.SlideshowMode
    public let sortOrder: SortOrder
    public let transitions: TransitionSettings
    
    public init(
        interval: TimeInterval = 3.0,
        mode: Slideshow.SlideshowMode = .sequential,
        sortOrder: SortOrder = .fileName(ascending: true),
        transitions: TransitionSettings = TransitionSettings()
    ) {
        self.interval = interval
        self.mode = mode
        self.sortOrder = sortOrder
        self.transitions = transitions
    }
}

// Note: CacheStatistics already exists in SlideshowRepository.swift

// Note: SettingsValidationError already exists in RepositoryTypes.swift

// Note: SettingsPreset already exists in SettingsRepositoryProtocol.swift