import SwiftUI
import AppKit

/// Unified button component for all slideshow controls with consistent styling and behavior
/// Implements Factory pattern for button creation and Strategy pattern for styling
public struct UnifiedSlideshowButton: View {
    
    // MARK: - Button Types
    
    /// Enum defining all available slideshow button types
    public enum ButtonType: String, CaseIterable {
        case play = "play"
        case pause = "pause"
        case stop = "stop"
        case next = "next"
        case previous = "previous"
        case first = "first"
        case last = "last"
        case shuffle = "shuffle"
        case `repeat` = "repeat"
        case settings = "settings"
        case info = "info"
        case fullscreen = "fullscreen"
        case selectFolder = "selectFolder"
        
        /// System image name for the button
        var systemImageName: String {
            switch self {
            case .play: return "play.circle.fill"
            case .pause: return "pause.circle.fill"
            case .stop: return "stop.circle.fill"
            case .next: return "chevron.right.circle.fill"
            case .previous: return "chevron.left.circle.fill"
            case .first: return "backward.end.circle.fill"
            case .last: return "forward.end.circle.fill"
            case .shuffle: return "shuffle.circle.fill"
            case .`repeat`: return "repeat.circle.fill"
            case .settings: return "gearshape.circle.fill"
            case .info: return "info.circle.fill"
            case .fullscreen: return "arrow.up.left.and.arrow.down.right.circle.fill"
            case .selectFolder: return "folder.circle.fill"
            }
        }
        
        /// Alternative system image name (for toggle states)
        var alternativeSystemImageName: String? {
            switch self {
            case .shuffle: return "shuffle.circle"
            case .`repeat`: return "repeat.circle"
            case .fullscreen: return "arrow.down.right.and.arrow.up.left.circle.fill"
            default: return nil
            }
        }
        
        /// Display name for accessibility and tooltips
        var displayName: String {
            switch self {
            case .play: return "Play"
            case .pause: return "Pause"
            case .stop: return "Stop"
            case .next: return "Next"
            case .previous: return "Previous"
            case .first: return "First"
            case .last: return "Last"
            case .shuffle: return "Shuffle"
            case .`repeat`: return "Repeat"
            case .settings: return "Settings"
            case .info: return "Info"
            case .fullscreen: return "Full Screen"
            case .selectFolder: return "Select Folder"
            }
        }
        
        /// Keyboard shortcut hint for tooltips
        var keyboardShortcut: String? {
            switch self {
            case .play, .pause: return "Space"
            case .next: return "→"
            case .previous: return "←"
            case .first: return "Home"
            case .last: return "End"
            case .shuffle: return "S"
            case .`repeat`: return "R"
            case .settings: return "⌘,"
            case .info: return "I"
            case .fullscreen: return "F"
            default: return nil
            }
        }
    }
    
    // MARK: - Button Styles
    
    /// Style presets for different button appearances
    public enum ButtonStyle {
        case minimal        // Simple icon, minimal styling
        case standard       // Default styling with background
        case prominent      // Larger, more prominent appearance
        case compact        // Smaller size for crowded interfaces
        case pill           // Pill-shaped background
        case borderless     // No background, just icon
        case glassmorphic   // Modern glass effect
        
        var sizing: ButtonSizing {
            switch self {
            case .minimal, .borderless: return .small
            case .compact: return .extraSmall
            case .standard: return .medium
            case .prominent: return .large
            case .pill, .glassmorphic: return .medium
            }
        }
        
        var hasBackground: Bool {
            switch self {
            case .minimal, .borderless: return false
            case .standard, .prominent, .pill, .glassmorphic, .compact: return true
            }
        }
    }
    
    // MARK: - Button Sizing
    
    /// Size variants for buttons
    public enum ButtonSizing {
        case extraSmall, small, medium, large, extraLarge
        
        var iconSize: Font {
            switch self {
            case .extraSmall: return .caption
            case .small: return .title3
            case .medium: return .title2
            case .large: return .largeTitle
            case .extraLarge: return .system(size: 32, weight: .medium)
            }
        }
        
        var padding: SwiftUI.EdgeInsets {
            switch self {
            case .extraSmall: return SwiftUI.EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
            case .small: return SwiftUI.EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            case .medium: return SwiftUI.EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            case .large: return SwiftUI.EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            case .extraLarge: return SwiftUI.EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .extraSmall: return 4
            case .small: return 6
            case .medium: return 8
            case .large: return 12
            case .extraLarge: return 16
            }
        }
    }
    
    // MARK: - Properties
    
    private let buttonType: ButtonType
    private let buttonStyle: ButtonStyle
    private let action: () -> Void
    private let isEnabled: Bool
    private let isToggled: Bool // For toggle buttons like shuffle/repeat
    private let customColor: Color?
    private let showTooltip: Bool
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Initialization
    
    /// Create a unified slideshow button
    /// - Parameters:
    ///   - type: The type of button (play, pause, next, etc.)
    ///   - style: Visual style preset
    ///   - isEnabled: Whether the button is enabled
    ///   - isToggled: Toggle state for buttons that can be on/off
    ///   - customColor: Custom color override
    ///   - showTooltip: Whether to show tooltips
    ///   - action: Action to perform when button is pressed
    @MainActor
    public init(
        type: ButtonType,
        style: ButtonStyle = .standard,
        isEnabled: Bool = true,
        isToggled: Bool = false,
        customColor: Color? = nil,
        showTooltip: Bool = true,
        action: @escaping () -> Void
    ) {
        self.buttonType = type
        self.buttonStyle = style
        self.action = action
        self.isEnabled = isEnabled
        self.isToggled = isToggled
        self.customColor = customColor
        self.showTooltip = showTooltip
    }
    
    // MARK: - Body
    
    public var body: some View {
        Button(action: {
            if isEnabled {
                // Haptic feedback for better UX
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                action()
            }
        }) {
            buttonContent
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .modifier(TooltipModifier(isEnabled: showTooltip))
        .accessibilityLabel(buttonType.displayName)
        .accessibilityHint(buttonType.keyboardShortcut.map { shortcut in "Keyboard shortcut: \(shortcut)" } ?? "")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Button Content
    
    @ViewBuilder
    private var buttonContent: some View {
        let iconName = (isToggled && buttonType.alternativeSystemImageName != nil) 
            ? buttonType.alternativeSystemImageName! 
            : buttonType.systemImageName
            
        let sizing = buttonStyle.sizing
        
        if buttonStyle.hasBackground {
            // Button with background
            Image(systemName: iconName)
                .font(sizing.iconSize)
                .foregroundColor(buttonColor)
                .padding(sizing.padding)
                .background(buttonBackground)
                .cornerRadius(sizing.cornerRadius)
        } else {
            // Borderless button
            Image(systemName: iconName)
                .font(sizing.iconSize)
                .foregroundColor(buttonColor)
        }
    }
    
    // MARK: - Styling Helpers
    
    private var buttonColor: Color {
        if let customColor = customColor {
            return customColor
        }
        
        if isToggled {
            return .accentColor
        }
        
        switch buttonStyle {
        case .minimal, .borderless:
            return .white
        case .standard, .compact:
            return .white
        case .prominent:
            return .white
        case .pill:
            return .primary
        case .glassmorphic:
            return .white
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch buttonStyle {
        case .minimal, .borderless:
            EmptyView()
            
        case .standard, .compact:
            RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.8 : 0.6)
                .overlay(
                    RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
        case .prominent:
            RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                .fill(isToggled ? Color.accentColor : Color.black.opacity(0.7))
                .opacity(isHovered ? 0.9 : 0.7)
                .overlay(
                    RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
            
        case .pill:
            Capsule()
                .fill(.regularMaterial)
                .opacity(isHovered ? 0.8 : 0.6)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
        case .glassmorphic:
            RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.9 : 0.7)
                .background(
                    RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: buttonStyle.sizing.cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Factory Pattern Implementation

public extension UnifiedSlideshowButton {
    
    /// Factory for creating common button configurations
    struct Factory {
        
        /// Create a play/pause button that dynamically shows the correct icon
        @MainActor
        public static func playPauseButton(
            isPlaying: Bool,
            style: ButtonStyle = .prominent,
            action: @escaping () -> Void
        ) -> UnifiedSlideshowButton {
            return UnifiedSlideshowButton(
                type: isPlaying ? .pause : .play,
                style: style,
                action: action
            )
        }
        
        /// Create a navigation button (next/previous)
        @MainActor
        public static func navigationButton(
            direction: NavigationDirection,
            style: ButtonStyle = .standard,
            isEnabled: Bool = true,
            action: @escaping () -> Void
        ) -> UnifiedSlideshowButton {
            let type: ButtonType = direction == .next ? .next : .previous
            return UnifiedSlideshowButton(
                type: type,
                style: style,
                isEnabled: isEnabled,
                action: action
            )
        }
        
        /// Create a toggle button (shuffle/repeat)
        @MainActor
        public static func toggleButton(
            type: ToggleButtonType,
            isToggled: Bool,
            style: ButtonStyle = .standard,
            action: @escaping () -> Void
        ) -> UnifiedSlideshowButton {
            let buttonType: ButtonType = type == .shuffle ? .shuffle : .`repeat`
            return UnifiedSlideshowButton(
                type: buttonType,
                style: style,
                isToggled: isToggled,
                action: action
            )
        }
        
        /// Create a control button (settings, info, etc.)
        @MainActor
        public static func controlButton(
            type: ControlButtonType,
            style: ButtonStyle = .minimal,
            action: @escaping () -> Void
        ) -> UnifiedSlideshowButton {
            let buttonType: ButtonType
            switch type {
            case .settings: buttonType = .settings
            case .info: buttonType = .info
            case .fullscreen: buttonType = .fullscreen
            case .selectFolder: buttonType = .selectFolder
            }
            
            return UnifiedSlideshowButton(
                type: buttonType,
                style: style,
                action: action
            )
        }
        
        /// Create a minimal set of control buttons for compact interfaces
        @MainActor
        public static func minimalControlSet(
            isPlaying: Bool,
            canNavigateNext: Bool,
            canNavigatePrevious: Bool,
            onPlayPause: @escaping () -> Void,
            onNext: @escaping () -> Void,
            onPrevious: @escaping () -> Void
        ) -> some View {
            HStack(spacing: 16) {
                navigationButton(
                    direction: .previous,
                    style: .standard,
                    isEnabled: canNavigatePrevious,
                    action: onPrevious
                )
                
                playPauseButton(
                    isPlaying: isPlaying,
                    style: .prominent,
                    action: onPlayPause
                )
                
                navigationButton(
                    direction: .next,
                    style: .standard,
                    isEnabled: canNavigateNext,
                    action: onNext
                )
            }
        }
    }
    
    // MARK: - Supporting Types
    
    enum NavigationDirection {
        case next, previous
    }
    
    enum ToggleButtonType {
        case shuffle, `repeat`
    }
    
    enum ControlButtonType {
        case settings, info, fullscreen, selectFolder
    }
}

// MARK: - Tooltip Support

private struct TooltipModifier: ViewModifier {
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .help(tooltipText) // Built-in SwiftUI tooltip
        } else {
            content
        }
    }
    
    private var tooltipText: String {
        // This would be dynamically generated based on button type
        // For now, returning a placeholder
        return "Slideshow Control"
    }
}

// MARK: - Preview Support

#Preview("Slideshow Buttons") {
    VStack(spacing: 20) {
        // Play/Pause buttons
        HStack(spacing: 16) {
            UnifiedSlideshowButton.Factory.playPauseButton(isPlaying: false) {
                print("Play pressed")
            }
            
            UnifiedSlideshowButton.Factory.playPauseButton(isPlaying: true) {
                print("Pause pressed")
            }
        }
        
        // Navigation buttons
        HStack(spacing: 16) {
            UnifiedSlideshowButton.Factory.navigationButton(direction: .previous) {
                print("Previous pressed")
            }
            
            UnifiedSlideshowButton.Factory.navigationButton(direction: .next) {
                print("Next pressed")
            }
        }
        
        // Toggle buttons
        HStack(spacing: 16) {
            UnifiedSlideshowButton.Factory.toggleButton(
                type: .shuffle,
                isToggled: false
            ) {
                print("Shuffle pressed")
            }
            
            UnifiedSlideshowButton.Factory.toggleButton(
                type: .repeat,
                isToggled: true
            ) {
                print("Repeat pressed")
            }
        }
        
        // Control buttons
        HStack(spacing: 16) {
            UnifiedSlideshowButton.Factory.controlButton(type: .settings) {
                print("Settings pressed")
            }
            
            UnifiedSlideshowButton.Factory.controlButton(type: .info) {
                print("Info pressed")
            }
        }
        
        // Minimal control set
        UnifiedSlideshowButton.Factory.minimalControlSet(
            isPlaying: false,
            canNavigateNext: true,
            canNavigatePrevious: true,
            onPlayPause: { print("Play/Pause") },
            onNext: { print("Next") },
            onPrevious: { print("Previous") }
        )
        
        // Different styles showcase
        VStack(spacing: 12) {
            Text("Style Variations")
                .font(.headline)
            
            HStack(spacing: 12) {
                UnifiedSlideshowButton(type: .play, style: .minimal) {
                    print("Minimal play")
                }
                
                UnifiedSlideshowButton(type: .play, style: .standard) {
                    print("Standard play")
                }
                
                UnifiedSlideshowButton(type: .play, style: .prominent) {
                    print("Prominent play")
                }
                
                UnifiedSlideshowButton(type: .play, style: .glassmorphic) {
                    print("Glassmorphic play")
                }
            }
        }
    }
    .padding()
    .background(Color.black)
}