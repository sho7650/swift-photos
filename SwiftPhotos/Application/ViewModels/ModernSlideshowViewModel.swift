import Foundation
import SwiftUI
import AppKit
import Observation

/// Loading states for detailed user feedback
public enum LoadingState: Equatable {
    case notLoading
    case selectingFolder
    case scanningFolder(Int) // number of files found so far
    case loadingFirstImage
    case preparingSlideshow
    
    public var isLoading: Bool {
        self != .notLoading
    }
    
    public var displayMessage: String {
        switch self {
        case .notLoading:
            return ""
        case .selectingFolder:
            return "Opening folder selection..."
        case .scanningFolder(let count):
            return count > 0 ? "Found \(count) images..." : "Scanning folder..."
        case .loadingFirstImage:
            return "Loading first image..."
        case .preparingSlideshow:
            return "Preparing slideshow..."
        }
    }
}

/// Modern Swift 6 compliant SlideshowViewModel using @Observable
/// This is the new implementation that replaces @ObservableObject with @Observable
@Observable
@MainActor
public final class ModernSlideshowViewModel {
    
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
            ProductionLogger.debug("SlideshowViewModel.currentPhoto changed (refreshCounter: \(refreshCounter), currentIndex: \(currentIndex))")
            if let photo = currentPhoto {
                ProductionLogger.debug("SlideshowViewModel.currentPhoto set to photo '\(photo.fileName)' with state: \(photo.loadState)")
            } else {
                ProductionLogger.debug("SlideshowViewModel.currentPhoto set to nil")
            }
        }
    }
    
    // MARK: - Private Dependencies
    private let domainService: SlideshowDomainService
    private let fileAccess: SecureFileAccess
    private var timer: Timer?
    
    // Performance optimizations for large collections
    private let virtualLoader: VirtualImageLoader
    private let backgroundPreloader: BackgroundPreloader
    private let targetImageLoader: TargetImageLoader
    private let performanceSettingsManager: ModernPerformanceSettingsManager
    private let slideshowSettingsManager: ModernSlideshowSettingsManager
    private let sortSettingsManager: ModernSortSettingsManager?
    
    // MARK: - Initialization
    
    public init(
        domainService: SlideshowDomainService,
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil,
        sortSettings: ModernSortSettingsManager? = nil
    ) {
        self.domainService = domainService
        self.fileAccess = fileAccess
        self.performanceSettingsManager = performanceSettings ?? ModernPerformanceSettingsManager()
        self.slideshowSettingsManager = slideshowSettings ?? ModernSlideshowSettingsManager()
        self.sortSettingsManager = sortSettings
        self.virtualLoader = VirtualImageLoader(settings: self.performanceSettingsManager.settings)
        self.backgroundPreloader = BackgroundPreloader(settings: self.performanceSettingsManager.settings)
        self.targetImageLoader = TargetImageLoader()
        
        ProductionLogger.lifecycle("SlideshowViewModel initialized with settings - window: \(self.performanceSettingsManager.settings.memoryWindowSize), threshold: \(self.performanceSettingsManager.settings.largeCollectionThreshold)")
        
        setupNotificationObservers()
        setupVirtualLoaderCallback()
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
                Task { [weak self] in
                    await self?.reloadSlideshowWithNewSorting()
                }
            }
        }
    }
    
    private func setupVirtualLoaderCallback() {
        Task {
            await self.virtualLoader.setImageLoadedCallback { [weak self] photoId, image in
                self?.handleVirtualImageLoaded(photoId: photoId, image: image)
            }
        }
    }
    
    // MARK: - Public Methods
    
    public func selectFolder() async {
        ProductionLogger.userAction("Starting folder selection")
        do {
            loadingState = .selectingFolder
            error = nil
            
            // Ensure cursor is visible when opening folder
            await MainActor.run {
                NSCursor.unhide()
            }
            
            ProductionLogger.debug("Calling fileAccess.selectFolder()")
            guard let folderURL = try fileAccess.selectFolder() else {
                ProductionLogger.userAction("Folder selection cancelled by user")
                loadingState = .notLoading
                // Ensure cursor remains visible when cancelled
                await MainActor.run {
                    NSCursor.unhide()
                }
                return
            }
            
            ProductionLogger.userAction("Selected folder: \(folderURL.path)")
            selectedFolderURL = folderURL
            
            // Ensure cursor is visible after folder selection
            await MainActor.run {
                NSCursor.unhide()
            }
            
            // Generate new random seed if sort order is random
            if let sortSettings = sortSettingsManager, sortSettings.settings.order == .random {
                ProductionLogger.debug("Generating new random seed for folder selection")
                sortSettings.regenerateRandomSeed()
            }
            
            await createSlideshow(from: folderURL)
            
        } catch let slideshowError as SlideshowError {
            ProductionLogger.error("SlideshowError: \(slideshowError.localizedDescription)")
            error = slideshowError
        } catch {
            ProductionLogger.error("Unexpected error: \(error)")
            // Don't set error for cancellation errors as they are expected during rapid folder changes
            if !(error is CancellationError) {
                self.error = SlideshowError.loadingFailed(underlying: error)
            } else {
                ProductionLogger.debug("Folder selection operation was cancelled (expected during rapid selections)")
            }
        }
        
        loadingState = .notLoading
        
        // Ensure cursor is visible when folder selection completes
        await MainActor.run {
            NSCursor.unhide()
        }
        
        ProductionLogger.lifecycle("Folder selection completed")
    }
    
    public func play() {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.play()
        slideshow = currentSlideshow
        startTimer()
    }
    
    public func pause() {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.pause()
        slideshow = currentSlideshow
        stopTimer()
    }
    
    public func stop() {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.stop()
        slideshow = currentSlideshow
        stopTimer()
    }
    
    public func nextPhoto() {
        guard var currentSlideshow = slideshow else { return }
        
        ProductionLogger.debug("NextPhoto: Current slideshow mode: \(currentSlideshow.mode), current index: \(currentSlideshow.currentIndex)")
        currentSlideshow.nextPhoto()
        ProductionLogger.debug("NextPhoto: After nextPhoto() - new index: \(currentSlideshow.currentIndex)")
        slideshow = currentSlideshow
        currentPhoto = currentSlideshow.currentPhoto
        refreshCounter += 1
        
        // Load the new current image
        Task {
            if currentSlideshow.photos.count > performanceSettingsManager.settings.largeCollectionThreshold {
                await loadCurrentImageVirtual()
                // Update preloader priorities
                await backgroundPreloader.updatePriorities(
                    photos: currentSlideshow.photos,
                    newIndex: currentSlideshow.currentIndex
                )
            } else {
                loadCurrentImage()
            }
        }
    }
    
    public func previousPhoto() {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.previousPhoto()
        slideshow = currentSlideshow
        currentPhoto = currentSlideshow.currentPhoto
        refreshCounter += 1
        
        // Load the new current image
        Task {
            if currentSlideshow.photos.count > performanceSettingsManager.settings.largeCollectionThreshold {
                await loadCurrentImageVirtual()
                // Update preloader priorities
                await backgroundPreloader.updatePriorities(
                    photos: currentSlideshow.photos,
                    newIndex: currentSlideshow.currentIndex
                )
            } else {
                loadCurrentImage()
            }
        }
    }
    
    public func goToPhoto(at index: Int) {
        guard var currentSlideshow = slideshow else { return }
        
        do {
            try currentSlideshow.setCurrentIndex(index)
            slideshow = currentSlideshow
            currentPhoto = currentSlideshow.currentPhoto
            refreshCounter += 1
            
            // Load the new current image
            Task {
                if currentSlideshow.photos.count > performanceSettingsManager.settings.largeCollectionThreshold {
                    await loadCurrentImageVirtual()
                    // Update preloader priorities for jump navigation
                    await backgroundPreloader.updatePriorities(
                        photos: currentSlideshow.photos,
                        newIndex: currentSlideshow.currentIndex
                    )
                } else {
                    loadCurrentImage()
                }
            }
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.invalidIndex(index)
        }
    }
    
    /// Fast navigation for progress bar - immediate display + background cache reconstruction
    public func fastGoToPhoto(at index: Int) {
        guard var currentSlideshow = slideshow else { return }
        
        ProductionLogger.performance("SlideshowViewModel: Fast jump to photo \(index)")
        let startTime = Date()
        
        do {
            // 1. Update index immediately
            try currentSlideshow.setCurrentIndex(index)
            slideshow = currentSlideshow
            refreshCounter += 1
            
            guard let targetPhoto = currentSlideshow.currentPhoto else {
                ProductionLogger.error("fastGoToPhoto: No photo at index \(index)")
                return
            }
            
            // 2. Load target image with highest priority
            Task {
                // Cancel existing load tasks
                await virtualLoader.cancelAllForProgressJump()
                await backgroundPreloader.cancelAllPreloads()
                
                // Emergency load target image
                await targetImageLoader.handleProgressBarJump(to: targetPhoto) { [weak self] result in
                    let jumpTime = Date().timeIntervalSince(startTime)
                    ProductionLogger.performance("fastGoToPhoto: Target image loaded", duration: jumpTime)
                    
                    switch result {
                    case .success(let image):
                        // Update UI immediately
                        var loadedPhoto = targetPhoto
                        loadedPhoto.updateLoadState(.loaded(SendableImage(image)))
                        self?.updatePhotoInSlideshow(loadedPhoto)
                        self?.currentPhoto = loadedPhoto
                        
                        ProductionLogger.debug("fastGoToPhoto: UI updated immediately")
                        
                    case .failure(let error):
                        ProductionLogger.error("fastGoToPhoto: Failed to load target image: \(error)")
                        self?.error = error as? SlideshowError ?? SlideshowError.fileNotFound(targetPhoto.imageURL.url)
                    }
                }
                
                // 3. Background cache window reconstruction (parallel execution)
                let largeCollectionThreshold = self.performanceSettingsManager.settings.largeCollectionThreshold
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    
                    if currentSlideshow.photos.count > largeCollectionThreshold {
                        ProductionLogger.debug("fastGoToPhoto: Starting background cache reconstruction")
                        
                        // Async cache window reconstruction
                        await self.virtualLoader.loadImageWindowAsync(
                            around: index,
                            photos: currentSlideshow.photos
                        )
                        
                        // Update background preloader priorities
                        await self.backgroundPreloader.updatePriorities(
                            photos: currentSlideshow.photos,
                            newIndex: index
                        )
                        
                        let totalTime = Date().timeIntervalSince(startTime)
                        ProductionLogger.performance("fastGoToPhoto: Background reconstruction completed", duration: totalTime)
                    }
                }
            }
            
        } catch {
            self.error = error as? SlideshowError ?? SlideshowError.invalidIndex(index)
        }
    }
    
    public func setInterval(_ interval: SlideshowInterval) {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.setInterval(interval)
        slideshow = currentSlideshow
        
        if currentSlideshow.isPlaying {
            stopTimer()
            startTimer()
        }
    }
    
    public func setMode(_ mode: Slideshow.SlideshowMode) {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.setMode(mode)
        slideshow = currentSlideshow
    }
    
    public func clearError() {
        error = nil
    }
    
    // MARK: - Performance Methods
    
    /// Update performance settings and propagate to components
    public func updatePerformanceSettings(_ newSettings: PerformanceSettings) async {
        performanceSettingsManager.updateSettings(newSettings)
        await updatePerformanceComponents()
        
        ProductionLogger.performance("SlideshowViewModel: Performance settings updated")
    }
    
    /// Get current performance statistics
    public func getPerformanceStatistics() async -> (virtualLoader: (hits: Int, misses: Int, hitRate: Double, loadedCount: Int, memoryUsageMB: Int), preloader: (total: Int, successful: Int, failed: Int, successRate: Double, activeLoads: Int)) {
        let virtualStats = await virtualLoader.getCacheStatistics()
        let preloaderStats = await backgroundPreloader.getStatistics()
        return (virtualLoader: virtualStats, preloader: preloaderStats)
    }
    
    /// Get performance recommendation analysis for current collection
    public func getPerformanceAnalysis() -> (currentSettings: PerformanceSettings, recommendedSettings: PerformanceSettings, collectionSize: Int, estimatedMemoryUsage: Int, canHandle: Bool) {
        let collectionSize = slideshow?.photos.count ?? 0
        let currentSettings = performanceSettingsManager.settings
        let recommendedSettings = performanceSettingsManager.recommendedSettings(for: collectionSize)
        let estimatedUsage = performanceSettingsManager.estimatedMemoryUsage(for: collectionSize)
        let canHandle = performanceSettingsManager.canHandleCollection(size: collectionSize)
        
        return (
            currentSettings: currentSettings,
            recommendedSettings: recommendedSettings,
            collectionSize: collectionSize,
            estimatedMemoryUsage: estimatedUsage,
            canHandle: canHandle
        )
    }
    
    // MARK: - Private Methods
    
    /// Cancel existing loading operations to prevent conflicts
    private func cancelExistingOperations() async {
        ProductionLogger.debug("Cancelling existing loading operations")
        
        // Cancel virtual loader operations
        await virtualLoader.clearCache()
        
        // Cancel background preloader operations
        await backgroundPreloader.cancelAllPreloads()
        
        // Cancel target image loader operations
        await targetImageLoader.cleanup()
        
        ProductionLogger.debug("Existing operations cancelled successfully")
    }
    
    private func createSlideshow(from folderURL: URL) async {
        ProductionLogger.lifecycle("Creating slideshow from folder: \(folderURL.path)")
        do {
            // Cancel any existing loading operations to prevent CancellationError
            await cancelExistingOperations()
            
            loadingState = .scanningFolder(0)
            ProductionLogger.debug("Calling domainService.createSlideshow")
            
            // Apply slideshow settings (random order is now handled by file sorting)
            let mode: Slideshow.SlideshowMode = .sequential
            ProductionLogger.debug("Applying slideshow settings - mode: \(mode), autoStart: \(slideshowSettingsManager.settings.autoStart)")
            
            let customInterval = try SlideshowInterval(slideshowSettingsManager.settings.slideDuration)
            
            loadingState = .preparingSlideshow
            let newSlideshow = try await domainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            ProductionLogger.lifecycle("Created slideshow with \(newSlideshow.photos.count) photos")
            
            // Ensure slideshow starts at index 0 (first image)
            var initializedSlideshow = newSlideshow
            if !initializedSlideshow.isEmpty && initializedSlideshow.currentIndex != 0 {
                ProductionLogger.debug("Resetting slideshow to start from first image (currentIndex was \(initializedSlideshow.currentIndex))")
                try initializedSlideshow.setCurrentIndex(0)
            }
            
            slideshow = initializedSlideshow
            
            if !initializedSlideshow.isEmpty {
                ProductionLogger.debug("Loading current image from index 0")
                ProductionLogger.debug("Current photo at creation: \(initializedSlideshow.currentPhoto?.fileName ?? "nil")")
                
                // Explicitly set currentPhoto to ensure first image is displayed
                currentPhoto = initializedSlideshow.currentPhoto
                refreshCounter += 1
                
                // Auto-recommend settings for collection size
                let recommendedSettings = performanceSettingsManager.recommendedSettings(for: initializedSlideshow.photos.count)
                if recommendedSettings != performanceSettingsManager.settings {
                    ProductionLogger.performance("Auto-applying recommended settings for \(initializedSlideshow.photos.count) photos")
                    ProductionLogger.performance("Settings: window=\(recommendedSettings.memoryWindowSize), memory=\(recommendedSettings.maxMemoryUsageMB)MB, concurrent=\(recommendedSettings.maxConcurrentLoads)")
                    performanceSettingsManager.updateSettings(recommendedSettings)
                    await updatePerformanceComponents()
                } else {
                    ProductionLogger.performance("Current settings already optimal for \(initializedSlideshow.photos.count) photos")
                }
                
                // Prioritize first image loading regardless of collection size
                loadingState = .loadingFirstImage
                
                // Use TargetImageLoader for immediate first image loading
                if let firstPhoto = initializedSlideshow.currentPhoto {
                    ProductionLogger.performance("Loading first image with high priority: \(firstPhoto.fileName)")
                    await targetImageLoader.handleFirstImageLoad(photo: firstPhoto) { [weak self] result in
                        Task { @MainActor in
                            guard let self = self else { return }
                            
                            switch result {
                            case .success(let image):
                                ProductionLogger.debug("First image loaded successfully via emergency load")
                                var loadedPhoto = firstPhoto
                                loadedPhoto.updateLoadState(.loaded(SendableImage(image)))
                                self.updatePhotoInSlideshow(loadedPhoto)
                                self.currentPhoto = loadedPhoto
                                self.refreshCounter += 1
                                
                            case .failure(let error):
                                ProductionLogger.error("Failed to load first image: \(error)")
                                // Don't set error for cancellation errors as they are expected during folder changes
                                if !(error is CancellationError) {
                                    self.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
                                } else {
                                    ProductionLogger.debug("First image loading was cancelled (expected during folder change)")
                                }
                            }
                        }
                    }
                }
                
                // Schedule background loading after first image
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    
                    // Small delay to let first image display
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    
                    // Check if this is a large collection for background processing
                    let largeCollectionThreshold = await self.performanceSettingsManager.settings.largeCollectionThreshold
                    if initializedSlideshow.photos.count > largeCollectionThreshold {
                        ProductionLogger.performance("Large collection (\(initializedSlideshow.photos.count) photos) - starting background virtual loading")
                        await self.loadCurrentImageVirtual()
                        
                        // Schedule background preloading with smart windowing
                        await self.backgroundPreloader.schedulePreload(
                            photos: initializedSlideshow.photos,
                            currentIndex: 0  // Always start preloading from first image
                        )
                    } else {
                        ProductionLogger.performance("Small collection (\(initializedSlideshow.photos.count) photos) - background standard loading")
                        await MainActor.run {
                            self.loadCurrentImage()
                        }
                    }
                }
            } else {
                ProductionLogger.warning("Slideshow is empty - no photos found")
            }
            
            // Auto-start slideshow if enabled in settings
            if !newSlideshow.isEmpty && slideshowSettingsManager.settings.autoStart {
                ProductionLogger.lifecycle("Auto-starting slideshow per settings")
                play()
            }
            
        } catch let slideshowError as SlideshowError {
            ProductionLogger.error("SlideshowError in createSlideshow: \(slideshowError.localizedDescription)")
            error = slideshowError
        } catch {
            ProductionLogger.error("Unexpected error in createSlideshow: \(error)")
            // Don't set error for cancellation errors as they are expected during folder operations
            if !(error is CancellationError) {
                self.error = SlideshowError.loadingFailed(underlying: error)
            } else {
                ProductionLogger.debug("Slideshow creation was cancelled (expected during folder operations)")
            }
        }
    }
    
    /// Update slideshow mode based on settings change (random order now handled by file sorting)
    private func updateSlideshowMode(randomOrder: Bool) {
        guard var currentSlideshow = slideshow else {
            ProductionLogger.debug("updateSlideshowMode: No slideshow to update")
            return
        }
        
        // Random order is now handled at file sorting level, slideshow always uses sequential
        let newMode: Slideshow.SlideshowMode = .sequential
        ProductionLogger.debug("updateSlideshowMode: Random order (\(randomOrder)) is handled by file sorting, slideshow mode remains \(newMode)")
        
        currentSlideshow.setMode(newMode)
        slideshow = currentSlideshow
        
        ProductionLogger.debug("updateSlideshowMode: Slideshow mode updated successfully")
    }
    
    /// Reload slideshow with new sorting settings
    private func reloadSlideshowWithNewSorting() async {
        guard let folderURL = selectedFolderURL else {
            ProductionLogger.debug("reloadSlideshowWithNewSorting: No folder selected, ignoring sort change")
            return
        }
        
        ProductionLogger.debug("reloadSlideshowWithNewSorting: Reloading slideshow with new sort settings")
        
        // Store current state
        let wasPlaying = slideshow?.isPlaying ?? false
        let currentIndex = slideshow?.currentIndex ?? 0
        
        // Pause slideshow if playing
        if wasPlaying {
            stop()
        }
        
        // Reload slideshow from folder with new sorting
        await createSlideshow(from: folderURL)
        
        // Always start from the first image when reloading folder
        if let newSlideshow = slideshow, !newSlideshow.isEmpty {
            // Force to start from index 0 (first image)
            if newSlideshow.currentIndex != 0 {
                ProductionLogger.debug("reloadSlideshowWithNewSorting: Resetting to first image")
                goToPhoto(at: 0)
            }
            
            // Resume playing if it was playing before
            if wasPlaying {
                play()
            }
        }
        
        ProductionLogger.debug("reloadSlideshowWithNewSorting: Slideshow reloaded successfully")
    }
    
    private func startTimer() {
        stopTimer()
        
        // Use settings from SlideshowSettingsManager
        let interval = slideshowSettingsManager.settings.slideDuration
        
        ProductionLogger.debug("StartTimer: Using interval \(interval) seconds from settings")
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextPhoto()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func loadCurrentImageVirtual() async {
        guard let currentSlideshow = slideshow else {
            ProductionLogger.debug("loadCurrentImageVirtual: No slideshow available")
            return
        }
        
        guard let photo = currentSlideshow.currentPhoto else {
            ProductionLogger.debug("loadCurrentImageVirtual: No current photo available")
            return
        }
        
        ProductionLogger.debug("loadCurrentImageVirtual: Loading image window around index \(currentSlideshow.currentIndex)")
        
        // Load images in a window around current index
        await virtualLoader.loadImageWindow(
            around: currentSlideshow.currentIndex,
            photos: currentSlideshow.photos
        )
        
        // Check if current image is ready in virtual cache
        if let cachedImage = await virtualLoader.getImage(for: photo.id) {
            ProductionLogger.debug("loadCurrentImageVirtual: Image loaded from virtual cache")
            
            // Create loaded photo directly from cached image
            var loadedPhoto = photo
            let sendableImage = SendableImage(cachedImage)
            loadedPhoto.updateLoadState(.loaded(sendableImage))
            updatePhotoInSlideshow(loadedPhoto)
        } else if !(await virtualLoader.isLoading(photoId: photo.id)) {
            ProductionLogger.debug("loadCurrentImageVirtual: Loading current image directly")
            // Fallback to direct loading if not in cache and not currently loading
            loadCurrentImage()
        } else {
            ProductionLogger.debug("loadCurrentImageVirtual: Image currently loading in virtual loader")
            // Image is being loaded by virtual loader - we'll get notified when complete
        }
    }
    
    private func loadCurrentImage() {
        guard let currentSlideshow = slideshow else {
            ProductionLogger.debug("loadCurrentImage: No slideshow available")
            return
        }
        
        guard let photo = currentSlideshow.currentPhoto else {
            ProductionLogger.debug("loadCurrentImage: No current photo available")
            return
        }
        
        ProductionLogger.debug("loadCurrentImage: Current photo state: \(photo.loadState)")
        ProductionLogger.debug("loadCurrentImage: Current photo filename: \(photo.fileName)")
        
        guard !photo.loadState.isLoaded && !photo.loadState.isLoading else {
            ProductionLogger.debug("loadCurrentImage: Photo already loaded or loading, skipping")
            return
        }
        
        ProductionLogger.debug("loadCurrentImage: Starting to load image")
        Task {
            do {
                let loadedPhoto = try await domainService.loadImage(for: photo)
                ProductionLogger.debug("loadCurrentImage: Successfully loaded image, updating slideshow")
                updatePhotoInSlideshow(loadedPhoto)
            } catch {
                ProductionLogger.error("loadCurrentImage: Failed to load image: \(error.localizedDescription)")
            }
        }
    }
    
    private func updatePhotoInSlideshow(_ photo: Photo) {
        ProductionLogger.debug("updatePhotoInSlideshow: Updating photo \(photo.fileName) with state \(photo.loadState)")
        
        guard var currentSlideshow = self.slideshow else {
            ProductionLogger.error("updatePhotoInSlideshow: No slideshow available")
            return
        }
        
        ProductionLogger.debug("updatePhotoInSlideshow: BEFORE update - currentIndex: \(currentSlideshow.currentIndex)")
        
        if let index = currentSlideshow.photos.firstIndex(where: { $0.id == photo.id }) {
            ProductionLogger.debug("updatePhotoInSlideshow: Found photo at index \(index), current index: \(currentSlideshow.currentIndex)")
            do {
                try currentSlideshow.updatePhoto(at: index, with: photo)
                ProductionLogger.debug("updatePhotoInSlideshow: AFTER updatePhoto - currentIndex: \(currentSlideshow.currentIndex)")
                
                // Store the current index before updating slideshow
                let wasCurrentPhoto = index == currentSlideshow.currentIndex
                
                // Update slideshow property
                ProductionLogger.debug("updatePhotoInSlideshow: Setting slideshow property")
                self.slideshow = currentSlideshow
                ProductionLogger.debug("updatePhotoInSlideshow: AFTER setting slideshow - currentIndex: \(self.slideshow?.currentIndex ?? -1)")
                
                // Only increment refreshCounter for the current photo, not for preloaded photos
                if wasCurrentPhoto {
                    ProductionLogger.debug("updatePhotoInSlideshow: Setting refreshCounter")
                    self.refreshCounter += 1
                    
                    // Update currentPhoto property directly
                    ProductionLogger.debug("updatePhotoInSlideshow: Setting currentPhoto property")
                    self.currentPhoto = currentSlideshow.currentPhoto
                    
                    // Clear loading state when first image is successfully loaded
                    if photo.loadState.isLoaded && loadingState == .loadingFirstImage {
                        ProductionLogger.debug("updatePhotoInSlideshow: First image loaded successfully, clearing loading state")
                        loadingState = .notLoading
                    }
                    
                    // Keep slideshow running if it was playing
                    ProductionLogger.debug("updatePhotoInSlideshow: Slideshow state: \(currentSlideshow.state)")
                    
                    ProductionLogger.debug("updatePhotoInSlideshow: Updated CURRENT photo (refreshCounter: \(self.refreshCounter), currentIndex: \(self.slideshow?.currentIndex ?? -1))")
                    ProductionLogger.debug("updatePhotoInSlideshow: Current photo after update: \(self.slideshow?.currentPhoto?.fileName ?? "nil") - \(self.slideshow?.currentPhoto?.loadState.description ?? "no state")")
                } else {
                    ProductionLogger.debug("updatePhotoInSlideshow: Updated preloaded photo (no refreshCounter change)")
                }
            } catch {
                ProductionLogger.error("updatePhotoInSlideshow: Failed to update photo: \(error.localizedDescription)")
            }
        } else {
            ProductionLogger.error("updatePhotoInSlideshow: Could not find photo with id \(photo.id)")
        }
    }
    
    /// Update performance components with current settings
    private func updatePerformanceComponents() async {
        await virtualLoader.updateSettings(performanceSettingsManager.settings)
        await backgroundPreloader.updateSettings(performanceSettingsManager.settings)
    }
    
    /// Handle virtual image loading completion for seamless UI integration
    private func handleVirtualImageLoaded(photoId: UUID, image: NSImage) {
        guard let currentSlideshow = slideshow else { return }
        
        // Find the photo that was loaded
        if let photoIndex = currentSlideshow.photos.firstIndex(where: { $0.id == photoId }) {
            let photo = currentSlideshow.photos[photoIndex]
            
            // Create loaded photo with the cached image
            var loadedPhoto = photo
            loadedPhoto.updateLoadState(.loaded(SendableImage(image)))
            
            // Update the slideshow
            updatePhotoInSlideshow(loadedPhoto)
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
        // Clean up async resources
        Task { [virtualLoader, backgroundPreloader] in
            await virtualLoader.clearCache()
            await backgroundPreloader.cancelAllPreloads()
        }
        
        // Timer will be cleaned up automatically when the actor is deallocated
    }
}

// MARK: - Sendable Conformance

extension ModernSlideshowViewModel: @unchecked Sendable {
    // @MainActor ensures thread safety
    // This conformance allows the ViewModel to be passed between actors safely
}