import Foundation
import AppKit

/// Factory for creating ViewModels with Repository pattern integration
/// Handles the complexity of dependency injection and provides both modern and legacy ViewModel creation
@MainActor
public struct ViewModelFactory {
    
    // MARK: - Factory Methods
    
    /// Create Enhanced ViewModel with Repository pattern (preferred)
    public static func createEnhancedSlideshowViewModel(
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager,
        slideshowSettings: ModernSlideshowSettingsManager,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService,
        enableLegacyFallback: Bool = true
    ) async -> EnhancedModernSlideshowViewModel {
        
        ProductionLogger.info("ViewModelFactory: Creating Enhanced ViewModel with Repository pattern")
        
        // Create ImageLoader for Repository integration
        let imageLoader = ImageLoader()
        
        // Create Enhanced ViewModel with Repository pattern
        let enhancedViewModel = await EnhancedModernSlideshowViewModel(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings
        )
        
        ProductionLogger.info("ViewModelFactory: Enhanced ViewModel created successfully")
        return enhancedViewModel
    }
    
    /// Create Legacy ViewModel (fallback)
    public static func createLegacySlideshowViewModel(
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager,
        slideshowSettings: ModernSlideshowSettingsManager,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService
    ) -> ModernSlideshowViewModel {
        
        ProductionLogger.info("ViewModelFactory: Creating Legacy ViewModel")
        
        // Create traditional dependencies
        let imageLoader = ImageLoader()
        let imageCache = ImageCache()
        let repository = FileSystemPhotoRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
        
        // Create legacy ViewModel
        let legacyViewModel = ModernSlideshowViewModel(
            domainService: domainService,
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings
        )
        
        ProductionLogger.info("ViewModelFactory: Legacy ViewModel created successfully")
        return legacyViewModel
    }
    
    /// Create ViewModel with automatic Repository pattern detection
    public static func createSlideshowViewModel(
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager,
        slideshowSettings: ModernSlideshowSettingsManager,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService,
        preferRepositoryPattern: Bool = true
    ) async -> any SlideshowViewModelProtocol {
        
        if preferRepositoryPattern {
            // Try to create Enhanced ViewModel with Repository pattern
            do {
                let enhancedViewModel = await createEnhancedSlideshowViewModel(
                    fileAccess: fileAccess,
                    performanceSettings: performanceSettings,
                    slideshowSettings: slideshowSettings,
                    sortSettings: sortSettings,
                    localizationService: localizationService,
                    enableLegacyFallback: true
                )
                
                ProductionLogger.info("ViewModelFactory: Successfully created Repository-based ViewModel")
                return enhancedViewModel
                
            } catch {
                ProductionLogger.warning("ViewModelFactory: Repository pattern creation failed, falling back to legacy: \(error)")
            }
        }
        
        // Fallback to legacy ViewModel
        let legacyViewModel = createLegacySlideshowViewModel(
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        
        return legacyViewModel
    }
    
    // MARK: - Health Check
    
    /// Verify Repository pattern readiness
    public static func checkRepositoryReadiness() async -> RepositoryReadinessStatus {
        let container = RepositoryContainer.shared
        let healthStatus = await container.performHealthCheck()
        
        return RepositoryReadinessStatus(
            isReady: healthStatus.isHealthy,
            healthStatus: healthStatus,
            recommendUseRepositoryPattern: healthStatus.isHealthy
        )
    }
    
    /// Get performance metrics from Repository system
    public static func getRepositoryMetrics() async -> [String: RepositoryMetrics] {
        let container = RepositoryContainer.shared
        
        // Gather metrics from all repositories
        var metrics: [String: RepositoryMetrics] = [:]
        
        let imageRepo = await container.imageRepository()
        if let localImageRepo = imageRepo as? LocalImageRepository {
            metrics["ImageRepository"] = await localImageRepo.getPerformanceMetrics()
        }
        
        let metadataRepo = await container.metadataRepository()
        if let fileMetadataRepo = metadataRepo as? FileSystemMetadataRepository {
            let stats = await fileMetadataRepo.getPerformanceStatistics()
            // Convert MetadataPerformanceStatistics to RepositoryMetrics
            metrics["MetadataRepository"] = RepositoryMetrics(
                operationCount: stats.totalExtractions,
                successCount: stats.successfulExtractions,
                errorCount: stats.failedExtractions,
                averageResponseTime: stats.averageExtractionTime,
                cacheHitRate: stats.cacheHitRate,
                totalDataTransferred: 0,
                lastOperation: Date()
            )
        }
        
        let settingsRepo = await container.settingsRepository()
        if let userDefaultsRepo = settingsRepo as? UserDefaultsSettingsRepository {
            metrics["SettingsRepository"] = await userDefaultsRepo.getPerformanceMetrics()
        }
        
        return metrics
    }
}

// MARK: - Supporting Types

/// Protocol to unify different ViewModel types
@MainActor
public protocol SlideshowViewModelProtocol: AnyObject {
    var slideshow: Slideshow? { get }
    var currentPhoto: Photo? { get set }
    var isLoading: Bool { get }
    var error: SlideshowError? { get set }
    var selectedFolderURL: URL? { get set }
    var windowLevel: WindowLevel { get set }
    var loadingState: LoadingState { get set }
    var refreshCounter: Int { get set }
    
    func selectFolder() async
    func play()
    func pause()
    func stop()
    func nextPhoto() async
    func previousPhoto() async
    func clearError()
    func setSlideshow(_ slideshow: Slideshow)
}

/// Repository readiness status
public struct RepositoryReadinessStatus: Sendable {
    public let isReady: Bool
    public let healthStatus: RepositoryHealthStatus
    public let recommendUseRepositoryPattern: Bool
    
    public init(isReady: Bool, healthStatus: RepositoryHealthStatus, recommendUseRepositoryPattern: Bool) {
        self.isReady = isReady
        self.healthStatus = healthStatus
        self.recommendUseRepositoryPattern = recommendUseRepositoryPattern
    }
}

// MARK: - Protocol Conformance

extension ModernSlideshowViewModel: SlideshowViewModelProtocol {
    // Methods already implemented in the class
}

extension EnhancedModernSlideshowViewModel: SlideshowViewModelProtocol {
    public func selectFolder() async {
        await selectFolderAndLoadPhotos()
    }
    
    public func play() {
        startSlideshow()
    }
    
    public func pause() {
        stopSlideshow()
    }
    
    public func stop() {
        stopSlideshow()
    }
}