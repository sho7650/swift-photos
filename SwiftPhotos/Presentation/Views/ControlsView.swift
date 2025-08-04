import SwiftUI
import AppKit

public struct ControlsView: View {
    var viewModel: any SlideshowViewModelProtocol
    @Environment(\.localizationService) private var localizationService
    
    public init(viewModel: any SlideshowViewModelProtocol) {
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
                Button(action: {
                    Task {
                        await viewModel.previousPhoto()
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
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
                .buttonStyle(.plain)
                
                Button(action: {
                    Task {
                        await viewModel.nextPhoto()
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
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
            UnifiedProgressBar(
                progress: slideshow.progress,
                currentIndex: slideshow.currentIndex,
                totalCount: slideshow.count,
                style: .standard
            ) { targetIndex in
                ProductionLogger.userAction("ControlsView: Progress bar clicked - jumping to photo \(targetIndex)")
                Task {
                    // Jump directly to target photo using the new direct navigation method
                    await viewModel.jumpToPhoto(at: targetIndex)
                }
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

// Note: InteractiveProgressBar has been replaced by UnifiedProgressBar with .standard style

