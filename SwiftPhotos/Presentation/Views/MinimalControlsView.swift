import SwiftUI
import AppKit
import Combine

/// Minimal, compact controls overlay positioned at bottom-center with blur background
public struct MinimalControlsView: View {
    var viewModel: ModernSlideshowViewModel
    @ObservedObject var uiControlStateManager: UIControlStateManager
    var uiControlSettings: ModernUIControlSettingsManager
    var localizationService: LocalizationService?
    
    @State private var isHovering = false
    @State private var languageUpdateTrigger = 0
    
    public init(
        viewModel: ModernSlideshowViewModel,
        uiControlStateManager: UIControlStateManager,
        uiControlSettings: ModernUIControlSettingsManager,
        localizationService: LocalizationService?
    ) {
        self.viewModel = viewModel
        self.uiControlStateManager = uiControlStateManager
        self.uiControlSettings = uiControlSettings
        self.localizationService = localizationService
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            if let slideshow = viewModel.slideshow, !slideshow.isEmpty {
                if uiControlStateManager.isControlsVisible {
                    controlsOverlay(slideshow: slideshow)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            ProductionLogger.debug("MinimalControlsView: Controls shown with slideshow - isEmpty: \(slideshow.isEmpty), currentIndex: \(slideshow.currentIndex), count: \(slideshow.count)")
                        }
                }
            } else {
                // Welcome state - folder selection
                if uiControlStateManager.isControlsVisible {
                    welcomeControls
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration), value: uiControlStateManager.isControlsVisible)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            languageUpdateTrigger += 1
            ProductionLogger.debug("MinimalControlsView: Received language change notification, trigger: \(languageUpdateTrigger)")
        }
        .onChange(of: localizationService?.currentLanguage) { oldValue, newValue in
            languageUpdateTrigger += 1
            ProductionLogger.debug("MinimalControlsView: Language changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil"), trigger: \(languageUpdateTrigger)")
        }
        .id(languageUpdateTrigger) // Force view recreation when language changes
    }
    
    private var welcomeControls: some View {
        VStack(spacing: 16) {
            Button(localizationService?.localizedString(for: "button.select_folder") ?? "Select Folder") {
                ProductionLogger.userAction("MinimalControlsView: Select Folder button pressed")
                uiControlStateManager.handleGestureInteraction()
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
                    Text(localizationService?.localizedString(for: "loading.loading_short") ?? "Loading...")
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
            uiControlStateManager.handleGestureInteraction()
        }
    }
    
    private func controlsOverlay(slideshow: Slideshow) -> some View {
        VStack(spacing: 8) {
            // Compact progress indicator
            if isHovering || uiControlStateManager.isDetailedInfoVisible {
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
                        uiControlStateManager.handleGestureInteraction()
                        viewModel.previousPhoto()
                    }
                )
                .shortcutTooltip(localizationService?.localizedString(for: "tooltip.previous") ?? "Previous", shortcut: "←")
                
                // Play/Pause button (larger)
                ControlButton(
                    systemName: slideshow.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                    size: .large,
                    action: {
                        uiControlStateManager.handleGestureInteraction()
                        if slideshow.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play()
                        }
                    }
                )
                .shortcutTooltip(slideshow.isPlaying ? (localizationService?.localizedString(for: "slideshow.button.pause") ?? "Pause") : (localizationService?.localizedString(for: "slideshow.button.play") ?? "Play"), shortcut: "Space")
                
                // Next button
                ControlButton(
                    systemName: "chevron.right.circle.fill",
                    size: .medium,
                    action: {
                        uiControlStateManager.handleGestureInteraction()
                        viewModel.nextPhoto()
                    }
                )
                .shortcutTooltip(localizationService?.localizedString(for: "tooltip.next") ?? "Next", shortcut: "→")
            }
            
            // Photo counter (minimal)
            if isHovering || uiControlStateManager.isDetailedInfoVisible {
                Text("\(slideshow.currentIndex + 1) / \(slideshow.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                    .onAppear {
                        ProductionLogger.debug("MinimalControlsView: Photo counter - currentIndex: \(slideshow.currentIndex), count: \(slideshow.count), photos.count: \(slideshow.photos.count)")
                    }
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
                uiControlStateManager.handleMouseInteraction(at: .zero)
            }
        }
        .onTapGesture {
            uiControlStateManager.toggleDetailedInfo()
        }
        .shortcutTooltip(localizationService?.localizedString(for: "tooltip.tap_for_info") ?? "Tap for info", shortcut: "I")
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: uiControlStateManager.isDetailedInfoVisible)
    }
    
    private func compactProgressBar(slideshow: Slideshow) -> some View {
        VStack(spacing: 4) {
            // Compact interactive progress bar
            CompactProgressBar(
                progress: slideshow.progress,
                currentIndex: slideshow.currentIndex,
                totalCount: slideshow.count
            ) { targetIndex in
                ProductionLogger.userAction("MinimalControlsView: Progress bar clicked - fast jumping to photo \(targetIndex)")
                uiControlStateManager.handleGestureInteraction()
                viewModel.fastGoToPhoto(at: targetIndex)
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

/// Compact progress bar for minimal controls
private struct CompactProgressBar: View {
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
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress fill
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: geometry.size.width * progress, height: 4)
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.2), value: progress)
                
                // Hover indicator
                if isHovering {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
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
        
        if validIndex != currentIndex {
            onJumpToIndex(validIndex)
        }
    }
}

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