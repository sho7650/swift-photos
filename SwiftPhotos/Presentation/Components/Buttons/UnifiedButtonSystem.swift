//
//  UnifiedButtonSystem.swift
//  Swift Photos
//
//  Unified button component system with design token integration
//  Phase 3.1: View Layer Consolidation - Button System Unification
//

import SwiftUI

// MARK: - Button Configuration

/// Comprehensive button configuration using design tokens
public struct ButtonConfiguration {
    public let type: ButtonType
    public let style: ButtonStyle
    public let size: ButtonSize
    public let state: ButtonState
    public let tooltip: TooltipModel?
    public let isEnabled: Bool
    public let action: () -> Void
    
    public init(
        type: ButtonType,
        style: ButtonStyle = .standard,
        size: ButtonSize = .medium,
        state: ButtonState = .normal,
        tooltip: TooltipModel? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.style = style
        self.size = size
        self.state = state
        self.tooltip = tooltip
        self.isEnabled = isEnabled
        self.action = action
    }
}

// MARK: - Button Types

public enum ButtonType {
    // Playback controls
    case play
    case pause
    case stop
    case next
    case previous
    case first
    case last
    
    // Slideshow controls
    case shuffle(isEnabled: Bool)
    case `repeat`(isEnabled: Bool)
    case fullscreen(isFullscreen: Bool)
    
    // Navigation
    case settings
    case info
    case selectFolder
    case close
    case minimize
    case maximize
    
    // Custom
    case custom(icon: String, alternativeIcon: String? = nil)
    
    var primaryIcon: String {
        switch self {
        case .play: return "play.circle.fill"
        case .pause: return "pause.circle.fill"
        case .stop: return "stop.circle.fill"
        case .next: return "chevron.right.circle.fill"
        case .previous: return "chevron.left.circle.fill"
        case .first: return "backward.end.circle.fill"
        case .last: return "forward.end.circle.fill"
        case .shuffle(let isEnabled): return isEnabled ? "shuffle.circle.fill" : "shuffle.circle"
        case .`repeat`(let isEnabled): return isEnabled ? "repeat.circle.fill" : "repeat.circle"
        case .fullscreen(let isFullscreen): return isFullscreen ? 
            "arrow.down.right.and.arrow.up.left.circle.fill" : 
            "arrow.up.left.and.arrow.down.right.circle.fill"
        case .settings: return "gearshape.circle.fill"
        case .info: return "info.circle.fill"
        case .selectFolder: return "folder.circle.fill"
        case .close: return "xmark.circle.fill"
        case .minimize: return "minus.circle.fill"
        case .maximize: return "plus.circle.fill"
        case .custom(let icon, _): return icon
        }
    }
    
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
        case .fullscreen: return "Full Screen"
        case .settings: return "Settings"
        case .info: return "Info"
        case .selectFolder: return "Select Folder"
        case .close: return "Close"
        case .minimize: return "Minimize"
        case .maximize: return "Maximize"
        case .custom: return "Custom"
        }
    }
    
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
    
    var semanticColor: Color? {
        switch self {
        case .play: return DesignTokens.Colors.success
        case .stop: return DesignTokens.Colors.error
        case .close: return DesignTokens.Colors.error
        case .info: return DesignTokens.Colors.info
        case .settings: return DesignTokens.Colors.interactiveSecondary
        default: return nil
        }
    }
}

// MARK: - Button Styles

public enum ButtonStyle {
    case minimal           // Icon only, no background
    case standard          // Icon with subtle background
    case prominent         // Icon with strong background
    case pill              // Pill-shaped background
    case glassmorphic      // Modern glass effect
    case bordered          // Outlined style
    case compact           // Smaller padding, minimal style
    case floating          // Elevated appearance
    
    var backgroundColor: Color {
        switch self {
        case .minimal, .compact: return Color.clear
        case .standard: return DesignTokens.Colors.controlsBackground
        case .prominent: return DesignTokens.Colors.accent
        case .pill: return DesignTokens.Colors.controlsBackground
        case .glassmorphic: return DesignTokens.Colors.glassFill
        case .bordered: return Color.clear
        case .floating: return DesignTokens.Colors.controlsBackground
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .minimal, .compact, .bordered: return DesignTokens.Colors.interactive
        case .standard, .pill, .floating: return DesignTokens.Colors.interactive
        case .prominent: return DesignTokens.Colors.primaryBackground
        case .glassmorphic: return DesignTokens.Colors.interactive
        }
    }
    
    var borderColor: Color? {
        switch self {
        case .bordered: return DesignTokens.Colors.border
        case .glassmorphic: return DesignTokens.Colors.glassStroke
        default: return nil
        }
    }
    
    var hasBackground: Bool {
        switch self {
        case .minimal, .compact, .bordered: return false
        case .standard, .prominent, .pill, .glassmorphic, .floating: return true
        }
    }
    
    var hasShadow: Bool {
        switch self {
        case .floating, .prominent: return true
        default: return false
        }
    }
    
    func cornerRadius(for size: ButtonSize) -> CGFloat {
        switch self {
        case .minimal, .compact: return 0
        case .standard, .bordered, .floating: return DesignTokens.CornerRadius.button
        case .prominent, .glassmorphic: return DesignTokens.CornerRadius.medium
        case .pill: return size.iconSize * 0.75 // Make it pill-shaped
        }
    }
}

// MARK: - Button Sizes

public enum ButtonSize {
    case extraSmall
    case small  
    case medium
    case large
    case extraLarge
    
    var iconSize: CGFloat {
        switch self {
        case .extraSmall: return 16
        case .small: return 20
        case .medium: return 24
        case .large: return 32
        case .extraLarge: return 40
        }
    }
    
    var font: Font {
        switch self {
        case .extraSmall: return .caption
        case .small: return .footnote
        case .medium: return .body
        case .large: return .title3
        case .extraLarge: return .title2
        }
    }
    
    var paddingValue: CGFloat {
        switch self {
        case .extraSmall: return DesignTokens.Spacing.xxxSmall
        case .small: return DesignTokens.Spacing.xxSmall
        case .medium: return DesignTokens.Spacing.xSmall
        case .large: return DesignTokens.Spacing.small
        case .extraLarge: return DesignTokens.Spacing.medium
        }
    }
    
    var minimumTapArea: CGFloat {
        switch self {
        case .extraSmall: return 32
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        case .extraLarge: return 60
        }
    }
}

// MARK: - Button States

public enum ButtonState {
    case normal
    case hovered
    case pressed
    case disabled
    case loading
    
    var opacity: Double {
        switch self {
        case .normal: return 1.0
        case .hovered: return 0.8
        case .pressed: return 0.6
        case .disabled: return 0.4
        case .loading: return 0.7
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .normal, .hovered, .disabled, .loading: return 1.0
        case .pressed: return 0.95
        }
    }
}

// MARK: - Unified Button View

/// The main unified button component
public struct UnifiedButton: View {
    let configuration: ButtonConfiguration
    
    @State private var currentState: ButtonState
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    public init(configuration: ButtonConfiguration) {
        self.configuration = configuration
        self._currentState = State(initialValue: configuration.state)
    }
    
    public var body: some View {
        Button(action: handleAction) {
            buttonContent
        }
        .buttonStyle(UnifiedButtonStyleImpl(
            buttonConfig: configuration,
            currentState: effectiveState
        ))
        .disabled(!configuration.isEnabled)
        .accessibilityLabel(configuration.type.displayName)
        .accessibilityHint(accessibilityHint)
        .frame(minWidth: configuration.size.minimumTapArea, 
               minHeight: configuration.size.minimumTapArea)
        .modifier(OptionalTooltipModifier(model: tooltipModel))
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.button) {
                isHovered = hovering
            }
        }
        .scaleEffect(effectiveState.scale)
        .opacity(effectiveState.opacity)
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: DesignTokens.Spacing.xxxSmall) {
            if currentState == .loading {
                ProgressView()
                    .scaleEffect(0.8)
                    .foregroundColor(configuration.style.foregroundColor)
            } else {
                Image(systemName: configuration.type.primaryIcon)
                    .font(.system(size: configuration.size.iconSize))
                    .foregroundColor(effectiveForegroundColor)
            }
        }
        .padding(configuration.size.paddingValue)
    }
    
    private var effectiveState: ButtonState {
        if !configuration.isEnabled {
            return .disabled
        } else if isPressed {
            return .pressed  
        } else if isHovered {
            return .hovered
        } else {
            return currentState
        }
    }
    
    private var effectiveForegroundColor: Color {
        let baseColor = configuration.type.semanticColor ?? configuration.style.foregroundColor
        
        switch effectiveState {
        case .normal: return baseColor
        case .hovered: return baseColor
        case .pressed: return baseColor.opacity(0.8)
        case .disabled: return baseColor.opacity(0.4)
        case .loading: return baseColor.opacity(0.7)
        }
    }
    
    private var accessibilityHint: String {
        var hint = "Activates \(configuration.type.displayName.lowercased())"
        if let shortcut = configuration.type.keyboardShortcut {
            hint += ". Keyboard shortcut: \(shortcut)"
        }
        return hint
    }
    
    private var tooltipModel: TooltipModel? {
        if let existingTooltip = configuration.tooltip {
            return existingTooltip
        }
        
        // Auto-generate tooltip if keyboard shortcut exists
        if let shortcut = configuration.type.keyboardShortcut {
            return TooltipModel(
                text: configuration.type.displayName,
                shortcut: shortcut,
                style: .standard
            )
        }
        
        return nil
    }
    
    private func handleAction() {
        withAnimation(DesignTokens.Animation.button) {
            isPressed = true
        }
        
        // Haptic feedback for macOS
        NSSound.beep()
        
        configuration.action()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(DesignTokens.Animation.button) {
                isPressed = false
            }
        }
    }
}

// MARK: - Unified Button Style

private struct UnifiedButtonStyleImpl: SwiftUI.ButtonStyle {
    let buttonConfig: ButtonConfiguration
    let currentState: ButtonState
    
    func makeBody(configuration: SwiftUI.ButtonStyle.Configuration) -> some View {
        configuration.label
            .background(backgroundView)
            .overlay(borderView)
            .cornerRadius(self.buttonConfig.style.cornerRadius(for: self.buttonConfig.size))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if buttonConfig.style.hasBackground {
            if buttonConfig.style == .glassmorphic {
                RoundedRectangle(cornerRadius: buttonConfig.style.cornerRadius(for: buttonConfig.size))
                    .fill(Material.ultraThinMaterial)
                    .overlay(buttonConfig.style.backgroundColor)
            } else {
                RoundedRectangle(cornerRadius: buttonConfig.style.cornerRadius(for: buttonConfig.size))
                    .fill(buttonConfig.style.backgroundColor)
            }
        }
    }
    
    @ViewBuilder
    private var borderView: some View {
        if let borderColor = buttonConfig.style.borderColor {
            RoundedRectangle(cornerRadius: buttonConfig.style.cornerRadius(for: buttonConfig.size))
                .stroke(borderColor, lineWidth: 1)
        }
    }
    
    private var shadowColor: Color {
        guard buttonConfig.style.hasShadow else { return Color.clear }
        
        switch currentState {
        case .normal: return DesignTokens.Shadows.button
        case .hovered: return DesignTokens.Shadows.medium
        case .pressed: return DesignTokens.Shadows.small
        case .disabled, .loading: return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        guard buttonConfig.style.hasShadow else { return 0 }
        
        switch currentState {
        case .normal: return 2
        case .hovered: return 4
        case .pressed: return 1
        case .disabled, .loading: return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        guard buttonConfig.style.hasShadow else { return 0 }
        
        switch currentState {
        case .normal: return 1
        case .hovered: return 2
        case .pressed: return 0.5
        case .disabled, .loading: return 0
        }
    }
}

// MARK: - Convenience Initializers

public extension UnifiedButton {
    /// Quick play/pause button
    static func playPause(isPlaying: Bool, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(configuration: ButtonConfiguration(
            type: isPlaying ? .pause : .play,
            style: .prominent,
            size: .large,
            action: action
        ))
    }
    
    /// Quick navigation button
    static func navigation(_ type: ButtonType, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(configuration: ButtonConfiguration(
            type: type,
            style: .standard,
            size: .medium,
            action: action
        ))
    }
    
    /// Quick settings button
    static func settings(action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(configuration: ButtonConfiguration(
            type: .settings,
            style: .minimal,
            size: .medium,
            action: action
        ))
    }
    
    /// Quick custom button
    static func custom(
        icon: String,
        text: String? = nil,
        style: ButtonStyle = .standard,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> UnifiedButton {
        let tooltip = text.map { TooltipModel(text: $0) }
        return UnifiedButton(configuration: ButtonConfiguration(
            type: .custom(icon: icon),
            style: style,
            size: size,
            tooltip: tooltip,
            action: action
        ))
    }
}

// MARK: - Helper Views

/// Helper modifier for optional tooltips
private struct OptionalTooltipModifier: ViewModifier {
    let model: TooltipModel?
    
    func body(content: Content) -> some View {
        if let model = model {
            content.tooltip(model)
        } else {
            content
        }
    }
}

// MARK: - Legacy Compatibility

/// Migration helpers for existing UnifiedSlideshowButton
public extension UnifiedButton {
    @available(*, deprecated, message: "Use UnifiedButton with ButtonConfiguration instead")
    static func fromLegacy(
        buttonType: String,
        style: String,
        action: @escaping () -> Void
    ) -> UnifiedButton {
        // Convert legacy parameters to new system
        let type: ButtonType
        switch buttonType {
        case "play": type = .play
        case "pause": type = .pause  
        case "next": type = .next
        case "previous": type = .previous
        case "settings": type = .settings
        default: type = .custom(icon: "questionmark.circle")
        }
        
        let buttonStyle: ButtonStyle
        switch style {
        case "minimal": buttonStyle = .minimal
        case "prominent": buttonStyle = .prominent
        case "glassmorphic": buttonStyle = .glassmorphic
        default: buttonStyle = .standard
        }
        
        return UnifiedButton(configuration: ButtonConfiguration(
            type: type,
            style: buttonStyle,
            action: action
        ))
    }
}