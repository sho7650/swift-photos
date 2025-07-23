import SwiftUI
import AppKit

public struct ImageDisplayView: View {
    let photo: Photo?
    let refreshCounter: Int
    @State private var showMetadata = false
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScaleValue: CGFloat = 1.0
    
    public init(photo: Photo?, refreshCounter: Int = 0) {
        self.photo = photo
        self.refreshCounter = refreshCounter
    }
    
    public var body: some View {
        let _ = Self._printChanges()
        let _ = print("🖼️ ImageDisplayView: BODY CALLED - photo: \(photo?.fileName ?? "nil"), refreshCounter: \(refreshCounter)")
        
        return ZStack {
            Color.black
                .ignoresSafeArea()
            
            Group {
                if let photo = photo {
                    let _ = print("🖼️ ImageDisplayView: Photo found - filename: \(photo.fileName), loadState: \(photo.loadState)")
                    switch photo.loadState {
                    case .notLoaded:
                        let _ = print("🖼️ ImageDisplayView: ❌ Photo not loaded - showing loading view for \(photo.fileName)")
                        loadingView
                        
                    case .loading:
                        let _ = print("🖼️ ImageDisplayView: ⏳ Photo loading - showing loading view for \(photo.fileName)")
                        loadingView
                        
                    case .loaded(let image):
                        let _ = print("🖼️ ImageDisplayView: ✅ Photo loaded for \(photo.fileName)")
                        let _ = print("🖼️ ImageDisplayView: NSImage details - size: \(image.size), representations: \(image.representations.count)")
                        let _ = print("🖼️ ImageDisplayView: NSImage.isValid: \(image.isValid)")
                        
                        VStack {
                            Text("✅ SHOULD DISPLAY: \(photo.fileName) | Refresh: \(refreshCounter)")
                                .foregroundColor(.green)
                                .font(.title)
                                .padding()
                            
                            // TEST: Use NSImageView directly instead of SwiftUI Image conversion
                            DirectNSImageViewWrapper(nsImage: image)
                                .frame(maxWidth: 800, maxHeight: 600)
                                .id(refreshCounter)
                                .border(Color.red, width: 3) // Red border to see if view exists
                            
                            // Show debug info
                            Text("🔍 Image: \(photo.fileName) | Size: \(image.size) | Valid: \(image.isValid)")
                                .foregroundColor(.white)
                                .font(.caption)
                                .padding()
                        }
                        
                    case .failed(let error):
                        let _ = print("🖼️ ImageDisplayView: ❌ Photo failed for \(photo.fileName): \(error)")
                        errorView(error: error)
                    }
                } else {
                    let _ = print("🖼️ ImageDisplayView: ⚠️ No photo available, showing empty view")
                    emptyView
                }
            }
            
            if showMetadata, let photo = photo, let metadata = photo.metadata {
                metadataOverlay(photo: photo, metadata: metadata)
            }
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if scale > 1.0 {
                    scale = 1.0
                    offset = .zero
                } else {
                    scale = 2.0
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showMetadata.toggle()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading...")
                .foregroundColor(.white)
                .font(.title2)
        }
    }
    
    private func imageView(image: NSImage) -> some View {
        let _ = print("🖼️ ImageDisplayView.imageView: Called with NSImage size: \(image.size)")
        let _ = print("🖼️ ImageDisplayView.imageView: image.isValid = \(image.isValid)")
        
        // Log representation details outside of ViewBuilder
        if !image.isValid {
            print("🖼️ ImageDisplayView.imageView: ❌ Image is NOT valid, showing error")
            print("🖼️ ImageDisplayView.imageView: NSImage representations count: \(image.representations.count)")
            for (index, rep) in image.representations.enumerated() {
                print("🖼️ ImageDisplayView.imageView: Rep[\(index)]: \(type(of: rep)), size: \(rep.size), hasAlpha: \(rep.hasAlpha)")
            }
        }
        
        return Group {
            if image.isValid {
                let _ = print("🖼️ ImageDisplayView.imageView: ✅ Image is valid, creating SwiftUI Image")
                let swiftUIImage = Image(nsImage: image)
                let _ = print("🖼️ ImageDisplayView.imageView: ✅ SwiftUI Image created successfully")
                swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
            } else {
                let _ = print("🖼️ ImageDisplayView.imageView: ❌ Showing error view")
                errorView(error: SlideshowError.loadingFailed(underlying: NSError(domain: "InvalidImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])))
            }
        }
        .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScaleValue
                            lastScaleValue = value
                            scale *= delta
                            scale = min(max(scale, 0.5), 5.0)
                        }
                        .onEnded { _ in
                            lastScaleValue = 1.0
                            if scale < 1.0 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                        },
                    
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = value.translation
                            }
                        }
                        .onEnded { _ in
                            if scale <= 1.0 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset = .zero
                                }
                            }
                        }
                )
            )
    }
    
    private func errorView(error: SlideshowError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error Loading Image")
                .foregroundColor(.white)
                .font(.title2)
            
            Text(error.localizedDescription)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Select a folder to start slideshow")
                .foregroundColor(.gray)
                .font(.title2)
        }
    }
    
    private func metadataOverlay(photo: Photo, metadata: Photo.PhotoMetadata) -> some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.fileName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(metadata.dimensionsString)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(metadata.fileSizeString)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let creationDate = metadata.creationDate {
                        Text(DateFormatter.slideshow.string(from: creationDate))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
        }
    }
}

/// Simple NSImageView wrapper to bypass SwiftUI Image conversion
struct DirectNSImageViewWrapper: NSViewRepresentable {
    let nsImage: NSImage
    let targetSize: CGSize?
    
    init(nsImage: NSImage, targetSize: CGSize? = nil) {
        self.nsImage = nsImage
        self.targetSize = targetSize
    }
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown  // Changed to scaleProportionallyDown for better control
        imageView.imageAlignment = .alignCenter
        imageView.image = nsImage
        imageView.wantsLayer = true
        
        // Simple opacity settings without problematic configurations
        imageView.alphaValue = 1.0
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        imageView.layer?.masksToBounds = true
        
        print("🖼️ DirectNSImageViewWrapper: Created - image size: \(nsImage.size), target: \(targetSize?.debugDescription ?? "nil")")
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = nsImage
        nsView.alphaValue = 1.0
        
        // Apply target size constraints if provided
        if let targetSize = targetSize {
            nsView.frame.size = targetSize
        }
        
        print("🖼️ DirectNSImageViewWrapper: Updated - image size: \(nsImage.size), target: \(targetSize?.debugDescription ?? "nil")")
    }
}

extension DateFormatter {
    static let slideshow: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}