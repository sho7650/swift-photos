//
//  UnifiedInteractionSystem.swift
//  Swift Photos
//
//  Unified interaction handling system consolidating event patterns
//  Phase 3.2: Presentation Layer Optimization - Event Handling Unification
//

import SwiftUI
import Combine

// MARK: - Interaction Configuration

/// Comprehensive interaction configuration model
public struct UnifiedInteractionConfiguration: Sendable {
    public let isEnabled: Bool
    public let hoverBehavior: HoverBehavior
    public let tapBehavior: TapBehavior
    public let keyboardBehavior: KeyboardBehavior
    public let focusBehavior: FocusBehavior
    public let feedbackBehavior: FeedbackBehavior
    
    public init(
        isEnabled: Bool = true,
        hoverBehavior: HoverBehavior = .standard(),
        tapBehavior: TapBehavior = .standard(action: {}),
        keyboardBehavior: KeyboardBehavior = .none,
        focusBehavior: FocusBehavior = .standard,
        feedbackBehavior: FeedbackBehavior = .standard
    ) {
        self.isEnabled = isEnabled
        self.hoverBehavior = hoverBehavior
        self.tapBehavior = tapBehavior
        self.keyboardBehavior = keyboardBehavior
        self.focusBehavior = focusBehavior
        self.feedbackBehavior = feedbackBehavior
    }
}

// MARK: - Interaction Behaviors

public enum HoverBehavior: Sendable {
    case none
    case standard(highlightColor: Color? = nil)
    case custom(onEnter: @Sendable () -> Void, onExit: @Sendable () -> Void)
    case cursorChange
    case tooltip(model: TooltipModel)
    
    var hasVisualFeedback: Bool {
        switch self {
        case .none: return false
        case .standard, .tooltip: return true
        case .custom, .cursorChange: return false
        }
    }
}

public enum TapBehavior: Sendable {
    case none
    case standard(action: @Sendable () -> Void)
    case doubleTap(action: @Sendable () -> Void)
    case longPress(minimumDuration: Double = 0.5, action: @Sendable () -> Void)
    case custom
    
    var hasAction: Bool {
        switch self {
        case .none: return false
        case .standard, .doubleTap, .longPress: return true
        case .custom: return false
        }
    }
}

public enum KeyboardBehavior: Sendable {
    case none
    case shortcut(key: KeyEquivalent, modifiers: EventModifiers = [], action: @Sendable () -> Void)
    case textInput(onSubmit: @Sendable (String) -> Void)
    case keyPress(onKeyPress: @Sendable (KeyPress) -> KeyPress.Result)
    case focus(onFocusChange: @Sendable (Bool) -> Void)
}

public enum FocusBehavior: Sendable {
    case none
    case standard
    case custom(onFocusChange: @Sendable (Bool) -> Void)
    case field
}

public enum FeedbackBehavior: Sendable {
    case none
    case standard
    case haptic(intensity: Double = 1.0)
    case sound(name: String)
    case custom(feedback: @Sendable () -> Void)
}

// MARK: - Unified Interaction Modifier

/// The main interaction modifier that consolidates all event handling patterns
public struct UnifiedInteractionModifier: ViewModifier {
    let configuration: UnifiedInteractionConfiguration
    
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    @State private var isFocused: Bool = false
    
    public init(configuration: UnifiedInteractionConfiguration) {
        self.configuration = configuration
    }
    
    public func body(content: Content) -> some View {
        content
            .modifier(HoverModifier(
                behavior: configuration.hoverBehavior,
                isHovered: $isHovered,
                isEnabled: configuration.isEnabled
            ))
            .modifier(TapModifier(
                behavior: configuration.tapBehavior,
                isPressed: $isPressed,
                isEnabled: configuration.isEnabled
            ))
            .modifier(KeyboardModifier(
                behavior: configuration.keyboardBehavior,
                isEnabled: configuration.isEnabled
            ))
            .modifier(FocusModifier(
                behavior: configuration.focusBehavior,
                isFocused: $isFocused,
                isEnabled: configuration.isEnabled
            ))
            .modifier(FeedbackModifier(
                behavior: configuration.feedbackBehavior,
                isHovered: isHovered,
                isPressed: isPressed,
                isFocused: isFocused
            ))
    }
}

// MARK: - Component Modifiers

private struct HoverModifier: ViewModifier {
    let behavior: HoverBehavior
    @Binding var isHovered: Bool
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        Group {
            switch behavior {
            case .none:
                content
                
            case .standard(let highlightColor):
                content
                    .background(
                        Rectangle()
                            .fill(highlightColor ?? DesignTokens.Colors.interactive.opacity(0.1))
                            .opacity(isHovered ? 1.0 : 0.0)
                            .animation(DesignTokens.Animation.fast, value: isHovered)
                    )
                    .onHover { hovering in
                        if isEnabled {
                            withAnimation(DesignTokens.Animation.fast) {
                                isHovered = hovering
                            }
                        }
                    }
                
            case .custom(let onEnter, let onExit):
                content
                    .onHover { hovering in
                        if isEnabled {
                            isHovered = hovering
                            if hovering {
                                onEnter()
                            } else {
                                onExit()
                            }
                        }
                    }
                
            case .cursorChange:
                content
                    .onHover { hovering in
                        if isEnabled {
                            isHovered = hovering
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                
            case .tooltip(let model):
                content
                    .tooltip(model)
                    .onHover { hovering in
                        if isEnabled {
                            isHovered = hovering
                        }
                    }
            }
        }
    }
}

private struct TapModifier: ViewModifier {
    let behavior: TapBehavior
    @Binding var isPressed: Bool
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        Group {
            switch behavior {
            case .none:
                content
                
            case .standard(let action):
                content
                    .onTapGesture {
                        if isEnabled {
                            action()
                        }
                    }
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        if isEnabled {
                            withAnimation(DesignTokens.Animation.fast) {
                                isPressed = pressing
                            }
                        }
                    }, perform: {})
                
            case .doubleTap(let action):
                content
                    .onTapGesture(count: 2) {
                        if isEnabled {
                            action()
                        }
                    }
                
            case .longPress(let duration, let action):
                content
                    .onLongPressGesture(minimumDuration: duration) {
                        if isEnabled {
                            action()
                        }
                    }
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        if isEnabled {
                            withAnimation(DesignTokens.Animation.fast) {
                                isPressed = pressing
                            }
                        }
                    }, perform: {})
                
            case .custom:
                content
                // Custom gesture handling would be implemented based on specific requirements
            }
        }
    }
}

private struct KeyboardModifier: ViewModifier {
    let behavior: KeyboardBehavior
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        Group {
            switch behavior {
            case .none:
                content
                
            case .shortcut(let key, let modifiers, let action):
                content
                    .keyboardShortcut(key, modifiers: modifiers)
                    .onKeyPress { keyPress in
                        if isEnabled && keyPress.key == key {
                            action()
                            return .handled
                        }
                        return .ignored
                    }
                
            case .textInput(_):
                content
                // Note: This would need additional implementation for text input handling
                
            case .keyPress(let onKeyPress):
                content
                    .onKeyPress { keyPress in
                        isEnabled ? onKeyPress(keyPress) : .ignored
                    }
                
            case .focus(_):
                content
                // Note: This would integrate with FocusModifier
            }
        }
    }
}

private struct FocusModifier: ViewModifier {
    let behavior: FocusBehavior
    @Binding var isFocused: Bool
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        switch behavior {
            case .none:
                content
                
            case .standard:
                content
                    .focusable()
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                            .stroke(DesignTokens.Colors.accent, lineWidth: 2)
                            .opacity(isFocused ? 1.0 : 0.0)
                            .animation(DesignTokens.Animation.fast, value: isFocused)
                    )
                
            case .custom(let onFocusChange):
                content
                    .focusable()
                    .onChange(of: isFocused) { _, focused in
                        if isEnabled {
                            onFocusChange(focused)
                        }
                    }
                
            case .field:
                content
                    .focusable()
        }
    }
}

private struct FeedbackModifier: ViewModifier {
    let behavior: FeedbackBehavior
    let isHovered: Bool
    let isPressed: Bool
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    provideFeedback()
                }
            }
    }
    
    private func provideFeedback() {
        switch behavior {
        case .none:
            break
            
        case .standard:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
        case .haptic(let intensity):
            let feedbackType: NSHapticFeedbackManager.FeedbackPattern = intensity > 0.7 ? .generic : .alignment
            NSHapticFeedbackManager.defaultPerformer.perform(feedbackType, performanceTime: .now)
            
        case .sound(let name):
            if let sound = NSSound(named: name) {
                sound.play()
            }
            
        case .custom(let feedback):
            feedback()
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply unified interaction handling to any view
    func unifiedInteraction(_ configuration: UnifiedInteractionConfiguration) -> some View {
        modifier(UnifiedInteractionModifier(configuration: configuration))
    }
    
    /// Quick hover interaction
    func quickHover(
        highlightColor: Color? = nil,
        action: (@Sendable () -> Void)? = nil
    ) -> some View {
        let hoverBehavior: HoverBehavior = action != nil ? 
            .custom(onEnter: action!, onExit: {}) : 
            .standard(highlightColor: highlightColor)
        
        return unifiedInteraction(UnifiedInteractionConfiguration(
            hoverBehavior: hoverBehavior
        ))
    }
    
    /// Quick tap interaction
    func quickTap(action: @Sendable @escaping () -> Void) -> some View {
        unifiedInteraction(UnifiedInteractionConfiguration(
            tapBehavior: .standard(action: action)
        ))
    }
    
    /// Quick keyboard shortcut
    func quickShortcut(
        key: KeyEquivalent,
        modifiers: EventModifiers = [],
        action: @Sendable @escaping () -> Void
    ) -> some View {
        unifiedInteraction(UnifiedInteractionConfiguration(
            keyboardBehavior: .shortcut(key: key, modifiers: modifiers, action: action)
        ))
    }
    
    /// Interactive control (combines hover, tap, and focus)
    func interactiveControl(
        onTap: @Sendable @escaping () -> Void,
        tooltip: TooltipModel? = nil
    ) -> some View {
        let hoverBehavior: HoverBehavior = tooltip != nil ? .tooltip(model: tooltip!) : .standard()
        
        return unifiedInteraction(UnifiedInteractionConfiguration(
            hoverBehavior: hoverBehavior,
            tapBehavior: .standard(action: onTap),
            focusBehavior: .standard,
            feedbackBehavior: .standard
        ))
    }
}

// MARK: - Predefined Configurations

public extension UnifiedInteractionConfiguration {
    /// Standard button interaction
    static let button = UnifiedInteractionConfiguration(
        hoverBehavior: .standard(),
        tapBehavior: .standard(action: {}),
        focusBehavior: .standard,
        feedbackBehavior: .standard
    )
    
    /// Control element interaction (with tooltip support)
    static func control(tooltip: TooltipModel? = nil) -> UnifiedInteractionConfiguration {
        UnifiedInteractionConfiguration(
            hoverBehavior: tooltip != nil ? .tooltip(model: tooltip!) : .standard(),
            tapBehavior: .standard(action: {}),
            focusBehavior: .standard,
            feedbackBehavior: .standard
        )
    }
    
    /// Information display interaction (hover only)
    static let info = UnifiedInteractionConfiguration(
        hoverBehavior: .standard(highlightColor: DesignTokens.Colors.info.opacity(0.1)),
        tapBehavior: .none,
        focusBehavior: .none,
        feedbackBehavior: .none
    )
    
    /// Image interaction (with cursor change)
    static let image = UnifiedInteractionConfiguration(
        hoverBehavior: .cursorChange,
        tapBehavior: .standard(action: {}),
        focusBehavior: .standard,
        feedbackBehavior: .haptic(intensity: 0.5)
    )
}

// MARK: - Legacy Compatibility

/// Migration helpers for existing interaction patterns
public extension View {
    @available(*, deprecated, message: "Use unifiedInteraction() instead")
    func legacyHover(action: @Sendable @escaping (Bool) -> Void) -> some View {
        unifiedInteraction(UnifiedInteractionConfiguration(
            hoverBehavior: .custom(
                onEnter: { action(true) },
                onExit: { action(false) }
            )
        ))
    }
    
    @available(*, deprecated, message: "Use unifiedInteraction() instead")
    func legacyTap(action: @Sendable @escaping () -> Void) -> some View {
        unifiedInteraction(UnifiedInteractionConfiguration(
            tapBehavior: .standard(action: action)
        ))
    }
}