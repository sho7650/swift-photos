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
    private let performanceSettingsManager: PerformanceSettingsManager
    
    public init(domainService: SlideshowDomainService, fileAccess: SecureFileAccess, performanceSettings: PerformanceSettingsManager? = nil) {
        self.domainService = domainService
        self.fileAccess = fileAccess
        self.performanceSettingsManager = performanceSettings ?? PerformanceSettingsManager()
        self.virtualLoader = VirtualImageLoader(settings: self.performanceSettingsManager.settings)
        self.backgroundPreloader = BackgroundPreloader(settings: self.performanceSettingsManager.settings)
        
        print("🚀 SlideshowViewModel: Initialized with settings - window: \(self.performanceSettingsManager.settings.memoryWindowSize), threshold: \(self.performanceSettingsManager.settings.largeCollectionThreshold)")
        
        // Set up virtual loader callback for seamless UI integration
        Task {
            await self.virtualLoader.setImageLoadedCallback { [weak self] photoId, image in
                self?.handleVirtualImageLoaded(photoId: photoId, image: image)
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
            let newSlideshow = try await domainService.createSlideshow(
                from: folderURL,
                interval: .default,
                mode: .sequential
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
        
        currentSlideshow.nextPhoto()
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
    
    private func startTimer() {
        stopTimer()
        
        guard let interval = slideshow?.interval else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval.timeInterval, repeats: true) { [weak self] _ in
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
        
        // Clean up async resources
        Task { [virtualLoader, backgroundPreloader] in
            await virtualLoader.clearCache()
            await backgroundPreloader.cancelAllPreloads()
        }
    }
}