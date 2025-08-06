import Foundation
import AppKit

/// Factory for creating ViewModels with Repository pattern integration
/// Handles the complexity of dependency injection and provides both modern and legacy ViewModel creation
@MainActor
public struct ViewModelFactory {
    
    // MARK: - Factory Methods
    
    
    /// Create ViewModel with automatic architecture detection (UNIFIED IMPLEMENTATION)
    public static func createSlideshowViewModel(
        fileAccess: SecureFileAccess,
        settingsCoordinator: AppSettingsCoordinator,
        localizationService: LocalizationService,
        preferRepositoryPattern: Bool = true
    ) async -> any SlideshowViewModelProtocol {
        
        ProductionLogger.info("ViewModelFactory: Creating Unified ViewModel with automatic architecture detection")
        
        // Check Repository pattern availability
        let repositoryContainer = RepositoryContainer.shared
        let healthStatus = await repositoryContainer.performHealthCheck()
        let repositoryReady = healthStatus.isHealthy
        
        if preferRepositoryPattern && repositoryReady {
            // Use Repository pattern
            let modernDomainService = await ModernSlideshowDomainService(
                repositoryContainer: repositoryContainer,
                sortSettings: settingsCoordinator.sort,
                localizationService: localizationService
            )
            
            let unifiedViewModel = UnifiedSlideshowViewModel(
                modernDomainService: modernDomainService,
                repositoryContainer: repositoryContainer,
                imageRepositoryFactory: ImageRepositoryFactory.createModernOnly(),
                legacyDomainService: nil,
                fileAccess: fileAccess,
                settingsCoordinator: settingsCoordinator,
                enableLegacyFallback: true,
                performanceMonitoring: true,
                preferRepositoryPattern: true
            )
            
            ProductionLogger.info("ViewModelFactory: Created Unified ViewModel with Repository pattern")
            return unifiedViewModel
            
        } else {
            // Use Legacy pattern
            let imageLoader = ImageLoader()
            let imageCache = UnifiedImageCacheBridgeFactory.createForSlideshow()
            let repository = FileSystemPhotoRepository(
                fileAccess: fileAccess,
                imageLoader: imageLoader,
                sortSettings: settingsCoordinator.sort,
                localizationService: localizationService
            )
            let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
            
            let unifiedViewModel = UnifiedSlideshowViewModel(
                modernDomainService: nil,
                repositoryContainer: nil,
                imageRepositoryFactory: nil,
                legacyDomainService: domainService,
                fileAccess: fileAccess,
                settingsCoordinator: settingsCoordinator,
                enableLegacyFallback: true,
                performanceMonitoring: true,
                preferRepositoryPattern: false
            )
            
            ProductionLogger.info("ViewModelFactory: Created Unified ViewModel with Legacy pattern")
            return unifiedViewModel
        }
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

/// Folder selection state for UI
public enum FolderSelectionState: Sendable {
    case idle
    case selecting
    case selected(URL)
    case failed(Error)
}

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
    
    // Performance tracking
    var stats: UnifiedPerformanceStats? { get }
    var canNavigateNext: Bool { get }
    var canNavigatePrevious: Bool { get }
    var progress: Double { get }
    var folderSelectionState: FolderSelectionState { get }
    var loadingProgress: Double { get }
    var estimatedTimeRemaining: TimeInterval? { get }
    var processedPhotoCount: Int { get }
    var totalPhotoCount: Int { get }
    var isGlobalSlideshow: Bool { get }
    
    func selectFolder() async
    func play()
    func pause()
    func stop()
    func nextPhoto() async
    func previousPhoto() async
    func jumpToPhoto(at index: Int) async
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

// UnifiedSlideshowViewModel already conforms to SlideshowViewModelProtocol