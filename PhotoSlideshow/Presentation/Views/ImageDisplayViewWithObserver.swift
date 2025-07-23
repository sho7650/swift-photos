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
                        Group {
                            if blurSettings.settings.isEnabled {
                                // When blur is enabled, show image in center with padding
                                VStack {
                                    Spacer()
                                    
                                    HStack {
                                        Spacer()
                                        
                                        // Main image in center
                                        DirectNSImageViewWrapper(nsImage: image)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(
                                                maxWidth: geometry.size.width * 0.7,
                                                maxHeight: geometry.size.height * 0.7
                                            )
                                        
                                        Spacer()
                                    }
                                    
                                    Spacer()
                                }
                            } else {
                                // When blur is disabled, show image full screen
                                DirectNSImageViewWrapper(nsImage: image)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
}