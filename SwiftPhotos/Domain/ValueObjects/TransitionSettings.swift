import Foundation
import SwiftUI

/// Screen transition effects configuration for slideshow
public struct TransitionSettings: Codable, Equatable, Sendable {
    /// Transition effect type
    public let effectType: TransitionEffectType
    
    /// Transition duration in seconds
    public let duration: Double
    
    /// Animation easing function
    public let easing: EasingFunction
    
    /// Effect intensity (0.0 to 1.0)
    public let intensity: Double
    
    /// Whether transitions are enabled
    public let isEnabled: Bool
    
    public init(
        effectType: TransitionEffectType = .fade,
        duration: Double = 0.5,
        easing: EasingFunction = .easeInOut,
        intensity: Double = 1.0,
        isEnabled: Bool = true
    ) {
        self.effectType = effectType
        self.duration = max(0.1, min(3.0, duration)) // Clamp between 0.1-3.0 seconds
        self.easing = easing
        self.intensity = max(0.0, min(1.0, intensity)) // Clamp between 0.0-1.0
        self.isEnabled = isEnabled
    }
    
    /// Transition effect types
    public enum TransitionEffectType: String, CaseIterable, Codable, Sendable {
        case none = "none"
        case fade = "fade"
        case slideLeft = "slideLeft"
        case slideRight = "slideRight" 
        case slideUp = "slideUp"
        case slideDown = "slideDown"
        case zoomIn = "zoomIn"
        case zoomOut = "zoomOut"
        case rotateClockwise = "rotateClockwise"
        case rotateCounterClockwise = "rotateCounterClockwise"
        case pushLeft = "pushLeft"
        case pushRight = "pushRight"
        case crossfade = "crossfade"
        
        public var displayName: String {
            switch self {
            case .none: return "None"
            case .fade: return "Fade"
            case .slideLeft: return "Slide Left"
            case .slideRight: return "Slide Right"
            case .slideUp: return "Slide Up"
            case .slideDown: return "Slide Down"
            case .zoomIn: return "Zoom In"
            case .zoomOut: return "Zoom Out"
            case .rotateClockwise: return "Rotate CW"
            case .rotateCounterClockwise: return "Rotate CCW"
            case .pushLeft: return "Push Left"
            case .pushRight: return "Push Right"
            case .crossfade: return "Crossfade"
            }
        }
        
        public var description: String {
            switch self {
            case .none: return "No transition effects"
            case .fade: return "Gradual fade in/out"
            case .slideLeft: return "Slide to the left"
            case .slideRight: return "Slide to the right"
            case .slideUp: return "Slide upward"
            case .slideDown: return "Slide downward"
            case .zoomIn: return "Zoom in effect"
            case .zoomOut: return "Zoom out effect"
            case .rotateClockwise: return "Rotate clockwise"
            case .rotateCounterClockwise: return "Rotate counter-clockwise"
            case .pushLeft: return "Push from right to left"
            case .pushRight: return "Push from left to right"
            case .crossfade: return "Smooth crossfade blend"
            }
        }
        
        public var icon: String {
            switch self {
            case .none: return "xmark.circle"
            case .fade: return "circle.dotted"
            case .slideLeft: return "arrow.left"
            case .slideRight: return "arrow.right"
            case .slideUp: return "arrow.up"
            case .slideDown: return "arrow.down"
            case .zoomIn: return "plus.magnifyingglass"
            case .zoomOut: return "minus.magnifyingglass"
            case .rotateClockwise: return "arrow.clockwise"
            case .rotateCounterClockwise: return "arrow.counterclockwise"
            case .pushLeft: return "rectangle.2.swap"
            case .pushRight: return "rectangle.2.swap"
            case .crossfade: return "overlay"
            }
        }
    }
    
    /// Animation easing functions
    public enum EasingFunction: String, CaseIterable, Codable, Sendable {
        case linear = "linear"
        case easeIn = "easeIn"
        case easeOut = "easeOut"
        case easeInOut = "easeInOut"
        case spring = "spring"
        
        public var displayName: String {
            switch self {
            case .linear: return "Linear"
            case .easeIn: return "Ease In"
            case .easeOut: return "Ease Out"
            case .easeInOut: return "Ease In-Out"
            case .spring: return "Spring"
            }
        }
        
        public var description: String {
            switch self {
            case .linear: return "Constant speed"
            case .easeIn: return "Start slow, accelerate"
            case .easeOut: return "Start fast, decelerate"
            case .easeInOut: return "Smooth start and end"
            case .spring: return "Bouncy spring effect"
            }
        }
        
        /// Convert to SwiftUI Animation
        public func toSwiftUIAnimation(duration: Double) -> Animation {
            switch self {
            case .linear:
                return .linear(duration: duration)
            case .easeIn:
                return .easeIn(duration: duration)
            case .easeOut:
                return .easeOut(duration: duration)
            case .easeInOut:
                return .easeInOut(duration: duration)
            case .spring:
                return .spring(duration: duration)
            }
        }
    }
    
    // MARK: - Preset Configurations
    
    /// No transition effects
    public static let none = TransitionSettings(
        effectType: .none,
        duration: 0.0,
        easing: .linear,
        intensity: 0.0,
        isEnabled: false
    )
    
    /// Simple fade transition
    public static let simpleFade = TransitionSettings(
        effectType: .fade,
        duration: 0.3,
        easing: .easeInOut,
        intensity: 1.0,
        isEnabled: true
    )
    
    /// Elegant slide transition
    public static let elegantSlide = TransitionSettings(
        effectType: .slideRight,
        duration: 0.6,
        easing: .easeInOut,
        intensity: 0.8,
        isEnabled: true
    )
    
    /// Dynamic zoom transition
    public static let dynamicZoom = TransitionSettings(
        effectType: .zoomIn,
        duration: 0.4,
        easing: .spring,
        intensity: 1.0,
        isEnabled: true
    )
    
    /// Smooth crossfade
    public static let smoothCrossfade = TransitionSettings(
        effectType: .crossfade,
        duration: 0.8,
        easing: .easeInOut,
        intensity: 0.9,
        isEnabled: true
    )
    
    /// Cinematic push effect
    public static let cinematicPush = TransitionSettings(
        effectType: .pushLeft,
        duration: 0.7,
        easing: .easeOut,
        intensity: 1.0,
        isEnabled: true
    )
    
    /// Default transition settings
    public static let `default` = simpleFade
}

