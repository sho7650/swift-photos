import SwiftUI
import AppKit
import os.log

/// Unified image display view that combines all functionality from previous implementations
/// Supports debug mode, performance metrics, viewport tracking, and transitions
public struct UnifiedImageDisplayView: View {
    // MARK: - Properties
    
    var viewModel: any SlideshowViewModelProtocol
    var transitionSettings: ModernTransitionSettingsManager
    var uiControlStateManager: UIControlStateManager? = nil
    
    // Configuration options
    var enableDebugMode: Bool = false
    var enableViewportTracking: Bool = false
    var enablePerformanceMetrics: Bool = false
    
    // MARK: - State
    
    @State private var transitionManager: ImageTransitionManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    @State private var viewportSize: CGSize = .zero
    @State private var performanceMetrics: [String: Any]?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    @Environment(\.localizationService) private var localizationService
    
    // MARK: - Initialization
    
    public init(
        viewModel: any SlideshowViewModelProtocol,
        transitionSettings: ModernTransitionSettingsManager,
        uiControlStateManager: UIControlStateManager? = nil,
        enableDebugMode: Bool = false,
        enableViewportTracking: Bool = false,
        enablePerformanceMetrics: Bool = false
    ) {
        self.viewModel = viewModel
        self.transitionSettings = transitionSettings
        self.uiControlStateManager = uiControlStateManager
        self.enableDebugMode = enableDebugMode
        self.enableViewportTracking = enableViewportTracking
        self.enablePerformanceMetrics = enablePerformanceMetrics
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
            setupTransitionManager()
        }
        .onChange(of: transitionSettings.settings) { _, _ in
            setupTransitionManager()
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
                    .scaleEffect(scale)
                    .offset(offset)
                    .transition(getTransitionEffect())
                    .onHover { hovering in
                        if hovering {
                            uiControlStateManager?.handleMouseEnteredImage()
                        } else {
                            uiControlStateManager?.handleMouseExitedImage()
                        }
                    }
                    .id(photo.id)
                    .onTapGesture(count: 2) {
                        resetZoom()
                    }
            }
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
            .buttonStyle(.borderedProminent)
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
    
    private func setupTransitionManager() {
        transitionManager = ImageTransitionManager(transitionSettings: transitionSettings)
    }
    
    private func getTransitionEffect() -> AnyTransition {
        guard transitionSettings.settings.isEnabled else {
            return .identity
        }
        
        return transitionManager?.getTransitionModifier(for: transitionSettings.settings.effectType) ?? .identity
    }
    
    private func handlePhotoChange(from oldID: UUID?, to newID: UUID?) {
        guard oldID != nil, newID != nil, oldID != newID else { return }
        
        if transitionManager != nil {
            showImage = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                currentPhotoID = newID
                showImage = true
            }
        } else {
            currentPhotoID = newID
        }
    }
    
    private func resetZoom() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
        }
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