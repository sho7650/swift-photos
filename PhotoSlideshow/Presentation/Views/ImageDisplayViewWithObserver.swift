import SwiftUI
import AppKit

public struct ImageDisplayViewWithObserver: View {
    @ObservedObject var viewModel: SlideshowViewModel
    @ObservedObject var blurSettings: BlurSettingsManager
    
    public init(viewModel: SlideshowViewModel, blurSettings: BlurSettingsManager) {
        self.viewModel = viewModel
        self.blurSettings = blurSettings
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer with blur/transparency effect
                if let photo = viewModel.currentPhoto,
                   case .loaded(let image) = photo.loadState {
                    BackgroundBlurView(image: image, settings: blurSettings.settings)
                } else {
                    Color.black.ignoresSafeArea()
                }
                
                // Main content layer
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
                            
                            // Image - positioned exactly over black background
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: imageDisplaySize.width,
                                    height: imageDisplaySize.height
                                )
                                .position(
                                    x: imagePosition.x,
                                    y: imagePosition.y
                                )
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
    }
    
    /// Calculate the actual display size of the image, accounting for aspect ratio
    private func calculateImageDisplaySize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        // Use 90% of container size as maximum, leaving margin for better display
        let maxWidth = containerSize.width * 0.9
        let maxHeight = containerSize.height * 0.9
        
        // Calculate aspect ratios
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = maxWidth / maxHeight
        
        let finalSize: CGSize
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container - constrain by width
            let width = maxWidth
            let height = width / imageAspectRatio
            finalSize = CGSize(width: width, height: height)
        } else {
            // Image is taller than container - constrain by height
            let height = maxHeight
            let width = height * imageAspectRatio
            finalSize = CGSize(width: width, height: height)
        }
        
        print("🖼️ ImageDisplayViewWithObserver: Calculated display size: \(finalSize) from image: \(imageSize), container: \(containerSize)")
        return finalSize
    }
    
    /// Calculate the center position for the image within the container
    private func calculateImagePosition(imageSize: CGSize, containerSize: CGSize) -> CGPoint {
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        let position = CGPoint(x: centerX, y: centerY)
        print("🖼️ ImageDisplayViewWithObserver: Calculated position: \(position) for image size: \(imageSize) in container: \(containerSize)")
        return position
    }
}