import Foundation
import SwiftUI
import AppKit
import Observation

/// Enhanced ModernSlideshowViewModel using the new Repository pattern
/// This integrates the Repository layer while maintaining backward compatibility
@Observable
@MainActor
public final class EnhancedModernSlideshowViewModel {
    
    // MARK: - Published Properties (No @Published needed with @Observable)
    public var slideshow: Slideshow?
    public var loadingState: LoadingState = .notLoading
    public var isLoading: Bool { loadingState.isLoading }
    public var error: SlideshowError?
    public var selectedFolderURL: URL?
    public var refreshCounter: Int = 0
    public var windowLevel: WindowLevel = .normal
    
    public var currentPhoto: Photo? = nil {
        didSet {
            let currentIndex = slideshow?.currentIndex ?? -1
            ProductionLogger.debug("EnhancedSlideshowViewModel.currentPhoto changed (refreshCounter: \(refreshCounter), currentIndex: \(currentIndex))")
            if let photo = currentPhoto {
                ProductionLogger.debug("EnhancedSlideshowViewModel.currentPhoto set to photo '\(photo.fileName)' with state: \(photo.loadState)")
            } else {
                ProductionLogger.debug("EnhancedSlideshowViewModel.currentPhoto set to nil")
            }
        }
    }
    
    // MARK: - Repository Layer Dependencies
    private let modernDomainService: ModernSlideshowDomainService
    private let repositoryContainer: RepositoryContainer
    private let imageRepositoryFactory: ImageRepositoryFactory
    
    // MARK: - Legacy Dependencies (for backward compatibility)
    private let legacyDomainService: SlideshowDomainService?
    private let fileAccess: SecureFileAccess
    private var timerId: UUID?
    private let timerPool = OptimizedTimerPool.shared
    
    // Performance optimizations for large collections
    private let virtualLoader: VirtualImageLoader
    private let backgroundPreloader: BackgroundPreloader
    private let targetImageLoader: TargetImageLoader
    private let performanceSettingsManager: ModernPerformanceSettingsManager
    private let slideshowSettingsManager: ModernSlideshowSettingsManager
    private let sortSettingsManager: ModernSortSettingsManager?
    
    // MARK: - Configuration
    private let enableLegacyFallback: Bool
    private let performanceMonitoring: Bool
    
    // MARK: - Performance Tracking
    private var operationCount = 0
    private var repositoryOperationCount = 0
    private var legacyOperationCount = 0
    
    // MARK: - State Management
    private var isCreatingSlideshow = false
    
    // MARK: - Performance Monitoring
    private let performanceMonitor = PerformanceMonitor.shared
    
    // MARK: - Initialization
    
    /// Initialize with Repository pattern support
    public init(
        modernDomainService: ModernSlideshowDomainService,
        repositoryContainer: RepositoryContainer = RepositoryContainer.shared,
        imageRepositoryFactory: ImageRepositoryFactory? = nil,
        legacyDomainService: SlideshowDomainService? = nil,
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil,
        sortSettings: ModernSortSettingsManager? = nil,
        enableLegacyFallback: Bool = true,
        performanceMonitoring: Bool = true
    ) {
        self.modernDomainService = modernDomainService
        self.repositoryContainer = repositoryContainer
        self.imageRepositoryFactory = imageRepositoryFactory ?? ImageRepositoryFactory.createModernOnly()
        self.legacyDomainService = legacyDomainService
        self.fileAccess = fileAccess
        self.enableLegacyFallback = enableLegacyFallback
        self.performanceMonitoring = performanceMonitoring
        
        // Initialize settings managers
        self.performanceSettingsManager = performanceSettings ?? ModernPerformanceSettingsManager()
        self.slideshowSettingsManager = slideshowSettings ?? ModernSlideshowSettingsManager()
        self.sortSettingsManager = sortSettings
        
        // Initialize performance components
        self.virtualLoader = VirtualImageLoader(settings: self.performanceSettingsManager.settings)
        self.backgroundPreloader = BackgroundPreloader(settings: self.performanceSettingsManager.settings)
        self.targetImageLoader = TargetImageLoader()
        
        ProductionLogger.lifecycle("EnhancedSlideshowViewModel initialized with Repository pattern support")
        
        // Start performance monitoring if enabled
        if performanceMonitoring {
            performanceMonitor.startMonitoring()
        }
        
        setupNotificationObservers()
        setupVirtualLoaderCallback()
    }
    
    /// Convenience initializer with legacy support
    public convenience init(
        fileAccess: SecureFileAccess,
        imageLoader: ImageLoader,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService,
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil
    ) async {
        // Create modern domain service with legacy support
        let modernService = await ModernSlideshowDomainService.createWithLegacySupport(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        
        // Create legacy domain service for fallback
        let legacyRepository = FileSystemPhotoRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        let cache = ImageCache()
        let legacyService = SlideshowDomainService(
            repository: legacyRepository,
            cache: cache
        )
        
        // Create repository factory with legacy support
        let factory = await ImageRepositoryFactory.createWithLegacySupport(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        
        self.init(
            modernDomainService: modernService,
            imageRepositoryFactory: factory,
            legacyDomainService: legacyService,
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings
        )
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationObservers() {
        // Listen for slideshow mode changes
        NotificationCenter.default.addObserver(
            forName: .slideshowModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let randomOrder = notification.object as? Bool {
                Task { @MainActor in
                    self?.updateSlideshowMode(randomOrder: randomOrder)
                }
            }
        }
        
        // Listen for slideshow settings changes (duration, etc.)
        NotificationCenter.default.addObserver(
            forName: .slideshowSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                // If slideshow is playing, restart timer with new duration
                if self.slideshow?.isPlaying == true {
                    ProductionLogger.debug("Slideshow settings changed while playing - restarting timer")
                    self.stopTimer()
                    self.startTimer()
                }
            }
        }
        
        // Listen for sort settings changes
        NotificationCenter.default.addObserver(
            forName: .sortSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let _ = notification.object as? SortSettings {
                Task { @MainActor [weak self] in
                    // Only reload if we have a slideshow to sort and not in the middle of initial creation
                    if self?.slideshow != nil && self?.isCreatingSlideshow == false {
                        await self?.reloadSlideshowWithNewSorting()
                    } else {
                        ProductionLogger.debug("EnhancedSlideshowViewModel: Skipping sort reload - no slideshow or creation in progress")
                    }
                }
            }
        }
        
        // Listen for repository changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("repositoryHealthChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleRepositoryHealthChange()
            }
        }
    }
    
    private func setupVirtualLoaderCallback() {
        Task {
            await self.virtualLoader.setImageLoadedCallback { [weak self] photoId, image in
                self?.handleVirtualImageLoaded(photoId: photoId, image: image.nsImage)
            }
        }
    }
    
    // MARK: - Public Slideshow Management
    
    /// Safely set a slideshow while ensuring internal state consistency
    public func setSlideshow(_ newSlideshow: Slideshow) {
        slideshow = newSlideshow
        currentPhoto = newSlideshow.currentPhoto
        refreshCounter += 1
    }
    
    /// Clear the current error
    public func clearError() {
        error = nil
    }
    
    /// Select a folder and load photos using Repository pattern
    public func selectFolderAndLoadPhotos() async {
        loadingState = .selectingFolder
        error = nil
        
        ProductionLogger.lifecycle("EnhancedSlideshowViewModel: Starting folder selection")
        
        do {
            let folderURL = try await openFolderSelection()
            selectedFolderURL = folderURL
            await createSlideshow(from: folderURL)
        } catch {
            ProductionLogger.error("EnhancedSlideshowViewModel: Error in selectFolderAndLoadPhotos: \(error)")
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            loadingState = .notLoading
        }
    }
    
    /// Create slideshow using Repository pattern with fallback to legacy
    private func createSlideshow(from folderURL: URL) async {
        // Prevent recursive calls
        guard !isCreatingSlideshow else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: Slideshow creation already in progress, ignoring request")
            return
        }
        
        isCreatingSlideshow = true
        defer { isCreatingSlideshow = false }
        
        ProductionLogger.lifecycle("EnhancedSlideshowViewModel: Creating slideshow from folder: \(folderURL.path)")
        operationCount += 1
        
        // Start performance monitoring for slideshow creation
        performanceMonitor.startOperation("slideshow_creation")
        
        do {
            // Cancel any existing loading operations
            await cancelExistingOperations()
            
            loadingState = .scanningFolder(0)
            ProductionLogger.debug("EnhancedSlideshowViewModel: Attempting Repository pattern approach")
            
            // Try Repository pattern first
            let slideshow = try await createSlideshowWithRepository(from: folderURL)
            repositoryOperationCount += 1
            
            ProductionLogger.lifecycle("EnhancedSlideshowViewModel: Successfully created slideshow via Repository pattern with \(slideshow.photos.count) photos")
            
            // Initialize slideshow
            await finalizeSlideshowCreation(slideshow)
            
        } catch {
            ProductionLogger.warning("EnhancedSlideshowViewModel: Repository pattern failed: \(error)")
            
            // Fallback to legacy approach if enabled
            if enableLegacyFallback {
                await fallbackToLegacyCreation(from: folderURL)
            } else {
                ProductionLogger.error("EnhancedSlideshowViewModel: Repository pattern failed and legacy fallback disabled")
                self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
                loadingState = .notLoading
                
                // End performance monitoring
                performanceMonitor.endOperation("slideshow_creation")
            }
        }
    }
    
    /// Create slideshow using Repository pattern
    private func createSlideshowWithRepository(from folderURL: URL) async throws -> Slideshow {
        loadingState = .preparingSlideshow
        
        let customInterval = try SlideshowInterval(slideshowSettingsManager.settings.slideDuration)
        let mode: Slideshow.SlideshowMode = .sequential
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Creating slideshow via ModernSlideshowDomainService")
        let slideshow = try await modernDomainService.createSlideshow(
            from: folderURL,
            interval: customInterval,
            mode: mode
        )
        
        return slideshow
    }
    
    /// Fallback to legacy slideshow creation
    private func fallbackToLegacyCreation(from folderURL: URL) async {
        ProductionLogger.info("EnhancedSlideshowViewModel: Falling back to legacy slideshow creation")
        
        guard let legacyService = legacyDomainService else {
            ProductionLogger.error("EnhancedSlideshowViewModel: Legacy fallback requested but no legacy service available")
            self.error = SlideshowError.loadingFailed(underlying: NSError(
                domain: "EnhancedSlideshowViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Repository pattern failed and no legacy fallback available"]
            ))
            loadingState = .notLoading
            return
        }
        
        do {
            loadingState = .preparingSlideshow
            
            let customInterval = try SlideshowInterval(slideshowSettingsManager.settings.slideDuration)
            let mode: Slideshow.SlideshowMode = .sequential
            
            let slideshow = try await legacyService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            legacyOperationCount += 1
            ProductionLogger.lifecycle("EnhancedSlideshowViewModel: Successfully created slideshow via legacy approach with \(slideshow.photos.count) photos")
            
            await finalizeSlideshowCreation(slideshow)
            
        } catch {
            ProductionLogger.error("EnhancedSlideshowViewModel: Legacy fallback also failed: \(error)")
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            loadingState = .notLoading
        }
    }
    
    /// Finalize slideshow creation with common setup
    private func finalizeSlideshowCreation(_ newSlideshow: Slideshow) async {
        // Ensure slideshow starts at index 0
        var initializedSlideshow = newSlideshow
        if !initializedSlideshow.isEmpty && initializedSlideshow.currentIndex != 0 {
            do {
                try initializedSlideshow.setCurrentIndex(0)
            } catch {
                ProductionLogger.warning("EnhancedSlideshowViewModel: Failed to reset slideshow index: \(error)")
            }
        }
        
        setSlideshow(initializedSlideshow)
        
        if !initializedSlideshow.isEmpty {
            // Explicitly set currentPhoto to ensure first image is displayed
            currentPhoto = initializedSlideshow.currentPhoto
            refreshCounter += 1
            
            // Load the current image immediately to display it
            ProductionLogger.debug("EnhancedSlideshowViewModel: Loading initial image after slideshow creation")
            await loadCurrentImage()
            
            // Auto-recommend settings for collection size
            let recommendedSettings = performanceSettingsManager.recommendedSettings(for: initializedSlideshow.photos.count)
            if recommendedSettings != performanceSettingsManager.settings {
                ProductionLogger.performance("Auto-applying recommended settings for \(initializedSlideshow.photos.count) photos")
                performanceSettingsManager.updateSettings(recommendedSettings)
                
                // Reinitialize virtual loader with new settings
                await reinitializeVirtualLoader()
            }
            
            // Setup virtual loading for large collections
            await setupVirtualLoadingIfNeeded()
            
            // Start auto slideshow if enabled
            if slideshowSettingsManager.settings.autoStart {
                ProductionLogger.debug("EnhancedSlideshowViewModel: Auto-starting slideshow")
                startSlideshow()
            }
        }
        
        loadingState = .notLoading
        
        // End performance monitoring
        performanceMonitor.endOperation("slideshow_creation")
        
        ProductionLogger.lifecycle("EnhancedSlideshowViewModel: Slideshow creation finalized")
    }
    
    /// Recreate slideshow with new sorting (dedicated method for sort changes)
    private func recreateSlideshowWithSorting(from folderURL: URL) async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Recreating slideshow with new sorting")
        
        do {
            // Create slideshow with new sorting directly
            let newSlideshow = try await createSlideshowWithRepository(from: folderURL)
            
            ProductionLogger.debug("EnhancedSlideshowViewModel: Successfully recreated slideshow with \(newSlideshow.photos.count) photos")
            
            // Apply the new slideshow
            await finalizeSlideshowCreation(newSlideshow)
            
        } catch {
            ProductionLogger.error("EnhancedSlideshowViewModel: Failed to recreate slideshow with new sorting: \(error)")
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            loadingState = .notLoading
        }
    }
    
    // MARK: - Image Loading with Repository Pattern
    
    /// Load current image using Repository pattern with fallback
    public func loadCurrentImage() async {
        guard let slideshow = slideshow,
              !slideshow.isEmpty,
              let currentPhoto = slideshow.currentPhoto else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: Cannot load current image - no slideshow or current photo")
            return
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Loading current image: \(currentPhoto.fileName)")
        
        do {
            // Try Repository pattern first
            let loadedPhoto = try await modernDomainService.loadImage(for: currentPhoto)
            await updatePhotoInSlideshow(loadedPhoto)
            repositoryOperationCount += 1
            
        } catch {
            ProductionLogger.warning("EnhancedSlideshowViewModel: Repository image loading failed: \(error)")
            
            // Fallback to legacy if available
            if enableLegacyFallback, let legacyService = legacyDomainService {
                do {
                    let loadedPhoto = try await legacyService.loadImage(for: currentPhoto)
                    await updatePhotoInSlideshow(loadedPhoto)
                    legacyOperationCount += 1
                    
                } catch {
                    ProductionLogger.error("EnhancedSlideshowViewModel: Legacy image loading also failed: \(error)")
                    await handleImageLoadingError(error, for: currentPhoto)
                }
            } else {
                await handleImageLoadingError(error, for: currentPhoto)
            }
        }
    }
    
    /// Update a photo in the slideshow
    private func updatePhotoInSlideshow(_ updatedPhoto: Photo) async {
        guard var currentSlideshow = slideshow else { return }
        
        // Find the photo index by ID
        if let index = currentSlideshow.photos.firstIndex(where: { $0.id == updatedPhoto.id }) {
            do {
                try currentSlideshow.updatePhoto(at: index, with: updatedPhoto)
                setSlideshow(currentSlideshow)
                
                if updatedPhoto.id == currentPhoto?.id {
                    currentPhoto = updatedPhoto
                }
                
            } catch {
                ProductionLogger.error("EnhancedSlideshowViewModel: Failed to update photo in slideshow: \(error)")
            }
        } else {
            ProductionLogger.error("EnhancedSlideshowViewModel: Could not find photo with id \(updatedPhoto.id)")
        }
    }
    
    /// Handle image loading errors
    private func handleImageLoadingError(_ error: Error, for photo: Photo) async {
        ProductionLogger.error("EnhancedSlideshowViewModel: Failed to load image for \(photo.fileName): \(error)")
        
        var failedPhoto = photo
        let slideshowError = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
        failedPhoto.updateLoadState(.failed(slideshowError))
        
        await updatePhotoInSlideshow(failedPhoto)
    }
    
    // MARK: - Repository Health Management
    
    /// Handle repository health changes
    private func handleRepositoryHealthChange() async {
        let healthStatus = await repositoryContainer.performHealthCheck()
        
        if !healthStatus.isHealthy {
            ProductionLogger.warning("EnhancedSlideshowViewModel: Repository health degraded: \(healthStatus.issues)")
            
            // Switch to legacy fallback if repositories are unhealthy
            if enableLegacyFallback && legacyDomainService != nil {
                ProductionLogger.info("EnhancedSlideshowViewModel: Switching to legacy mode due to repository health issues")
                // Could implement automatic fallback logic here
            }
        } else {
            ProductionLogger.info("EnhancedSlideshowViewModel: Repository health restored")
        }
    }
    
    // MARK: - Performance and Health Monitoring
    
    /// Get comprehensive performance metrics
    public func getPerformanceMetrics() async -> EnhancedViewModelMetrics {
        let domainMetrics = modernDomainService.getPerformanceMetrics()
        let repositoryHealth = await repositoryContainer.performHealthCheck()
        let performanceReport = performanceMonitor.getPerformanceReport()
        
        return EnhancedViewModelMetrics(
            totalOperations: operationCount,
            repositoryOperations: repositoryOperationCount,
            legacyOperations: legacyOperationCount,
            repositorySuccessRate: domainMetrics.successRate,
            repositoryHealth: repositoryHealth,
            isUsingLegacyFallback: legacyOperationCount > 0,
            performanceMonitoringEnabled: performanceMonitoring,
            systemPerformance: performanceReport
        )
    }
    
    // MARK: - Utility Methods (delegate to existing implementation)
    
    // NOTE: The following methods would delegate to the existing ModernSlideshowViewModel
    // implementation to maintain backward compatibility. For brevity, I'm including 
    // method signatures but the full implementation would delegate appropriately.
    
    public func startSlideshow() {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Starting slideshow")
        
        guard var currentSlideshow = slideshow else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No slideshow available to start")
            return
        }
        
        // Update slideshow state to playing
        currentSlideshow.play()
        setSlideshow(currentSlideshow)
        
        // Start the timer for auto-progression
        startTimer()
    }
    
    public func stopSlideshow() {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Stopping slideshow")
        
        guard var currentSlideshow = slideshow else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No slideshow available to stop")
            return
        }
        
        // Update slideshow state to stopped
        currentSlideshow.stop()
        setSlideshow(currentSlideshow)
        
        // Stop the timer
        stopTimer()
    }
    
    public func nextPhoto() async {
        guard var currentSlideshow = slideshow else { 
            ProductionLogger.debug("EnhancedSlideshowViewModel: No slideshow available for nextPhoto")
            return 
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Moving to next photo")
        
        // Move to next photo in slideshow
        currentSlideshow.nextPhoto()
        setSlideshow(currentSlideshow)
        currentPhoto = currentSlideshow.currentPhoto
        refreshCounter += 1
        
        // Load the new current image using Repository pattern
        await loadCurrentImage()
        
        // Update virtual loading window for the new position
        await updateVirtualLoadingWindow()
    }
    
    public func previousPhoto() async {
        guard var currentSlideshow = slideshow else { 
            ProductionLogger.debug("EnhancedSlideshowViewModel: No slideshow available for previousPhoto")
            return 
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Moving to previous photo")
        
        // Move to previous photo in slideshow
        currentSlideshow.previousPhoto()
        setSlideshow(currentSlideshow)
        currentPhoto = currentSlideshow.currentPhoto
        refreshCounter += 1
        
        // Load the new current image using Repository pattern
        await loadCurrentImage()
        
        // Update virtual loading window for the new position
        await updateVirtualLoadingWindow()
    }
    
    // MARK: - Private Implementation Methods
    
    private func openFolderSelection() async throws -> URL {
        ProductionLogger.userAction("EnhancedSlideshowViewModel: Starting folder selection")
        
        // Ensure cursor is visible when opening folder
        await MainActor.run {
            NSCursor.unhide()
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Calling fileAccess.selectFolder()")
        guard let folderURL = try fileAccess.selectFolder() else {
            ProductionLogger.userAction("EnhancedSlideshowViewModel: Folder selection cancelled by user")
            // Ensure cursor remains visible when cancelled
            await MainActor.run {
                NSCursor.unhide()
            }
            throw SlideshowError.loadingFailed(underlying: NSError(
                domain: "EnhancedSlideshowViewModel",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Folder selection was cancelled"]
            ))
        }
        
        ProductionLogger.userAction("EnhancedSlideshowViewModel: Selected folder: \(folderURL.path)")
        
        // Ensure cursor is visible after folder selection
        await MainActor.run {
            NSCursor.unhide()
        }
        
        // Generate new random seed if sort order is random
        if let sortSettings = sortSettingsManager, sortSettings.settings.order == .random {
            ProductionLogger.debug("EnhancedSlideshowViewModel: Generating new random seed for folder selection")
            sortSettings.regenerateRandomSeed()
        }
        
        return folderURL
    }
    
    private func cancelExistingOperations() async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Cancelling existing operations")
        
        // Stop any running timer
        stopTimer()
        
        // Cancel virtual loading operations
        await cancelVirtualLoadingOperations()
    }
    
    private func updateSlideshowMode(randomOrder: Bool) {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Updating slideshow mode - randomOrder: \(randomOrder)")
        
        guard let currentSlideshow = slideshow, !currentSlideshow.isEmpty else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No slideshow available for mode update")
            return
        }
        
        // Update sort settings if needed
        if let sortSettings = sortSettingsManager {
            if randomOrder && sortSettings.settings.order != .random {
                ProductionLogger.debug("EnhancedSlideshowViewModel: Switching to random order")
                let newSettings = SortSettings(
                    order: .random,
                    direction: sortSettings.settings.direction,
                    randomSeed: sortSettings.settings.randomSeed
                )
                sortSettings.updateSettings(newSettings)
            } else if !randomOrder && sortSettings.settings.order == .random {
                ProductionLogger.debug("EnhancedSlideshowViewModel: Switching from random to sequential order")
                let newSettings = SortSettings(
                    order: .fileName, // Default to fileName sorting
                    direction: sortSettings.settings.direction,
                    randomSeed: sortSettings.settings.randomSeed
                )
                sortSettings.updateSettings(newSettings)
            }
        }
        
        // If we have photos, trigger a reload to apply new sorting
        if let folderURL = selectedFolderURL {
            Task {
                await reloadSlideshowWithCurrentSettings(from: folderURL)
            }
        }
    }
    
    private func reloadSlideshowWithNewSorting() async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Reloading slideshow with new sorting")
        
        guard let folderURL = selectedFolderURL else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No folder URL available for sorting reload")
            return
        }
        
        // Store current photo ID to maintain position if possible
        let currentPhotoId = slideshow?.currentPhoto?.id
        let wasPlaying = slideshow?.isPlaying == true
        
        // Pause slideshow during reload
        if wasPlaying {
            stopSlideshow()
        }
        
        // Regenerate random seed if using random sort order
        if let sortSettings = sortSettingsManager, sortSettings.settings.order == .random {
            ProductionLogger.debug("EnhancedSlideshowViewModel: Regenerating random seed for sorting reload")
            sortSettings.regenerateRandomSeed()
        }
        
        // Set loading state explicitly for sort operation
        loadingState = .preparingSlideshow
        
        // Create new slideshow with updated sorting (bypassing isCreatingSlideshow check)
        await recreateSlideshowWithSorting(from: folderURL)
        
        // Try to restore position to the same photo if possible
        if let currentPhotoId = currentPhotoId, var newSlideshow = slideshow {
            if let newIndex = newSlideshow.photos.firstIndex(where: { $0.id == currentPhotoId }) {
                do {
                    try newSlideshow.setCurrentIndex(newIndex)
                    setSlideshow(newSlideshow)
                    currentPhoto = newSlideshow.currentPhoto
                    refreshCounter += 1
                    ProductionLogger.debug("EnhancedSlideshowViewModel: Restored position to photo at index \(newIndex)")
                } catch {
                    ProductionLogger.warning("EnhancedSlideshowViewModel: Failed to restore photo position: \(error)")
                }
            }
        }
        
        // Resume playback if it was playing before
        if wasPlaying {
            startSlideshow()
        }
        
        // Ensure loading state is cleared
        if loadingState != .notLoading {
            loadingState = .notLoading
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Sort reload completed successfully")
    }
    
    private func handleVirtualImageLoaded(photoId: UUID, image: NSImage) {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Virtual image loaded for photo ID: \(photoId)")
        
        guard var currentSlideshow = slideshow else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No slideshow available for virtual image update")
            return
        }
        
        // Check if we're in the middle of creating a new slideshow
        guard !isCreatingSlideshow else {
            ProductionLogger.debug("EnhancedSlideshowViewModel: Ignoring virtual image update - slideshow creation in progress")
            return
        }
        
        // Find the photo with the matching ID and update it
        if let photoIndex = currentSlideshow.photos.firstIndex(where: { $0.id == photoId }) {
            var updatedPhoto = currentSlideshow.photos[photoIndex]
            
            // Update the photo with the loaded image
            let sendableImage = SendableImage(image)
            updatedPhoto.updateLoadState(.loaded(sendableImage))
            
            do {
                try currentSlideshow.updatePhoto(at: photoIndex, with: updatedPhoto)
                setSlideshow(currentSlideshow)
                
                // If this is the current photo, update the display
                if updatedPhoto.id == currentPhoto?.id {
                    currentPhoto = updatedPhoto
                    refreshCounter += 1
                    ProductionLogger.debug("EnhancedSlideshowViewModel: Updated current photo display with virtual image")
                }
                
                ProductionLogger.debug("EnhancedSlideshowViewModel: Successfully updated photo at index \(photoIndex) with virtual image")
                
            } catch {
                ProductionLogger.error("EnhancedSlideshowViewModel: Failed to update photo with virtual image: \(error)")
            }
        } else {
            // This is normal when slideshow has been recreated - don't log as warning
            ProductionLogger.debug("EnhancedSlideshowViewModel: Photo with ID \(photoId) no longer in slideshow (likely recreated)")
        }
    }
    
    private func startTimer() {
        stopTimer()
        
        // Use settings from SlideshowSettingsManager
        let interval = slideshowSettingsManager.settings.slideDuration
        
        ProductionLogger.debug("EnhancedSlideshowViewModel.startTimer: Using interval \(interval) seconds from optimized timer pool")
        
        timerId = timerPool.scheduleTimer(
            duration: interval,
            tolerance: 0.1, // 100ms tolerance for better efficiency
            repeats: true
        ) { [weak self] in
            Task { @MainActor in
                await self?.nextPhoto()
            }
        }
    }
    
    private func stopTimer() {
        if let timerId = timerId {
            timerPool.cancelTimer(timerId)
            self.timerId = nil
        }
    }
    
    private func reinitializeVirtualLoader() async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Reinitializing virtual loader with new settings")
        
        guard let currentSlideshow = slideshow, !currentSlideshow.isEmpty else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No slideshow available for virtual loader reinitialization")
            return
        }
        
        // Stop any existing virtual loading operations
        await cancelVirtualLoadingOperations()
        
        // Update virtual loader settings
        await virtualLoader.updateSettings(performanceSettingsManager.settings)
        
        // Update background preloader settings
        await backgroundPreloader.updateSettings(performanceSettingsManager.settings)
        
        // Setup the callback again
        await virtualLoader.setImageLoadedCallback { [weak self] photoId, image in
            self?.handleVirtualImageLoaded(photoId: photoId, image: image.nsImage)
        }
        
        // Setup virtual loading if needed
        await setupVirtualLoadingIfNeeded()
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Virtual loader reinitialization completed")
    }
    
    private func setupVirtualLoadingIfNeeded() async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Setting up virtual loading if needed")
        
        guard let currentSlideshow = slideshow, !currentSlideshow.isEmpty else {
            ProductionLogger.warning("EnhancedSlideshowViewModel: No slideshow available for virtual loading setup")
            return
        }
        
        let photoCount = currentSlideshow.photos.count
        let largeCollectionThreshold = performanceSettingsManager.settings.largeCollectionThreshold
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Photo count: \(photoCount), threshold: \(largeCollectionThreshold)")
        
        if photoCount >= largeCollectionThreshold {
            ProductionLogger.performance("EnhancedSlideshowViewModel: Large collection detected (\(photoCount) photos) - enabling virtual loading")
            
            // Configure virtual loader window for this collection
            await virtualLoader.loadImageWindow(
                around: currentSlideshow.currentIndex, 
                photos: currentSlideshow.photos
            )
            
            // Start background preloading for adjacent images
            let preloadDistance = min(performanceSettingsManager.settings.preloadDistance, 100)
            await backgroundPreloader.schedulePreload(
                photos: currentSlideshow.photos,
                currentIndex: currentSlideshow.currentIndex,
                windowSize: preloadDistance
            )
            
            ProductionLogger.debug("EnhancedSlideshowViewModel: Virtual loading configured with preload distance: \(preloadDistance)")
            
        } else {
            ProductionLogger.debug("EnhancedSlideshowViewModel: Small collection (\(photoCount) photos) - using standard loading")
            
            // For smaller collections, we can load images more aggressively
            let preloadDistance = min(photoCount / 4, 20) // Load up to 25% of photos or 20, whichever is smaller
            await backgroundPreloader.schedulePreload(
                photos: currentSlideshow.photos,
                currentIndex: currentSlideshow.currentIndex,
                windowSize: preloadDistance
            )
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Virtual loading setup completed")
    }
    
    // MARK: - Helper Methods
    
    private func reloadSlideshowWithCurrentSettings(from folderURL: URL) async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Reloading slideshow with current settings")
        
        let wasPlaying = slideshow?.isPlaying == true
        let currentPhotoId = slideshow?.currentPhoto?.id
        
        // Pause slideshow during reload
        if wasPlaying {
            stopSlideshow()
        }
        
        // Reload slideshow
        await createSlideshow(from: folderURL)
        
        // Try to restore position if possible
        if let currentPhotoId = currentPhotoId, var newSlideshow = slideshow {
            if let newIndex = newSlideshow.photos.firstIndex(where: { $0.id == currentPhotoId }) {
                do {
                    try newSlideshow.setCurrentIndex(newIndex)
                    setSlideshow(newSlideshow)
                    currentPhoto = newSlideshow.currentPhoto
                    refreshCounter += 1
                } catch {
                    ProductionLogger.warning("EnhancedSlideshowViewModel: Failed to restore photo position: \(error)")
                }
            }
        }
        
        // Resume playback if it was playing before
        if wasPlaying {
            startSlideshow()
        }
    }
    
    private func cancelVirtualLoadingOperations() async {
        ProductionLogger.debug("EnhancedSlideshowViewModel: Cancelling virtual loading operations")
        
        // Cancel virtual loader operations
        await virtualLoader.clearCache()
        
        // Cancel background preloader operations
        await backgroundPreloader.cancelAllPreloads()
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Virtual loading operations cancelled")
    }
    
    /// Update virtual loading window when navigation occurs
    private func updateVirtualLoadingWindow() async {
        guard let currentSlideshow = slideshow, 
              !currentSlideshow.isEmpty,
              currentSlideshow.photos.count >= performanceSettingsManager.settings.largeCollectionThreshold else {
            ProductionLogger.debug("EnhancedSlideshowViewModel: Skipping virtual loading update for small collection")
            return
        }
        
        ProductionLogger.debug("EnhancedSlideshowViewModel: Updating virtual loading window for index \\(currentSlideshow.currentIndex)")
        
        // Update virtual loader window
        await virtualLoader.loadImageWindow(
            around: currentSlideshow.currentIndex,
            photos: currentSlideshow.photos
        )
        
        // Update background preloader priorities
        await backgroundPreloader.updatePriorities(
            photos: currentSlideshow.photos,
            newIndex: currentSlideshow.currentIndex
        )
    }
}

// MARK: - Supporting Types

/// Performance metrics for the enhanced ViewModel
public struct EnhancedViewModelMetrics: Sendable {
    public let totalOperations: Int
    public let repositoryOperations: Int
    public let legacyOperations: Int
    public let repositorySuccessRate: Double
    public let repositoryHealth: RepositoryHealthStatus
    public let isUsingLegacyFallback: Bool
    public let performanceMonitoringEnabled: Bool
    public let systemPerformance: PerformanceReport?
    
    public init(
        totalOperations: Int,
        repositoryOperations: Int,
        legacyOperations: Int,
        repositorySuccessRate: Double,
        repositoryHealth: RepositoryHealthStatus,
        isUsingLegacyFallback: Bool,
        performanceMonitoringEnabled: Bool,
        systemPerformance: PerformanceReport? = nil
    ) {
        self.totalOperations = totalOperations
        self.repositoryOperations = repositoryOperations
        self.legacyOperations = legacyOperations
        self.repositorySuccessRate = repositorySuccessRate
        self.repositoryHealth = repositoryHealth
        self.isUsingLegacyFallback = isUsingLegacyFallback
        self.performanceMonitoringEnabled = performanceMonitoringEnabled
        self.systemPerformance = systemPerformance
    }
    
    public var repositoryUsageRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(repositoryOperations) / Double(totalOperations)
    }
    
    public var legacyUsageRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(legacyOperations) / Double(totalOperations)
    }
    
    public var memoryUsageMB: UInt64 {
        return systemPerformance?.currentMetrics.memoryUsageMB ?? 0
    }
    
    public var peakMemoryUsageMB: UInt64 {
        return systemPerformance?.peakMemoryUsage ?? 0
    }
}