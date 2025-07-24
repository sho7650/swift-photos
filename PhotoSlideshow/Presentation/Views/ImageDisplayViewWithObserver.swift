import SwiftUI
import AppKit

public struct ImageDisplayViewWithObserver: View {
    @ObservedObject var viewModel: SlideshowViewModel
    @ObservedObject var photoZoomState: PhotoZoomState
    @ObservedObject var advancedGestureManager: AdvancedGestureManager
    @EnvironmentObject var transitionSettings: TransitionSettingsManager
    @State private var transitionManager: ImageTransitionManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    @State private var viewportSize: CGSize = .zero
    
    public init(
        viewModel: SlideshowViewModel,
        photoZoomState: PhotoZoomState,
        advancedGestureManager: AdvancedGestureManager
    ) {
        self.viewModel = viewModel
        self.photoZoomState = photoZoomState
        self.advancedGestureManager = advancedGestureManager
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Always use solid black background - no transparency
                Color.black.ignoresSafeArea()
                
                // Hidden view to track geometry changes and update viewport size
                Color.clear
                    .onAppear {
                        viewportSize = geometry.size
                        updateZoomStateWithViewport(geometry.size)
                        // Ensure initial photo is fitted to window
                        if viewModel.currentPhoto != nil {
                            photoZoomState.resetZoom(animated: false)
                        }
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        viewportSize = newSize
                        updateZoomStateWithViewport(newSize)
                        // Reset zoom to fit when window size changes
                        photoZoomState.resetZoom(animated: false)
                    }
                
                // Main content layer with transition effects
                if let photo = viewModel.currentPhoto {
                    switch photo.loadState {
                    case .loaded(let image):
                        // FIXED: Accurate positioning and size matching
                        let imageDisplaySize = calculateImageDisplaySize(
                            imageSize: image.size,
                            containerSize: geometry.size
                        )
                        let imagePosition = calculateImagePosition(
                            imageSize: imageDisplaySize,
                            containerSize: geometry.size
                        )
                        
                        ZStack {
                            // Black background - same size as image
                            Rectangle()
                                .fill(Color.black)
                                .frame(
                                    width: imageDisplaySize.width,
                                    height: imageDisplaySize.height
                                )
                                .position(
                                    x: imagePosition.x,
                                    y: imagePosition.y
                                )
                            
                            // Image with transition effects and zoom support
                            if showImage {
                                advancedGestureManager.createPhotoGestureView(
                                    content: {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(
                                                width: imageDisplaySize.width,
                                                height: imageDisplaySize.height
                                            )
                                            .scaleEffect(photoZoomState.currentZoomLevel)
                                            .offset(
                                                x: photoZoomState.zoomOffset.x + (viewModel.swipeProgress * geometry.size.width),
                                                y: photoZoomState.zoomOffset.y
                                            )
                                            .position(
                                                x: imagePosition.x,
                                                y: imagePosition.y
                                            )
                                            .transition(getTransitionEffect())
                                    },
                                    bounds: CGRect(origin: .zero, size: geometry.size)
                                )
                            }
                        }
                        .id(viewModel.refreshCounter)  // Apply the id for refresh
                    
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                case .notLoaded:
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                case .failed(_):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Failed to load image")
                            .foregroundColor(.white)
                    }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("Select a folder to start")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            initializeTransitionManager()
            setupTransitionNotifications()
        }
        .onChange(of: viewModel.currentPhoto?.id) { oldPhotoID, newPhotoID in
            handlePhotoChange(newPhotoID: newPhotoID)
            updateZoomStateWithViewport(viewportSize)
        }
        .animation(getTransitionAnimation(), value: showImage)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: viewModel.swipeProgress)
    }
    
    /// Calculate the actual display size of the image, accounting for aspect ratio
    private func calculateImageDisplaySize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        // Use full container size for proper fit-to-screen calculation
        let maxWidth = containerSize.width
        let maxHeight = containerSize.height
        
        guard maxWidth > 0 && maxHeight > 0 && imageSize.width > 0 && imageSize.height > 0 else {
            return containerSize
        }
        
        // Calculate scale factors for width and height
        let scaleX = maxWidth / imageSize.width
        let scaleY = maxHeight / imageSize.height
        
        // Use the smaller scale to ensure the entire image fits
        let scale = min(scaleX, scaleY)
        
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
    
    /// Calculate the center position for the image within the container
    private func calculateImagePosition(imageSize: CGSize, containerSize: CGSize) -> CGPoint {
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        return CGPoint(x: centerX, y: centerY)
    }
    
    // MARK: - Transition Effects
    
    /// Initialize transition manager
    private func initializeTransitionManager() {
        if transitionManager == nil {
            transitionManager = ImageTransitionManager(transitionSettings: transitionSettings)
        }
        
        // Initialize showImage state
        showImage = true
        currentPhotoID = viewModel.currentPhoto?.id
    }
    
    /// Setup transition settings notifications
    private func setupTransitionNotifications() {
        NotificationCenter.default.addObserver(
            forName: .transitionSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak transitionSettings] _ in
            Task { @MainActor in
                // Force update the transition manager with new settings
                if let settings = transitionSettings {
                    self.transitionManager = ImageTransitionManager(transitionSettings: settings)
                    
                    // Trigger a brief visual feedback to show the effect immediately
                    if settings.settings.isEnabled && self.viewModel.currentPhoto != nil {
                        self.showImage = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.showImage = true
                        }
                    }
                }
            }
        }
    }
    
    /// Handle photo change with transitions
    private func handlePhotoChange(newPhotoID: UUID?) {
        guard let newID = newPhotoID, newID != currentPhotoID else { return }
        
        currentPhotoID = newID
        
        // Update zoom state with new photo context
        if let photo = viewModel.currentPhoto,
           case .loaded(let image) = photo.loadState {
            // Reset zoom to fit screen for each new photo
            photoZoomState.setPhotoContext(
                photoId: newID.uuidString,
                photoSize: image.size,
                viewportSize: viewportSize.width > 0 ? viewportSize : CGSize(width: 800, height: 600)
            )
        }
        
        // Trigger transition if enabled
        if transitionSettings.settings.isEnabled {
            // Hide current image, then show new one with transition
            showImage = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showImage = true
            }
        } else {
            showImage = true
        }
    }
    
    /// Get transition effect for current settings
    private func getTransitionEffect() -> AnyTransition {
        guard transitionSettings.settings.isEnabled else {
            return .identity
        }
        
        return transitionManager?.getTransitionModifier(for: transitionSettings.settings.effectType) ?? .identity
    }
    
    /// Get transition animation for current settings
    private func getTransitionAnimation() -> Animation? {
        guard transitionSettings.settings.isEnabled else {
            return nil
        }
        
        return transitionManager?.getAnimation()
    }
    
    /// Update zoom state with current viewport size and photo context
    private func updateZoomStateWithViewport(_ viewportSize: CGSize) {
        guard let photo = viewModel.currentPhoto,
              case .loaded(let image) = photo.loadState else { return }
        
        let isNewPhoto = photo.id.uuidString != currentPhotoID?.uuidString
        
        photoZoomState.setPhotoContext(
            photoId: photo.id.uuidString,
            photoSize: image.size,
            viewportSize: viewportSize
        )
        
        // Ensure photo fits in window when it's a new photo
        if isNewPhoto {
            photoZoomState.resetZoom(animated: false)
        }
    }
}