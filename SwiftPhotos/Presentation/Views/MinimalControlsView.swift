import SwiftUI
import AppKit
import Combine

/// Minimal, compact controls overlay positioned at bottom-center with blur background
public struct MinimalControlsView: View {
    var viewModel: any SlideshowViewModelProtocol
    @ObservedObject var uiInteractionManager: UIInteractionManager
    var uiControlSettings: ModernUIControlSettingsManager
    var localizationService: LocalizationService?
    
    @State private var isHovering = false
    @State private var languageUpdateTrigger = 0
    
    public init(
        viewModel: any SlideshowViewModelProtocol,
        uiInteractionManager: UIInteractionManager,
        uiControlSettings: ModernUIControlSettingsManager,
        localizationService: LocalizationService?
    ) {
        self.viewModel = viewModel
        self.uiInteractionManager = uiInteractionManager
        self.uiControlSettings = uiControlSettings
        self.localizationService = localizationService
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            if let slideshow = viewModel.slideshow, !slideshow.isEmpty {
                if uiInteractionManager.isControlsVisible {
                    controlsOverlay(slideshow: slideshow)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                // Welcome state - folder selection
                if uiInteractionManager.isControlsVisible {
                    welcomeControls
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration), value: uiInteractionManager.isControlsVisible)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            languageUpdateTrigger += 1
            ProductionLogger.debug("MinimalControlsView: Received language change notification, trigger: \(languageUpdateTrigger)")
        }
        .onChange(of: localizationService?.currentLanguage) { oldValue, newValue in
            languageUpdateTrigger += 1
            ProductionLogger.debug("MinimalControlsView: Language changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil"), trigger: \(languageUpdateTrigger)")
        }
        .onChange(of: viewModel.slideshow) { oldValue, newValue in
            ProductionLogger.debug("MinimalControlsView: Slideshow changed - old: \(oldValue?.count ?? -1) photos, new: \(newValue?.count ?? -1) photos")
            if let newSlideshow = newValue {
                ProductionLogger.debug("MinimalControlsView: New slideshow - currentIndex: \(newSlideshow.currentIndex), count: \(newSlideshow.count), isEmpty: \(newSlideshow.isEmpty)")
            }
        }
        .id(languageUpdateTrigger) // Force view refresh when language changes
    }
    
    private var welcomeControls: some View {
        VStack(spacing: 16) {
            Button("Select Folder") {
                ProductionLogger.userAction("MinimalControlsView: Select Folder button pressed")
                uiInteractionManager.handleUserInteraction()
                Task {
                    await viewModel.selectFolder()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(
            BlurredBackground(
                intensity: uiControlSettings.settings.backgroundBlurIntensity,
                opacity: uiControlSettings.settings.backgroundOpacity
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, uiControlSettings.settings.bottomOffset)
        .onTapGesture {
            uiInteractionManager.handleUserInteraction()
        }
    }
    
    private func controlsOverlay(slideshow: Slideshow) -> some View {
        VStack(spacing: 8) {
            // Compact progress indicator
            if isHovering || uiInteractionManager.isDetailedInfoVisible {
                compactProgressBar(slideshow: slideshow)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Main control buttons
            HStack(spacing: 20) {
                // Previous button
                ControlButton(
                    systemName: "chevron.left.circle.fill",
                    size: .medium,
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        Task {
                            await viewModel.previousPhoto()
                        }
                    }
                )
                .shortcutTooltip("Previous", shortcut: "←")
                
                // Play/Pause button (larger)
                ControlButton(
                    systemName: slideshow.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                    size: .large,
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        if slideshow.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play()
                        }
                    }
                )
                .shortcutTooltip(slideshow.isPlaying ? "Pause" : "Play", shortcut: "Space")
                
                // Next button
                ControlButton(
                    systemName: "chevron.right.circle.fill",
                    size: .medium,
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        Task {
                            await viewModel.nextPhoto()
                        }
                    }
                )
                .shortcutTooltip("Next", shortcut: "→")
            }
            
            // Photo counter (minimal)
            if isHovering || uiInteractionManager.isDetailedInfoVisible {
                Text("\(slideshow.currentIndex + 1) / \(slideshow.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            BlurredBackground(
                intensity: uiControlSettings.settings.backgroundBlurIntensity,
                opacity: uiControlSettings.settings.backgroundOpacity
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, uiControlSettings.settings.bottomOffset)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
            if hovering {
                uiInteractionManager.handleMouseInteraction(at: .zero)
            }
        }
        .onTapGesture {
            uiInteractionManager.toggleDetailedInfo()
        }
        .shortcutTooltip("Tap for info", shortcut: "I")
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: uiInteractionManager.isDetailedInfoVisible)
    }
    
    private func compactProgressBar(slideshow: Slideshow) -> some View {
        VStack(spacing: 4) {
            // Compact interactive progress bar
            UnifiedProgressBar(
                progress: slideshow.progress,
                currentIndex: slideshow.currentIndex,
                totalCount: slideshow.count,
                style: .compact
            ) { targetIndex in
                ProductionLogger.userAction("MinimalControlsView: Progress bar clicked - jumping to photo \(targetIndex)")
                uiInteractionManager.handleUserInteraction()
                // Use standard navigation method available in protocol
                Task {
                    // Jump directly to target photo using the new direct navigation method
                    await viewModel.jumpToPhoto(at: targetIndex)
                }
            }
            .frame(height: 4)
        }
        .frame(width: 200)
    }
}

/// Reusable control button with consistent styling
private struct ControlButton: View {
    enum Size {
        case small, medium, large
        
        var fontSize: Font {
            switch self {
            case .small: return .title3
            case .medium: return .title2
            case .large: return .largeTitle
            }
        }
    }
    
    let systemName: String
    let size: Size
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(size.fontSize)
                .foregroundColor(.white)
                .opacity(isPressed ? 0.6 : 1.0)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Note: CompactProgressBar has been replaced by UnifiedProgressBar with .compact style

/// Blurred background component with configurable intensity and opacity
private struct BlurredBackground: View {
    let intensity: Double
    let opacity: Double
    
    var body: some View {
        ZStack {
            // Base material with blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(intensity)
            
            // Additional opacity layer
            Rectangle()
                .fill(Color.black.opacity(opacity))
        }
    }
}