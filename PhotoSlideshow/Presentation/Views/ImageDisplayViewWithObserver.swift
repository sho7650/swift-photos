import SwiftUI
import AppKit

public struct ImageDisplayViewWithObserver: View {
    @ObservedObject var viewModel: SlideshowViewModel
    
    public init(viewModel: SlideshowViewModel) {
        self.viewModel = viewModel
        print("🔍 ImageDisplayViewWithObserver: Initialized with viewModel")
    }
    
    public var body: some View {
        let _ = Self._printChanges()
        let _ = print("🔍 ImageDisplayViewWithObserver: BODY CALLED")
        let _ = print("🔍 ImageDisplayViewWithObserver: currentPhoto = \(viewModel.currentPhoto?.fileName ?? "nil")")
        let _ = print("🔍 ImageDisplayViewWithObserver: refreshCounter = \(viewModel.refreshCounter)")
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let photo = viewModel.currentPhoto {
                switch photo.loadState {
                case .loaded(let image):
                    let _ = print("🔍 ImageDisplayViewWithObserver: ✅ Displaying loaded photo: \(photo.fileName)")
                    
                    VStack {
                        Text("✅ SUCCESSFULLY DISPLAYING: \(photo.fileName)")
                            .foregroundColor(.green)
                            .font(.title)
                            .padding()
                        
                        DirectNSImageViewWrapper(nsImage: image)
                            .frame(maxWidth: 800, maxHeight: 600)
                            .border(Color.red, width: 3)
                            .id(viewModel.refreshCounter)
                        
                        Text("🔍 Size: \(image.size) | Valid: \(image.isValid)")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                case .loading:
                    VStack {
                        ProgressView()
                        Text("Loading: \(photo.fileName)")
                            .foregroundColor(.white)
                    }
                    
                case .notLoaded:
                    VStack {
                        Text("Not Loaded: \(photo.fileName)")
                            .foregroundColor(.yellow)
                        Text("This should load automatically!")
                            .foregroundColor(.red)
                    }
                    
                case .failed(let error):
                    VStack {
                        Text("Failed: \(photo.fileName)")
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            } else {
                VStack {
                    Text("No Current Photo")
                        .foregroundColor(.gray)
                        .font(.title)
                    Text("Select a folder to start")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}