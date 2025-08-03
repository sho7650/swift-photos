import Foundation
import SwiftUI

/// Comprehensive configuration for multi-touch trackpad gesture support
public struct MultiTouchGestureConfiguration: Codable, Sendable {
    
    // MARK: - Basic Gesture Settings
    
    /// Enable/disable pinch-to-zoom gesture
    public var enablePinchToZoom: Bool = true
    
    /// Enable/disable rotation gesture
    public var enableRotation: Bool = true
    
    /// Enable/disable swipe gestures
    public var enableSwipeGestures: Bool = true
    
    /// Enable/disable smart magnify (double-tap zoom)
    public var enableSmartMagnify: Bool = true
    
    /// Enable/disable three-finger gestures
    public var enableThreeFingerGestures: Bool = false
    
    /// Enable/disable force touch gestures
    public var enableForceTouchGestures: Bool = false
    
    // MARK: - Sensitivity Settings
    
    /// Minimum scale change to register a pinch gesture (0.01 - 1.0)
    public var pinchSensitivity: Double = 0.05
    
    /// Minimum rotation angle in degrees to register rotation (1.0 - 45.0)
    public var rotationSensitivity: Double = 5.0
    
    /// Minimum velocity for swipe recognition (pixels per second)
    public var swipeVelocityThreshold: Double = 150.0
    
    /// Minimum distance for drag recognition (pixels)
    public var dragDistanceThreshold: Double = 10.0
    
    /// Trackpad pressure sensitivity for force touch (0.1 - 1.0)
    public var pressureSensitivity: Double = 0.7
    
    // MARK: - Timing Settings
    
    /// Maximum time between gesture start and end (seconds)
    public var gestureTimeout: TimeInterval = 2.0
    
    /// Debounce interval between similar gestures (seconds)
    public var debounceInterval: TimeInterval = 0.1
    
    /// Smart magnify double-tap interval (seconds)
    public var smartMagnifyInterval: TimeInterval = 0.3
    
    // MARK: - Zoom and Scale Settings
    
    /// Minimum zoom scale factor
    public var minimumZoomScale: Double = 0.1
    
    /// Maximum zoom scale factor
    public var maximumZoomScale: Double = 10.0
    
    /// Default zoom increment for smart magnify
    public var smartMagnifyZoomFactor: Double = 2.0
    
    /// Zoom animation duration (seconds)
    public var zoomAnimationDuration: TimeInterval = 0.3
    
    // MARK: - Navigation Settings
    
    /// Enable swipe navigation between photos
    public var enableSwipeNavigation: Bool = true
    
    /// Minimum swipe distance for navigation (percentage of view width)
    public var navigationSwipeThreshold: Double = 0.3
    
    /// Enable rubber band effect for over-swipe
    public var enableRubberBandEffect: Bool = true
    
    /// Rubber band resistance factor (0.1 - 1.0)
    public var rubberBandResistance: Double = 0.6
    
    // MARK: - Advanced Gesture Settings
    
    /// Enable simultaneous gesture recognition
    public var enableSimultaneousGestures: Bool = true
    
    /// Maximum number of concurrent gestures
    public var maxConcurrentGestures: Int = 3
    
    /// Enable gesture prediction and smoothing
    public var enableGestureSmoothing: Bool = true
    
    /// Gesture smoothing factor (0.1 - 1.0)
    public var gestureSmoothingFactor: Double = 0.8
    
    // MARK: - Accessibility Settings
    
    /// Enable larger touch targets for accessibility
    public var enableLargeTouchTargets: Bool = false
    
    /// Enable gesture assistance (guided gestures)
    public var enableGestureAssistance: Bool = false
    
    /// Enable audio feedback for gestures
    public var enableAudioFeedback: Bool = false
    
    /// Enable haptic feedback for gestures (if supported)
    public var enableHapticFeedback: Bool = false
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Preset Configurations
    
    /// Conservative gesture configuration with basic gestures only
    public static let conservative: MultiTouchGestureConfiguration = {
        var config = MultiTouchGestureConfiguration()
        config.enableRotation = false
        config.enableThreeFingerGestures = false
        config.enableForceTouchGestures = false
        config.pinchSensitivity = 0.1
        config.rotationSensitivity = 10.0
        config.swipeVelocityThreshold = 200.0
        config.enableSimultaneousGestures = false
        return config
    }()
    
    /// Standard gesture configuration for most users
    public static let standard = MultiTouchGestureConfiguration()
    
    /// Advanced gesture configuration with all features enabled
    public static let advanced: MultiTouchGestureConfiguration = {
        var config = MultiTouchGestureConfiguration()
        config.enableThreeFingerGestures = true
        config.enableForceTouchGestures = true
        config.pinchSensitivity = 0.03
        config.rotationSensitivity = 2.0
        config.swipeVelocityThreshold = 100.0
        config.maxConcurrentGestures = 5
        return config
    }()
    
    /// Accessibility-focused configuration
    public static let accessibility: MultiTouchGestureConfiguration = {
        var config = MultiTouchGestureConfiguration()
        config.enableRotation = false
        config.pinchSensitivity = 0.2
        config.swipeVelocityThreshold = 300.0
        config.enableLargeTouchTargets = true
        config.enableGestureAssistance = true
        config.enableAudioFeedback = true
        config.enableHapticFeedback = true
        return config
    }()
    
    // MARK: - Validation
    
    /// Validate and clamp configuration values to acceptable ranges
    public mutating func validate() {
        pinchSensitivity = max(0.01, min(1.0, pinchSensitivity))
        rotationSensitivity = max(1.0, min(45.0, rotationSensitivity))
        swipeVelocityThreshold = max(50.0, min(1000.0, swipeVelocityThreshold))
        dragDistanceThreshold = max(1.0, min(50.0, dragDistanceThreshold))
        pressureSensitivity = max(0.1, min(1.0, pressureSensitivity))
        
        gestureTimeout = max(0.5, min(10.0, gestureTimeout))
        debounceInterval = max(0.01, min(1.0, debounceInterval))
        smartMagnifyInterval = max(0.1, min(1.0, smartMagnifyInterval))
        
        minimumZoomScale = max(0.01, min(1.0, minimumZoomScale))
        maximumZoomScale = max(1.0, min(50.0, maximumZoomScale))
        smartMagnifyZoomFactor = max(1.1, min(10.0, smartMagnifyZoomFactor))
        zoomAnimationDuration = max(0.1, min(2.0, zoomAnimationDuration))
        
        navigationSwipeThreshold = max(0.1, min(0.8, navigationSwipeThreshold))
        rubberBandResistance = max(0.1, min(1.0, rubberBandResistance))
        
        maxConcurrentGestures = max(1, min(10, maxConcurrentGestures))
        gestureSmoothingFactor = max(0.1, min(1.0, gestureSmoothingFactor))
    }
}

/// Enhanced gesture data with multi-touch support
public struct MultiTouchGestureData: Codable, Sendable {
    
    /// Base gesture information
    public let gestureType: GestureType
    public let phase: GesturePhase
    public let timestamp: TimeInterval
    
    /// Touch information
    public let touchCount: Int
    public let touchPositions: [CGPoint]
    public let touchPressures: [Double]?
    
    /// Movement data
    public let translation: CGVector?
    public let velocity: CGVector?
    public let acceleration: CGVector?
    
    /// Scale and rotation data
    public let scale: Double?
    public let rotation: Double?
    public let scaleVelocity: Double?
    public let rotationVelocity: Double?
    
    /// Additional metadata
    public let confidence: Double
    public let isSimultaneous: Bool
    public let relatedGestures: [UUID]
    
    public init(
        gestureType: GestureType,
        phase: GesturePhase,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        touchCount: Int = 1,
        touchPositions: [CGPoint] = [],
        touchPressures: [Double]? = nil,
        translation: CGVector? = nil,
        velocity: CGVector? = nil,
        acceleration: CGVector? = nil,
        scale: Double? = nil,
        rotation: Double? = nil,
        scaleVelocity: Double? = nil,
        rotationVelocity: Double? = nil,
        confidence: Double = 1.0,
        isSimultaneous: Bool = false,
        relatedGestures: [UUID] = []
    ) {
        self.gestureType = gestureType
        self.phase = phase
        self.timestamp = timestamp
        self.touchCount = touchCount
        self.touchPositions = touchPositions
        self.touchPressures = touchPressures
        self.translation = translation
        self.velocity = velocity
        self.acceleration = acceleration
        self.scale = scale
        self.rotation = rotation
        self.scaleVelocity = scaleVelocity
        self.rotationVelocity = rotationVelocity
        self.confidence = confidence
        self.isSimultaneous = isSimultaneous
        self.relatedGestures = relatedGestures
    }
}

/// Extended gesture types for multi-touch support
public enum ExtendedGestureType: String, CaseIterable, Codable, Sendable {
    // Basic gestures
    case tap = "tap"
    case doubleTap = "doubleTap"
    case longPress = "longPress"
    
    // Movement gestures
    case pan = "pan"
    case swipeLeft = "swipeLeft"
    case swipeRight = "swipeRight"
    case swipeUp = "swipeUp"
    case swipeDown = "swipeDown"
    
    // Transformation gestures
    case pinch = "pinch"
    case rotation = "rotation"
    case smartMagnify = "smartMagnify"
    
    // Multi-finger gestures
    case threeFingerSwipeLeft = "threeFingerSwipeLeft"
    case threeFingerSwipeRight = "threeFingerSwipeRight"
    case threeFingerSwipeUp = "threeFingerSwipeUp"
    case threeFingerSwipeDown = "threeFingerSwipeDown"
    case threeFingerTap = "threeFingerTap"
    case fourFingerTap = "fourFingerTap"
    
    // Force touch gestures
    case forceTouch = "forceTouch"
    case deepPress = "deepPress"
    
    // Compound gestures
    case pinchAndRotate = "pinchAndRotate"
    case panAndPinch = "panAndPinch"
    
    /// Whether this gesture involves multiple touches
    public var isMultiTouch: Bool {
        switch self {
        case .tap, .doubleTap, .longPress, .pan, .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            return false
        case .pinch, .rotation, .smartMagnify, .forceTouch, .deepPress:
            return true
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown, .threeFingerTap:
            return true
        case .fourFingerTap, .pinchAndRotate, .panAndPinch:
            return true
        }
    }
    
    /// Minimum number of touches required for this gesture
    public var minimumTouchCount: Int {
        switch self {
        case .tap, .doubleTap, .longPress, .pan, .swipeLeft, .swipeRight, .swipeUp, .swipeDown, .forceTouch, .deepPress:
            return 1
        case .pinch, .rotation, .smartMagnify, .panAndPinch:
            return 2
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown, .threeFingerTap, .pinchAndRotate:
            return 3
        case .fourFingerTap:
            return 4
        }
    }
}

/// Manager for multi-touch gesture processing
@MainActor
public class MultiTouchGestureManager: ObservableObject {
    @Published public var configuration: MultiTouchGestureConfiguration
    @Published public private(set) var activeGestures: [UUID: MultiTouchGestureData] = [:]
    @Published public private(set) var gestureHistory: [MultiTouchGestureData] = []
    
    public weak var delegate: MultiTouchGestureManagerDelegate?
    
    private let maxHistorySize = 50
    private var gestureTimers: [UUID: Timer] = [:]
    
    public init(configuration: MultiTouchGestureConfiguration = .standard) {
        self.configuration = configuration
    }
    
    public func processGesture(_ gestureData: MultiTouchGestureData) {
        let gestureId = UUID()
        
        // Validate gesture based on configuration
        guard isGestureEnabled(gestureData.gestureType) else { return }
        
        // Store active gesture
        activeGestures[gestureId] = gestureData
        
        // Add to history
        gestureHistory.append(gestureData)
        if gestureHistory.count > maxHistorySize {
            gestureHistory.removeFirst()
        }
        
        // Set up gesture timeout timer
        if gestureData.phase == .began {
            setupGestureTimeout(for: gestureId)
        }
        
        // Clean up completed gestures
        if gestureData.phase == .ended || gestureData.phase == .cancelled {
            cleanupGesture(gestureId)
        }
        
        // Notify delegate
        delegate?.gestureManager(self, didProcessGesture: gestureData)
    }
    
    private func isGestureEnabled(_ gestureType: GestureType) -> Bool {
        switch gestureType {
        case .magnify:
            return configuration.enablePinchToZoom
        case .rotation:
            return configuration.enableRotation
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            return configuration.enableSwipeGestures
        case .smartMagnify:
            return configuration.enableSmartMagnify
        default:
            return true
        }
    }
    
    private func setupGestureTimeout(for gestureId: UUID) {
        gestureTimers[gestureId] = Timer.scheduledTimer(withTimeInterval: configuration.gestureTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupGesture(gestureId)
            }
        }
    }
    
    private func cleanupGesture(_ gestureId: UUID) {
        activeGestures.removeValue(forKey: gestureId)
        gestureTimers[gestureId]?.invalidate()
        gestureTimers.removeValue(forKey: gestureId)
    }
}

/// Delegate protocol for multi-touch gesture management
public protocol MultiTouchGestureManagerDelegate: AnyObject {
    func gestureManager(_ manager: MultiTouchGestureManager, didProcessGesture gesture: MultiTouchGestureData)
    func gestureManager(_ manager: MultiTouchGestureManager, didDetectSimultaneousGestures gestures: [MultiTouchGestureData])
    func gestureManagerDidExceedGestureLimit(_ manager: MultiTouchGestureManager)
}