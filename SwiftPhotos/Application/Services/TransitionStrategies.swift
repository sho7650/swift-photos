import SwiftUI
import Foundation

/// Strategy pattern implementation for transition effects
/// Consolidates all transition logic into pluggable strategies

// MARK: - Strategy Protocol

/// Protocol defining the interface for transition strategies
public protocol TransitionStrategy: Sendable {
    /// The type of transition this strategy handles
    var effectType: TransitionSettings.TransitionEffectType { get }
    
    /// Create a SwiftUI transition for view changes
    func createSwiftUITransition() -> AnyTransition
    
    /// Apply custom effects to a view during transition
    func applyCustomEffects<Content: View>(
        to content: Content,
        progress: Double,
        isVisible: Bool,
        bounds: CGRect
    ) -> AnyView
    
    /// Get animation timing for this transition
    func getAnimation(duration: Double, easing: TransitionSettings.EasingFunction) -> Animation?
}

// MARK: - Base Strategy

/// Base implementation providing common functionality
open class BaseTransitionStrategy: @unchecked Sendable, TransitionStrategy {
    public let effectType: TransitionSettings.TransitionEffectType
    
    public init(effectType: TransitionSettings.TransitionEffectType) {
        self.effectType = effectType
    }
    
    open func createSwiftUITransition() -> AnyTransition {
        return .identity
    }
    
    open func applyCustomEffects<Content: View>(
        to content: Content,
        progress: Double,
        isVisible: Bool,
        bounds: CGRect
    ) -> AnyView {
        return AnyView(content)
    }
    
    open func getAnimation(duration: Double, easing: TransitionSettings.EasingFunction) -> Animation? {
        return easing.toSwiftUIAnimation(duration: duration)
    }
}

// MARK: - Concrete Strategies

/// No transition - instant change
public final class NoneTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    public init() {
        super.init(effectType: .none)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        return .identity
    }
    
    public override func getAnimation(duration: Double, easing: TransitionSettings.EasingFunction) -> Animation? {
        return nil
    }
}

/// Fade in/out transition
public final class FadeTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    public init() {
        super.init(effectType: .fade)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        return .opacity
    }
}

/// Slide transitions (left, right, up, down)
public final class SlideTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    private let edge: Edge
    
    public override init(effectType: TransitionSettings.TransitionEffectType) {
        switch effectType {
        case .slideLeft:
            self.edge = .leading
        case .slideRight:
            self.edge = .trailing
        case .slideUp:
            self.edge = .top
        case .slideDown:
            self.edge = .bottom
        default:
            self.edge = .leading
        }
        super.init(effectType: effectType)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        return .asymmetric(
            insertion: .move(edge: edge.opposite),
            removal: .move(edge: edge)
        )
    }
    
    public override func applyCustomEffects<Content: View>(
        to content: Content,
        progress: Double,
        isVisible: Bool,
        bounds: CGRect
    ) -> AnyView {
        let offset = calculateSlideOffset(progress: progress, isVisible: isVisible, bounds: bounds)
        return AnyView(
            content.offset(offset)
        )
    }
    
    private func calculateSlideOffset(progress: Double, isVisible: Bool, bounds: CGRect) -> CGSize {
        let distance: CGFloat
        let direction: CGSize
        
        switch edge {
        case .leading, .trailing:
            distance = bounds.width
            direction = edge == .leading ? CGSize(width: -1, height: 0) : CGSize(width: 1, height: 0)
        case .top, .bottom:
            distance = bounds.height
            direction = edge == .top ? CGSize(width: 0, height: -1) : CGSize(width: 0, height: 1)
        }
        
        let offset = distance * (isVisible ? (1.0 - progress) : progress)
        return CGSize(width: direction.width * offset, height: direction.height * offset)
    }
}

/// Scale transitions (zoom in/out)
public final class ScaleTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    private let isZoomIn: Bool
    
    public override init(effectType: TransitionSettings.TransitionEffectType) {
        self.isZoomIn = effectType == .zoomIn
        super.init(effectType: effectType)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        let scale = isZoomIn ? 0.1 : 1.5
        return .asymmetric(
            insertion: .scale(scale: scale).combined(with: .opacity),
            removal: .scale(scale: isZoomIn ? 1.5 : 0.1).combined(with: .opacity)
        )
    }
    
    public override func applyCustomEffects<Content: View>(
        to content: Content,
        progress: Double,
        isVisible: Bool,
        bounds: CGRect
    ) -> AnyView {
        let scale = calculateScale(progress: progress, isVisible: isVisible)
        return AnyView(
            content
                .scaleEffect(scale)
                .opacity(progress)
        )
    }
    
    private func calculateScale(progress: Double, isVisible: Bool) -> CGFloat {
        if isZoomIn {
            return isVisible ? CGFloat(0.1 + (0.9 * progress)) : CGFloat(1.0 + (0.5 * progress))
        } else {
            return isVisible ? CGFloat(1.5 - (0.5 * progress)) : CGFloat(1.0 - (0.9 * progress))
        }
    }
}

/// Rotation transitions with proper rotation effects
public final class RotationTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    private let isClockwise: Bool
    
    public override init(effectType: TransitionSettings.TransitionEffectType) {
        self.isClockwise = effectType == .rotateClockwise
        super.init(effectType: effectType)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        // Use scale+opacity for SwiftUI transition, custom rotation applied in applyCustomEffects
        return .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.2).combined(with: .opacity)
        )
    }
    
    public override func applyCustomEffects<Content: View>(
        to content: Content,
        progress: Double,
        isVisible: Bool,
        bounds: CGRect
    ) -> AnyView {
        let rotation = calculateRotation(progress: progress, isVisible: isVisible)
        let scale = calculateScale(progress: progress, isVisible: isVisible)
        
        return AnyView(
            content
                .rotationEffect(rotation)
                .scaleEffect(scale)
                .opacity(progress)
        )
    }
    
    private func calculateRotation(progress: Double, isVisible: Bool) -> Angle {
        let baseAngle: Double = isClockwise ? -90 : 90
        return .degrees(baseAngle + (baseAngle * progress))
    }
    
    private func calculateScale(progress: Double, isVisible: Bool) -> CGFloat {
        return isVisible ? CGFloat(0.8 + (0.2 * progress)) : CGFloat(1.2 - (0.2 * progress))
    }
}

/// Push transitions (slide with opacity)
public final class PushTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    private let direction: Edge
    
    public override init(effectType: TransitionSettings.TransitionEffectType) {
        self.direction = effectType == .pushLeft ? .leading : .trailing
        super.init(effectType: effectType)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        return .asymmetric(
            insertion: .move(edge: direction.opposite).combined(with: .opacity),
            removal: .move(edge: direction).combined(with: .opacity)
        )
    }
}

/// Crossfade transition (same as fade but with different timing)
public final class CrossfadeTransitionStrategy: BaseTransitionStrategy, @unchecked Sendable {
    public init() {
        super.init(effectType: .crossfade)
    }
    
    public override func createSwiftUITransition() -> AnyTransition {
        return .opacity
    }
    
    public override func getAnimation(duration: Double, easing: TransitionSettings.EasingFunction) -> Animation? {
        // Crossfade uses slightly different timing
        return .easeInOut(duration: duration * 1.2)
    }
}

// MARK: - Strategy Factory

/// Factory for creating transition strategies
public final class TransitionStrategyFactory {
    private static let strategies: [TransitionSettings.TransitionEffectType: TransitionStrategy] = [
        .none: NoneTransitionStrategy(),
        .fade: FadeTransitionStrategy(),
        .slideLeft: SlideTransitionStrategy(effectType: .slideLeft),
        .slideRight: SlideTransitionStrategy(effectType: .slideRight),
        .slideUp: SlideTransitionStrategy(effectType: .slideUp),
        .slideDown: SlideTransitionStrategy(effectType: .slideDown),
        .zoomIn: ScaleTransitionStrategy(effectType: .zoomIn),
        .zoomOut: ScaleTransitionStrategy(effectType: .zoomOut),
        .rotateClockwise: RotationTransitionStrategy(effectType: .rotateClockwise),
        .rotateCounterClockwise: RotationTransitionStrategy(effectType: .rotateCounterClockwise),
        .pushLeft: PushTransitionStrategy(effectType: .pushLeft),
        .pushRight: PushTransitionStrategy(effectType: .pushRight),
        .crossfade: CrossfadeTransitionStrategy()
    ]
    
    public static func strategy(for effectType: TransitionSettings.TransitionEffectType) -> TransitionStrategy {
        return strategies[effectType] ?? NoneTransitionStrategy()
    }
    
    public static func allStrategies() -> [TransitionStrategy] {
        return Array(strategies.values)
    }
}

// MARK: - Edge Extension

private extension Edge {
    var opposite: Edge {
        switch self {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top: return .bottom
        case .bottom: return .top
        }
    }
}