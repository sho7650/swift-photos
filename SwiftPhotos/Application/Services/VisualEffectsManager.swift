import SwiftUI
import Combine
import os.log

// MARK: - Notification Extensions
// Note: Notification names are already defined in their respective settings files

/// Consolidated visual effects manager for blur effects, transitions, and overlay positioning
/// Replaces: BlurEffectManager, ImageTransitionManager, OverlayPositionManager
@MainActor
public final class VisualEffectsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    // Blur effects
    @Published public var currentBlurStyle: VisualBlurStyle = .regular
    @Published public var isPerformanceMode: Bool = false
    @Published public var globalBlurIntensity: Double = 1.0
    
    // Transition effects
    @Published public var currentTransition: AnyTransition = .opacity
    @Published public var transitionDuration: Double = 0.3
    
    // Overlay positioning
    @Published public var overlayAlignment: Alignment = .bottom
    @Published public var overlayOffset: CGSize = .zero
    @Published public var overlayPadding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    
    // MARK: - Configuration
    
    private let transitionSettings: ModernTransitionSettingsManager
    private let uiControlSettings: ModernUIControlSettingsManager
    
    // MARK: - Private Properties
    
    private var cachedEffects: [EffectCacheKey: CachedEffect] = [:]
    private var animationQueue: [AnimationRequest] = []
    private var isAnimating: Bool = false
    
    // Performance monitoring
    private var renderCount: Int = 0
    private var lastPerformanceCheck: Date = Date()
    private let performanceThreshold: Int = 30 // renders per second
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "VisualEffectsManager")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        transitionSettings: ModernTransitionSettingsManager,
        uiControlSettings: ModernUIControlSettingsManager
    ) {
        self.transitionSettings = transitionSettings
        self.uiControlSettings = uiControlSettings
        
        setupBindings()
        setupDefaultEffects()
        
        logger.info("🎨 VisualEffectsManager: Initialized with consolidated visual effects")
    }
    
    // MARK: - Blur Effects
    
    /// Get blur effect for a specific overlay type
    public func blurEffect(for overlayType: VisualOverlayType) -> some View {
        let intensity = overlayType.baseIntensity * globalBlurIntensity
        let radius = isPerformanceMode ? intensity * 0.5 : intensity
        
        return Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: radius)
            .opacity(overlayType.opacity)
    }
    
    /// Create background blur view
    public func backgroundBlur(intensity: Double? = nil) -> some View {
        let effectiveIntensity = intensity ?? uiControlSettings.settings.backgroundBlurIntensity
        
        return Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: effectiveIntensity * 10)
            .opacity(uiControlSettings.settings.backgroundOpacity)
    }
    
    /// Animate blur intensity
    public func animateBlur(to intensity: Double, duration: Double = 0.3) {
        withAnimation(.easeInOut(duration: duration)) {
            globalBlurIntensity = intensity
        }
    }
    
    // MARK: - Transition Effects
    
    /// Get transition for current settings
    public func imageTransition() -> AnyTransition {
        guard transitionSettings.settings.isEnabled else {
            return .identity
        }
        
        let key = EffectCacheKey.transition(
            type: transitionSettings.settings.effectType,
            duration: transitionSettings.settings.duration
        )
        
        if let cached = cachedEffects[key] {
            return cached.transition
        }
        
        let transition = createTransition(
            type: transitionSettings.settings.effectType,
            duration: transitionSettings.settings.duration,
            easing: transitionSettings.settings.easing
        )
        
        cachedEffects[key] = CachedEffect(transition: transition)
        return transition
    }
    
    /// Create custom transition
    public func customTransition(
        type: TransitionSettings.TransitionEffectType,
        duration: Double? = nil
    ) -> AnyTransition {
        createTransition(
            type: type,
            duration: duration ?? transitionDuration,
            easing: .easeInOut
        )
    }
    
    // MARK: - Overlay Positioning
    
    /// Calculate overlay position for given screen size
    public func overlayPosition(
        for overlayType: VisualOverlayType,
        in geometry: GeometryProxy
    ) -> (alignment: Alignment, offset: CGSize, padding: EdgeInsets) {
        switch overlayType {
        case .controls:
            return controlsPosition(in: geometry)
        case .info:
            return infoPosition(in: geometry)
        case .settings:
            return settingsPosition(in: geometry)
        case .custom:
            return (overlayAlignment, overlayOffset, overlayPadding)
        }
    }
    
    /// Update overlay position with animation
    public func setOverlayPosition(
        alignment: Alignment,
        offset: CGSize = .zero,
        padding: EdgeInsets? = nil,
        animated: Bool = true
    ) {
        if animated {
            withAnimation(.spring()) {
                self.overlayAlignment = alignment
                self.overlayOffset = offset
                if let padding = padding {
                    self.overlayPadding = padding
                }
            }
        } else {
            self.overlayAlignment = alignment
            self.overlayOffset = offset
            if let padding = padding {
                self.overlayPadding = padding
            }
        }
    }
    
    // MARK: - Performance Management
    
    /// Enable performance mode
    public func enablePerformanceMode() {
        isPerformanceMode = true
        globalBlurIntensity = min(globalBlurIntensity, 0.5)
        logger.info("⚡️ Performance mode enabled")
    }
    
    /// Disable performance mode
    public func disablePerformanceMode() {
        isPerformanceMode = false
        logger.info("⚡️ Performance mode disabled")
    }
    
    /// Track render for performance monitoring
    public func trackRender() {
        renderCount += 1
        
        let now = Date()
        if now.timeIntervalSince(lastPerformanceCheck) >= 1.0 {
            let fps = renderCount
            if fps < performanceThreshold && !isPerformanceMode {
                enablePerformanceMode()
            }
            renderCount = 0
            lastPerformanceCheck = now
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe transition settings
        // Note: Using notification-based updates since settings are @Observable
        NotificationCenter.default.addObserver(
            forName: .transitionSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.transitionDuration = self?.transitionSettings.settings.duration ?? 0.3
                self?.cachedEffects.removeAll() // Clear cache on settings change
            }
        }
        
        // Observe UI control settings
        NotificationCenter.default.addObserver(
            forName: .uiControlSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if let settings = self?.uiControlSettings.settings {
                    self?.updateOverlayDefaults(from: settings)
                }
            }
        }
    }
    
    private func setupDefaultEffects() {
        // Pre-cache common effects
        _ = imageTransition() // Cache current transition
    }
    
    private func createTransition(
        type: TransitionSettings.TransitionEffectType,
        duration: Double,
        easing: TransitionSettings.EasingFunction
    ) -> AnyTransition {
        let animation = createAnimation(duration: duration, easing: easing)
        
        switch type {
        case .none:
            return .identity
        case .fade:
            return .opacity.animation(animation)
        case .slideLeft:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ).animation(animation)
        case .slideRight:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            ).animation(animation)
        case .slideUp:
            return .asymmetric(
                insertion: .move(edge: .bottom),
                removal: .move(edge: .top)
            ).animation(animation)
        case .slideDown:
            return .asymmetric(
                insertion: .move(edge: .top),
                removal: .move(edge: .bottom)
            ).animation(animation)
        case .zoomIn:
            return .scale(scale: 0.8).combined(with: .opacity).animation(animation)
        case .zoomOut:
            return .scale(scale: 1.2).combined(with: .opacity).animation(animation)
        case .rotateClockwise:
            return .modifier(
                active: RotateModifier(angle: .degrees(-90)),
                identity: RotateModifier(angle: .degrees(0))
            ).animation(animation)
        case .rotateCounterClockwise:
            return .modifier(
                active: RotateModifier(angle: .degrees(90)),
                identity: RotateModifier(angle: .degrees(0))
            ).animation(animation)
        case .pushLeft:
            return .asymmetric(
                insertion: .push(from: .trailing),
                removal: .push(from: .leading)
            ).animation(animation)
        case .pushRight:
            return .asymmetric(
                insertion: .push(from: .leading),
                removal: .push(from: .trailing)
            ).animation(animation)
        case .crossfade:
            return .opacity.animation(animation)
        }
    }
    
    private func createAnimation(
        duration: Double,
        easing: TransitionSettings.EasingFunction
    ) -> Animation {
        switch easing {
        case .linear:
            return .linear(duration: duration)
        case .easeIn:
            return .easeIn(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .easeInOut:
            return .easeInOut(duration: duration)
        case .spring:
            return .spring(response: duration, dampingFraction: 0.8)
        // Note: bounce case removed as it doesn't exist in TransitionSettings.EasingFunction
        // case .bounce:
        //     return .interpolatingSpring(stiffness: 100, damping: 10).speed(1.0 / duration)
        }
    }
    
    private func controlsPosition(
        in geometry: GeometryProxy
    ) -> (Alignment, CGSize, EdgeInsets) {
        let bottomOffset = uiControlSettings.settings.bottomOffset
        return (
            .bottom,
            CGSize(width: 0, height: -bottomOffset),
            EdgeInsets(top: 0, leading: 20, bottom: bottomOffset + 20, trailing: 20)
        )
    }
    
    private func infoPosition(
        in geometry: GeometryProxy
    ) -> (Alignment, CGSize, EdgeInsets) {
        return (
            .topTrailing,
            CGSize(width: -20, height: 20),
            EdgeInsets(top: 40, leading: 20, bottom: 20, trailing: 40)
        )
    }
    
    private func settingsPosition(
        in geometry: GeometryProxy
    ) -> (Alignment, CGSize, EdgeInsets) {
        return (
            .center,
            .zero,
            EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40)
        )
    }
    
    private func updateOverlayDefaults(from settings: UIControlSettings) {
        overlayPadding = EdgeInsets(
            top: 20,
            leading: 20,
            bottom: settings.bottomOffset + 20,
            trailing: 20
        )
    }
}

// MARK: - Supporting Types

/// Visual overlay type enumeration
public enum VisualOverlayType {
    case controls
    case info
    case settings
    case custom
    
    var baseIntensity: Double {
        switch self {
        case .controls: return 5.0
        case .info: return 3.0
        case .settings: return 8.0
        case .custom: return 5.0
        }
    }
    
    var opacity: Double {
        switch self {
        case .controls: return 0.8
        case .info: return 0.9
        case .settings: return 0.95
        case .custom: return 0.8
        }
    }
}

/// Visual blur style options
public enum VisualBlurStyle: Hashable, Equatable {
    case ultraLight
    case light
    case regular
    case dark
    case chromeMaterial
    case custom(radius: Double, opacity: Double)
}

/// Cache key for effects
private enum EffectCacheKey: Hashable {
    case blur(style: VisualBlurStyle, intensity: Double)
    case transition(type: TransitionSettings.TransitionEffectType, duration: Double)
}

/// Cached effect storage
private struct CachedEffect {
    var blur: (radius: Double, opacity: Double)?
    var transition: AnyTransition
    
    init(blur: (radius: Double, opacity: Double)? = nil, transition: AnyTransition = .identity) {
        self.blur = blur
        self.transition = transition
    }
}

/// Animation request for queueing
private struct AnimationRequest {
    let id = UUID()
    let type: AnimationType
    let duration: Double
    let completion: (() -> Void)?
    
    enum AnimationType {
        case blur(intensity: Double)
        case position(alignment: Alignment, offset: CGSize)
        case transition(type: TransitionSettings.TransitionEffectType)
    }
}

/// Rotate modifier for custom transitions
private struct RotateModifier: ViewModifier {
    let angle: Angle
    
    func body(content: Content) -> some View {
        content.rotationEffect(angle)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply visual effect manager blur
    public func visualBlur(_ manager: VisualEffectsManager, for type: VisualOverlayType) -> some View {
        background(manager.blurEffect(for: type))
    }
    
    /// Apply managed transition
    public func visualTransition(_ manager: VisualEffectsManager) -> some View {
        transition(manager.imageTransition())
    }
}