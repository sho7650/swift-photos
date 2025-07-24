import Foundation
import SwiftUI
import AppKit

@MainActor
public class SlideshowViewModel: ObservableObject {
    @Published public var slideshow: Slideshow?
    @Published public var isLoading = false
    @Published public var error: SlideshowError?
    @Published public var selectedFolderURL: URL?
    @Published public var refreshCounter: Int = 0
    // Swipe functionality removed
    
    @Published public var currentPhoto: Photo? = nil {
        didSet {
            let currentIndex = slideshow?.currentIndex ?? -1
            print("🔄 SlideshowViewModel.currentPhoto: CHANGED (refreshCounter: \(refreshCounter), currentIndex: \(currentIndex))")
            if let photo = currentPhoto {
                print("🔄 SlideshowViewModel.currentPhoto: SET to photo '\(photo.fileName)' with state: \(photo.loadState)")
            } else {
                print("🔄 SlideshowViewModel.currentPhoto: SET to nil")
            }
        }
    }
    
    private let domainService: SlideshowDomainService
    private let fileAccess: SecureFileAccess
    private var timer: Timer?
    
    // Performance optimizations for large collections
    private let virtualLoader: VirtualImageLoader
    private let backgroundPreloader: BackgroundPreloader
    private let targetImageLoader: TargetImageLoader
    private let performanceSettingsManager: PerformanceSettingsManager
    private let slideshowSettingsManager: SlideshowSettingsManager
    private let sortSettingsManager: SortSettingsManager?
    
    public init(domainService: SlideshowDomainService, fileAccess: SecureFileAccess, performanceSettings: PerformanceSettingsManager? = nil, slideshowSettings: SlideshowSettingsManager? = nil, sortSettings: SortSettingsManager? = nil) {
        self.domainService = domainService
        self.fileAccess = fileAccess
        self.performanceSettingsManager = performanceSettings ?? PerformanceSettingsManager()
        self.slideshowSettingsManager = slideshowSettings ?? SlideshowSettingsManager()
        self.sortSettingsManager = sortSettings
        self.virtualLoader = VirtualImageLoader(settings: self.performanceSettingsManager.settings)
        self.backgroundPreloader = BackgroundPreloader(settings: self.performanceSettingsManager.settings)
        self.targetImageLoader = TargetImageLoader()
        
        print("🚀 SlideshowViewModel: Initialized with settings - window: \(self.performanceSettingsManager.settings.memoryWindowSize), threshold: \(self.performanceSettingsManager.settings.largeCollectionThreshold)")
        
        // Set up virtual loader callback for seamless UI integration
        Task {
            await self.virtualLoader.setImageLoadedCallback { [weak self] photoId, image in
                self?.handleVirtualImageLoaded(photoId: photoId, image: image)
            }
        }
        
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
        
        // Listen for sort settings changes
        NotificationCenter.default.addObserver(
            forName: .sortSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let _ = notification.object as? SortSettings {
                Task { @MainActor in
                    await self?.reloadSlideshowWithNewSorting()
                }
            }
        }
    }
    
    
    public func selectFolder() async {
        print("🚀 Starting folder selection...")
        do {
            isLoading = true
            error = nil
            
            print("🚀 Calling fileAccess.selectFolder()...")
            guard let folderURL = try fileAccess.selectFolder() else {
                print("🚀 Folder selection cancelled by user")
                isLoading = false
                return
            }
            
            print("🚀 Selected folder: \(folderURL.path)")
            selectedFolderURL = folderURL
            
            // Generate new random seed if sort order is random
            if let sortSettings = sortSettingsManager, sortSettings.settings.order == .random {
                print("🎲 Generating new random seed for folder selection")
                sortSettings.regenerateRandomSeed()
            }
            
            await createSlideshow(from: folderURL)
            
        } catch let slideshowError as SlideshowError {
            print("❌ SlideshowError: \(slideshowError.localizedDescription)")
            error = slideshowError
        } catch {
            print("❌ Unexpected error: \(error)")
            self.error = SlideshowError.loadingFailed(underlying: error)
        }
        
        isLoading = false
        print("🚀 Folder selection completed")
    }
    
    private func createSlideshow(from folderURL: URL) async {
        print("🚀 Creating slideshow from folder: \(folderURL.path)")
        do {
            print("🚀 Calling domainService.createSlideshow...")
            
            // Apply slideshow settings (random order is now handled by file sorting)
            let mode: Slideshow.SlideshowMode = .sequential
            print("🎬 Applying slideshow settings - mode: \(mode), autoStart: \(slideshowSettingsManager.settings.autoStart)")
            
            let customInterval = try SlideshowInterval(slideshowSettingsManager.settings.slideDuration)
            let newSlideshow = try await domainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            print("🚀 Created slideshow with \(newSlideshow.photos.count) photos")
            slideshow = newSlideshow
            
            if !newSlideshow.isEmpty {
                print("🚀 Loading current image...")
                print("🚀 Current photo at creation: \(newSlideshow.currentPhoto?.fileName ?? "nil")")
                
                // Auto-recommend settings for collection size
                let recommendedSettings = performanceSettingsManager.recommendedSettings(for: newSlideshow.photos.count)
                if recommendedSettings != performanceSettingsManager.settings {
                    print("🚀 Auto-applying recommended settings for \(newSlideshow.photos.count) photos")
                    print("   📊 Settings: window=\(recommendedSettings.memoryWindowSize), memory=\(recommendedSettings.maxMemoryUsageMB)MB, concurrent=\(recommendedSettings.maxConcurrentLoads)")
                    performanceSettingsManager.updateSettings(recommendedSettings)
                    await updatePerformanceComponents()
                } else {
                    print("🚀 Current settings already optimal for \(newSlideshow.photos.count) photos")
                }
                
                // Check if this is a large collection
                if newSlideshow.photos.count > performanceSettingsManager.settings.largeCollectionThreshold {
                    print("🚀 Large collection detected (\(newSlideshow.photos.count) photos) - using virtual loading")
                    await loadCurrentImageVirtual()
                    
                    // Schedule background preloading with smart windowing
                    await backgroundPreloader.schedulePreload(
                        photos: newSlideshow.photos,
                        currentIndex: newSlideshow.currentIndex
                    )
                } else {
                    print("🚀 Small collection (\(newSlideshow.photos.count) photos) - using standard loading")
                    loadCurrentImage()
                }
            } else {
                print("⚠️ Slideshow is empty - no photos found")
            }
            
            // Auto-start slideshow if enabled in settings
            if !newSlideshow.isEmpty && slideshowSettingsManager.settings.autoStart {
                print("🎬 Auto-starting slideshow per settings")
                play()
            }
            
        } catch let slideshowError as SlideshowError {
            print("❌ SlideshowError in createSlideshow: \(slideshowError.localizedDescription)")
            error = slideshowError
        } catch {
            print("❌ Unexpected error in createSlideshow: \(error)")
            self.error = SlideshowError.loadingFailed(underlying: error)
        }
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
        
        print("🎬 NextPhoto: Current slideshow mode: \(currentSlideshow.mode), current index: \(currentSlideshow.currentIndex)")
        currentSlideshow.nextPhoto()
        print("🎬 NextPhoto: After nextPhoto() - new index: \(currentSlideshow.currentIndex)")
        slideshow = currentSlideshow
        currentPhoto = currentSlideshow.currentPhoto  // UPDATE @Published property
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
        currentPhoto = currentSlideshow.currentPhoto  // UPDATE @Published property
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
            currentPhoto = currentSlideshow.currentPhoto  // UPDATE @Published property
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
    
    /// プログレスバー専用高速ナビゲーション - 即座表示＋バックグラウンドキャッシュ再構成
    public func fastGoToPhoto(at index: Int) {
        guard var currentSlideshow = slideshow else { return }
        
        print("🚀 SlideshowViewModel: Fast jump to photo \(index)")
        let startTime = Date()
        
        do {
            // 1. まずインデックスを即座に更新
            try currentSlideshow.setCurrentIndex(index)
            slideshow = currentSlideshow
            refreshCounter += 1
            
            guard let targetPhoto = currentSlideshow.currentPhoto else {
                print("❌ fastGoToPhoto: No photo at index \(index)")
                return
            }
            
            // 2. ターゲット画像を最優先で即座ロード
            Task {
                // 既存のロードタスクをキャンセル
                await virtualLoader.cancelAllForProgressJump()
                await backgroundPreloader.cancelAllPreloads()
                
                // ターゲット画像を緊急ロード
                await targetImageLoader.handleProgressBarJump(to: targetPhoto) { [weak self] result in
                    let jumpTime = Date().timeIntervalSince(startTime)
                    print("🎯 fastGoToPhoto: Target image loaded in \(String(format: "%.2f", jumpTime * 1000))ms")
                    
                    switch result {
                    case .success(let image):
                        // 即座にUIを更新
                        var loadedPhoto = targetPhoto
                        loadedPhoto.updateLoadState(.loaded(image))
                        self?.updatePhotoInSlideshow(loadedPhoto)
                        self?.currentPhoto = loadedPhoto
                        
                        print("✅ fastGoToPhoto: UI updated immediately")
                        
                    case .failure(let error):
                        print("❌ fastGoToPhoto: Failed to load target image: \(error)")
                        self?.error = error as? SlideshowError ?? SlideshowError.fileNotFound(targetPhoto.imageURL.url)
                    }
                }
                
                // 3. バックグラウンドでキャッシュウィンドウを再構成（並行実行）
                let largeCollectionThreshold = self.performanceSettingsManager.settings.largeCollectionThreshold
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    
                    if currentSlideshow.photos.count > largeCollectionThreshold {
                        print("🗄️ fastGoToPhoto: Starting background cache reconstruction")
                        
                        // 非同期でキャッシュウィンドウを再構成
                        await self.virtualLoader.loadImageWindowAsync(
                            around: index,
                            photos: currentSlideshow.photos
                        )
                        
                        // バックグラウンドプリローダーの優先度を更新
                        await self.backgroundPreloader.updatePriorities(
                            photos: currentSlideshow.photos,
                            newIndex: index
                        )
                        
                        let totalTime = Date().timeIntervalSince(startTime)
                        print("🗄️ fastGoToPhoto: Background reconstruction completed in \(String(format: "%.2f", totalTime * 1000))ms total")
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
    
    /// Update slideshow mode based on settings change (random order now handled by file sorting)
    private func updateSlideshowMode(randomOrder: Bool) {
        guard var currentSlideshow = slideshow else { 
            print("🎬 updateSlideshowMode: No slideshow to update")
            return 
        }
        
        // Random order is now handled at file sorting level, slideshow always uses sequential
        let newMode: Slideshow.SlideshowMode = .sequential
        print("🎬 updateSlideshowMode: Random order (\(randomOrder)) is handled by file sorting, slideshow mode remains \(newMode)")
        
        currentSlideshow.setMode(newMode)
        slideshow = currentSlideshow
        
        print("🎬 updateSlideshowMode: Slideshow mode updated successfully")
    }
    
    /// Reload slideshow with new sorting settings
    @MainActor
    private func reloadSlideshowWithNewSorting() async {
        guard let folderURL = selectedFolderURL else {
            print("🔄 reloadSlideshowWithNewSorting: No folder selected, ignoring sort change")
            return
        }
        
        print("🔄 reloadSlideshowWithNewSorting: Reloading slideshow with new sort settings")
        
        // Store current state
        let wasPlaying = slideshow?.isPlaying ?? false
        let currentIndex = slideshow?.currentIndex ?? 0
        
        // Pause slideshow if playing
        if wasPlaying {
            stop()
        }
        
        // Reload slideshow from folder with new sorting
        await createSlideshow(from: folderURL)
        
        // Try to maintain current position if possible
        if let newSlideshow = slideshow, !newSlideshow.isEmpty {
            let targetIndex = min(currentIndex, newSlideshow.photos.count - 1)
            if targetIndex != newSlideshow.currentIndex {
                goToPhoto(at: targetIndex)
            }
            
            // Resume playing if it was playing before
            if wasPlaying {
                play()
            }
        }
        
        print("🔄 reloadSlideshowWithNewSorting: Slideshow reloaded successfully")
    }
    
    private func startTimer() {
        stopTimer()
        
        // Use settings from SlideshowSettingsManager
        let interval = slideshowSettingsManager.settings.slideDuration
        
        print("🔄 StartTimer: Using interval \(interval) seconds from settings")
        
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
            print("🖼️ loadCurrentImageVirtual: No slideshow available")
            return
        }
        
        guard let photo = currentSlideshow.currentPhoto else {
            print("🖼️ loadCurrentImageVirtual: No current photo available")
            return
        }
        
        print("🖼️ loadCurrentImageVirtual: Loading image window around index \(currentSlideshow.currentIndex)")
        
        // Load images in a window around current index
        await virtualLoader.loadImageWindow(
            around: currentSlideshow.currentIndex,
            photos: currentSlideshow.photos
        )
        
        // Check if current image is ready in virtual cache
        if let cachedImage = await virtualLoader.getImage(for: photo.id) {
            print("🖼️ loadCurrentImageVirtual: Image loaded from virtual cache")
            
            // Create loaded photo directly from cached image
            Task { @MainActor in
                var loadedPhoto = photo
                loadedPhoto.updateLoadState(.loaded(cachedImage))
                updatePhotoInSlideshow(loadedPhoto)
            }
        } else if !(await virtualLoader.isLoading(photoId: photo.id)) {
            print("🖼️ loadCurrentImageVirtual: Loading current image directly")
            // Fallback to direct loading if not in cache and not currently loading
            loadCurrentImage()
        } else {
            print("🖼️ loadCurrentImageVirtual: Image currently loading in virtual loader")
            // Image is being loaded by virtual loader - we'll get notified when complete
        }
    }
    
    private func loadCurrentImage() {
        guard let currentSlideshow = slideshow else {
            print("🖼️ loadCurrentImage: No slideshow available")
            return
        }
        
        guard let photo = currentSlideshow.currentPhoto else {
            print("🖼️ loadCurrentImage: No current photo available")
            return
        }
        
        print("🖼️ loadCurrentImage: Current photo state: \(photo.loadState)")
        print("🖼️ loadCurrentImage: Current photo filename: \(photo.fileName)")
        
        guard !photo.loadState.isLoaded && !photo.loadState.isLoading else {
            print("🖼️ loadCurrentImage: Photo already loaded or loading, skipping")
            return
        }
        
        print("🖼️ loadCurrentImage: Starting to load image...")
        Task {
            do {
                let loadedPhoto = try await domainService.loadImage(for: photo)
                print("🖼️ loadCurrentImage: Successfully loaded image, updating slideshow")
                updatePhotoInSlideshow(loadedPhoto)
            } catch {
                print("❌ loadCurrentImage: Failed to load image: \(error.localizedDescription)")
                SlideshowLogger.shared.error("Failed to load image: \(error.localizedDescription)")
            }
        }
    }
    
    private func updatePhotoInSlideshow(_ photo: Photo) {
        print("🔄 updatePhotoInSlideshow: Updating photo \(photo.fileName) with state \(photo.loadState)")
        
        // CRITICAL: Use MainActor.run to ensure proper UI thread execution
        Task { @MainActor in
            
            guard var currentSlideshow = self.slideshow else { 
                print("❌ updatePhotoInSlideshow: No slideshow available")
                return 
            }
            
            print("🔄 updatePhotoInSlideshow: BEFORE update - currentIndex: \(currentSlideshow.currentIndex)")
            
            if let index = currentSlideshow.photos.firstIndex(where: { $0.id == photo.id }) {
                print("🔄 updatePhotoInSlideshow: Found photo at index \(index), current index: \(currentSlideshow.currentIndex)")
                do {
                    try currentSlideshow.updatePhoto(at: index, with: photo)
                    print("🔄 updatePhotoInSlideshow: AFTER updatePhoto - currentIndex: \(currentSlideshow.currentIndex)")
                    
                    // Store the current index before updating slideshow
                    let wasCurrentPhoto = index == currentSlideshow.currentIndex
                    
                    // CRITICAL: Force UI update by setting properties individually
                    print("🔄 updatePhotoInSlideshow: Setting slideshow property...")
                    self.slideshow = currentSlideshow
                    print("🔄 updatePhotoInSlideshow: AFTER setting slideshow - currentIndex: \(self.slideshow?.currentIndex ?? -1)")
                    
                    // Only increment refreshCounter for the current photo, not for preloaded photos
                    if wasCurrentPhoto {
                        print("🔄 updatePhotoInSlideshow: Setting refreshCounter...")
                        self.refreshCounter += 1
                        
                                // CRITICAL: Update currentPhoto @Published property directly
                        print("🔄 updatePhotoInSlideshow: Setting currentPhoto @Published property...")
                        self.currentPhoto = currentSlideshow.currentPhoto
                        
                        // Keep slideshow running if it was playing
                        print("🔄 updatePhotoInSlideshow: Slideshow state: \(currentSlideshow.state)")
                        
                        print("✅ updatePhotoInSlideshow: Updated CURRENT photo (refreshCounter: \(self.refreshCounter), currentIndex: \(self.slideshow?.currentIndex ?? -1))")
                        print("✅ updatePhotoInSlideshow: Current photo after update: \(self.slideshow?.currentPhoto?.fileName ?? "nil") - \(self.slideshow?.currentPhoto?.loadState.description ?? "no state")")
                        
                        print("🔄 updatePhotoInSlideshow: Forcing objectWillChange notification...")
                        self.objectWillChange.send()
                        print("✅ updatePhotoInSlideshow: objectWillChange sent")
                        
                        // Force a small delay to ensure UI update
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                        print("✅ updatePhotoInSlideshow: UI update completed")
                    } else {
                        print("✅ updatePhotoInSlideshow: Updated preloaded photo (no refreshCounter change)")
                    }
                } catch {
                    print("❌ updatePhotoInSlideshow: Failed to update photo: \(error.localizedDescription)")
                    SlideshowLogger.shared.error("Failed to update photo: \(error.localizedDescription)")
                }
            } else {
                print("❌ updatePhotoInSlideshow: Could not find photo with id \(photo.id)")
            }
        }
    }
    
    public func clearError() {
        error = nil
    }
    
    /// Update performance settings and propagate to components
    public func updatePerformanceSettings(_ newSettings: PerformanceSettings) async {
        performanceSettingsManager.updateSettings(newSettings)
        await updatePerformanceComponents()
        
        print("🚀 SlideshowViewModel: Performance settings updated")
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
    
    /// Update performance components with current settings
    private func updatePerformanceComponents() async {
        await virtualLoader.updateSettings(performanceSettingsManager.settings)
        await backgroundPreloader.updateSettings(performanceSettingsManager.settings)
    }
    
    /// Handle virtual image loading completion for seamless UI integration
    @MainActor
    private func handleVirtualImageLoaded(photoId: UUID, image: NSImage) {
        guard let currentSlideshow = slideshow else { return }
        
        // Find the photo that was loaded
        if let photoIndex = currentSlideshow.photos.firstIndex(where: { $0.id == photoId }) {
            let photo = currentSlideshow.photos[photoIndex]
            
            // Create loaded photo with the cached image
            var loadedPhoto = photo
            loadedPhoto.updateLoadState(.loaded(image))
            
            // Update the slideshow
            updatePhotoInSlideshow(loadedPhoto)
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
        // Clean up async resources
        Task { [virtualLoader, backgroundPreloader] in
            await virtualLoader.clearCache()
            await backgroundPreloader.cancelAllPreloads()
        }
    }
}