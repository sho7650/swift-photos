import SwiftUI
import AppKit

public struct ImageDisplayViewWithObserver: View {
    @ObservedObject var viewModel: SlideshowViewModel
    @EnvironmentObject var transitionSettings: TransitionSettingsManager
    @State private var transitionManager: ImageTransitionManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    @State private var viewportSize: CGSize = .zero
    
    public init(
        viewModel: SlideshowViewModel
    ) {
        self.viewModel = viewModel
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
                        // Disable all zoom state updates - use fixed scaling
                        ProductionLogger.debug("ImageDisplay: Viewport size: \(geometry.size)")
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        viewportSize = newSize
                        // Disable all zoom state updates - use fixed scaling
                        ProductionLogger.debug("ImageDisplay: Viewport size changed: \(newSize)")
                    }
                
                // Main content layer with transition effects
                if let photo = viewModel.currentPhoto {
                    switch photo.loadState {
                    case .loaded(let image):
                        ZStack {
                            // Black background fills entire view
                            Rectangle()
                                .fill(Color.black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            // Image with transition effects (simplified - no gesture conflicts)
                            if showImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(
                                        width: geometry.size.width,
                                        height: geometry.size.height,
                                        alignment: .center
                                    )
                                    .clipped()
                                    .transition(getTransitionEffect())
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
            // Disable zoom state updates - use fixed scaling
            ProductionLogger.debug("ImageDisplay: Photo changed: \(newPhotoID?.uuidString ?? "nil")")
        }
        .animation(getTransitionAnimation(), value: showImage)
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
        
        // Disable zoom state updates - images use fixed scaling
        ProductionLogger.debug("handlePhotoChange: New photo loaded: \(newID.uuidString)")
        
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
    
    // Zoom functionality removed - no longer needed
}