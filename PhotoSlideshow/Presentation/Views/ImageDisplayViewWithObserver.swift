import SwiftUI
import AppKit

public struct ImageDisplayViewWithObserver: View {
    @ObservedObject var viewModel: SlideshowViewModel
    
    public init(viewModel: SlideshowViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let photo = viewModel.currentPhoto {
                switch photo.loadState {
                case .loaded(let image):
                    DirectNSImageViewWrapper(nsImage: image)
                        .aspectRatio(contentMode: .fit)
                        .id(viewModel.refreshCounter)
                    
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                case .notLoaded:
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                case .failed(let error):
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
            }
        }
    }
}