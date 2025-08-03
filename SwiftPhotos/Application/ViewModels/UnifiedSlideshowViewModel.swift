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
    private let timerPool = OptimizedTimerPool.shared
    
    // MARK: - Performance Components (Shared)
    private let virtualLoader: VirtualImageLoader
    private let backgroundPreloader: BackgroundPreloader
    private let targetImageLoader: TargetImageLoader
    private let performanceSettingsManager: ModernPerformanceSettingsManager
    private let slideshowSettingsManager: ModernSlideshowSettingsManager
    private let sortSettingsManager: ModernSortSettingsManager?
    
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
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil,
        sortSettings: ModernSortSettingsManager? = nil,
        
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
        
        // Store configuration
        self.enableLegacyFallback = enableLegacyFallback
        self.performanceMonitoring = performanceMonitoring
        self.preferRepositoryPattern = preferRepositoryPattern
        
        // Initialize settings managers
        self.performanceSettingsManager = performanceSettings ?? ModernPerformanceSettingsManager()
        self.slideshowSettingsManager = slideshowSettings ?? ModernSlideshowSettingsManager()
        self.sortSettingsManager = sortSettings
        
        // Initialize performance components
        self.virtualLoader = VirtualImageLoader(settings: self.performanceSettingsManager.settings)
        self.backgroundPreloader = BackgroundPreloader(settings: self.performanceSettingsManager.settings)
        self.targetImageLoader = TargetImageLoader()
        
        ProductionLogger.lifecycle("UnifiedSlideshowViewModel initialized with \(effectiveDomainService) pattern - window: \(self.performanceSettingsManager.settings.memoryWindowSize), threshold: \(self.performanceSettingsManager.settings.largeCollectionThreshold)")
        
        setupNotificationObservers()
        setupVirtualLoaderCallback()
    }
    
    /// Convenience initializer for Repository pattern
    public convenience init(
        modernDomainService: ModernSlideshowDomainService,
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil,
        sortSettings: ModernSortSettingsManager? = nil
    ) {
        self.init(
            modernDomainService: modernDomainService,
            repositoryContainer: RepositoryContainer.shared,
            imageRepositoryFactory: ImageRepositoryFactory.createModernOnly(),
            legacyDomainService: nil,
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings,
            enableLegacyFallback: false,
            performanceMonitoring: true,
            preferRepositoryPattern: true
        )
    }
    
    /// Convenience initializer for Legacy pattern  
    public convenience init(
        legacyDomainService: SlideshowDomainService,
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil,
        sortSettings: ModernSortSettingsManager? = nil
    ) {
        self.init(
            modernDomainService: nil,
            repositoryContainer: nil,
            imageRepositoryFactory: nil,
            legacyDomainService: legacyDomainService,
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings,
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
    
    private func setupVirtualLoaderCallback() {
        Task {
            await virtualLoader.setImageLoadedCallback { [weak self] photoId, image in
                Task { @MainActor [weak self] in
                    self?.handleVirtualImageLoaded(photoId, image)
                }
            }
        }
        ProductionLogger.debug("UnifiedSlideshowViewModel: Virtual loader callback set up")
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
        
        do {
            loadingState = .scanningFolder(0)
            
            let customInterval = try SlideshowInterval(slideshowSettingsManager.settings.slideDuration)
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
                if slideshowSettingsManager.settings.autoStart {
                    play()
                }
            }
            
            ProductionLogger.info("UnifiedSlideshowViewModel: Repository slideshow created with \(newSlideshow.photos.count) photos")
            
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            ProductionLogger.error("UnifiedSlideshowViewModel: Repository slideshow creation failed - \(error)")
        }
    }
    
    private func createSlideshowWithLegacy(from folderURL: URL) async {
        guard let legacyDomainService = legacyDomainService else {
            error = SlideshowError.domainServiceNotAvailable
            return
        }
        
        do {
            loadingState = .scanningFolder(0)
            
            let customInterval = try SlideshowInterval(slideshowSettingsManager.settings.slideDuration)
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
                if slideshowSettingsManager.settings.autoStart {
                    play()
                }
            }
            
            ProductionLogger.info("UnifiedSlideshowViewModel: Legacy slideshow created with \(newSlideshow.photos.count) photos")
            
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
            ProductionLogger.error("UnifiedSlideshowViewModel: Legacy slideshow creation failed - \(error)")
        }
    }
    
    // MARK: - Playback Controls (Unified)
    
    public func play() {
        guard let slideshow = slideshow, !slideshow.isEmpty else {
            ProductionLogger.debug("UnifiedSlideshowViewModel: Cannot play - no slideshow or empty slideshow")
            return
        }
        
        stopTimer()
        
        let interval = slideshowSettingsManager.settings.slideDuration
        
        timerId = timerPool.every(interval) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.nextPhoto()
            }
        }
        
        ProductionLogger.info("UnifiedSlideshowViewModel: Slideshow started with \(interval)s interval using \(effectiveDomainService) pattern")
    }
    
    public func pause() {
        stopTimer()
        ProductionLogger.info("UnifiedSlideshowViewModel: Slideshow paused")
    }
    
    public func stop() {
        stopTimer()
        ProductionLogger.info("UnifiedSlideshowViewModel: Slideshow stopped")
    }
    
    private func stopTimer() {
        if let timerId = timerId {
            timerPool.cancelTimer(timerId)
            self.timerId = nil
        }
    }
    
    // MARK: - Photo Navigation (Unified)
    
    public func nextPhoto() async {
        guard var slideshow = slideshow else { return }
        
        slideshow.nextPhoto()
        self.slideshow = slideshow
        currentPhoto = slideshow.currentPhoto
        refreshCounter += 1
        
        await handleLargeCollectionNavigation()
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Advanced to photo \(slideshow.currentIndex + 1)/\(slideshow.photos.count)")
    }
    
    public func previousPhoto() async {
        guard var slideshow = slideshow else { return }
        
        slideshow.previousPhoto()
        self.slideshow = slideshow
        currentPhoto = slideshow.currentPhoto
        refreshCounter += 1
        
        await handleLargeCollectionNavigation()
        
        ProductionLogger.debug("UnifiedSlideshowViewModel: Moved back to photo \(slideshow.currentIndex + 1)/\(slideshow.photos.count)")
    }
    
    // MARK: - Performance Optimization (Unified)
    
    private func handleLargeCollectionOptimization() async {
        guard let slideshow = slideshow else { return }
        
        let photoCount = slideshow.photos.count
        let threshold = performanceSettingsManager.settings.largeCollectionThreshold
        
        if photoCount > threshold {
            ProductionLogger.performance("UnifiedSlideshowViewModel: Large collection detected (\(photoCount) photos) - enabling virtual loading")
            await virtualLoader.loadImageWindow(around: slideshow.currentIndex, photos: slideshow.photos)
        }
    }
    
    private func handleLargeCollectionNavigation() async {
        guard let slideshow = slideshow else { return }
        
        let photoCount = slideshow.photos.count
        let threshold = performanceSettingsManager.settings.largeCollectionThreshold
        
        if photoCount > threshold {
            await virtualLoader.loadImageWindow(around: slideshow.currentIndex, photos: slideshow.photos)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleSortSettingsChanged() {
        guard let _ = slideshow, let folderURL = selectedFolderURL else { return }
        
        // Cancel any existing sort reload task
        sortReloadTask?.cancel()
        
        sortReloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
            
            guard !Task.isCancelled else { return }
            
            await self?.reloadSlideshowForSortChange(from: folderURL)
        }
    }
    
    private func reloadSlideshowForSortChange(from folderURL: URL) async {
        ProductionLogger.debug("UnifiedSlideshowViewModel: Reloading slideshow for sort settings change")
        
        if shouldUseRepositoryPattern {
            await createSlideshowWithRepository(from: folderURL)
        } else {
            await createSlideshowWithLegacy(from: folderURL)
        }
    }
    
    private func handlePerformanceSettingsChanged() {
        ProductionLogger.debug("UnifiedSlideshowViewModel: Performance settings changed - updating virtual loader")
        Task {
            await virtualLoader.updateSettings(performanceSettingsManager.settings)
            await backgroundPreloader.updateSettings(performanceSettingsManager.settings)
        }
    }
    
    private func handleVirtualImageLoaded(_ photoId: UUID, _ image: SendableImage) {
        guard let slideshow = slideshow,
              let photoIndex = slideshow.photos.firstIndex(where: { $0.id == photoId }),
              photoIndex == slideshow.currentIndex else { return }
        
        // Update current photo with loaded image
        if slideshow.photos.first(where: { $0.id == photoId }) != nil {
            // Note: Photo is immutable, so we update through the slideshow
            refreshCounter += 1
            ProductionLogger.debug("UnifiedSlideshowViewModel: Virtual image loaded for current photo")
        }
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