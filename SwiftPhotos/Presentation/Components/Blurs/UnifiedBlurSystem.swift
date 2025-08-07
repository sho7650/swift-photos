//
//  UnifiedBlurSystem.swift
//  Swift Photos
//
//  Unified blur effect system consolidating all blur implementations
//  Phase 3.1: View Layer Consolidation - Blur Effect Unification
//

import SwiftUI

// MARK: - Blur Configuration

/// Configuration model for blur effects
public struct BlurConfiguration: Sendable {
    public let style: UnifiedBlurStyle
    public let intensity: Double
    public let isAnimated: Bool
    public let animationType: BlurAnimationType
    public let isContextAware: Bool
    public let performanceMode: BlurPerformanceMode
    
    public init(
        style: UnifiedBlurStyle = .material(.regular),
        intensity: Double = 1.0,
        isAnimated: Bool = false,
        animationType: BlurAnimationType = .fade,
        isContextAware: Bool = true,
        performanceMode: BlurPerformanceMode = .standard
    ) {
        self.style = style
        self.intensity = intensity
        self.isAnimated = isAnimated
        self.animationType = animationType
        self.isContextAware = isContextAware
        self.performanceMode = performanceMode
    }
    
    // Convenience configurations
    public static let controlsBlur = BlurConfiguration(
        style: .material(.ultraThinMaterial),
        intensity: 0.8,
        isAnimated: true,
        animationType: .fade
    )
    
    public static let overlayBlur = BlurConfiguration(
        style: .material(.thinMaterial),
        intensity: 0.6,
        isAnimated: true,
        animationType: .scale
    )
    
    public static let tooltipBlur = BlurConfiguration(
        style: .material(.thickMaterial),
        intensity: 0.9,
        performanceMode: .optimized
    )
    
    public static let glassmorphicBlur = BlurConfiguration(
        style: .glassmorphic,
        intensity: 0.7,
        isAnimated: true,
        animationType: .fade
    )
}

// MARK: - Blur Styles

public enum UnifiedBlurStyle: Sendable {
    case material(Material)
    case gaussian(radius: CGFloat)
    case glassmorphic
    case contextAdaptive
    
    @ViewBuilder
    func makeBlurView(intensity: Double, isContextAware: Bool) -> some View {
        switch self {
        case .material(let material):
            Rectangle()
                .fill(material)
                .opacity(intensity)
                
        case .gaussian(let radius):
            Rectangle()
                .fill(DesignTokens.Colors.overlayBackground)
                .blur(radius: radius * intensity)
                
        case .glassmorphic:
            Rectangle()
                .fill(Material.ultraThinMaterial)
                .overlay(DesignTokens.Colors.glassFill)
                .opacity(intensity)
                
        case .contextAdaptive:
            ContextAdaptiveBlurView(intensity: intensity)
        }
    }
}

// MARK: - Animation Types

public enum BlurAnimationType: Sendable {
    case fade
    case scale
    case slide(edge: Edge)
    case rotate
    case custom(animation: Animation)
    
    var animation: Animation {
        switch self {
        case .fade: return DesignTokens.Animation.standard
        case .scale: return DesignTokens.Animation.standard
        case .slide: return DesignTokens.Animation.standard
        case .rotate: return DesignTokens.Animation.slow
        case .custom(let animation): return animation
        }
    }
    
    var transition: AnyTransition {
        switch self {
        case .fade:
            return .opacity
        case .scale:
            return .scale.combined(with: .opacity)
        case .slide(let edge):
            return .move(edge: edge).combined(with: .opacity)
        case .rotate:
            return .asymmetric(
                insertion: .modifier(
                    active: RotationModifier(angle: .degrees(-180)),
                    identity: RotationModifier(angle: .degrees(0))
                ).combined(with: .opacity),
                removal: .opacity
            )
        case .custom:
            return .opacity // Default fallback
        }
    }
}

// MARK: - Performance Modes

public enum BlurPerformanceMode: Sendable {
    case standard
    case optimized
    case highQuality
    
    var shouldUseReducedMotion: Bool {
        switch self {
        case .standard: return false
        case .optimized: return true
        case .highQuality: return false
        }
    }
    
    var maxBlurRadius: CGFloat {
        switch self {
        case .standard: return 20
        case .optimized: return 10
        case .highQuality: return 40
        }
    }
}

// MARK: - Unified Blur View

/// The main unified blur view that handles all blur rendering
public struct UnifiedBlurView: View {
    let configuration: BlurConfiguration
    @State private var isVisible: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    public init(configuration: BlurConfiguration) {
        self.configuration = configuration
    }
    
    public var body: some View {
        Group {
            if effectiveConfiguration.isAnimated {
                animatedBlurContent
                    .transition(configuration.animationType.transition)
                    .animation(configuration.animationType.animation, value: isVisible)
            } else {
                staticBlurContent
            }
        }
        .onAppear {
            if configuration.isAnimated {
                withAnimation {
                    isVisible = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var staticBlurContent: some View {
        effectiveConfiguration.style.makeBlurView(
            intensity: effectiveIntensity,
            isContextAware: configuration.isContextAware
        )
    }
    
    @ViewBuilder
    private var animatedBlurContent: some View {
        if isVisible {
            staticBlurContent
        }
    }
    
    private var effectiveConfiguration: BlurConfiguration {
        guard configuration.isContextAware else { return configuration }
        
        // Adapt to accessibility settings
        if reduceTransparency {
            return BlurConfiguration(
                style: .material(.regular),
                intensity: 1.0,
                isAnimated: false,
                performanceMode: .optimized
            )
        }
        
        // Adapt to color scheme
        var adaptedStyle: UnifiedBlurStyle = configuration.style
        
        // Handle context-adaptive cases
        if case .contextAdaptive = configuration.style {
            adaptedStyle = colorScheme == .dark ?
                .material(.thickMaterial) :
                .material(.regularMaterial)
        }
        
        return BlurConfiguration(
            style: adaptedStyle,
            intensity: configuration.intensity,
            isAnimated: configuration.isAnimated,
            animationType: configuration.animationType,
            isContextAware: configuration.isContextAware,
            performanceMode: configuration.performanceMode
        )
    }
    
    private var effectiveIntensity: Double {
        let baseIntensity = configuration.intensity
        
        // Reduce intensity in optimized mode
        if configuration.performanceMode == .optimized {
            return baseIntensity * 0.8
        }
        
        // Increase intensity in high quality mode
        if configuration.performanceMode == .highQuality {
            return min(1.0, baseIntensity * 1.2)
        }
        
        return baseIntensity
    }
}

// MARK: - Context Adaptive Blur View

private struct ContextAdaptiveBlurView: View {
    let intensity: Double
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        Rectangle()
            .fill(adaptiveMaterial)
            .opacity(adaptiveOpacity)
    }
    
    private var adaptiveMaterial: Material {
        if reduceTransparency {
            return .regular
        }
        
        switch colorScheme {
        case .dark:
            return .ultraThinMaterial
        case .light:
            return .thinMaterial
        @unknown default:
            return .regularMaterial
        }
    }
    
    private var adaptiveOpacity: Double {
        if reduceTransparency {
            return 1.0
        }
        
        return intensity
    }
}

// MARK: - Unified Blur Modifier

/// ViewModifier for applying unified blur effects
public struct UnifiedBlurModifier: ViewModifier {
    let configuration: BlurConfiguration
    let isEnabled: Bool
    
    public init(configuration: BlurConfiguration, isEnabled: Bool = true) {
        self.configuration = configuration
        self.isEnabled = isEnabled
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                if isEnabled {
                    UnifiedBlurView(configuration: configuration)
                }
            }
    }
}

// MARK: - Interactive Blur Modifier

/// ViewModifier for interactive blur effects that respond to hover/focus
public struct InteractiveBlurModifier: ViewModifier {
    let configuration: BlurConfiguration
    let hoverConfiguration: BlurConfiguration?
    let focusConfiguration: BlurConfiguration?
    
    @State private var isHovered: Bool = false
    @State private var isFocused: Bool = false
    
    public init(
        configuration: BlurConfiguration,
        hoverConfiguration: BlurConfiguration? = nil,
        focusConfiguration: BlurConfiguration? = nil
    ) {
        self.configuration = configuration
        self.hoverConfiguration = hoverConfiguration
        self.focusConfiguration = focusConfiguration
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                UnifiedBlurView(configuration: currentConfiguration)
            }
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.fast) {
                    isHovered = hovering
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                withAnimation(DesignTokens.Animation.standard) {
                    isFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                withAnimation(DesignTokens.Animation.standard) {
                    isFocused = false
                }
            }
    }
    
    private var currentConfiguration: BlurConfiguration {
        if isFocused, let focusConfig = focusConfiguration {
            return focusConfig
        } else if isHovered, let hoverConfig = hoverConfiguration {
            return hoverConfig
        } else {
            return configuration
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply unified blur effect
    func unifiedBlur(_ configuration: BlurConfiguration, isEnabled: Bool = true) -> some View {
        modifier(UnifiedBlurModifier(configuration: configuration, isEnabled: isEnabled))
    }
    
    /// Apply interactive blur effect
    func interactiveBlur(
        _ configuration: BlurConfiguration,
        hover: BlurConfiguration? = nil,
        focus: BlurConfiguration? = nil
    ) -> some View {
        modifier(InteractiveBlurModifier(
            configuration: configuration,
            hoverConfiguration: hover,
            focusConfiguration: focus
        ))
    }
    
    /// Quick controls blur
    func controlsBlur(isEnabled: Bool = true) -> some View {
        unifiedBlur(.controlsBlur, isEnabled: isEnabled)
    }
    
    /// Quick overlay blur
    func overlayBlur(isEnabled: Bool = true) -> some View {
        unifiedBlur(.overlayBlur, isEnabled: isEnabled)
    }
    
    /// Quick tooltip blur
    func tooltipBlur(isEnabled: Bool = true) -> some View {
        unifiedBlur(.tooltipBlur, isEnabled: isEnabled)
    }
    
    /// Quick glassmorphic blur
    func glassmorphicBlur(isEnabled: Bool = true) -> some View {
        unifiedBlur(.glassmorphicBlur, isEnabled: isEnabled)
    }
}

// MARK: - Supporting Types

private struct RotationModifier: ViewModifier {
    let angle: Angle
    
    func body(content: Content) -> some View {
        content.rotationEffect(angle)
    }
}

// MARK: - Legacy Compatibility

/// Migration helpers for existing blur implementations
/// Note: managedBlur is already defined in BlurEffectViews.swift