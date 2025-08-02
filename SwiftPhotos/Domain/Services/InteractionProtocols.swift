import Foundation
import CoreGraphics
import SwiftUI

/// Custom EdgeInsets type for cross-platform compatibility
public struct EdgeInsets: Codable, Equatable, Sendable {
    public let top: Double
    public let leading: Double
    public let bottom: Double
    public let trailing: Double
    
    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
    
    public static let zero: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

// MARK: - Core Interaction Detection Protocol

/// Primary protocol for unified interaction detection across all input methods
@MainActor
public protocol InteractionDetecting: AnyObject {
    /// Delegate to receive interaction events and errors
    var delegate: InteractionDetectorDelegate? { get set }
    
    /// Current detection state
    var isEnabled: Bool { get set }
    
    /// Detection configuration
    var configuration: InteractionConfiguration { get set }
    
    /// Current active observers
    var observerCount: Int { get }
    
    /// Start interaction detection
    func startDetection() throws
    
    /// Stop interaction detection
    func stopDetection()
    
    /// Manually inject an interaction (for testing or external sources)
    func detectInteraction(type: InteractionType, data: InteractionData)
    
    /// Add an observer for interaction events
    func addObserver(_ observer: InteractionObserver)
    
    /// Remove a specific observer
    func removeObserver(_ observer: InteractionObserver)
    
    /// Remove all observers
    func removeAllObservers()
    
    /// Get recent interactions within a time window
    func getRecentInteractions(within interval: TimeInterval) -> [Interaction]
    
    /// Update configuration and restart detection if needed
    func updateConfiguration(_ configuration: InteractionConfiguration) throws
}

/// Delegate protocol for interaction detection events
@MainActor
public protocol InteractionDetectorDelegate: AnyObject {
    /// Called when a new interaction is detected
    func detectorDidDetectInteraction(_ detector: InteractionDetecting, interaction: Interaction)
    
    /// Called when detection encounters an error
    func detectorDidEncounterError(_ detector: InteractionDetecting, error: InteractionError)
    
    /// Called when detection starts successfully
    func detectorDidStartDetection(_ detector: InteractionDetecting)
    
    /// Called when detection stops
    func detectorDidStopDetection(_ detector: InteractionDetecting)
    
    /// Called when configuration changes
    func detectorDidUpdateConfiguration(_ detector: InteractionDetecting, configuration: InteractionConfiguration)
}

// MARK: - Mouse Tracking Protocol

/// Enhanced mouse tracking with velocity and zone detection
@MainActor
public protocol MouseTracking: AnyObject {
    /// Current tracking configuration
    var configuration: MouseTrackingConfiguration { get set }
    
    /// Current mouse position in global coordinates
    var currentPosition: CGPoint { get }
    
    /// Current mouse velocity vector
    var velocity: CGVector { get }
    
    /// Current acceleration
    var acceleration: Double { get }
    
    /// Whether tracking is currently active
    var isTracking: Bool { get }
    
    /// Tracking zones (if any)
    var trackingZones: [MouseTrackingZone] { get }
    
    /// Start mouse tracking
    func startTracking() throws
    
    /// Stop mouse tracking
    func stopTracking()
    
    /// Add a tracking zone for specific area monitoring
    func addTrackingZone(_ zone: MouseTrackingZone)
    
    /// Remove a specific tracking zone
    func removeTrackingZone(id: UUID)
    
    /// Clear all tracking zones
    func clearTrackingZones()
    
    /// Check if a point is within any tracking zone
    func isPointInTrackingZone(_ point: CGPoint) -> MouseTrackingZone?
    
    /// Get velocity history for the specified duration
    func getVelocityHistory(duration: TimeInterval) -> [VelocityDataPoint]
}

/// Configuration for mouse tracking behavior
public struct MouseTrackingConfiguration: Codable, Equatable, Sendable {
    public let sensitivity: Double
    public let velocitySmoothing: Double
    public let accelerationThreshold: Double
    public let samplingRate: Double
    public let enableZoneDetection: Bool
    public let enableVelocityTracking: Bool
    public let historyDuration: TimeInterval
    
    public init(
        sensitivity: Double = 1.0,
        velocitySmoothing: Double = 0.8,
        accelerationThreshold: Double = 100.0,
        samplingRate: Double = 60.0,
        enableZoneDetection: Bool = true,
        enableVelocityTracking: Bool = true,
        historyDuration: TimeInterval = 2.0
    ) {
        self.sensitivity = max(0.1, min(10.0, sensitivity))
        self.velocitySmoothing = max(0.0, min(1.0, velocitySmoothing))
        self.accelerationThreshold = max(0.0, accelerationThreshold)
        self.samplingRate = max(1.0, min(240.0, samplingRate))
        self.enableZoneDetection = enableZoneDetection
        self.enableVelocityTracking = enableVelocityTracking
        self.historyDuration = max(0.1, min(10.0, historyDuration))
    }
    
    /// High-performance configuration for gaming-like responsiveness
    public static let highPerformance: MouseTrackingConfiguration = MouseTrackingConfiguration(
        sensitivity: 1.5,
        velocitySmoothing: 0.6,
        samplingRate: 120.0,
        historyDuration: 1.0
    )
    
    /// Battery-optimized configuration for longer usage
    public static let batteryOptimized: MouseTrackingConfiguration = MouseTrackingConfiguration(
        sensitivity: 0.8,
        velocitySmoothing: 0.9,
        samplingRate: 30.0,
        enableVelocityTracking: false,
        historyDuration: 0.5
    )
}

/// Tracking zone for area-specific mouse detection
public struct MouseTrackingZone: Identifiable, Codable, Equatable {
    public let id: UUID
    public let frame: CGRect
    public let sensitivity: Double
    public let name: String
    public let isEnabled: Bool
    public let priority: Int
    
    public init(
        id: UUID = UUID(),
        frame: CGRect,
        sensitivity: Double = 1.0,
        name: String = "",
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.frame = frame
        self.sensitivity = max(0.1, min(10.0, sensitivity))
        self.name = name
        self.isEnabled = isEnabled
        self.priority = priority
    }
    
    /// Check if a point is within this zone
    public func contains(_ point: CGPoint) -> Bool {
        return isEnabled && frame.contains(point)
    }
}

/// Data point for velocity tracking
public struct VelocityDataPoint: Codable, Equatable {
    public let timestamp: TimeInterval
    public let position: CGPoint
    public let velocity: CGVector
    public let acceleration: Double
    
    public init(timestamp: TimeInterval, position: CGPoint, velocity: CGVector, acceleration: Double) {
        self.timestamp = timestamp
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
    }
}

// MARK: - Adaptive Timer Protocol

/// Smart timer with context-aware adaptation capabilities
@MainActor
public protocol AdaptiveTimerProviding: AnyObject {
    /// Timer delegate for receiving events
    var delegate: AdaptiveTimerDelegate? { get set }
    
    /// Current timer state
    var isRunning: Bool { get }
    var isPaused: Bool { get }
    
    /// Time information
    var remainingTime: TimeInterval { get }
    var elapsedTime: TimeInterval { get }
    var totalDuration: TimeInterval { get }
    
    /// Adaptation settings
    var adaptationEnabled: Bool { get set }
    var currentConfiguration: TimerConfiguration { get }
    
    /// Start timer with specified configuration
    func start(with configuration: TimerConfiguration) throws
    
    /// Pause the timer (can be resumed)
    func pause()
    
    /// Resume a paused timer
    func resume()
    
    /// Stop the timer completely
    func stop()
    
    /// Extend the timer by additional duration
    func extend(by duration: TimeInterval)
    
    /// Adapt timing based on context
    func adaptTiming(based context: TimingContext)
    
    /// Reset timer to original configuration
    func reset()
    
    /// Get adaptation history
    func getAdaptationHistory(limit: Int) -> [TimingAdaptation]
}

/// Delegate for adaptive timer events
@MainActor
public protocol AdaptiveTimerDelegate: AnyObject {
    /// Called when the timer fires
    func timerDidFire(_ timer: AdaptiveTimerProviding)
    
    /// Called when timer adapts its duration
    func timerDidAdapt(_ timer: AdaptiveTimerProviding, newDuration: TimeInterval, reason: AdaptationReason)
    
    /// Called when timer is paused
    func timerWasPaused(_ timer: AdaptiveTimerProviding)
    
    /// Called when timer is resumed
    func timerWasResumed(_ timer: AdaptiveTimerProviding)
    
    /// Called when timer is stopped
    func timerWasStopped(_ timer: AdaptiveTimerProviding)
    
    /// Called when timer encounters an error
    func timerDidEncounterError(_ timer: AdaptiveTimerProviding, error: TimerError)
}

/// Configuration for adaptive timer behavior
public struct TimerConfiguration: Codable, Equatable {
    public let baseDuration: TimeInterval
    public let minimumDuration: TimeInterval
    public let maximumDuration: TimeInterval
    public let adaptationSensitivity: Double
    public let learningEnabled: Bool
    public let coalescingEnabled: Bool
    public let backgroundOptimization: Bool
    
    public init(
        baseDuration: TimeInterval,
        minimumDuration: TimeInterval? = nil,
        maximumDuration: TimeInterval? = nil,
        adaptationSensitivity: Double = 1.0,
        learningEnabled: Bool = true,
        coalescingEnabled: Bool = true,
        backgroundOptimization: Bool = true
    ) {
        self.baseDuration = max(0.1, baseDuration)
        self.minimumDuration = minimumDuration ?? (baseDuration * 0.5)
        self.maximumDuration = maximumDuration ?? (baseDuration * 2.0)
        self.adaptationSensitivity = max(0.0, min(2.0, adaptationSensitivity))
        self.learningEnabled = learningEnabled
        self.coalescingEnabled = coalescingEnabled
        self.backgroundOptimization = backgroundOptimization
    }
    
    /// Configuration for UI auto-hide timers
    public static func autoHide(duration: TimeInterval) -> TimerConfiguration {
        return TimerConfiguration(
            baseDuration: duration,
            minimumDuration: duration * 0.3,
            maximumDuration: duration * 3.0,
            adaptationSensitivity: 1.2,
            learningEnabled: true
        )
    }
    
    /// Configuration for performance-critical timers
    public static func performance(duration: TimeInterval) -> TimerConfiguration {
        return TimerConfiguration(
            baseDuration: duration,
            minimumDuration: duration * 0.8,
            maximumDuration: duration * 1.2,
            adaptationSensitivity: 0.5,
            learningEnabled: false,
            coalescingEnabled: true
        )
    }
}

/// Context information for timer adaptation
public struct TimingContext: Codable, Equatable {
    public let userActivity: UserActivityLevel
    public let appState: AppState
    public let systemLoad: SystemLoadLevel
    public let batteryLevel: Double?
    public let interactionCount: Int // Simplified from full interaction array
    public let customFactors: [String: Double]
    
    public init(
        userActivity: UserActivityLevel,
        appState: AppState,
        systemLoad: SystemLoadLevel = .normal,
        batteryLevel: Double? = nil,
        recentInteractions: [Interaction] = [],
        customFactors: [String: Double] = [:]
    ) {
        self.userActivity = userActivity
        self.appState = appState
        self.systemLoad = systemLoad
        self.batteryLevel = batteryLevel.map { max(0.0, min(1.0, $0)) }
        self.interactionCount = recentInteractions.count
        self.customFactors = customFactors
    }
    
    /// Computed property for backwards compatibility
    public var recentInteractions: [Interaction] { return [] }
}

/// User activity levels for adaptation
public enum UserActivityLevel: String, CaseIterable, Codable {
    case idle = "idle"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case intensive = "intensive"
    
    public var adaptationFactor: Double {
        switch self {
        case .idle: return 1.5      // Longer delays when idle
        case .light: return 1.2
        case .moderate: return 1.0  // Baseline
        case .active: return 0.8
        case .intensive: return 0.6 // Shorter delays when very active
        }
    }
}

/// Application states affecting timing
public enum AppState: String, CaseIterable, Codable {
    case foreground = "foreground"
    case background = "background"
    case inactive = "inactive"
    case minimized = "minimized"
    case fullscreen = "fullscreen"
    case slideshow = "slideshow"
    
    public var adaptationFactor: Double {
        switch self {
        case .foreground, .fullscreen: return 1.0
        case .slideshow: return 0.7 // Faster response during slideshow
        case .inactive: return 1.3
        case .background, .minimized: return 2.0 // Much longer delays when not visible
        }
    }
}

/// System load levels affecting performance
public enum SystemLoadLevel: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    public var adaptationFactor: Double {
        switch self {
        case .low: return 0.9
        case .normal: return 1.0
        case .high: return 1.2   // Longer delays under load
        case .critical: return 1.5
        }
    }
}

/// Reasons for timer adaptation
public enum AdaptationReason: String, CaseIterable, Codable {
    case userBehavior = "userBehavior"
    case systemLoad = "systemLoad"
    case batteryOptimization = "batteryOptimization"
    case appState = "appState"
    case learningAlgorithm = "learningAlgorithm"
    case manual = "manual"
    
    public var description: String {
        switch self {
        case .userBehavior: return "Adapted based on user interaction patterns"
        case .systemLoad: return "Adapted due to system performance constraints"
        case .batteryOptimization: return "Adapted to optimize battery usage"
        case .appState: return "Adapted due to application state change"
        case .learningAlgorithm: return "Adapted by machine learning algorithm"
        case .manual: return "Manually adjusted"
        }
    }
}

/// Record of timing adaptation
public struct TimingAdaptation: Codable, Equatable {
    public let timestamp: TimeInterval
    public let previousDuration: TimeInterval
    public let newDuration: TimeInterval
    public let reason: AdaptationReason
    public let context: TimingContext
    public let confidence: Double
    
    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        previousDuration: TimeInterval,
        newDuration: TimeInterval,
        reason: AdaptationReason,
        context: TimingContext,
        confidence: Double = 1.0
    ) {
        self.timestamp = timestamp
        self.previousDuration = previousDuration
        self.newDuration = newDuration
        self.reason = reason
        self.context = context
        self.confidence = max(0.0, min(1.0, confidence))
    }
    
    /// Calculate the adaptation magnitude
    public var adaptationMagnitude: Double {
        return abs(newDuration - previousDuration) / previousDuration
    }
    
    /// Check if this was a significant adaptation
    public var isSignificant: Bool {
        return adaptationMagnitude > 0.2 // 20% change threshold
    }
}

/// Errors that can occur with adaptive timers
public enum TimerError: LocalizedError, Equatable {
    case configurationInvalid(parameter: String)
    case systemResourceUnavailable
    case adaptationFailed(reason: String)
    case timerNotRunning
    case timerAlreadyRunning
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid(let parameter):
            return "Invalid timer configuration: \(parameter)"
        case .systemResourceUnavailable:
            return "System timer resources unavailable"
        case .adaptationFailed(let reason):
            return "Timer adaptation failed: \(reason)"
        case .timerNotRunning:
            return "Operation requires running timer"
        case .timerAlreadyRunning:
            return "Timer is already running"
        }
    }
}

// MARK: - Interaction Zone Protocol

/// Protocol for managing invisible interaction zones with gesture detection
@MainActor
public protocol InteractionZoneProviding: AnyObject {
    /// Current interaction zones
    var zones: [InteractionZone] { get }
    
    /// Gesture configuration for zone detection
    var gestureConfiguration: GestureConfiguration { get set }
    
    /// Whether zone detection is enabled
    var isEnabled: Bool { get set }
    
    /// Add a new interaction zone
    func addZone(_ zone: InteractionZone)
    
    /// Remove a zone by ID
    func removeZone(id: UUID)
    
    /// Enable a specific zone
    func enableZone(id: UUID)
    
    /// Disable a specific zone
    func disableZone(id: UUID)
    
    /// Update an existing zone
    func updateZone(_ zone: InteractionZone)
    
    /// Clear all zones
    func clearAllZones()
}

/// Interaction zone definition for gesture detection areas
public struct InteractionZone: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let frame: CGRect
    public let sensitivity: Double
    public let name: String
    public let isEnabled: Bool
    public let priority: Int
    public let allowedGestures: Set<GestureType>
    
    public init(
        id: UUID = UUID(),
        frame: CGRect,
        sensitivity: Double = 1.0,
        name: String = "",
        isEnabled: Bool = true,
        priority: Int = 0,
        allowedGestures: Set<GestureType> = Set(GestureType.allCases)
    ) {
        self.id = id
        self.frame = frame
        self.sensitivity = max(0.1, min(10.0, sensitivity))
        self.name = name
        self.isEnabled = isEnabled
        self.priority = priority
        self.allowedGestures = allowedGestures
    }
    
    /// Check if a point is within this zone
    public func contains(_ point: CGPoint) -> Bool {
        return isEnabled && frame.contains(point)
    }
    
    /// Create a zone for common UI areas
    public static func controlsZone(frame: CGRect) -> InteractionZone {
        return InteractionZone(
            frame: frame,
            sensitivity: 1.2,
            name: "Controls Zone",
            allowedGestures: [.tap, .doubleTap, .longPress]
        )
    }
    
    /// Create a zone for gesture navigation
    public static func navigationZone(frame: CGRect, allowSwipe: Bool = true) -> InteractionZone {
        var gestures: Set<GestureType> = [.tap, .pan]
        if allowSwipe {
            gestures.formUnion([.swipeLeft, .swipeRight, .swipeUp, .swipeDown])
        }
        
        return InteractionZone(
            frame: frame,
            sensitivity: 0.8,
            name: "Navigation Zone",
            allowedGestures: gestures
        )
    }
    
    /// Create a zone for pinch/zoom gestures
    public static func zoomZone(frame: CGRect) -> InteractionZone {
        return InteractionZone(
            frame: frame,
            sensitivity: 1.0,
            name: "Zoom Zone",
            allowedGestures: [.pinch, .magnify, .smartMagnify, .doubleTap]
        )
    }
}

// MARK: - Position Management Protocol

/// Protocol for managing overlay positioning with intelligent placement
public protocol PositionManaging: AnyObject {
    /// Current positioning strategy
    var strategy: PositioningStrategy { get set }
    
    /// Position calculation configuration
    var configuration: PositionConfiguration { get set }
    
    /// Current screen bounds
    var screenBounds: CGRect { get }
    
    /// Active position constraints
    var constraints: [PositionConstraint] { get set }
    
    /// Calculate optimal position for an overlay
    func calculatePosition(for overlay: OverlayType, in bounds: CGRect) -> CGPoint
    
    /// Validate a proposed position
    func validatePosition(_ position: CGPoint, for overlay: OverlayType, in bounds: CGRect) -> ValidationResult
    
    /// Animate overlay to a new position
    func animateToPosition(_ position: CGPoint, overlay: OverlayType, duration: TimeInterval, completion: @escaping () -> Void)
    
    /// Add position observer
    func addPositionObserver(_ observer: PositionObserver)
    
    /// Remove position observer  
    func removePositionObserver(_ observer: PositionObserver)
    
    /// Handle screen configuration changes
    func screenConfigurationDidChange(_ newBounds: CGRect)
}

/// Strategy for calculating overlay positions
public protocol PositioningStrategy {
    /// Calculate position for an overlay type
    func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint
    
    /// Validate if a position is acceptable
    func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool
    
    /// Get preferred positioning zones
    func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect]
}

/// Types of overlays that can be positioned
public enum OverlayType: String, CaseIterable, Codable {
    case controls = "controls"
    case information = "information"
    case progress = "progress"
    case menu = "menu"
    case tooltip = "tooltip"
    case notification = "notification"
    
    public var defaultSize: CGSize {
        switch self {
        case .controls: return CGSize(width: 200, height: 60)
        case .information: return CGSize(width: 300, height: 200)
        case .progress: return CGSize(width: 250, height: 8)
        case .menu: return CGSize(width: 150, height: 100)
        case .tooltip: return CGSize(width: 120, height: 30)
        case .notification: return CGSize(width: 300, height: 80)
        }
    }
    
    public var priority: Int {
        switch self {
        case .notification: return 100
        case .tooltip: return 90
        case .menu: return 80
        case .controls: return 70
        case .progress: return 60
        case .information: return 50
        }
    }
}

/// Observer protocol for position changes
@MainActor
public protocol PositionObserver: AnyObject, Sendable {
    func positionDidChange(overlay: OverlayType, from oldPosition: CGPoint, to newPosition: CGPoint)
    func positionValidationFailed(overlay: OverlayType, invalidPosition: CGPoint, reason: String)
}

// MARK: - Supporting Types

/// Configuration for position calculations
public struct PositionConfiguration: Codable, Equatable {
    public let margins: EdgeInsets
    public let minimumSpacing: Double
    public let preferredAlignment: PositionAlignment
    public let allowOverlap: Bool
    public let adaptToScreenSize: Bool
    public let animationDuration: TimeInterval
    
    public init(
        margins: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        minimumSpacing: Double = 10.0,
        preferredAlignment: PositionAlignment = .center,
        allowOverlap: Bool = false,
        adaptToScreenSize: Bool = true,
        animationDuration: TimeInterval = 0.3
    ) {
        self.margins = margins
        self.minimumSpacing = max(0.0, minimumSpacing)
        self.preferredAlignment = preferredAlignment
        self.allowOverlap = allowOverlap
        self.adaptToScreenSize = adaptToScreenSize
        self.animationDuration = max(0.0, animationDuration)
    }
}

/// Position alignment preferences
public enum PositionAlignment: String, CaseIterable, Codable {
    case topLeading = "topLeading"
    case top = "top"
    case topTrailing = "topTrailing"
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"
    case bottomLeading = "bottomLeading"
    case bottom = "bottom"
    case bottomTrailing = "bottomTrailing"
}

/// Position constraint types
public struct PositionConstraint: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: ConstraintType
    public let area: CGRect?
    public let priority: Int
    public let isEnabled: Bool
    
    public init(id: UUID = UUID(), type: ConstraintType, area: CGRect? = nil, priority: Int = 0, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.area = area
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

/// Types of position constraints
public enum ConstraintType: String, CaseIterable, Codable {
    case avoidArea = "avoidArea"
    case preferArea = "preferArea"
    case stayWithinBounds = "stayWithinBounds"
    case maintainAspectRatio = "maintainAspectRatio"
    case minimumDistance = "minimumDistance"
}

/// Constraints for position validation
public struct PositionConstraints: Codable, Equatable {
    public let bounds: CGRect
    public let obstacles: [CGRect]
    public let margins: EdgeInsets
    public let minimumSpacing: Double
    
    public init(bounds: CGRect, obstacles: [CGRect] = [], margins: EdgeInsets = EdgeInsets(), minimumSpacing: Double = 10.0) {
        self.bounds = bounds
        self.obstacles = obstacles
        self.margins = margins
        self.minimumSpacing = minimumSpacing
    }
}

/// Result of position validation
public struct ValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let adjustedPosition: CGPoint?
    public let violations: [String]
    
    public init(isValid: Bool, adjustedPosition: CGPoint? = nil, violations: [String] = []) {
        self.isValid = isValid
        self.adjustedPosition = adjustedPosition
        self.violations = violations
    }
    
    public static let valid: ValidationResult = ValidationResult(isValid: true)
    
    public static func invalid(violations: [String]) -> ValidationResult {
        return ValidationResult(isValid: false, violations: violations)
    }
    
    public static func adjusted(to position: CGPoint, violations: [String] = []) -> ValidationResult {
        return ValidationResult(isValid: true, adjustedPosition: position, violations: violations)
    }
}