import SwiftUI
import AppKit
import os.log

/// Unified image display view that combines all functionality from previous implementations
/// Supports debug mode, performance metrics, viewport tracking, and transitions
public struct UnifiedImageDisplayView: View {
    // MARK: - Properties
    
    var viewModel: any SlideshowViewModelProtocol
    var transitionSettings: ModernTransitionSettingsManager
    var uiInteractionManager: UIInteractionManager? = nil
    
    // Configuration options
    var enableDebugMode: Bool = false
    var enableViewportTracking: Bool = false
    var enablePerformanceMetrics: Bool = false
    var enableAdvancedGestures: Bool = true
    
    // MARK: - State
    
    @State private var visualEffectsManager: VisualEffectsManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    @State private var viewportSize: CGSize = .zero
    @State private var performanceMetrics: [String: Any]?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var gestureManager: GestureNavigationManager?

    
    @Environment(\.localizationService) private var localizationService
    
    // MARK: - Initialization
    
    public init(
        viewModel: any SlideshowViewModelProtocol,
        transitionSettings: ModernTransitionSettingsManager,
        uiInteractionManager: UIInteractionManager? = nil,
        enableDebugMode: Bool = false,
        enableViewportTracking: Bool = false,
        enablePerformanceMetrics: Bool = false,
        enableAdvancedGestures: Bool = true
    ) {
        self.viewModel = viewModel
        self.transitionSettings = transitionSettings
        self.uiInteractionManager = uiInteractionManager
        self.enableDebugMode = enableDebugMode
        self.enableViewportTracking = enableViewportTracking
        self.enablePerformanceMetrics = enablePerformanceMetrics
        self.enableAdvancedGestures = enableAdvancedGestures
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Viewport tracking (if enabled)
                if enableViewportTracking {
                    Color.clear
                        .onAppear {
                            viewportSize = geometry.size
                            if enableDebugMode {
                                ProductionLogger.debug("UnifiedImageDisplay: Viewport size: \(geometry.size)")
                            }
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            viewportSize = newSize
                            if enableDebugMode {
                                ProductionLogger.debug("UnifiedImageDisplay: Viewport size changed: \(newSize)")
                            }
                        }
                }
                
                // Main content
                mainImageContent(geometry: geometry)
                
                // Performance metrics overlay (if enabled)
                if enablePerformanceMetrics, let metrics = performanceMetrics {
                    performanceOverlay(metrics: metrics)
                }
            }
        }
        .onAppear {
            setupVisualEffectsManager()
            if enableAdvancedGestures {
                setupAdvancedGestures()
            }
        }
        .onChange(of: transitionSettings.settings) { _, _ in
            setupVisualEffectsManager()
        }
        .onChange(of: viewModel.currentPhoto?.id) { oldValue, newValue in
            handlePhotoChange(from: oldValue, to: newValue)
        }
        .onChange(of: viewModel.refreshCounter) { _, _ in
            // Force view refresh when refreshCounter changes
        }
        .onChange(of: viewModel.slideshow?.currentPhoto?.loadState) { _, _ in
            // Force view refresh when photo load state changes
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private func mainImageContent(geometry: GeometryProxy) -> some View {
        if let slideshow = viewModel.slideshow,
           let photo = slideshow.currentPhoto {
            // Force view refresh by including refreshCounter in the view state
            let _ = viewModel.refreshCounter
            
            switch photo.loadState {
            case .loaded(let image):
                loadedImageView(image: image, photo: photo, geometry: geometry)
                
            case .loading:
                loadingView
                
            case .notLoaded:
                if enableDebugMode {
                    debugNotLoadedView(photo: photo)
                } else {
                    loadingView
                }
                
            case .failed:
                errorView
            }
        } else {
            emptyView
        }
    }
    
    @ViewBuilder
    private func loadedImageView(image: SendableImage, photo: Photo, geometry: GeometryProxy) -> some View {
        ZStack {
            // Black background
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Debug mode header
            if enableDebugMode {
                VStack {
                    Text("✅ DISPLAYING: \(photo.fileName)")
                        .foregroundColor(.green)
                        .font(.title)
                        .padding()
                    Spacer()
                }
            }
            
            // Main image with transitions
            Image(nsImage: image.nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .center
                )
                .clipped()
                .scaleEffect(scale)
                .offset(offset)
                .transition(getTransitionEffect())
                .onHover { hovering in
                    if hovering {
                        uiInteractionManager?.handleMouseInteraction(at: CGPoint.zero)
                    } else {
                        // Mouse exited - no specific action needed for UIInteractionManager
                    }
                }
                .id(currentPhotoID ?? photo.id)
                .animation(getTransitionAnimation(), value: currentPhotoID)
                .onTapGesture(count: 2) {
                    if enableAdvancedGestures {
                        handleAdvancedDoubleTap(at: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2))
                    } else {
                        resetZoom()
                    }
                }
                .gesture(
                    enableAdvancedGestures ? createAdvancedGestureModifier(geometry: geometry) : AnyGesture(TapGesture().map { _ in })
                )
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading...")
                .foregroundColor(.white)
                .font(.headline)
        }
    }
    
    @ViewBuilder
    private func debugNotLoadedView(photo: Photo) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Not Loaded: \(photo.fileName)")
                .foregroundColor(.white)
                .font(.headline)
            
            Button("Load Image") {
                // Note: Direct loading not available through protocol
                // This would need to be handled by the ViewModel
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Failed to load image")
                .foregroundColor(.white)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Photos")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Select a folder to start slideshow")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private func performanceOverlay(metrics: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.white)
            
            if let totalOps = metrics["totalOperations"] as? Int {
                Text("Total Operations: \(totalOps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let cacheHits = metrics["cacheHits"] as? Int,
               let cacheMisses = metrics["cacheMisses"] as? Int {
                let hitRate = cacheHits + cacheMisses > 0 
                    ? Double(cacheHits) / Double(cacheHits + cacheMisses) * 100 
                    : 0
                Text("Cache Hit Rate: \(String(format: "%.1f%%", hitRate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func setupVisualEffectsManager() {
        visualEffectsManager = VisualEffectsManager(
            transitionSettings: transitionSettings,
            uiControlSettings: ModernUIControlSettingsManager()
        )
    }
    
    private func getTransitionEffect() -> AnyTransition {
        guard transitionSettings.settings.isEnabled else {
            return .identity
        }
        
        return visualEffectsManager?.imageTransition() ?? .identity
    }
    
    private func handlePhotoChange(from oldID: UUID?, to newID: UUID?) {
        guard oldID != nil, newID != nil, oldID != newID else { return }
        
        ProductionLogger.debug("🎨 UnifiedImageDisplayView: Photo change detected - applying transition")
        ProductionLogger.debug("🎨 Transition enabled: \(self.transitionSettings.settings.isEnabled), type: \(self.transitionSettings.settings.effectType), duration: \(self.transitionSettings.settings.duration)")
        
        // Simply update the photo ID - let SwiftUI handle the transition
        withAnimation(getTransitionAnimation()) {
            currentPhotoID = newID
        }
    }
    
    private func resetZoom() {
        if enableAdvancedGestures {
            gestureManager?.resetZoom()
        } else {
            withAnimation(.spring()) {
                scale = 1.0
                offset = .zero
            }
        }
    }
    
    private func getTransitionAnimation() -> Animation {
        guard transitionSettings.settings.isEnabled else {
            return .linear(duration: 0)
        }
        
        let duration = transitionSettings.settings.duration
        
        switch transitionSettings.settings.easing {
        case .linear:
            return .linear(duration: duration)
        case .easeIn:
            return .easeIn(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .easeInOut:
            return .easeInOut(duration: duration)
        case .spring:
            return .spring(response: duration, dampingFraction: 0.8)
        }
    }
    
    // MARK: - Advanced Gesture Methods
    
    private func setupAdvancedGestures() {
        // Create GestureNavigationManager with dependencies
        gestureManager = GestureNavigationManager(
            slideshowViewModel: viewModel,
            gestureSettings: ModernGestureSettingsManager()
        )
        
        if enableDebugMode {
            ProductionLogger.debug("UnifiedImageDisplay: Gesture navigation system initialized")
        }
    }
    
    private func createAdvancedGestureModifier(geometry: GeometryProxy) -> AnyGesture<Void> {
        guard let gestureManager = gestureManager else { 
            return AnyGesture(TapGesture().map { _ in })
        }
        
        return AnyGesture(
            SimultaneousGesture(
                gestureManager.createPinchGesture(),
                gestureManager.createPanGesture()
            ).map { _ in }
        )
    }
    
    private func handleAdvancedDoubleTap(at location: CGPoint) {
        // GestureNavigationManager handles double tap internally via gesture creation
        // For manual double tap handling, we can call resetZoom or toggle zoom
        gestureManager?.resetZoom()
    }
}

// MARK: - Preview Provider

struct UnifiedImageDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedImageDisplayView(
            viewModel: PreviewSlideshowViewModel(),
            transitionSettings: ModernTransitionSettingsManager(),
            enableDebugMode: true,
            enablePerformanceMetrics: true
        )
    }
}

// MARK: - Preview Helper

private class PreviewSlideshowViewModel: SlideshowViewModelProtocol {
    var slideshow: Slideshow? = nil
    var currentPhoto: Photo? = nil
    var isPlaying: Bool = false
    var windowLevel: WindowLevel = .normal
    var isLoading: Bool = false
    var error: SlideshowError? = nil
    var selectedFolderURL: URL? = nil
    var loadingState: LoadingState = .notLoading
    var refreshCounter: Int = 0
    
    // Performance tracking properties
    var stats: UnifiedPerformanceStats? = nil
    var canNavigateNext: Bool = false
    var canNavigatePrevious: Bool = false
    var progress: Double = 0.0
    var folderSelectionState: FolderSelectionState = .idle
    var loadingProgress: Double = 0.0
    var estimatedTimeRemaining: TimeInterval? = nil
    var processedPhotoCount: Int = 0
    var totalPhotoCount: Int = 0
    var isGlobalSlideshow: Bool = false
    
    func selectFolder() async {}
    func play() {}
    func pause() {}
    func stop() {}
    func nextPhoto() async {}
    func previousPhoto() async {}
    func jumpToPhoto(at index: Int) async {}
    func clearError() {}
    func setSlideshow(_ slideshow: Slideshow) {}
}