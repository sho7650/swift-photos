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
    
    public init(domainService: SlideshowDomainService, fileAccess: SecureFileAccess) {
        self.domainService = domainService
        self.fileAccess = fileAccess
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
                loadCurrentImage()
                
                // TEMPORARILY DISABLE PRELOADING TO TEST DISPLAY
                print("🚀 PRELOADING DISABLED FOR DEBUG - currentIndex should stay 0")
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
        loadCurrentImage()
        
        // TEMPORARILY DISABLE PRELOADING TO TEST DISPLAY
        print("🚀 nextPhoto: PRELOADING DISABLED FOR DEBUG")
    }
    
    public func previousPhoto() {
        guard var currentSlideshow = slideshow else { return }
        
        currentSlideshow.previousPhoto()
        slideshow = currentSlideshow
        currentPhoto = currentSlideshow.currentPhoto  // UPDATE @Published property
        refreshCounter += 1
        
        // Load the new current image
        loadCurrentImage()
        
        // TEMPORARILY DISABLE PRELOADING TO TEST DISPLAY
        print("🚀 previousPhoto: PRELOADING DISABLED FOR DEBUG")
    }
    
    public func goToPhoto(at index: Int) {
        guard var currentSlideshow = slideshow else { return }
        
        do {
            try currentSlideshow.setCurrentIndex(index)
            slideshow = currentSlideshow
            currentPhoto = currentSlideshow.currentPhoto  // UPDATE @Published property
            refreshCounter += 1
            
            // Load the new current image
            loadCurrentImage()
            
            // TEMPORARILY DISABLE PRELOADING TO TEST DISPLAY
            print("🚀 goToPhoto: PRELOADING DISABLED FOR DEBUG")
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
        print("🚨 startTimer: TIMER DISABLED FOR DEBUG")
        stopTimer()
        
        // TEMPORARILY DISABLED FOR DEBUG
        // guard let interval = slideshow?.interval else { return }
        // 
        // timer = Timer.scheduledTimer(withTimeInterval: interval.timeInterval, repeats: true) { [weak self] _ in
        //     Task { @MainActor in
        //         self?.nextPhoto()
        //     }
        // }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
            print("🔄 updatePhotoInSlideshow: Running on MainActor")
            
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
                        
                        // CRITICAL: Check if slideshow is auto-playing and stop it for debugging
                        print("🔄 updatePhotoInSlideshow: Slideshow state: \(currentSlideshow.state)")
                        if currentSlideshow.isPlaying {
                            print("🚨 updatePhotoInSlideshow: SLIDESHOW IS AUTO-PLAYING! Stopping it for debug...")
                            var debugSlideshow = currentSlideshow
                            debugSlideshow.stop()
                            self.slideshow = debugSlideshow
                            self.stopTimer()
                        }
                        
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
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
}