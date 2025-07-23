import SwiftUI
import AppKit

public struct ControlsView: View {
    @ObservedObject var viewModel: SlideshowViewModel
    
    public init(viewModel: SlideshowViewModel) {
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
                print("🎮 ControlsView: Select Folder button pressed")
                Task { @MainActor in
                    do {
                        await viewModel.selectFolder()
                    } catch {
                        print("❌ ControlsView: Error in selectFolder task: \(error)")
                    }
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
            ProgressView(value: slideshow.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 4)
            
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

