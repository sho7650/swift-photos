import SwiftUI
import AppKit

/// Image display view specifically designed for Repository pattern ViewModels
/// Provides enhanced display capabilities while maintaining compatibility with existing UI
public struct RepositoryImageDisplayView: View {
    var viewModel: any SlideshowViewModelProtocol
    var transitionSettings: ModernTransitionSettingsManager
    var uiControlStateManager: UIControlStateManager? = nil
    @State private var transitionManager: ImageTransitionManager?
    @State private var currentPhotoID: UUID?
    @State private var showImage = true
    @State private var performanceMetrics: [String: Any]?
    
    public init(
        viewModel: any SlideshowViewModelProtocol, 
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
                if let metrics = performanceMetrics, 
                   let monitoringEnabled = metrics["performanceMonitoringEnabled"] as? Bool,
                   monitoringEnabled {
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
                    // Open folder selection (method name may vary)
                    // Task {
                    //     await viewModel.selectFolderAndLoadPhotos()
                    // }
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
                
                if let metrics = performanceMetrics,
                   let repositoryOps = metrics["repositoryOperations"] as? Int {
                    Text("Repository operations: \(repositoryOps)")
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
                    // Retry loading current image
                    // Note: loadCurrentImage is not part of the protocol
                    // This would need to be handled differently
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
                    // Load current image
                    // Note: loadCurrentImage is not part of the protocol
                    // This would need to be handled differently
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
            
            if let metrics = performanceMetrics,
               let totalOps = metrics["totalOperations"] as? Int {
                VStack(spacing: 8) {
                    let isHealthy = (metrics["repositoryHealthy"] as? Bool) ?? false
                    Text("Repository Health: \(isHealthy ? "Healthy" : "Degraded")")
                        .font(.subheadline)
                        .foregroundColor(isHealthy ? .green : .orange)
                    
                    Text("Total Operations: \(totalOps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let usingFallback = (metrics["isUsingLegacyFallback"] as? Bool) ?? false
                    if usingFallback {
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
            
            if let metrics = performanceMetrics,
               let repositoryOps = metrics["repositoryOperations"] as? Int,
               let legacyOps = metrics["legacyOperations"] as? Int {
                VStack(spacing: 8) {
                    Text("Repository Status:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Repository Operations: \(repositoryOps)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Legacy Operations: \(legacyOps)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    let usingFallback = (metrics["isUsingLegacyFallback"] as? Bool) ?? false
                    if usingFallback {
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
                    // Retry loading (method name may vary)
                    // Task {
                    //     await viewModel.selectFolderAndLoadPhotos()
                    // }
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
    
    private func repositoryStatusOverlay(metrics: [String: Any]) -> some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Repository Pattern")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        let isHealthy = (metrics["repositoryHealthy"] as? Bool) ?? false
                        Circle()
                            .fill(isHealthy ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        
                        let repositoryOps = metrics["repositoryOperations"] as? Int ?? 0
                        let totalOps = metrics["totalOperations"] as? Int ?? 0
                        Text("\(repositoryOps)/\(totalOps)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    let usingFallback = (metrics["isUsingLegacyFallback"] as? Bool) ?? false
                    if usingFallback {
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
        // Create placeholder metrics since getPerformanceMetrics is not part of the protocol
        performanceMetrics = [
            "performanceMonitoringEnabled": false,
            "repositoryOperations": 0,
            "totalOperations": 0,
            "legacyOperations": 0,
            "repositoryHealthy": true,
            "isUsingLegacyFallback": false
        ]
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