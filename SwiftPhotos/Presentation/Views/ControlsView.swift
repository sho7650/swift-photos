import SwiftUI
import AppKit

public struct ControlsView: View {
    var viewModel: ModernSlideshowViewModel
    
    public init(viewModel: ModernSlideshowViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            if let slideshow = viewModel.slideshow, !slideshow.isEmpty {
                slideshowControls(slideshow: slideshow)
            } else {
                welcomeControls
            }
        }
    }
    
    private var welcomeControls: some View {
        VStack(spacing: 24) {
            Button("Select Folder") {
                ProductionLogger.userAction("ControlsView: Select Folder button pressed")
                Task { @MainActor in
                    await viewModel.selectFolder()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            
            if viewModel.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading images...")
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = viewModel.error {
                VStack(spacing: 8) {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
    
    private func slideshowControls(slideshow: Slideshow) -> some View {
        VStack(spacing: 16) {
            progressBar(slideshow: slideshow)
            
            HStack(spacing: 24) {
                Button(action: viewModel.previousPhoto) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    if slideshow.isPlaying {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }) {
                    Image(systemName: slideshow.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: viewModel.nextPhoto) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            photoInfo(slideshow: slideshow)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
    
    private func progressBar(slideshow: Slideshow) -> some View {
        VStack(spacing: 8) {
            // Interactive progress bar with click-to-jump functionality
            InteractiveProgressBar(
                progress: slideshow.progress,
                currentIndex: slideshow.currentIndex,
                totalCount: slideshow.count
            ) { targetIndex in
                ProductionLogger.userAction("ControlsView: Progress bar clicked - jumping to photo \(targetIndex)")
                viewModel.goToPhoto(at: targetIndex)
            }
            .frame(height: 8)  // DOUBLED: from 4 to 8 for better clickability
            
            HStack {
                Text("\(slideshow.currentIndex + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(slideshow.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func photoInfo(slideshow: Slideshow) -> some View {
        VStack(spacing: 4) {
            if let currentPhoto = slideshow.currentPhoto {
                Text(currentPhoto.fileName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let metadata = currentPhoto.metadata {
                    Text("\(metadata.dimensionsString) • \(metadata.fileSizeString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// Interactive progress bar that supports click-to-jump navigation
struct InteractiveProgressBar: View {
    let progress: Double
    let currentIndex: Int
    let totalCount: Int
    let onJumpToIndex: (Int) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)  // DOUBLED: from 4 to 8
                    .cornerRadius(4)   // DOUBLED: from 2 to 4
                
                // Progress fill
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 8)  // DOUBLED: from 4 to 8
                    .cornerRadius(4)   // DOUBLED: from 2 to 4
                    .animation(.easeInOut(duration: 0.2), value: progress)
                
                // Hover indicator
                if isHovering {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 8)  // DOUBLED: from 4 to 8
                        .cornerRadius(4)   // DOUBLED: from 2 to 4
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle()) // Make entire area clickable
            .onTapGesture { location in
                handleTap(at: location, in: geometry)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint, in geometry: GeometryProxy) {
        let relativeX = location.x / geometry.size.width
        let clampedProgress = max(0, min(1, relativeX))
        let targetIndex = Int(clampedProgress * Double(totalCount - 1))
        let validIndex = max(0, min(totalCount - 1, targetIndex))
        
        ProductionLogger.debug("InteractiveProgressBar: Tap at \(location.x)/\(geometry.size.width) (\(clampedProgress*100)%) -> index \(validIndex)")
        
        // Only jump if clicking on a different photo
        if validIndex != currentIndex {
            onJumpToIndex(validIndex)
        }
    }
}

