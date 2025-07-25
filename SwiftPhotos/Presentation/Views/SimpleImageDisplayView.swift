import SwiftUI
import AppKit

public struct SimpleImageDisplayView: View {
    var viewModel: ModernSlideshowViewModel
    var transitionSettings: ModernTransitionSettingsManager
    @State private var transitionManager: ImageTransitionManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    
    public init(viewModel: ModernSlideshowViewModel, transitionSettings: ModernTransitionSettingsManager) {
        self.viewModel = viewModel
        self.transitionSettings = transitionSettings
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Always use solid black background
                Color.black.ignoresSafeArea()
                
                // Main content layer with transition effects
                if let photo = viewModel.currentPhoto {
                    switch photo.loadState {
                    case .loaded(let image):
                        ZStack {
                            // Black background fills entire view
                            Rectangle()
                                .fill(Color.black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            // Image with transition effects (no gesture functionality)
                            if showImage {
                                Image(nsImage: image.nsImage)
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
                        .id(viewModel.refreshCounter)
                    
                    case .loading:
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(2.0)
                                .tint(.white)
                            
                            Text("Loading image...")
                                .font(.title2)
                                .foregroundColor(.white)
                                .opacity(0.8)
                        }
                    
                    case .notLoaded:
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(2.0)
                                .tint(.white)
                            
                            Text("Preparing image...")
                                .font(.title2)
                                .foregroundColor(.white)
                                .opacity(0.8)
                        }
                    
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
        .onChange(of: viewModel.currentPhoto?.id) { newPhotoID in
            handlePhotoChange(newPhotoID: newPhotoID)
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
}