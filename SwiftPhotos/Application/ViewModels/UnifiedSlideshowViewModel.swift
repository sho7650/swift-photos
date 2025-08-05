import Foundation
import SwiftUI
import AppKit
import Observation

/// Unified SlideshowViewModel that consolidates ModernSlideshowViewModel and EnhancedModernSlideshowViewModel
/// Automatically selects between Repository pattern and legacy pattern based on availability
/// This replaces both existing ViewModels with a single, unified implementation
@Observable
@MainActor
public final class UnifiedSlideshowViewModel {
    
    // MARK: - Public Properties (Observable)
    public var slideshow: Slideshow?
    public var loadingState: LoadingState = .notLoading
    public var isLoading: Bool { loadingState.isLoading }
    public var error: SlideshowError?
    public var selectedFolderURL: URL?
    public var refreshCounter: Int = 0
    public var windowLevel: WindowLevel = .normal
    
    // Performance tracking integration
    public var stats: UnifiedPerformanceStats? {
        PerformanceMetricsManager.shared.unifiedStats
    }
    
    // SlideshowViewModelProtocol conformance properties
    public var canNavigateNext: Bool {
        guard let slideshow = slideshow else { return false }
        return !slideshow.isEmpty && slideshow.currentIndex < slideshow.photos.count - 1
    }
    
    public var canNavigatePrevious: Bool {
        guard let slideshow = slideshow else { return false }
        return !slideshow.isEmpty && slideshow.currentIndex > 0
    }
    
    public var progress: Double {
        guard let slideshow = slideshow, !slideshow.isEmpty else { return 0.0 }
        return Double(slideshow.currentIndex + 1) / Double(slideshow.photos.count)
    }
    
    public var folderSelectionState: FolderSelectionState {
        if isLoading {
            return .selecting
        } else if let url = selectedFolderURL {
            return .selected(url)
        } else if let error = error {
            return .failed(error)
        } else {
            return .idle
        }
    }
    
    public var loadingProgress: Double {
        // For now, return simple loading state - could be enhanced with actual progress
        return isLoading ? 0.5 : 1.0
    }
    
    public var estimatedTimeRemaining: TimeInterval? {
        // Could implement actual time estimation based on loading patterns
        return nil
    }
    
    public var processedPhotoCount: Int {
        slideshow?.photos.filter { $0.loadState.isLoaded }.count ?? 0
    }
    
    public var totalPhotoCount: Int {
        slideshow?.photos.count ?? 0
    }
    
    public var isGlobalSlideshow: Bool {
        // Could track if this is a global slideshow vs folder-specific
        false
    }
    
    public var currentPhoto: Photo? = nil {
        didSet {
            let currentIndex = slideshow?.currentIndex ?? -1
            ProductionLogger.debug("UnifiedSlideshowViewModel.currentPhoto changed (refreshCounter: \(refreshCounter), currentIndex: \(currentIndex))")
            if let photo = currentPhoto {
                ProductionLogger.debug("UnifiedSlideshowViewModel.currentPhoto set to photo '\(photo.fileName)' with state: \(photo.loadState)")
            } else {
                ProductionLogger.debug("UnifiedSlideshowViewModel.currentPhoto set to nil")
            }
        }
    }
    
    // MARK: - Architecture Dependencies
    
    /// Repository pattern dependencies (preferred)
    private let modernDomainService: ModernSlideshowDomainService?
    private let repositoryContainer: RepositoryContainer?
    private let imageRepositoryFactory: ImageRepositoryFactory?
    
    /// Legacy dependencies (fallback)
    private let legacyDomainService: SlideshowDomainService?
    private let fileAccess: SecureFileAccess
    
    // MARK: - Timer Management (Unified)
    private var timerId: UUID?
    private let timerManager: TimerManagementProtocol
    
    // MARK: - Performance Components (Unified)
    private let unifiedImageLoader: UnifiedImageLoader
    private let settingsCoordinator: AppSettingsCoordinator
    
    // MARK: - Configuration
    private let enableLegacyFallback: Bool
    private let performanceMonitoring: Bool
    private let preferRepositoryPattern: Bool
    
    // MARK: - Performance Tracking
    private var operationCount = 0
    private var repositoryOperationCount = 0
    private var legacyOperationCount = 0
    
    // MARK: - State Management
    private var isCreatingSlideshow = false
    private var sortReloadTask: Task<Void, Never>?
    private var lastSortSettingsHash: Int = 0
    
    // MARK: - Performance Monitoring
    private let performanceMonitor = PerformanceMonitor.shared
    
    // MARK: - Architecture Detection
    
    /// Determine which architecture pattern to use
    private var shouldUseRepositoryPattern: Bool {
        guard preferRepositoryPattern else { return false }
        return modernDomainService != nil && repositoryContainer != nil
    }
    
    private var effectiveDomainService: String {
        return shouldUseRepositoryPattern ? "Repository" : "Legacy"
    }
    
    // MARK: - Initialization
    
    /// Primary initializer with automatic architecture detection
    public init(
        // Repository pattern dependencies (preferred)
        modernDomainService: ModernSlideshowDomainService? = nil,
        repositoryContainer: RepositoryContainer? = nil,
        imageRepositoryFactory: ImageRepositoryFactory? = nil,
        
        // Legacy dependencies (fallback)
        legacyDomainService: SlideshowDomainService? = nil,
        
        // Shared dependencies
        fileAccess: SecureFileAccess,
        settingsCoordinator: AppSettingsCoordinator? = nil,
        timerManager: TimerManagementProtocol = UnifiedTimerManager(),
        
        // Configuration
        enableLegacyFallback: Bool = true,
        performanceMonitoring: Bool = true,
        preferRepositoryPattern: Bool = true
    ) {
        // Store architecture dependencies
        self.modernDomainService = modernDomainService
        self.repositoryContainer = repositoryContainer ?? (modernDomainService != nil ? RepositoryContainer.shared : nil)
        self.imageRepositoryFactory = imageRepositoryFactory ?? (modernDomainService != nil ? ImageRepositoryFactory.createModernOnly() : nil)
        self.legacyDomainService = legacyDomainService
        self.fileAccess = fileAccess
        self.timerManager = timerManager
        
        // Store configuration
        self.enableLegacyFallback = enableLegacyFallback
        self.performanceMonitoring = performanceMonitoring
        self.preferRepositoryPattern = preferRepositoryPattern
        
        // Initialize unified settings coordinator
        self.settingsCoordinator = settingsCoordinator ?? AppSettingsCoordinator()
        
        // Initialize unified performance component
        self.unifiedImageLoader = UnifiedImageLoader(settings: self.settingsCoordinator.performance.settings)
        
        ProductionLogger.lifecycle("UnifiedSlideshowViewModel initialized with \(effectiveDomainService) pattern - window: \(self.settingsCoordinator.performance.settings.memoryWindowSize), threshold: \(self.settingsCoordinator.performance.settings.largeCollectionThreshold)")
        
        setupNotificationObservers()
        setupUnifiedLoaderCallback()
        
        // Start unified performance monitoring
        if performanceMonitoring {
            PerformanceMetricsManager.shared.startMonitoring()
            ProductionLogger.debug("UnifiedSlideshowViewModel: Unified performance monitoring started")
        }
    }
    
    /// Convenience initializer for Repository pattern
    public convenience init(
        modernDomainService: ModernSlideshowDomainService,
        fileAccess: SecureFileAccess,
        settingsCoordinator: AppSettingsCoordinator? = nil,
        timerManager: TimerManagementProtocol = UnifiedTimerManager()
    ) {
        self.init(
            modernDomainService: modernDomainService,
            repositoryContainer: RepositoryContainer.shared,
            imageRepositoryFactory: ImageRepositoryFactory.createModernOnly(),
            legacyDomainService: nil,
            fileAccess: fileAccess,
            settingsCoordinator: settingsCoordinator,
            timerManager: timerManager,
            enableLegacyFallback: false,
            performanceMonitoring: true,
            preferRepositoryPattern: true
        )
    }
    
    /// Convenience initializer for Legacy pattern  
    public convenience init(
        legacyDomainService: SlideshowDomainService,
        fileAccess: SecureFileAccess,
        settingsCoordinator: AppSettingsCoordinator? = nil,
        timerManager: TimerManagementProtocol = UnifiedTimerManager()
    ) {
        self.init(
            modernDomainService: nil,
            repositoryContainer: nil,
            imageRepositoryFactory: nil,
            legacyDomainService: legacyDomainService,
            fileAccess: fileAccess,
            settingsCoordinator: settingsCoordinator,
            timerManager: timerManager,
            enableLegacyFallback: true,
            performanceMonitoring: true,
            preferRepositoryPattern: false
        )
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationObservers() {
        // Sort settings change observer
        NotificationCenter.default.addObserver(
            forName: .sortSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSortSettingsChanged()
            }
        }
        
        // Performance settings change observer (if notification exists)
        // Note: Using hardcoded notification name as .performanceSettingsChanged may not exist
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("performanceSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePerformanceSettingsChanged()
            }
        }
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Notification observers set up")
    }
    
    private func setupUnifiedLoaderCallback() {
        Task {
            await unifiedImageLoader.setImageLoadedCallback { [weak self] photoId, image in
                Task { @MainActor [weak self] in
                    self?.handleUnifiedImageLoaded(photoId, image)
                }
            }
            
            await unifiedImageLoader.setImageLoadFailedCallback { [weak self] photoId, error in
                Task { @MainActor [weak self] in
                    self?.handleUnifiedImageLoadFailed(photoId, error)
                }
            }
        }
        ProductionLogger.debug("UnifiedSlideshowViewModel: Unified loader callback set up")
    }
    
    // MARK: - Public Slideshow Management
    
    /// Safely set a slideshow while ensuring internal state consistency
    public func setSlideshow(_ newSlideshow: Slideshow) {
        slideshow = newSlideshow
        currentPhoto = newSlideshow.currentPhoto
        refreshCounter += 1
        operationCount += 1
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Slideshow set with \(newSlideshow.photos.count) photos using \(effectiveDomainService) pattern")
    }
    
    /// Clear the current error
    public func clearError() {
        error = nil
        ProductionLogger.debug("UnifiedSlideshowViewModel: Error cleared")
    }
    
    // MARK: - Folder Selection (Unified)
    
    /// Select a folder and load photos using the appropriate pattern
    public func selectFolder() async {
        if shouldUseRepositoryPattern {
            await selectFolderWithRepository()
        } else {
            await selectFolderWithLegacy()
        }
    }
    
    private func selectFolderWithRepository() async {
        guard modernDomainService != nil else {
            ProductionLogger.error("UnifiedSlideshowViewModel: Repository pattern requested but modernDomainService is nil")
            error = SlideshowError.repositoryNotAvailable
            return
        }
        
        loadingState = .selectingFolder
        error = nil
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Photo Folder"
        panel.prompt = "Select Folder"
        
        let response = panel.runModal()
        
        if response == .OK, let selectedURL = panel.url {
            selectedFolderURL = selectedURL
            await createSlideshowWithRepository(from: selectedURL)
        } else {
            ProductionLogger.debug("UnifiedSlideshowViewModel: Repository folder selection cancelled")
        }
        
        loadingState = .notLoading
        repositoryOperationCount += 1
    }
    
    private func selectFolderWithLegacy() async {
        guard legacyDomainService != nil else {
            ProductionLogger.error("UnifiedSlideshowViewModel: Legacy pattern requested but legacyDomainService is nil")
            error = SlideshowError.domainServiceNotAvailable
            return
        }
        
        loadingState = .selectingFolder
        error = nil
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Photo Folder"
        panel.prompt = "Select Folder"
        
        let response = panel.runModal()
        
        if response == .OK, let selectedURL = panel.url {
            selectedFolderURL = selectedURL
            await createSlideshowWithLegacy(from: selectedURL)
        } else {
            ProductionLogger.debug("UnifiedSlideshowViewModel: Legacy folder selection cancelled")
        }
        
        loadingState = .notLoading
        legacyOperationCount += 1
    }
    
    // MARK: - Slideshow Creation (Architecture-Specific)
    
    private func createSlideshowWithRepository(from folderURL: URL) async {
        guard let modernDomainService = modernDomainService else {
            error = SlideshowError.repositoryNotAvailable
            return
        }
        
        // Track slideshow creation performance
        PerformanceMetricsManager.shared.startOperation("SlideshowCreation")
        
        do {
            loadingState = .scanningFolder(0)
            
            // Generate new random seed if sort order is random (for fresh folder loads)
            if settingsCoordinator.sort.settings.order == .random {
                ProductionLogger.debug("UnifiedSlideshowViewModel: Generating new random seed for folder load with random sort")
                settingsCoordinator.sort.regenerateRandomSeedSilently()
            }
            
            let customInterval = try SlideshowInterval(settingsCoordinator.slideshow.settings.slideDuration)
            let mode: Slideshow.SlideshowMode = .sequential
            
            ProductionLogger.debug("UnifiedSlideshowViewModel: Creating slideshow with Repository pattern")
            let newSlideshow = try await modernDomainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            setSlideshow(newSlideshow)
            
            if !newSlideshow.isEmpty {
                await handleLargeCollectionOptimization()
                if settingsCoordinator.slideshow.settings.autoStart {
                    play()
                }
            }
            
            ProductionLogger.info("UnifiedSlideshowViewModel: Repository slideshow created with \(newSlideshow.photos.count) photos")
            
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            ProductionLogger.error("UnifiedSlideshowViewModel: Repository slideshow creation failed - \(error)")
        }
        
        // End performance tracking
        PerformanceMetricsManager.shared.endOperation("SlideshowCreation")
        
        // Always reset loading state after slideshow creation
        loadingState = .notLoading
    }
    
    /// Create slideshow for sort change without regenerating random seeds unnecessarily
    private func createSlideshowForSortChange(from folderURL: URL) async {
        guard let modernDomainService = modernDomainService else {
            error = SlideshowError.repositoryNotAvailable
            return
        }
        
        do {
            loadingState = .scanningFolder(0)
            
            // DON'T regenerate random seed here - it was already handled in handleSortSettingsChanged() if needed
            // This method is specifically for sort changes, not fresh folder loads
            
            let customInterval = try SlideshowInterval(settingsCoordinator.slideshow.settings.slideDuration)
            let mode: Slideshow.SlideshowMode = .sequential
            
            ProductionLogger.debug("UnifiedSlideshowViewModel: Creating slideshow for sort change with Repository pattern")
            let newSlideshow = try await modernDomainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            setSlideshow(newSlideshow)
            
            if !newSlideshow.isEmpty {
                await handleLargeCollectionOptimization()
                // Don't auto-start on sort changes - let user control playback
            }
            
            ProductionLogger.info("UnifiedSlideshowViewModel: Repository slideshow created for sort change with \(newSlideshow.photos.count) photos")
            
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            ProductionLogger.error("UnifiedSlideshowViewModel: Repository slideshow creation for sort change failed - \(error)")
        }
        
        // Always reset loading state after slideshow creation
        loadingState = .notLoading
    }
    
    private func createSlideshowWithLegacy(from folderURL: URL) async {
        guard let legacyDomainService = legacyDomainService else {
            error = SlideshowError.domainServiceNotAvailable
            return
        }
        
        // Track slideshow creation performance
        PerformanceMetricsManager.shared.startOperation("SlideshowCreation")
        
        do {
            loadingState = .scanningFolder(0)
            
            // Generate new random seed if sort order is random (for fresh folder loads)
            if settingsCoordinator.sort.settings.order == .random {
                ProductionLogger.debug("UnifiedSlideshowViewModel: Generating new random seed for folder load with random sort")
                settingsCoordinator.sort.regenerateRandomSeedSilently()
            }
            
            let customInterval = try SlideshowInterval(settingsCoordinator.slideshow.settings.slideDuration)
            let mode: Slideshow.SlideshowMode = .sequential
            
            ProductionLogger.debug("UnifiedSlideshowViewModel: Creating slideshow with Legacy pattern")
            let newSlideshow = try await legacyDomainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            setSlideshow(newSlideshow)
            
            if !newSlideshow.isEmpty {
                await handleLargeCollectionOptimization()
                if settingsCoordinator.slideshow.settings.autoStart {
                    play()
                }
            }
            
            ProductionLogger.info("UnifiedSlideshowViewModel: Legacy slideshow created with \(newSlideshow.photos.count) photos")
            
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            ProductionLogger.error("UnifiedSlideshowViewModel: Legacy slideshow creation failed - \(error)")
        }
        
        // End performance tracking
        PerformanceMetricsManager.shared.endOperation("SlideshowCreation")
        
        // Always reset loading state after slideshow creation
        loadingState = .notLoading
    }
    
    // MARK: - Playback Controls (Unified)
    
    public func play() {
        guard var slideshow = slideshow, !slideshow.isEmpty else {
            ProductionLogger.debug("UnifiedSlideshowViewModel: Cannot play - no slideshow or empty slideshow")
            return
        }
        
        stopTimer()
        
        // CRITICAL FIX: Update slideshow state so UI icons update
        slideshow.play()
        self.slideshow = slideshow
        refreshCounter += 1
        
        let interval = settingsCoordinator.slideshow.settings.slideDuration
        
        Task { [weak self] in
            guard let self = self else { return }
            let newTimerId = await self.timerManager.scheduleRepeatingTimer(interval: interval) { [weak self] in
                Task { @MainActor in
                    await self?.nextPhoto()
                }
            }
            await MainActor.run {
                self.timerId = newTimerId
            }
        }
        
        ProductionLogger.info("UnifiedSlideshowViewModel: Slideshow started with \(interval)s interval using \(effectiveDomainService) pattern")
    }
    
    public func pause() {
        stopTimer()
        
        // CRITICAL FIX: Update slideshow state so UI icons update
        guard var slideshow = slideshow else { return }
        slideshow.pause()
        self.slideshow = slideshow
        refreshCounter += 1
        
        ProductionLogger.info("UnifiedSlideshowViewModel: Slideshow paused")
    }
    
    public func stop() {
        stopTimer()
        
        // CRITICAL FIX: Update slideshow state so UI icons update
        guard var slideshow = slideshow else { return }
        slideshow.stop()
        self.slideshow = slideshow
        refreshCounter += 1
        
        ProductionLogger.info("UnifiedSlideshowViewModel: Slideshow stopped")
    }
    
    private func stopTimer() {
        if let timerId = timerId {
            Task { await timerManager.cancelTimer(timerId) }
            self.timerId = nil
        }
    }
    
    // MARK: - Photo Navigation (Unified)
    
    /// Reset slideshow to first photo (useful after sort changes)
    public func resetToFirstPhoto() {
        guard var slideshow = slideshow, !slideshow.isEmpty else { return }
        
        do {
            try slideshow.setCurrentIndex(0)
            self.slideshow = slideshow
            currentPhoto = slideshow.currentPhoto
            refreshCounter += 1
            
            ProductionLogger.debug("UnifiedSlideshowViewModel: Reset to first photo successfully")
        } catch {
            ProductionLogger.error("UnifiedSlideshowViewModel: Failed to reset to first photo: \(error)")
        }
    }
    
    public func nextPhoto() async {
        guard var slideshow = slideshow else { return }
        
        // Check if we should pause auto-play on manual navigation
        let shouldPauseOnManualNavigation = settingsCoordinator.slideshow.settings.pauseOnManualNavigation
        let wasPlaying = slideshow.isPlaying
        
        if wasPlaying && shouldPauseOnManualNavigation {
            pause()
            ProductionLogger.userAction("UnifiedSlideshowViewModel: Paused auto-play for manual navigation to next photo (setting enabled)")
        }
        
        slideshow.nextPhoto()
        self.slideshow = slideshow
        currentPhoto = slideshow.currentPhoto
        refreshCounter += 1
        
        await handleLargeCollectionNavigation()
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Advanced to photo \(slideshow.currentIndex + 1)/\(slideshow.photos.count)")
    }
    
    public func previousPhoto() async {
        guard var slideshow = slideshow else { return }
        
        // Check if we should pause auto-play on manual navigation
        let shouldPauseOnManualNavigation = settingsCoordinator.slideshow.settings.pauseOnManualNavigation
        let wasPlaying = slideshow.isPlaying
        
        if wasPlaying && shouldPauseOnManualNavigation {
            pause()
            ProductionLogger.userAction("UnifiedSlideshowViewModel: Paused auto-play for manual navigation to previous photo (setting enabled)")
        }
        
        slideshow.previousPhoto()
        self.slideshow = slideshow
        currentPhoto = slideshow.currentPhoto
        refreshCounter += 1
        
        await handleLargeCollectionNavigation()
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Moved back to photo \(slideshow.currentIndex + 1)/\(slideshow.photos.count)")
    }
    
    public func jumpToPhoto(at index: Int) async {
        guard var slideshow = slideshow else { return }
        guard slideshow.photos.indices.contains(index) else {
            ProductionLogger.error("UnifiedSlideshowViewModel: Invalid jump index \(index) for collection of \(slideshow.photos.count) photos")
            return
        }
        
        ProductionLogger.userAction("UnifiedSlideshowViewModel: 🎯 Jumping directly to photo \(index + 1)/\(slideshow.photos.count)")
        
        // Stop slideshow if playing to prevent conflicts
        stop()
        
        do {
            try slideshow.setCurrentIndex(index)
            self.slideshow = slideshow
            currentPhoto = slideshow.currentPhoto
            refreshCounter += 1
            
            // Handle large collection navigation for the new position
            await handleLargeCollectionNavigation()
            
            ProductionLogger.debug("UnifiedSlideshowViewModel: Successfully jumped to photo \(slideshow.currentIndex + 1)/\(slideshow.photos.count)")
        } catch {
            ProductionLogger.error("UnifiedSlideshowViewModel: Failed to jump to photo \(index): \(error)")
        }
    }
    
    // MARK: - Performance Optimization (Unified)
    
    private func handleLargeCollectionOptimization() async {
        guard let slideshow = slideshow else { return }
        
        let photoCount = slideshow.photos.count
        let threshold = settingsCoordinator.performance.settings.largeCollectionThreshold
        
        if photoCount > threshold {
            ProductionLogger.performance("UnifiedSlideshowViewModel: Large collection detected (\(photoCount) photos) - enabling virtual loading")
            await unifiedImageLoader.loadImageWindow(around: slideshow.currentIndex, photos: slideshow.photos)
        }
    }
    
    private func handleLargeCollectionNavigation() async {
        guard let slideshow = slideshow else { return }
        
        let photoCount = slideshow.photos.count
        let threshold = settingsCoordinator.performance.settings.largeCollectionThreshold
        
        if photoCount > threshold {
            await unifiedImageLoader.loadImageWindow(around: slideshow.currentIndex, photos: slideshow.photos)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleSortSettingsChanged() {
        guard let _ = slideshow, let folderURL = selectedFolderURL else { return }
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Sort settings changed - reloading slideshow dynamically")
        
        // ENHANCED DEBUGGING: Trace settings manager instance and UserDefaults values
        let settingsManagerAddress = "\(Unmanaged.passUnretained(settingsCoordinator).toOpaque())"
        let sortManagerAddress = "\(Unmanaged.passUnretained(settingsCoordinator.sort).toOpaque())"
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Settings manager instance: \(settingsManagerAddress)")
        ProductionLogger.debug("UnifiedSlideshowViewModel: Sort manager instance: \(sortManagerAddress)")
        
        // Read directly from UserDefaults to verify what's actually stored
        if let data = UserDefaults.standard.data(forKey: "SwiftPhotosSortSettings"),
           let sortSettingsFromUserDefaults = try? JSONDecoder().decode(SortSettings.self, from: data) {
            ProductionLogger.debug("UnifiedSlideshowViewModel: UserDefaults contains SortSettings: \(sortSettingsFromUserDefaults)")
            ProductionLogger.debug("UnifiedSlideshowViewModel: UserDefaults sort order: \(sortSettingsFromUserDefaults.order.displayName)")
        } else {
            ProductionLogger.debug("UnifiedSlideshowViewModel: UserDefaults has no SortSettings data or failed to decode")
        }
        
        // CRITICAL FIX: Capture the current sort settings IMMEDIATELY when notification is received
        // Don't read them after the async delay where settings might be stale
        let currentSortOrder = settingsCoordinator.sort.settings.order
        let currentSortDirection = settingsCoordinator.sort.settings.direction
        ProductionLogger.debug("UnifiedSlideshowViewModel: Captured sort order from settingsCoordinator: \(currentSortOrder.displayName)")
        ProductionLogger.debug("UnifiedSlideshowViewModel: Captured sort direction from settingsCoordinator: \(currentSortDirection.displayName)")
        
        // Also check the underlying ModernSortSettingsManager directly
        let modernSortSettings = settingsCoordinator.sort.settings
        ProductionLogger.debug("UnifiedSlideshowViewModel: ModernSortSettingsManager settings: order=\(modernSortSettings.order.displayName), direction=\(modernSortSettings.direction.displayName), seed=\(modernSortSettings.randomSeed)")
        
        // CRITICAL: Track direction changes specifically
        ProductionLogger.debug("UnifiedSlideshowViewModel: Sort direction captured: \(modernSortSettings.direction.displayName)")
        
        // Stop current playback if running
        if slideshow?.isPlaying == true {
            pause()
        }
        
        // Cancel any existing sort reload task first to prevent accumulation
        sortReloadTask?.cancel()
        
        sortReloadTask = Task { [weak self] in
            // Wait for debouncing to handle rapid setting changes
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second debounce
            
            guard !Task.isCancelled else { return }
            
            // Generate new random seed if sort order is random (do this just before reload)
            // Use captured sort settings from notification time
            ProductionLogger.debug("UnifiedSlideshowViewModel: Current sort order for seed check: \(currentSortOrder.displayName)")
            ProductionLogger.debug("UnifiedSlideshowViewModel: Current sort direction for reload: \(currentSortDirection.displayName)")
            
            if currentSortOrder == .random {
                ProductionLogger.debug("UnifiedSlideshowViewModel: Generating new random seed for dynamic sort change to random")
                self?.settingsCoordinator.sort.regenerateRandomSeedSilently()
            } else {
                ProductionLogger.debug("UnifiedSlideshowViewModel: NOT generating random seed - sort order is \(currentSortOrder.displayName)")
            }
            
            // Verify direction is still correct before reload
            let currentDirectionBeforeReload = self?.settingsCoordinator.sort.settings.direction
            ProductionLogger.debug("UnifiedSlideshowViewModel: Direction verification before reload: captured=\(currentSortDirection.displayName), current=\(currentDirectionBeforeReload?.displayName ?? "nil")")
            
            await self?.reloadSlideshowForSortChange(from: folderURL)
        }
    }
    
    private func reloadSlideshowForSortChange(from folderURL: URL) async {
        ProductionLogger.debug("UnifiedSlideshowViewModel: Reloading slideshow for sort settings change")
        
        // Clear current state to ensure clean reload
        currentPhoto = nil
        
        if shouldUseRepositoryPattern {
            await createSlideshowForSortChange(from: folderURL)
        } else {
            await createSlideshowWithLegacy(from: folderURL)
        }
        
        // Ensure we start from the first photo after sort change
        if var newSlideshow = slideshow, !newSlideshow.isEmpty {
            // Force reset to first photo
            do {
                try newSlideshow.setCurrentIndex(0)
                self.slideshow = newSlideshow
                self.currentPhoto = newSlideshow.currentPhoto
                refreshCounter += 1
                
                ProductionLogger.info("UnifiedSlideshowViewModel: Sort reload complete - showing first of \(newSlideshow.photos.count) photos")
            } catch {
                ProductionLogger.error("UnifiedSlideshowViewModel: Failed to reset to first photo: \(error)")
            }
        }
    }
    
    private func handlePerformanceSettingsChanged() {
        ProductionLogger.debug("UnifiedSlideshowViewModel: Performance settings changed - updating unified loader")
        Task {
            await unifiedImageLoader.updateSettings(settingsCoordinator.performance.settings)
        }
    }
    
    private func handleUnifiedImageLoaded(_ photoId: UUID, _ image: SendableImage) {
        guard var slideshow = slideshow,
              let photoIndex = slideshow.photos.firstIndex(where: { $0.id == photoId }) else { 
            ProductionLogger.debug("UnifiedSlideshowViewModel: Photo not found in slideshow for virtual image load")
            return 
        }
        
        // 1. Update Photo state
        var updatedPhoto = slideshow.photos[photoIndex]
        updatedPhoto.updateLoadState(.loaded(image))
        do {
            try slideshow.updatePhoto(at: photoIndex, with: updatedPhoto)
        } catch {
            ProductionLogger.error("UnifiedSlideshowViewModel: Failed to update photo at index \(photoIndex): \(error)")
            return
        }
        
        // 2. Update slideshow
        self.slideshow = slideshow
        
        // 3. Update currentPhoto if this is the currently displayed photo
        if photoIndex == slideshow.currentIndex {
            self.currentPhoto = updatedPhoto
            ProductionLogger.debug("UnifiedSlideshowViewModel: Current photo '\(updatedPhoto.fileName)' loaded successfully - state: \(updatedPhoto.loadState.description)")
        } else {
            ProductionLogger.debug("UnifiedSlideshowViewModel: Background photo '\(updatedPhoto.fileName)' loaded successfully - index: \(photoIndex)")
        }
        
        // 4. Trigger UI update
        refreshCounter += 1
    }
    
    /// Handle image loading failures
    private func handleUnifiedImageLoadFailed(_ photoId: UUID, _ error: Error) {
        guard var slideshow = slideshow,
              let photoIndex = slideshow.photos.firstIndex(where: { $0.id == photoId }) else {
            ProductionLogger.error("UnifiedSlideshowViewModel: Photo not found for failed load - \(error)")
            return
        }
        
        // 1. Update Photo state to failed
        var failedPhoto = slideshow.photos[photoIndex]
        let slideshowError = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
        failedPhoto.updateLoadState(.failed(slideshowError))
        do {
            try slideshow.updatePhoto(at: photoIndex, with: failedPhoto)
        } catch {
            ProductionLogger.error("UnifiedSlideshowViewModel: Failed to update failed photo at index \(photoIndex): \(error)")
            return
        }
        
        // 2. Update slideshow
        self.slideshow = slideshow
        
        // 3. Update currentPhoto if this is the currently displayed photo
        if photoIndex == slideshow.currentIndex {
            self.currentPhoto = failedPhoto
            ProductionLogger.error("UnifiedSlideshowViewModel: Current photo '\(failedPhoto.fileName)' failed to load: \(error)")
        } else {
            ProductionLogger.error("UnifiedSlideshowViewModel: Background photo '\(failedPhoto.fileName)' failed to load: \(error)")
        }
        
        // 4. Trigger UI update
        refreshCounter += 1
    }
    
    // MARK: - Performance Metrics
    
    public func getPerformanceMetrics() -> [String: Any] {
        return [
            "architecture": effectiveDomainService,
            "totalOperations": operationCount,
            "repositoryOperations": repositoryOperationCount,
            "legacyOperations": legacyOperationCount,
            "preferredPattern": preferRepositoryPattern ? "Repository" : "Legacy",
            "fallbackEnabled": enableLegacyFallback,
            "monitoringEnabled": performanceMonitoring
        ]
    }
    
    deinit {
        // Note: Cannot access @MainActor properties from deinit
        ProductionLogger.lifecycle("UnifiedSlideshowViewModel deinitialized")
    }
}

// MARK: - SlideshowViewModelProtocol Conformance

extension UnifiedSlideshowViewModel: SlideshowViewModelProtocol {
    // All required methods are already implemented above
}

// MARK: - Error Extensions

extension SlideshowError {
    static let repositoryNotAvailable = SlideshowError.loadingFailed(underlying: NSError(domain: "UnifiedSlideshowViewModel", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Repository pattern dependencies not available"]))
    static let domainServiceNotAvailable = SlideshowError.loadingFailed(underlying: NSError(domain: "UnifiedSlideshowViewModel", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Legacy domain service not available"]))
}