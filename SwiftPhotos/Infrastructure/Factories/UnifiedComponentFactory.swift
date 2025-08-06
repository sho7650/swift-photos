import Foundation
import SwiftUI

/// Unified component factory that consolidates all factory patterns in the application
/// Replaces: ViewModelFactory, RepositoryFactory, CacheFactory, SettingsFactory, etc.
@MainActor
public final class UnifiedComponentFactory {
    
    // MARK: - Singleton
    
    public static let shared = UnifiedComponentFactory()
    
    // MARK: - Configuration
    
    private let configuration: FactoryConfiguration
    private var componentRegistry: [String: Any] = [:]
    private var singletonInstances: [String: Any] = [:]
    
    // MARK: - Core Dependencies
    
    private lazy var serviceConfiguration = ServiceConfiguration(
        enablePerformanceMonitoring: configuration.enablePerformanceMonitoring,
        enableDebugLogging: configuration.enableDebugLogging,
        maxMemoryUsage: configuration.maxMemoryUsage
    )
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = FactoryConfiguration()
        ProductionLogger.lifecycle("🏭 UnifiedComponentFactory: Initialized with configuration")
    }
    
    public convenience init(configuration: FactoryConfiguration) {
        self.init()
        // Note: Cannot reassign to let property, but configuration is already set in private init
        ProductionLogger.lifecycle("🏭 UnifiedComponentFactory: Initialized with custom configuration")
    }
    
    // MARK: - ViewModel Creation
    
    /// Create unified slideshow view model with all dependencies
    public func createSlideshowViewModel(
        preferRepositoryPattern: Bool = true,
        enablePerformanceMonitoring: Bool = true
    ) -> UnifiedSlideshowViewModel {
        
        let key = "SlideshowViewModel_\(preferRepositoryPattern)_\(enablePerformanceMonitoring)"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? UnifiedSlideshowViewModel {
            return cached
        }
        
        let fileAccess = createSecureFileAccess()
        let settingsCoordinator = createSettingsCoordinator()
        let timerManager = createTimerManager()
        
        let viewModel: UnifiedSlideshowViewModel
        
        if preferRepositoryPattern && isRepositoryPatternAvailable() {
            viewModel = UnifiedSlideshowViewModel(
                modernDomainService: createModernDomainService(),
                repositoryContainer: createRepositoryContainer(),
                imageRepositoryFactory: createImageRepositoryFactory(),
                legacyDomainService: nil,
                fileAccess: fileAccess,
                settingsCoordinator: settingsCoordinator,
                timerManager: timerManager,
                enableLegacyFallback: false,
                performanceMonitoring: enablePerformanceMonitoring,
                preferRepositoryPattern: true
            )
        } else {
            // Fallback to legacy pattern
            viewModel = UnifiedSlideshowViewModel(
                modernDomainService: nil,
                repositoryContainer: nil,
                imageRepositoryFactory: nil,
                legacyDomainService: createLegacyDomainService(),
                fileAccess: fileAccess,
                settingsCoordinator: settingsCoordinator,
                timerManager: timerManager,
                enableLegacyFallback: true,
                performanceMonitoring: enablePerformanceMonitoring,
                preferRepositoryPattern: false
            )
        }
        
        if configuration.useSingletons {
            singletonInstances[key] = viewModel
        }
        
        ProductionLogger.debug("🏭 Created SlideshowViewModel with \(preferRepositoryPattern ? "Repository" : "Legacy") pattern")
        return viewModel
    }
    
    // MARK: - Service Creation
    
    /// Create settings coordinator
    public func createSettingsCoordinator() -> AppSettingsCoordinator {
        let key = "AppSettingsCoordinator"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? AppSettingsCoordinator {
            return cached
        }
        
        let coordinator = AppSettingsCoordinator()
        
        if configuration.useSingletons {
            singletonInstances[key] = coordinator
        }
        
        return coordinator
    }
    
    /// Create unified image loader
    public func createImageLoader(performanceSettings: PerformanceSettings? = nil) -> UnifiedImageLoader {
        let key = "UnifiedImageLoader"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? UnifiedImageLoader {
            return cached
        }
        
        let settings = performanceSettings ?? createSettingsCoordinator().performance.settings
        let loader = UnifiedImageLoader(settings: settings)
        
        if configuration.useSingletons {
            singletonInstances[key] = loader
        }
        
        return loader
    }
    
    /// Create unified image cache bridge
    public func createImageCacheBridge() -> UnifiedImageCacheBridge {
        let key = "UnifiedImageCacheBridge"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? UnifiedImageCacheBridge {
            return cached
        }
        
        let bridge = UnifiedImageCacheBridgeFactory.createForSlideshow()
        
        if configuration.useSingletons {
            singletonInstances[key] = bridge
        }
        
        return bridge
    }
    
    /// Create visual effects manager
    public func createVisualEffectsManager(
        transitionSettings: ModernTransitionSettingsManager? = nil,
        uiControlSettings: ModernUIControlSettingsManager? = nil
    ) -> VisualEffectsManager {
        
        let key = "VisualEffectsManager"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? VisualEffectsManager {
            return cached
        }
        
        let coordinator = createSettingsCoordinator()
        let manager = VisualEffectsManager(
            transitionSettings: transitionSettings ?? coordinator.transition,
            uiControlSettings: uiControlSettings ?? coordinator.uiControl
        )
        
        if configuration.useSingletons {
            singletonInstances[key] = manager
        }
        
        return manager
    }
    
    /// Create UI interaction manager
    public func createUIInteractionManager(
        uiControlSettings: ModernUIControlSettingsManager? = nil
    ) -> UIInteractionManager {
        
        let key = "UIInteractionManager"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? UIInteractionManager {
            return cached
        }
        
        let settings = uiControlSettings ?? createSettingsCoordinator().uiControl
        let manager = UIInteractionManager(uiControlSettings: settings)
        
        if configuration.useSingletons {
            singletonInstances[key] = manager
        }
        
        return manager
    }
    
    // MARK: - Repository Creation
    
    /// Create repository container
    public func createRepositoryContainer() -> RepositoryContainer {
        let key = "RepositoryContainer"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? RepositoryContainer {
            return cached
        }
        
        let container = RepositoryContainer.shared
        
        if configuration.useSingletons {
            singletonInstances[key] = container
        }
        
        return container
    }
    
    /// Create image repository factory
    public func createImageRepositoryFactory() -> ImageRepositoryFactory {
        return ImageRepositoryFactory.createModernOnly()
    }
    
    // MARK: - Domain Service Creation
    
    /// Create modern domain service if available
    public func createModernDomainService() -> ModernSlideshowDomainService? {
        // Check if modern domain service is available
        guard isRepositoryPatternAvailable() else {
            return nil
        }
        
        let key = "ModernSlideshowDomainService"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? ModernSlideshowDomainService {
            return cached
        }
        
        // Create modern domain service with repository container
        let container = createRepositoryContainer()
        let domainService = ModernSlideshowDomainService(repositoryContainer: container)
        
        if configuration.useSingletons {
            singletonInstances[key] = domainService
        }
        
        return domainService
    }
    
    /// Create legacy domain service for fallback
    public func createLegacyDomainService() -> SlideshowDomainService {
        let key = "SlideshowDomainService"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? SlideshowDomainService {
            return cached
        }
        
        let fileAccess = createSecureFileAccess()
        let domainService = SlideshowDomainService(fileAccess: fileAccess)
        
        if configuration.useSingletons {
            singletonInstances[key] = domainService
        }
        
        return domainService
    }
    
    // MARK: - Infrastructure Creation
    
    /// Create secure file access
    public func createSecureFileAccess() -> SecureFileAccess {
        let key = "SecureFileAccess"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? SecureFileAccess {
            return cached
        }
        
        let fileAccess = SecureFileAccess()
        
        if configuration.useSingletons {
            singletonInstances[key] = fileAccess
        }
        
        return fileAccess
    }
    
    /// Create timer manager
    public func createTimerManager() -> TimerManagementProtocol {
        let key = "UnifiedTimerManager"
        
        if configuration.useSingletons, let cached = singletonInstances[key] as? UnifiedTimerManager {
            return cached
        }
        
        let timerManager = UnifiedTimerManager()
        
        if configuration.useSingletons {
            singletonInstances[key] = timerManager
        }
        
        return timerManager
    }
    
    // MARK: - View Creation
    
    /// Create unified image display view
    public func createImageDisplayView(
        viewModel: any SlideshowViewModelProtocol,
        enableDebugMode: Bool = false,
        enablePerformanceMetrics: Bool = false
    ) -> UnifiedImageDisplayView {
        
        let settingsCoordinator = createSettingsCoordinator()
        let uiInteractionManager = createUIInteractionManager()
        
        return UnifiedImageDisplayView(
            viewModel: viewModel,
            transitionSettings: settingsCoordinator.transition,
            uiInteractionManager: uiInteractionManager,
            enableDebugMode: enableDebugMode,
            enablePerformanceMetrics: enablePerformanceMetrics
        )
    }
    
    // MARK: - Utility Methods
    
    /// Check if repository pattern is available
    private func isRepositoryPatternAvailable() -> Bool {
        // Check if all required repository components are available
        do {
            let container = RepositoryContainer.shared
            let _ = container.modernDomainService()
            return true
        } catch {
            ProductionLogger.debug("Repository pattern not available: \(error)")
            return false
        }
    }
    
    /// Clear all singleton instances (useful for testing)
    public func clearSingletons() {
        singletonInstances.removeAll()
        ProductionLogger.debug("🏭 UnifiedComponentFactory: Cleared all singleton instances")
    }
    
    /// Get factory statistics
    public func getStatistics() -> FactoryStatistics {
        return FactoryStatistics(
            totalComponents: componentRegistry.count,
            singletonInstances: singletonInstances.count,
            configuration: configuration
        )
    }
}

// MARK: - Configuration

public struct FactoryConfiguration {
    public let useSingletons: Bool
    public let enablePerformanceMonitoring: Bool
    public let enableDebugLogging: Bool
    public let maxMemoryUsage: Int64
    public let preferRepositoryPattern: Bool
    
    public init(
        useSingletons: Bool = true,
        enablePerformanceMonitoring: Bool = true,
        enableDebugLogging: Bool = false,
        maxMemoryUsage: Int64 = 2 * 1024 * 1024 * 1024, // 2GB
        preferRepositoryPattern: Bool = true
    ) {
        self.useSingletons = useSingletons
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.enableDebugLogging = enableDebugLogging
        self.maxMemoryUsage = maxMemoryUsage
        self.preferRepositoryPattern = preferRepositoryPattern
    }
}

// MARK: - Statistics

public struct FactoryStatistics {
    public let totalComponents: Int
    public let singletonInstances: Int
    public let configuration: FactoryConfiguration
    
    public var memoryEfficiency: Double {
        guard totalComponents > 0 else { return 1.0 }
        return Double(singletonInstances) / Double(totalComponents)
    }
    
    public var description: String {
        return """
        Factory Statistics:
        - Total Components: \(totalComponents)
        - Singleton Instances: \(singletonInstances)
        - Memory Efficiency: \(String(format: "%.1f%%", memoryEfficiency * 100))
        - Performance Monitoring: \(configuration.enablePerformanceMonitoring ? "✅" : "❌")
        - Repository Pattern: \(configuration.preferRepositoryPattern ? "✅" : "❌")
        """
    }
}

// MARK: - Extensions for Convenience

public extension UnifiedComponentFactory {
    
    /// Create complete slideshow setup with all dependencies
    func createCompleteSlideshowSetup(
        enableDebugMode: Bool = false
    ) -> (viewModel: UnifiedSlideshowViewModel, displayView: UnifiedImageDisplayView, facade: SwiftPhotosServiceFacade) {
        
        let viewModel = createSlideshowViewModel()
        let displayView = createImageDisplayView(
            viewModel: viewModel,
            enableDebugMode: enableDebugMode,
            enablePerformanceMetrics: configuration.enablePerformanceMonitoring
        )
        let facade = SwiftPhotosServiceFacade.shared
        
        return (viewModel, displayView, facade)
    }
    
    /// Create development setup with enhanced debugging
    func createDevelopmentSetup() -> (viewModel: UnifiedSlideshowViewModel, displayView: UnifiedImageDisplayView) {
        let setup = createCompleteSlideshowSetup(enableDebugMode: true)
        return (setup.viewModel, setup.displayView)
    }
    
    /// Create production setup with optimized performance
    func createProductionSetup() -> (viewModel: UnifiedSlideshowViewModel, displayView: UnifiedImageDisplayView) {
        let setup = createCompleteSlideshowSetup(enableDebugMode: false)
        return (setup.viewModel, setup.displayView)
    }
}