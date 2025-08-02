import SwiftUI
import AppKit

/// Image display view specifically designed for Repository pattern ViewModels
/// Provides enhanced display capabilities while maintaining compatibility with existing UI
public struct RepositoryImageDisplayView: View {
    var viewModel: EnhancedModernSlideshowViewModel
    var transitionSettings: ModernTransitionSettingsManager
    var uiControlStateManager: UIControlStateManager? = nil
    @State private var transitionManager: ImageTransitionManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    @State private var performanceMetrics: EnhancedViewModelMetrics?
    
    public init(
        viewModel: EnhancedModernSlideshowViewModel, 
        transitionSettings: ModernTransitionSettingsManager, 
        uiControlStateManager: UIControlStateManager? = nil
    ) {
        self.viewModel = viewModel
        self.transitionSettings = transitionSettings
        self.uiControlStateManager = uiControlStateManager
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Main image content
                mainImageContent(geometry: geometry)
                
                // Repository status overlay (debug mode)
                if let metrics = performanceMetrics, metrics.performanceMonitoringEnabled {
                    repositoryStatusOverlay(metrics: metrics)
                }
            }
        }
        .onAppear {
            setupTransitionManager()
            updatePerformanceMetrics()
        }
        .onChange(of: transitionSettings.settings) { _, _ in
            setupTransitionManager()
        }
        .task {
            // Update performance metrics periodically
            await updateMetricsPeriodically()
        }
    }
    
    @ViewBuilder
    private func mainImageContent(geometry: GeometryProxy) -> some View {
        if let slideshow = viewModel.slideshow,
           let currentPhoto = viewModel.currentPhoto {
            
            // Repository-aware image display
            repositoryImageView(
                photo: currentPhoto,
                slideshow: slideshow,
                geometry: geometry
            )
            .id(currentPhoto.id)
            .animation(.default, value: currentPhoto.id)
            
        } else if viewModel.isLoading {
            // Enhanced loading state with Repository info
            repositoryLoadingView()
            
        } else if let error = viewModel.error {
            // Repository-aware error display
            repositoryErrorView(error: error)
            
        } else {
            // Empty state
            ContentUnavailableView(
                "No Photos Loaded",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Select a folder to start slideshow with Repository pattern")
            )
            .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private func repositoryImageView(
        photo: Photo,
        slideshow: Slideshow,
        geometry: GeometryProxy
    ) -> some View {
        
        switch photo.loadState {
        case .loaded(let sendableImage):
            Image(nsImage: sendableImage.nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    Task {
                        await viewModel.selectFolderAndLoadPhotos()
                    }
                }
                .onAppear {
                    // Update photo ID tracking
                    if currentPhotoID != photo.id {
                        currentPhotoID = photo.id
                        showImage = true
                    }
                }
            
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("Loading with Repository pattern...")
                    .foregroundColor(.white)
                    .font(.headline)
                
                if let metrics = performanceMetrics {
                    Text("Repository operations: \(metrics.repositoryOperations)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        case .failed(let error):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("Repository Loading Failed")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Retry") {
                    Task {
                        await viewModel.loadCurrentImage()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(40)
            
        case .notLoaded:
            VStack(spacing: 16) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Repository: Image Not Loaded")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Load Image") {
                    Task {
                        await viewModel.loadCurrentImage()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private func repositoryLoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Repository Pattern Loading...")
                .font(.title2)
                .foregroundColor(.white)
            
            if let metrics = performanceMetrics {
                VStack(spacing: 8) {
                    Text("Repository Health: \(metrics.repositoryHealth.isHealthy ? "Healthy" : "Degraded")")
                        .font(.subheadline)
                        .foregroundColor(metrics.repositoryHealth.isHealthy ? .green : .orange)
                    
                    Text("Total Operations: \(metrics.totalOperations)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if metrics.isUsingLegacyFallback {
                        Text("Using legacy fallback")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
            }
        }
    }
    
    private func repositoryErrorView(error: SlideshowError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Repository Error")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let metrics = performanceMetrics {
                VStack(spacing: 8) {
                    Text("Repository Status:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Repository Operations: \(metrics.repositoryOperations)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Legacy Operations: \(metrics.legacyOperations)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if metrics.isUsingLegacyFallback {
                        Text("Currently using legacy fallback")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
            }
            
            HStack(spacing: 16) {
                Button("Retry") {
                    Task {
                        await viewModel.selectFolderAndLoadPhotos()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Clear Error") {
                    // Would need to expose clearError on protocol
                    // viewModel.clearError()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }
    
    private func repositoryStatusOverlay(metrics: EnhancedViewModelMetrics) -> some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Repository Pattern")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(metrics.repositoryHealth.isHealthy ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("\(metrics.repositoryOperations)/\(metrics.totalOperations)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if metrics.isUsingLegacyFallback {
                        Text("Fallback Active")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupTransitionManager() {
        transitionManager = ImageTransitionManager(transitionSettings: transitionSettings)
    }
    
    private func updatePerformanceMetrics() {
        Task {
            performanceMetrics = await viewModel.getPerformanceMetrics()
        }
    }
    
    private func updateMetricsPeriodically() async {
        while !Task.isCancelled {
            updatePerformanceMetrics()
            try? await Task.sleep(for: .seconds(5))
        }
    }
}

// MARK: - Preview

#Preview {
    // Simplified preview without async initialization
    Color.black
        .frame(width: 800, height: 600)
        .overlay(
            Text("Repository Image Display View Preview")
                .foregroundColor(.white)
        )
}