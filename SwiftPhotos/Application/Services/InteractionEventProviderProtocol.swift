//
//  InteractionEventProviderProtocol.swift
//  Swift Photos
//
//  Clean Architecture Interface for Interaction Event Provision
//  Application layer defines the contract, Infrastructure implements it
//

import Foundation
import CoreGraphics
import AppKit

// Import Domain types to avoid redefinition
// GestureType and GesturePhase are defined in Domain/ValueObjects/InteractionTypes.swift

// MARK: - Interaction Event Provider Protocol

/// Protocol for unified interaction event detection and provision
/// Defines the contract that Infrastructure implementations must fulfill
/// Consolidates raw input event detection into a clean interface
public protocol InteractionEventProviderProtocol: AnyObject, Sendable {
    
    // MARK: - Event Subscription
    
    /// Subscribe to mouse movement events
    /// - Parameter handler: Closure called when mouse moves
    /// - Returns: Subscription identifier for cancellation
    func subscribeToMouseMovement(handler: @escaping @Sendable (CGPoint) -> Void) async -> UUID
    
    /// Subscribe to mouse click events
    /// - Parameter handler: Closure called when mouse is clicked
    /// - Returns: Subscription identifier for cancellation
    func subscribeToMouseClicks(handler: @escaping @Sendable (MouseClickEvent) -> Void) async -> UUID
    
    /// Subscribe to keyboard events
    /// - Parameter handler: Closure called when key is pressed
    /// - Returns: Subscription identifier for cancellation
    func subscribeToKeyboardEvents(handler: @escaping @Sendable (KeyboardEvent) -> Void) async -> UUID
    
    /// Subscribe to gesture events
    /// - Parameter handler: Closure called when gesture is detected
    /// - Returns: Subscription identifier for cancellation
    func subscribeToGestureEvents(handler: @escaping @Sendable (GestureEvent) -> Void) async -> UUID
    
    // MARK: - Subscription Management
    
    /// Cancel a specific event subscription
    /// - Parameter subscriptionId: The subscription to cancel
    func cancelSubscription(_ subscriptionId: UUID) async
    
    /// Cancel all active subscriptions
    func cancelAllSubscriptions() async
    
    // MARK: - State Queries
    
    /// Get current mouse position in global coordinates
    /// - Returns: Current mouse position
    func getCurrentMousePosition() async -> CGPoint
    
    /// Check if mouse is within the application window
    /// - Returns: Whether mouse is in window bounds
    func isMouseInApplicationWindow() async -> Bool
    
    /// Get interaction detection statistics
    /// - Returns: Current statistics about event detection
    func getDetectionStatistics() async -> InteractionDetectionStatistics
    
    // MARK: - Configuration
    
    /// Enable or disable event detection
    /// - Parameter enabled: Whether detection should be active
    func setDetectionEnabled(_ enabled: Bool) async
    
    /// Update detection configuration
    /// - Parameter config: New configuration settings
    func updateConfiguration(_ config: InteractionDetectionConfig) async
}

// MARK: - Supporting Types

/// Mouse click event information
public struct MouseClickEvent: Sendable {
    public let position: CGPoint
    public let button: MouseButton
    public let clickCount: Int
    public let timestamp: Date
    public let modifierFlags: ModifierFlags
    
    public init(
        position: CGPoint,
        button: MouseButton,
        clickCount: Int = 1,
        timestamp: Date = Date(),
        modifierFlags: ModifierFlags = []
    ) {
        self.position = position
        self.button = button
        self.clickCount = clickCount
        self.timestamp = timestamp
        self.modifierFlags = modifierFlags
    }
}

/// Keyboard event information
public struct KeyboardEvent: Sendable {
    public let keyCode: UInt16
    public let characters: String?
    public let isKeyDown: Bool
    public let timestamp: Date
    public let modifierFlags: ModifierFlags
    
    public init(
        keyCode: UInt16,
        characters: String? = nil,
        isKeyDown: Bool,
        timestamp: Date = Date(),
        modifierFlags: ModifierFlags = []
    ) {
        self.keyCode = keyCode
        self.characters = characters
        self.isKeyDown = isKeyDown
        self.timestamp = timestamp
        self.modifierFlags = modifierFlags
    }
}

/// Gesture event information
public struct GestureEvent: Sendable {
    public let type: GestureType
    public let location: CGPoint
    public let velocity: CGPoint?
    public let timestamp: Date
    public let phase: GesturePhase
    
    public init(
        type: GestureType,
        location: CGPoint,
        velocity: CGPoint? = nil,
        timestamp: Date = Date(),
        phase: GesturePhase = .began
    ) {
        self.type = type
        self.location = location
        self.velocity = velocity
        self.timestamp = timestamp
        self.phase = phase
    }
}

/// Mouse button types
public enum MouseButton: Int, Sendable, CaseIterable {
    case left = 0
    case right = 1
    case middle = 2
    case other = 3
    
    public var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .middle: return "Middle"
        case .other: return "Other"
        }
    }
}



/// Modifier flags for events
public struct ModifierFlags: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let command = ModifierFlags(rawValue: 1 << 0)
    public static let shift = ModifierFlags(rawValue: 1 << 1)
    public static let control = ModifierFlags(rawValue: 1 << 2)
    public static let option = ModifierFlags(rawValue: 1 << 3)
    public static let function = ModifierFlags(rawValue: 1 << 4)
}

/// Interaction detection statistics
public struct InteractionDetectionStatistics: Sendable {
    public let activeSubscriptions: Int
    public let eventsProcessedPerSecond: Double
    public let totalEventsProcessed: Int
    public let detectionEnabled: Bool
    public let lastEventTimestamp: Date?
    
    public init(
        activeSubscriptions: Int,
        eventsProcessedPerSecond: Double,
        totalEventsProcessed: Int,
        detectionEnabled: Bool,
        lastEventTimestamp: Date? = nil
    ) {
        self.activeSubscriptions = activeSubscriptions
        self.eventsProcessedPerSecond = eventsProcessedPerSecond
        self.totalEventsProcessed = totalEventsProcessed
        self.detectionEnabled = detectionEnabled
        self.lastEventTimestamp = lastEventTimestamp
    }
}

/// Configuration for interaction detection
public struct InteractionDetectionConfig: Sendable {
    public let mouseSensitivity: Double
    public let gestureSensitivity: Double
    public let keyboardRepeatHandling: Bool
    public let enableGlobalMouseTracking: Bool
    public let enableLocalMouseTracking: Bool
    public let eventProcessingInterval: TimeInterval
    
    public init(
        mouseSensitivity: Double = 1.0,
        gestureSensitivity: Double = 1.0,
        keyboardRepeatHandling: Bool = true,
        enableGlobalMouseTracking: Bool = true,
        enableLocalMouseTracking: Bool = true,
        eventProcessingInterval: TimeInterval = 0.016 // ~60fps
    ) {
        self.mouseSensitivity = mouseSensitivity
        self.gestureSensitivity = gestureSensitivity
        self.keyboardRepeatHandling = keyboardRepeatHandling
        self.enableGlobalMouseTracking = enableGlobalMouseTracking
        self.enableLocalMouseTracking = enableLocalMouseTracking
        self.eventProcessingInterval = eventProcessingInterval
    }
    
    /// Default configuration for normal use
    public static let standard = InteractionDetectionConfig()
    
    /// High performance configuration for intensive interactions
    public static let highPerformance = InteractionDetectionConfig(
        mouseSensitivity: 0.8,
        gestureSensitivity: 0.8,
        eventProcessingInterval: 0.008 // ~120fps
    )
    
    /// Battery optimized configuration
    public static let batteryOptimized = InteractionDetectionConfig(
        mouseSensitivity: 1.2,
        gestureSensitivity: 1.2,
        eventProcessingInterval: 0.033 // ~30fps
    )
}

// MARK: - Factory Protocol

/// Factory for creating interaction event provider instances
/// Allows Application layer to create Infrastructure services without direct dependencies
public protocol InteractionEventProviderFactory: Sendable {
    
    /// Create an interaction event provider instance
    @MainActor func createEventProvider() -> InteractionEventProviderProtocol
}

// MARK: - Convenience Extensions

extension InteractionEventProviderProtocol {
    
    /// Subscribe to all mouse events (movement and clicks)
    public func subscribeToAllMouseEvents(
        movementHandler: @escaping @Sendable (CGPoint) -> Void,
        clickHandler: @escaping @Sendable (MouseClickEvent) -> Void
    ) async -> [UUID] {
        let movementId = await subscribeToMouseMovement(handler: movementHandler)
        let clickId = await subscribeToMouseClicks(handler: clickHandler)
        return [movementId, clickId]
    }
    
    /// Subscribe to essential interaction events
    public func subscribeToEssentialEvents(
        mouseHandler: @escaping @Sendable (CGPoint) -> Void,
        keyboardHandler: @escaping @Sendable (KeyboardEvent) -> Void
    ) async -> [UUID] {
        let mouseId = await subscribeToMouseMovement(handler: mouseHandler)
        let keyboardId = await subscribeToKeyboardEvents(handler: keyboardHandler)
        return [mouseId, keyboardId]
    }
    
    /// Enable standard detection with default configuration
    public func enableStandardDetection() async {
        await updateConfiguration(.standard)
        await setDetectionEnabled(true)
    }
}