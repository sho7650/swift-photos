import Foundation
import CoreGraphics

// MARK: - Core Interaction Types

/// Types of interactions that can be detected
public enum InteractionType: String, CaseIterable, Codable, Sendable {
    case mouseMove = "mouseMove"
    case mouseClick = "mouseClick"
    case mouseScroll = "mouseScroll"
    case keyPress = "keyPress"
    case gesture = "gesture"
    case touch = "touch"
    case windowFocus = "windowFocus"
    case systemEvent = "systemEvent"
    
    public var priority: Int {
        switch self {
        case .gesture, .touch: return 100
        case .mouseClick: return 90
        case .keyPress: return 80
        case .mouseMove: return 70
        case .mouseScroll: return 60
        case .windowFocus: return 50
        case .systemEvent: return 10
        }
    }
    
    public var description: String {
        switch self {
        case .mouseMove: return "Mouse movement"
        case .mouseClick: return "Mouse click"
        case .mouseScroll: return "Mouse scroll"
        case .keyPress: return "Key press"
        case .gesture: return "Gesture input"
        case .touch: return "Touch input"
        case .windowFocus: return "Window focus change"
        case .systemEvent: return "System event"
        }
    }
}

/// Gesture types supported by the interaction system
public enum GestureType: String, CaseIterable, Codable, Sendable {
    case tap = "tap"
    case doubleTap = "doubleTap"
    case longPress = "longPress"
    case pan = "pan"
    case pinch = "pinch"
    case rotation = "rotation"
    case swipeLeft = "swipeLeft"
    case swipeRight = "swipeRight"
    case swipeUp = "swipeUp"
    case swipeDown = "swipeDown"
    case magnify = "magnify"
    case smartMagnify = "smartMagnify"
    
    public var isDirectional: Bool {
        switch self {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown, .pan:
            return true
        default:
            return false
        }
    }
    
    public var requiresMultiTouch: Bool {
        switch self {
        case .pinch, .rotation, .magnify:
            return true
        default:
            return false
        }
    }
}

/// Data associated with an interaction event
public struct InteractionData: Codable, Equatable, Sendable {
    public let timestamp: TimeInterval
    public let position: CGPoint?
    public let velocity: CGVector?
    public let pressure: Double?
    public let modifierFlags: UInt?
    public let gestureData: GestureData?
    public let keyCode: UInt16?
    public let customData: [String: String]?
    
    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        position: CGPoint? = nil,
        velocity: CGVector? = nil,
        pressure: Double? = nil,
        modifierFlags: UInt? = nil,
        gestureData: GestureData? = nil,
        keyCode: UInt16? = nil,
        customData: [String: String]? = nil
    ) {
        self.timestamp = timestamp
        self.position = position
        self.velocity = velocity
        self.pressure = pressure
        self.modifierFlags = modifierFlags
        self.gestureData = gestureData
        self.keyCode = keyCode
        self.customData = customData
    }
}

/// Specific data for gesture interactions
public struct GestureData: Codable, Equatable, Sendable {
    public let gestureType: GestureType
    public let phase: GesturePhase
    public let scale: Double?
    public let rotation: Double?
    public let translation: CGVector?
    public let touchCount: Int?
    
    public init(
        gestureType: GestureType,
        phase: GesturePhase,
        scale: Double? = nil,
        rotation: Double? = nil,
        translation: CGVector? = nil,
        touchCount: Int? = nil
    ) {
        self.gestureType = gestureType
        self.phase = phase
        self.scale = scale
        self.rotation = rotation
        self.translation = translation
        self.touchCount = touchCount
    }
}

/// Phases of gesture recognition
public enum GesturePhase: String, CaseIterable, Codable, Sendable {
    case began = "began"
    case changed = "changed"
    case ended = "ended"
    case cancelled = "cancelled"
    case failed = "failed"
    
    public var isActive: Bool {
        switch self {
        case .began, .changed:
            return true
        case .ended, .cancelled, .failed:
            return false
        }
    }
}

/// Complete interaction event
public struct Interaction: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let type: InteractionType
    public let data: InteractionData
    public let source: InteractionSource
    public let confidence: Double
    
    public init(
        id: UUID = UUID(),
        type: InteractionType,
        data: InteractionData,
        source: InteractionSource,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.source = source
        self.confidence = max(0.0, min(1.0, confidence))
    }
    
    /// Check if this interaction occurred recently
    public func isRecent(within interval: TimeInterval) -> Bool {
        let now = Date().timeIntervalSince1970
        return (now - data.timestamp) <= interval
    }
    
    /// Get the position of this interaction if available
    public var position: CGPoint? {
        return data.position
    }
    
    /// Get the velocity of this interaction if available
    public var velocity: CGVector? {
        return data.velocity
    }
    
    /// Check if this interaction involves a specific gesture
    public func involvesGesture(_ gestureType: GestureType) -> Bool {
        return type == .gesture && data.gestureData?.gestureType == gestureType
    }
}

/// Source of an interaction event
public enum InteractionSource: String, CaseIterable, Codable, Sendable {
    case mouse = "mouse"
    case trackpad = "trackpad"
    case keyboard = "keyboard"
    case touchBar = "touchBar"
    case systemAPI = "systemAPI"
    case external = "external"
    case synthesized = "synthesized"
    
    public var reliability: Double {
        switch self {
        case .mouse, .trackpad, .keyboard: return 1.0
        case .touchBar, .systemAPI: return 0.9
        case .external: return 0.7
        case .synthesized: return 0.5
        }
    }
    
    public var supportsGestures: Bool {
        switch self {
        case .trackpad, .touchBar: return true
        case .mouse, .keyboard, .systemAPI, .external, .synthesized: return false
        }
    }
}

// MARK: - Configuration Types

/// Configuration for interaction detection
public struct InteractionConfiguration: Codable, Equatable, Sendable {
    public let enabledTypes: Set<InteractionType>
    public let sensitivity: Double
    public let minimumConfidence: Double
    public let debounceInterval: TimeInterval
    public let maxEventRate: Double
    public let enableGestures: Bool
    public let gestureConfiguration: GestureConfiguration
    
    public init(
        enabledTypes: Set<InteractionType> = Set(InteractionType.allCases),
        sensitivity: Double = 1.0,
        minimumConfidence: Double = 0.5,
        debounceInterval: TimeInterval = 0.016, // ~60fps
        maxEventRate: Double = 120.0, // events per second
        enableGestures: Bool = true,
        gestureConfiguration: GestureConfiguration = GestureConfiguration()
    ) {
        self.enabledTypes = enabledTypes
        self.sensitivity = max(0.1, min(10.0, sensitivity))
        self.minimumConfidence = max(0.0, min(1.0, minimumConfidence))
        self.debounceInterval = max(0.001, debounceInterval)
        self.maxEventRate = max(1.0, min(1000.0, maxEventRate))
        self.enableGestures = enableGestures
        self.gestureConfiguration = gestureConfiguration
    }
    
    /// Default configuration for performance-focused detection
    public static let performance: InteractionConfiguration = InteractionConfiguration(
        enabledTypes: [.mouseMove, .mouseClick, .keyPress],
        sensitivity: 0.8,
        debounceInterval: 0.033, // ~30fps
        maxEventRate: 60.0,
        enableGestures: false
    )
    
    /// Default configuration for gesture-rich interaction
    public static let gestureRich: InteractionConfiguration = InteractionConfiguration(
        enabledTypes: Set(InteractionType.allCases),
        sensitivity: 1.2,
        debounceInterval: 0.008, // ~120fps
        maxEventRate: 240.0,
        enableGestures: true
    )
    
    /// Configuration for accessibility-focused interaction
    public static let accessibility: InteractionConfiguration = InteractionConfiguration(
        enabledTypes: [.mouseClick, .keyPress, .gesture],
        sensitivity: 1.5,
        minimumConfidence: 0.3,
        debounceInterval: 0.05,
        maxEventRate: 30.0,
        enableGestures: true,
        gestureConfiguration: GestureConfiguration.accessibility
    )
}

/// Configuration for gesture recognition
public struct GestureConfiguration: Codable, Equatable, Sendable {
    public let enabledGestures: Set<GestureType>
    public let minimumTouchCount: Int
    public let maximumTouchCount: Int
    public let recognitionDelay: TimeInterval
    public let simultaneousRecognition: Bool
    public let pressureSupport: Bool
    
    public init(
        enabledGestures: Set<GestureType> = Set(GestureType.allCases),
        minimumTouchCount: Int = 1,
        maximumTouchCount: Int = 5,
        recognitionDelay: TimeInterval = 0.1,
        simultaneousRecognition: Bool = true,
        pressureSupport: Bool = true
    ) {
        self.enabledGestures = enabledGestures
        self.minimumTouchCount = max(1, minimumTouchCount)
        self.maximumTouchCount = max(minimumTouchCount, maximumTouchCount)
        self.recognitionDelay = max(0.0, recognitionDelay)
        self.simultaneousRecognition = simultaneousRecognition
        self.pressureSupport = pressureSupport
    }
    
    /// Configuration optimized for accessibility
    public static let accessibility: GestureConfiguration = GestureConfiguration(
        enabledGestures: [.tap, .doubleTap, .longPress, .pan],
        minimumTouchCount: 1,
        maximumTouchCount: 2,
        recognitionDelay: 0.2,
        simultaneousRecognition: false,
        pressureSupport: false
    )
    
    /// Configuration for advanced gesture users
    public static let advanced: GestureConfiguration = GestureConfiguration(
        enabledGestures: Set(GestureType.allCases),
        minimumTouchCount: 1,
        maximumTouchCount: 10,
        recognitionDelay: 0.05,
        simultaneousRecognition: true,
        pressureSupport: true
    )
}

// MARK: - Error Types

/// Errors that can occur during interaction processing
public enum InteractionError: LocalizedError, Equatable, Sendable {
    case detectionFailed(reason: String)
    case configurationInvalid(parameter: String)
    case rateLimitExceeded(currentRate: Double, maxRate: Double)
    case resourceUnavailable(resource: String)
    case gestureRecognitionFailed(gesture: GestureType)
    case systemPermissionDenied(permission: String)
    
    public var errorDescription: String? {
        switch self {
        case .detectionFailed(let reason):
            return "Interaction detection failed: \(reason)"
        case .configurationInvalid(let parameter):
            return "Invalid configuration parameter: \(parameter)"
        case .rateLimitExceeded(let currentRate, let maxRate):
            return "Rate limit exceeded: \(currentRate) > \(maxRate) events/second"
        case .resourceUnavailable(let resource):
            return "Required resource unavailable: \(resource)"
        case .gestureRecognitionFailed(let gesture):
            return "Failed to recognize gesture: \(gesture.rawValue)"
        case .systemPermissionDenied(let permission):
            return "System permission denied: \(permission)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .detectionFailed:
            return "Check system permissions and try restarting detection"
        case .configurationInvalid:
            return "Review configuration parameters and correct invalid values"
        case .rateLimitExceeded:
            return "Reduce event generation rate or increase rate limit"
        case .resourceUnavailable:
            return "Ensure required system resources are available"
        case .gestureRecognitionFailed:
            return "Try using simpler gestures or adjust recognition sensitivity"
        case .systemPermissionDenied:
            return "Grant required permissions in System Preferences"
        }
    }
}

// MARK: - Observer Protocol

/// Protocol for observing interaction events
@MainActor
public protocol InteractionObserver: AnyObject {
    /// Called when an interaction is detected
    func interactionOccurred(_ interaction: Interaction)
    
    /// Called when interaction detection encounters an error
    func interactionDetectionFailed(_ error: InteractionError)
    
    /// Called when the interaction system configuration changes
    func interactionConfigurationDidChange(_ configuration: InteractionConfiguration)
}

// MARK: - Utility Extensions

extension Set where Element == InteractionType {
    /// Check if mouse interactions are enabled
    public var includesMouseInteractions: Bool {
        return contains(.mouseMove) || contains(.mouseClick) || contains(.mouseScroll)
    }
    
    /// Check if keyboard interactions are enabled
    public var includesKeyboardInteractions: Bool {
        return contains(.keyPress)
    }
    
    /// Check if gesture interactions are enabled
    public var includesGestureInteractions: Bool {
        return contains(.gesture) || contains(.touch)
    }
    
    /// Get enabled interaction types with their priorities
    public var prioritizedTypes: [(InteractionType, Int)] {
        return self.map { ($0, $0.priority) }.sorted { $0.1 > $1.1 }
    }
}

extension Set where Element == GestureType {
    /// Get gestures that require multi-touch
    public var multiTouchGestures: Set<GestureType> {
        return Set(self.filter { $0.requiresMultiTouch })
    }
    
    /// Get directional gestures
    public var directionalGestures: Set<GestureType> {
        return Set(self.filter { $0.isDirectional })
    }
    
    /// Check if advanced gestures are enabled
    public var includesAdvancedGestures: Bool {
        return contains(.pinch) || contains(.rotation) || contains(.magnify)
    }
}