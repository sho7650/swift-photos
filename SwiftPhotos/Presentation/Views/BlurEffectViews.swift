import SwiftUI
import Combine

// MARK: - Blur Effect View Modifiers

/// View modifier for applying managed blur effects to any view
public struct ManagedBlurEffect: ViewModifier {
    @ObservedObject private var blurManager: BlurEffectManager
    
    private let overlayType: OverlayType
    private let style: BlurStyle?
    private let customIntensity: Double?
    private let isEnabled: Bool
    
    public init(
        blurManager: BlurEffectManager,
        overlayType: OverlayType,
        style: BlurStyle? = nil,
        intensity: Double? = nil,
        isEnabled: Bool = true
    ) {
        self.blurManager = blurManager
        self.overlayType = overlayType
        self.style = style
        self.customIntensity = intensity
        self.isEnabled = isEnabled
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                if isEnabled {
                    blurManager.createBlurView(
                        for: overlayType,
                        style: style,
                        customIntensity: customIntensity
                    )
                }
            }
    }
}

/// View modifier for animated blur transitions
public struct AnimatedBlurTransition: ViewModifier {
    @ObservedObject private var blurManager: BlurEffectManager
    
    private let overlayType: OverlayType
    private let isVisible: Bool
    private let animationDuration: TimeInterval
    
    @State private var currentIntensity: Double = 0.0
    
    public init(
        blurManager: BlurEffectManager,
        overlayType: OverlayType,
        isVisible: Bool,
        animationDuration: TimeInterval = 0.3
    ) {
        self.blurManager = blurManager
        self.overlayType = overlayType
        self.isVisible = isVisible
        self.animationDuration = animationDuration
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                blurManager.createBlurView(
                    for: overlayType,
                    customIntensity: currentIntensity
                )
            }
            .onAppear {
                if isVisible {
                    withAnimation(.easeInOut(duration: animationDuration)) {
                        currentIntensity = 1.0
                    }
                }
            }
            .onChange(of: isVisible) { newValue in
                withAnimation(.easeInOut(duration: animationDuration)) {
                    currentIntensity = newValue ? 1.0 : 0.0
                }
            }
    }
}

/// View modifier for context-aware blur adaptation
public struct ContextAwareBlur: ViewModifier {
    @ObservedObject private var blurManager: BlurEffectManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    private let overlayType: OverlayType
    private let adaptToContext: Bool
    
    public init(
        blurManager: BlurEffectManager,
        overlayType: OverlayType,
        adaptToContext: Bool = true
    ) {
        self.blurManager = blurManager
        self.overlayType = overlayType
        self.adaptToContext = adaptToContext
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                blurManager.createBlurView(
                    for: overlayType,
                    style: adaptiveBlurStyle,
                    customIntensity: adaptiveIntensity
                )
            }
    }
    
    private var adaptiveBlurStyle: BlurStyle {
        guard adaptToContext else { return blurManager.currentStyle }
        
        if reduceTransparency {
            return .thick
        }
        
        switch colorScheme {
        case .dark:
            return .prominent
        case .light:
            return .regular
        @unknown default:
            return .regular
        }
    }
    
    private var adaptiveIntensity: Double {
        guard adaptToContext else { return 1.0 }
        
        if reduceTransparency {
            return 1.0 // Full opacity for accessibility
        }
        
        return blurManager.globalBlurIntensity
    }
}

// MARK: - Specialized Blur Views

/// Enhanced blur view with performance monitoring
public struct PerformanceOptimizedBlurView: View {
    @ObservedObject private var blurManager: BlurEffectManager
    @State private var renderCount: Int = 0
    @State private var isOptimized: Bool = false
    
    private let overlayType: OverlayType
    private let style: BlurStyle?
    private let performanceThreshold: Int
    
    public init(
        blurManager: BlurEffectManager,
        overlayType: OverlayType,
        style: BlurStyle? = nil,
        performanceThreshold: Int = 60
    ) {
        self.blurManager = blurManager
        self.overlayType = overlayType
        self.style = style
        self.performanceThreshold = performanceThreshold
    }
    
    public var body: some View {
        blurManager.createBlurView(
            for: overlayType,
            style: effectiveStyle,
            customIntensity: isOptimized ? 0.6 : nil
        )
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            renderCount += 1
            
            if renderCount > performanceThreshold {
                if !isOptimized {
                    isOptimized = true
                    blurManager.setPerformanceMode(true)
                }
            } else if renderCount < performanceThreshold / 2 && isOptimized {
                isOptimized = false
                blurManager.setPerformanceMode(false)
            }
            
            // Reset counter every second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                renderCount = 0
            }
        }
    }
    
    private var effectiveStyle: BlurStyle {
        if isOptimized {
            switch style ?? blurManager.currentStyle {
            case .ultraThick, .thick: return .regular
            case .prominent: return .regular
            default: return style ?? blurManager.currentStyle
            }
        }
        return style ?? blurManager.currentStyle
    }
}

/// Interactive blur view that responds to hover and focus
public struct InteractiveBlurView: View {
    @ObservedObject private var blurManager: BlurEffectManager
    @State private var isHovered: Bool = false
    @State private var isFocused: Bool = false
    
    private let overlayType: OverlayType
    private let hoverIntensityMultiplier: Double
    private let focusIntensityMultiplier: Double
    
    public init(
        blurManager: BlurEffectManager,
        overlayType: OverlayType,
        hoverIntensityMultiplier: Double = 1.2,
        focusIntensityMultiplier: Double = 1.5
    ) {
        self.blurManager = blurManager
        self.overlayType = overlayType
        self.hoverIntensityMultiplier = hoverIntensityMultiplier
        self.focusIntensityMultiplier = focusIntensityMultiplier
    }
    
    public var body: some View {
        blurManager.createBlurView(
            for: overlayType,
            customIntensity: currentIntensity
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = false
            }
        }
    }
    
    private var currentIntensity: Double {
        var intensity = 1.0
        
        if isFocused {
            intensity *= focusIntensityMultiplier
        }
        
        if isHovered {
            intensity *= hoverIntensityMultiplier
        }
        
        return min(1.0, intensity)
    }
}

/// Gradient blur view that transitions between different blur intensities
public struct GradientBlurView: View {
    @ObservedObject private var blurManager: BlurEffectManager
    
    private let overlayType: OverlayType
    private let gradientDirection: GradientDirection
    private let intensityRange: ClosedRange<Double>
    
    public init(
        blurManager: BlurEffectManager,
        overlayType: OverlayType,
        gradientDirection: GradientDirection = .vertical,
        intensityRange: ClosedRange<Double> = 0.3...1.0
    ) {
        self.blurManager = blurManager
        self.overlayType = overlayType
        self.gradientDirection = gradientDirection
        self.intensityRange = intensityRange
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Create multiple blur layers with varying intensities
                ForEach(0..<5, id: \.self) { index in
                    let intensity = calculateIntensity(for: index, total: 5)
                    let frame = calculateFrame(for: index, total: 5, in: geometry)
                    
                    blurManager.createBlurView(
                        for: overlayType,
                        customIntensity: intensity
                    )
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
    }
    
    private func calculateIntensity(for index: Int, total: Int) -> Double {
        let ratio = Double(index) / Double(total - 1)
        return intensityRange.lowerBound + (intensityRange.upperBound - intensityRange.lowerBound) * ratio
    }
    
    private func calculateFrame(for index: Int, total: Int, in geometry: GeometryProxy) -> CGRect {
        let ratio = Double(index) / Double(total - 1)
        
        switch gradientDirection {
        case .horizontal:
            let width = geometry.size.width / Double(total)
            let x = width * Double(index)
            return CGRect(x: x, y: 0, width: width, height: geometry.size.height)
            
        case .vertical:
            let height = geometry.size.height / Double(total)
            let y = height * Double(index)
            return CGRect(x: 0, y: y, width: geometry.size.width, height: height)
            
        case .radial:
            let radius = min(geometry.size.width, geometry.size.height) * 0.5 * ratio
            let center = CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
            return CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        }
    }
}

// MARK: - Supporting Types

public enum GradientDirection {
    case horizontal
    case vertical
    case radial
}

// MARK: - View Extensions

public extension View {
    /// Apply managed blur effect to this view
    func managedBlur(
        manager: BlurEffectManager,
        overlayType: OverlayType,
        style: BlurStyle? = nil,
        intensity: Double? = nil,
        isEnabled: Bool = true
    ) -> some View {
        modifier(ManagedBlurEffect(
            blurManager: manager,
            overlayType: overlayType,
            style: style,
            intensity: intensity,
            isEnabled: isEnabled
        ))
    }
    
    /// Apply animated blur transition to this view
    func animatedBlur(
        manager: BlurEffectManager,
        overlayType: OverlayType,
        isVisible: Bool,
        animationDuration: TimeInterval = 0.3
    ) -> some View {
        modifier(AnimatedBlurTransition(
            blurManager: manager,
            overlayType: overlayType,
            isVisible: isVisible,
            animationDuration: animationDuration
        ))
    }
    
    /// Apply context-aware blur that adapts to environment
    func contextAwareBlur(
        manager: BlurEffectManager,
        overlayType: OverlayType,
        adaptToContext: Bool = true
    ) -> some View {
        modifier(ContextAwareBlur(
            blurManager: manager,
            overlayType: overlayType,
            adaptToContext: adaptToContext
        ))
    }
}

// MARK: - Legacy Compatibility

/// Compatibility layer for existing BlurredBackground views
public struct LegacyBlurredBackground: View {
    private let intensity: Double
    private let opacity: Double
    
    public init(intensity: Double, opacity: Double) {
        self.intensity = intensity
        self.opacity = opacity
    }
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(intensity)
            
            Rectangle()
                .fill(Color.black.opacity(opacity * 0.3))
        }
    }
}

/// Enhanced replacement for existing blur views
public struct EnhancedBlurredBackground: View {
    @EnvironmentObject private var blurManager: BlurEffectManager
    
    private let overlayType: OverlayType
    private let fallbackIntensity: Double
    private let fallbackOpacity: Double
    
    public init(
        overlayType: OverlayType = .controls,
        fallbackIntensity: Double = 0.8,
        fallbackOpacity: Double = 0.3
    ) {
        self.overlayType = overlayType
        self.fallbackIntensity = fallbackIntensity
        self.fallbackOpacity = fallbackOpacity
    }
    
    public var body: some View {
        // Use managed blur effect since blurManager is available as @EnvironmentObject
        blurManager.createBlurView(for: overlayType)
    }
}

// MARK: - Environment Support

private struct BlurManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: BlurEffectManager? = nil
}

public extension EnvironmentValues {
    var blurManager: BlurEffectManager? {
        get { self[BlurManagerEnvironmentKey.self] }
        set { self[BlurManagerEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func blurManager(_ manager: BlurEffectManager) -> some View {
        environment(\.blurManager, manager)
    }
}