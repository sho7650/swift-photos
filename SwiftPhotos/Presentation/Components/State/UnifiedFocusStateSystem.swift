//
//  UnifiedFocusStateSystem.swift
//  Swift Photos
//
//  Unified focus and state management system
//  Phase 3.2: Presentation Layer Optimization - Focus Management Unification
//

import SwiftUI
import Combine

// MARK: - Focus State Configuration

/// Comprehensive focus state configuration
public struct FocusStateConfiguration: Sendable {
    public let isEnabled: Bool
    public let focusStyle: FocusStyle
    public let keyboardNavigation: KeyboardNavigationBehavior
    public let accessibilityConfig: AccessibilityConfiguration
    public let animations: AnimationConfiguration
    
    public init(
        isEnabled: Bool = true,
        focusStyle: FocusStyle = .standard,
        keyboardNavigation: KeyboardNavigationBehavior = .standard,
        accessibilityConfig: AccessibilityConfiguration = .standard,
        animations: AnimationConfiguration = .standard
    ) {
        self.isEnabled = isEnabled
        self.focusStyle = focusStyle
        self.keyboardNavigation = keyboardNavigation
        self.accessibilityConfig = accessibilityConfig
        self.animations = animations
    }
}

// MARK: - Focus Style

public enum FocusStyle: Sendable {
    case none
    case standard
    case prominent
    case subtle
    case custom(ringColor: Color, ringWidth: CGFloat, cornerRadius: CGFloat)
    
    var ringColor: Color {
        switch self {
        case .none: return .clear
        case .standard: return DesignTokens.Colors.accent
        case .prominent: return DesignTokens.Colors.accent
        case .subtle: return DesignTokens.Colors.interactiveSecondary
        case .custom(let color, _, _): return color
        }
    }
    
    var ringWidth: CGFloat {
        switch self {
        case .none: return 0
        case .standard: return 2
        case .prominent: return 3
        case .subtle: return 1
        case .custom(_, let width, _): return width
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .none: return 0
        case .standard, .prominent: return DesignTokens.CornerRadius.small
        case .subtle: return DesignTokens.CornerRadius.small
        case .custom(_, _, let radius): return radius
        }
    }
}

// MARK: - Keyboard Navigation

public enum KeyboardNavigationBehavior: Sendable {
    case none
    case standard
    case custom(onNext: @Sendable () -> Void, onPrevious: @Sendable () -> Void)
    case tabNavigation(onTab: @Sendable () -> Void, onShiftTab: @Sendable () -> Void)
    case arrowNavigation(onUp: @Sendable () -> Void, onDown: @Sendable () -> Void, onLeft: @Sendable () -> Void, onRight: @Sendable () -> Void)
}

// MARK: - Accessibility Configuration

public struct AccessibilityConfiguration: Sendable {
    public let label: String?
    public let hint: String?
    public let traits: AccessibilityTraits
    public let customActions: [String] // Simplified for Sendable compliance
    
    public init(
        label: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        customActions: [String] = [] // Simplified for Sendable compliance
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.customActions = customActions
    }
    
    public static let standard = AccessibilityConfiguration()
}

// MARK: - Animation Configuration

public struct AnimationConfiguration: Sendable {
    public let focusAnimation: Animation
    public let hoverAnimation: Animation
    public let pressAnimation: Animation
    
    public init(
        focusAnimation: Animation = DesignTokens.Animation.standard,
        hoverAnimation: Animation = DesignTokens.Animation.fast,
        pressAnimation: Animation = DesignTokens.Animation.fast
    ) {
        self.focusAnimation = focusAnimation
        self.hoverAnimation = hoverAnimation
        self.pressAnimation = pressAnimation
    }
    
    public static let standard = AnimationConfiguration()
    public static let subtle = AnimationConfiguration(
        focusAnimation: DesignTokens.Animation.slow,
        hoverAnimation: DesignTokens.Animation.standard,
        pressAnimation: DesignTokens.Animation.standard
    )
}

// MARK: - Unified Focus State Manager

/// Central focus state management for the application
@MainActor
public class UnifiedFocusStateManager: ObservableObject {
    @Published public private(set) var currentFocus: String?
    @Published public private(set) var focusHistory: [String] = []
    @Published public private(set) var isKeyboardNavigationActive: Bool = false
    
    private var focusElements: [String: FocusStateConfiguration] = [:]
    private var focusChain: [String] = []
    private var cancellables = Set<AnyCancellable>()
    
    public static let shared = UnifiedFocusStateManager()
    
    private init() {
        setupKeyboardMonitoring()
    }
    
    // MARK: - Focus Management
    
    public func registerFocusElement(
        id: String,
        configuration: FocusStateConfiguration,
        insertAtIndex: Int? = nil
    ) {
        focusElements[id] = configuration
        
        if let index = insertAtIndex {
            focusChain.insert(id, at: min(index, focusChain.count))
        } else {
            focusChain.append(id)
        }
    }
    
    public func unregisterFocusElement(id: String) {
        focusElements.removeValue(forKey: id)
        focusChain.removeAll { $0 == id }
        
        if currentFocus == id {
            currentFocus = nil
        }
    }
    
    public func setFocus(to id: String?) {
        guard let id = id, focusElements[id] != nil else {
            currentFocus = nil
            return
        }
        
        if let previousFocus = currentFocus {
            addToHistory(previousFocus)
        }
        
        currentFocus = id
    }
    
    public func moveFocusNext() {
        guard let currentId = currentFocus,
              let currentIndex = focusChain.firstIndex(of: currentId) else {
            // No current focus, focus on first element
            setFocus(to: focusChain.first)
            return
        }
        
        let nextIndex = (currentIndex + 1) % focusChain.count
        setFocus(to: focusChain[nextIndex])
    }
    
    public func moveFocusPrevious() {
        guard let currentId = currentFocus,
              let currentIndex = focusChain.firstIndex(of: currentId) else {
            // No current focus, focus on last element
            setFocus(to: focusChain.last)
            return
        }
        
        let previousIndex = currentIndex == 0 ? focusChain.count - 1 : currentIndex - 1
        setFocus(to: focusChain[previousIndex])
    }
    
    public func restorePreviousFocus() {
        guard let previousId = focusHistory.last else { return }
        focusHistory.removeLast()
        currentFocus = previousId
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ id: String) {
        focusHistory.append(id)
        // Limit history to 10 items
        if focusHistory.count > 10 {
            focusHistory.removeFirst()
        }
    }
    
    private func setupKeyboardMonitoring() {
        // Monitor keyboard events to detect navigation activity
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.isKeyboardNavigationActive = false
            }
            .store(in: &cancellables)
    }
}

// MARK: - Unified Focus State Modifier

/// ViewModifier that provides unified focus state management
public struct UnifiedFocusStateModifier: ViewModifier {
    let id: String
    let configuration: FocusStateConfiguration
    
    @StateObject private var focusManager = UnifiedFocusStateManager.shared
    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    public init(id: String, configuration: FocusStateConfiguration) {
        self.id = id
        self.configuration = configuration
    }
    
    public func body(content: Content) -> some View {
        content
            .focusable(configuration.isEnabled)
            .focused($isFocused)
            .overlay(focusRing)
            .onAppear {
                focusManager.registerFocusElement(id: id, configuration: configuration)
            }
            .onDisappear {
                focusManager.unregisterFocusElement(id: id)
            }
            .onChange(of: isFocused) { focused in
                if focused {
                    focusManager.setFocus(to: id)
                } else if focusManager.currentFocus == id {
                    focusManager.setFocus(to: nil)
                }
            }
            .onChange(of: focusManager.currentFocus) { currentFocus in
                isFocused = (currentFocus == id)
            }
            .onKeyPress(action: handleKeyPress)
            .accessibilityLabel(configuration.accessibilityConfig.label ?? "")
            .accessibilityHint(configuration.accessibilityConfig.hint ?? "")
            .accessibilityAddTraits(configuration.accessibilityConfig.traits)
    }
    
    @ViewBuilder
    private var focusRing: some View {
        if isFocused {
            switch configuration.focusStyle {
            case .none:
                EmptyView()
            default:
                RoundedRectangle(cornerRadius: configuration.focusStyle.cornerRadius)
                    .stroke(
                        configuration.focusStyle.ringColor,
                        lineWidth: configuration.focusStyle.ringWidth
                    )
                    .animation(configuration.animations.focusAnimation, value: isFocused)
            }
        }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard configuration.isEnabled else { return .ignored }
        
        switch configuration.keyboardNavigation {
        case .none:
            return .ignored
            
        case .standard:
            switch press.key {
            case .tab:
                if press.modifiers.contains(.shift) {
                    focusManager.moveFocusPrevious()
                } else {
                    focusManager.moveFocusNext()
                }
                return .handled
            default:
                return .ignored
            }
            
        case .custom(let onNext, let onPrevious):
            switch press.key {
            case .tab:
                if press.modifiers.contains(.shift) {
                    onPrevious()
                } else {
                    onNext()
                }
                return .handled
            default:
                return .ignored
            }
            
        case .tabNavigation(let onTab, let onShiftTab):
            if press.key == .tab {
                if press.modifiers.contains(.shift) {
                    onShiftTab()
                } else {
                    onTab()
                }
                return .handled
            }
            return .ignored
            
        case .arrowNavigation(let onUp, let onDown, let onLeft, let onRight):
            switch press.key {
            case .upArrow: onUp(); return .handled
            case .downArrow: onDown(); return .handled
            case .leftArrow: onLeft(); return .handled
            case .rightArrow: onRight(); return .handled
            default: return .ignored
            }
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply unified focus state management
    func unifiedFocusState(
        id: String,
        configuration: FocusStateConfiguration = FocusStateConfiguration()
    ) -> some View {
        modifier(UnifiedFocusStateModifier(id: id, configuration: configuration))
    }
    
    /// Quick focusable setup
    func quickFocusable(
        id: String,
        style: FocusStyle = .standard
    ) -> some View {
        unifiedFocusState(
            id: id,
            configuration: FocusStateConfiguration(focusStyle: style)
        )
    }
    
    /// Keyboard navigable setup
    func keyboardNavigable(
        id: String,
        onNext: @Sendable @escaping () -> Void = {},
        onPrevious: @Sendable @escaping () -> Void = {}
    ) -> some View {
        unifiedFocusState(
            id: id,
            configuration: FocusStateConfiguration(
                keyboardNavigation: .custom(onNext: onNext, onPrevious: onPrevious)
            )
        )
    }
    
    /// Accessible focusable setup
    func accessibleFocusable(
        id: String,
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        unifiedFocusState(
            id: id,
            configuration: FocusStateConfiguration(
                accessibilityConfig: AccessibilityConfiguration(
                    label: label,
                    hint: hint,
                    traits: traits
                )
            )
        )
    }
}

// MARK: - Predefined Configurations

public extension FocusStateConfiguration {
    /// Standard interactive element
    static let interactive = FocusStateConfiguration(
        focusStyle: .standard,
        keyboardNavigation: .standard,
        accessibilityConfig: AccessibilityConfiguration(traits: [])
    )
    
    /// Text input field
    static let textField = FocusStateConfiguration(
        focusStyle: .prominent,
        keyboardNavigation: .tabNavigation(onTab: {}, onShiftTab: {}),
        accessibilityConfig: AccessibilityConfiguration(traits: [])
    )
    
    /// Control button
    static let button = FocusStateConfiguration(
        focusStyle: .standard,
        keyboardNavigation: .standard,
        accessibilityConfig: AccessibilityConfiguration(traits: [])
    )
    
    /// Information display
    static let info = FocusStateConfiguration(
        focusStyle: .subtle,
        keyboardNavigation: .standard,
        accessibilityConfig: AccessibilityConfiguration(traits: [])
    )
    
    /// Navigation element
    static let navigation = FocusStateConfiguration(
        focusStyle: .prominent,
        keyboardNavigation: .arrowNavigation(
            onUp: {}, onDown: {}, onLeft: {}, onRight: {}
        ),
        accessibilityConfig: AccessibilityConfiguration(traits: [])
    )
}

// MARK: - Legacy Compatibility

/// Migration helpers for existing focus management
public extension View {
    @available(*, deprecated, message: "Use unifiedFocusState() instead")
    func legacyFocusable(_ condition: Bool = true) -> some View {
        if condition {
            return AnyView(self.unifiedFocusState(
                id: UUID().uuidString,
                configuration: .interactive
            ))
        } else {
            return AnyView(self)
        }
    }
    
    @available(*, deprecated, message: "Use accessibleFocusable() instead")
    func legacyAccessible(label: String, hint: String? = nil) -> some View {
        self.accessibleFocusable(
            id: UUID().uuidString,
            label: label,
            hint: hint
        )
    }
}