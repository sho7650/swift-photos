//
//  UnifiedInteractionEventProvider.swift
//  Swift Photos
//
//  Unified interaction event provider that implements InteractionEventProviderProtocol
//  Consolidates InteractionDetector functionality with clean interface
//

import Foundation
import AppKit
import CoreGraphics

/// Unified interaction event provider that implements the InteractionEventProviderProtocol
/// Wraps InteractionDetector and provides clean Application layer interface
@MainActor
public final class UnifiedInteractionEventProvider: InteractionEventProviderProtocol {
    
    // MARK: - Properties
    
    private let interactionDetector: InteractionDetector
    private var subscriptions: [UUID: EventSubscription] = [:]
    private var isEnabled: Bool = false
    private var currentConfig: InteractionDetectionConfig = .standard
    
    // MARK: - Initialization
    
    public init(interactionDetector: InteractionDetector = InteractionDetector()) {
        self.interactionDetector = interactionDetector
        setupDetectorDelegate()
        ProductionLogger.lifecycle("UnifiedInteractionEventProvider initialized")
    }
    
    // MARK: - InteractionEventProviderProtocol Implementation
    
    public func subscribeToMouseMovement(handler: @escaping @Sendable (CGPoint) -> Void) async -> UUID {
        let subscriptionId = UUID()
        let subscription = EventSubscription(
            id: subscriptionId,
            type: .mouseMovement,
            handler: .mouseMovement(handler)
        )
        
        subscriptions[subscriptionId] = subscription
        
        // Enable mouse tracking if this is the first mouse subscription
        if !hasActiveMouseSubscriptions() {
            try? interactionDetector.updateConfiguration(currentConfig.toInteractionConfiguration())
        }
        
        ProductionLogger.debug("UnifiedInteractionEventProvider: Subscribed to mouse movement \(subscriptionId.uuidString.prefix(8))")
        return subscriptionId
    }
    
    public func subscribeToMouseClicks(handler: @escaping @Sendable (MouseClickEvent) -> Void) async -> UUID {
        let subscriptionId = UUID()
        let subscription = EventSubscription(
            id: subscriptionId,
            type: .mouseClicks,
            handler: .mouseClicks(handler)
        )
        
        subscriptions[subscriptionId] = subscription
        
        ProductionLogger.debug("UnifiedInteractionEventProvider: Subscribed to mouse clicks \(subscriptionId.uuidString.prefix(8))")
        return subscriptionId
    }
    
    public func subscribeToKeyboardEvents(handler: @escaping @Sendable (KeyboardEvent) -> Void) async -> UUID {
        let subscriptionId = UUID()
        let subscription = EventSubscription(
            id: subscriptionId,
            type: .keyboard,
            handler: .keyboard(handler)
        )
        
        subscriptions[subscriptionId] = subscription
        
        ProductionLogger.debug("UnifiedInteractionEventProvider: Subscribed to keyboard events \(subscriptionId.uuidString.prefix(8))")
        return subscriptionId
    }
    
    public func subscribeToGestureEvents(handler: @escaping @Sendable (GestureEvent) -> Void) async -> UUID {
        let subscriptionId = UUID()
        let subscription = EventSubscription(
            id: subscriptionId,
            type: .gestures,
            handler: .gestures(handler)
        )
        
        subscriptions[subscriptionId] = subscription
        
        ProductionLogger.debug("UnifiedInteractionEventProvider: Subscribed to gesture events \(subscriptionId.uuidString.prefix(8))")
        return subscriptionId
    }
    
    public func cancelSubscription(_ subscriptionId: UUID) async {
        subscriptions.removeValue(forKey: subscriptionId)
        ProductionLogger.debug("UnifiedInteractionEventProvider: Cancelled subscription \(subscriptionId.uuidString.prefix(8))")
        
        // Disable detection if no subscriptions remain
        if subscriptions.isEmpty && isEnabled {
            interactionDetector.isEnabled = false
        }
    }
    
    public func cancelAllSubscriptions() async {
        let count = subscriptions.count
        subscriptions.removeAll()
        
        if isEnabled {
            interactionDetector.isEnabled = false
        }
        
        ProductionLogger.info("UnifiedInteractionEventProvider: Cancelled all \(count) subscriptions")
    }
    
    public func getCurrentMousePosition() async -> CGPoint {
        return NSEvent.mouseLocation
    }
    
    public func isMouseInApplicationWindow() async -> Bool {
        guard let window = NSApp.mainWindow else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        return windowFrame.contains(mouseLocation)
    }
    
    public func getDetectionStatistics() async -> InteractionDetectionStatistics {
        // InteractionDetector doesn't expose performance metrics directly
        // This is a simplified implementation - could be enhanced later
        return InteractionDetectionStatistics(
            activeSubscriptions: subscriptions.count,
            eventsProcessedPerSecond: 0.0, // Simplified - would need performance tracking
            totalEventsProcessed: 0, // Simplified - would need event counting
            detectionEnabled: isEnabled,
            lastEventTimestamp: nil // Simplified - would need timestamp tracking
        )
    }
    
    public func setDetectionEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        interactionDetector.isEnabled = enabled && !subscriptions.isEmpty
        
        ProductionLogger.info("UnifiedInteractionEventProvider: Detection \(enabled ? "enabled" : "disabled")")
    }
    
    public func updateConfiguration(_ config: InteractionDetectionConfig) async {
        currentConfig = config
        
        do {
            try interactionDetector.updateConfiguration(config.toInteractionConfiguration())
            ProductionLogger.debug("UnifiedInteractionEventProvider: Configuration updated")
        } catch {
            ProductionLogger.error("UnifiedInteractionEventProvider: Failed to update configuration - \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDetectorDelegate() {
        interactionDetector.delegate = self
    }
    
    private func hasActiveMouseSubscriptions() -> Bool {
        return subscriptions.values.contains { subscription in
            subscription.type == .mouseMovement || subscription.type == .mouseClicks
        }
    }
    
    private func notifySubscribers(for eventType: EventType, with data: Any) {
        let relevantSubscriptions = subscriptions.values.filter { $0.type == eventType }
        
        for subscription in relevantSubscriptions {
            switch subscription.handler {
            case .mouseMovement(let handler):
                if let position = data as? CGPoint {
                    handler(position)
                }
                
            case .mouseClicks(let handler):
                if let clickEvent = data as? MouseClickEvent {
                    handler(clickEvent)
                }
                
            case .keyboard(let handler):
                if let keyboardEvent = data as? KeyboardEvent {
                    handler(keyboardEvent)
                }
                
            case .gestures(let handler):
                if let gestureEvent = data as? GestureEvent {
                    handler(gestureEvent)
                }
            }
        }
    }
}

// MARK: - InteractionDetectorDelegate

extension UnifiedInteractionEventProvider: InteractionDetectorDelegate {
    
    public func detectorDidDetectInteraction(_ detector: InteractionDetecting, interaction: Interaction) {
        // Convert Interaction to appropriate event types and notify subscribers
        switch interaction.type {
        case .mouseMove:
            if let position = interaction.data.position {
                notifySubscribers(for: .mouseMovement, with: position)
            }
            
        case .mouseClick:
            // Convert interaction data to MouseClickEvent
            let position = interaction.data.position ?? .zero
            let button = MouseButton(rawValue: Int(interaction.data.modifierFlags ?? 0) & 0x3) ?? .left
            let clickCount = 1 // Simplified - InteractionData doesn't track click count
            
            let clickEvent = MouseClickEvent(
                position: position,
                button: button,
                clickCount: clickCount,
                timestamp: Date(timeIntervalSince1970: interaction.data.timestamp)
            )
            notifySubscribers(for: .mouseClicks, with: clickEvent)
            
        case .keyPress:
            // Convert interaction data to KeyboardEvent
            let keyCode = interaction.data.keyCode ?? 0
            let characters: String? = nil // InteractionData doesn't include character strings
            let isKeyDown = true // Simplified - assume key down events
            
            let keyboardEvent = KeyboardEvent(
                keyCode: keyCode,
                characters: characters,
                isKeyDown: isKeyDown,
                timestamp: Date(timeIntervalSince1970: interaction.data.timestamp)
            )
            notifySubscribers(for: .keyboard, with: keyboardEvent)
            
        case .gesture:
            // Convert interaction data to GestureEvent
            let gestureType = interaction.data.gestureData?.gestureType ?? .tap
            let location = interaction.data.position ?? .zero
            let velocity = interaction.data.velocity
            
            let gestureEvent = GestureEvent(
                type: gestureType,
                location: location,
                velocity: velocity != nil ? CGPoint(x: velocity!.dx, y: velocity!.dy) : nil,
                timestamp: Date(timeIntervalSince1970: interaction.data.timestamp),
                phase: interaction.data.gestureData?.phase ?? .began
            )
            notifySubscribers(for: .gestures, with: gestureEvent)
            
        default:
            // Handle other interaction types that might not have direct mappings
            break
        }
    }
    
    public func detectorDidEncounterError(_ detector: InteractionDetecting, error: InteractionError) {
        ProductionLogger.error("UnifiedInteractionEventProvider: Detector error - \(error)")
    }
    
    public func detectorDidStartDetection(_ detector: InteractionDetecting) {
        ProductionLogger.debug("UnifiedInteractionEventProvider: Detector started detection")
    }
    
    public func detectorDidStopDetection(_ detector: InteractionDetecting) {
        ProductionLogger.debug("UnifiedInteractionEventProvider: Detector stopped detection")
    }
    
    public func detectorDidUpdateConfiguration(_ detector: InteractionDetecting, configuration: InteractionConfiguration) {
        ProductionLogger.debug("UnifiedInteractionEventProvider: Detector updated configuration")
    }
}

// MARK: - Convenience Extensions

extension UnifiedInteractionEventProvider {
    
    /// Create a provider optimized for UI interactions
    public static func forUIInteractions() -> UnifiedInteractionEventProvider {
        let provider = UnifiedInteractionEventProvider()
        Task {
            await provider.updateConfiguration(.standard)
        }
        ProductionLogger.debug("UnifiedInteractionEventProvider: Created UI interactions optimized instance")
        return provider
    }
    
    /// Create a provider optimized for high performance scenarios
    public static func highPerformance() -> UnifiedInteractionEventProvider {
        let provider = UnifiedInteractionEventProvider()
        Task {
            await provider.updateConfiguration(.highPerformance)
        }
        ProductionLogger.debug("UnifiedInteractionEventProvider: Created high performance instance")
        return provider
    }
    
    /// Create a provider optimized for battery life
    public static func batteryOptimized() -> UnifiedInteractionEventProvider {
        let provider = UnifiedInteractionEventProvider()
        Task {
            await provider.updateConfiguration(.batteryOptimized)
        }
        ProductionLogger.debug("UnifiedInteractionEventProvider: Created battery optimized instance")
        return provider
    }
}

// MARK: - Supporting Types

/// Internal event subscription management
private struct EventSubscription {
    let id: UUID
    let type: EventType
    let handler: EventHandler
}

/// Event types for subscription management
private enum EventType {
    case mouseMovement
    case mouseClicks
    case keyboard
    case gestures
}

/// Handler types for different events
private enum EventHandler {
    case mouseMovement(@Sendable (CGPoint) -> Void)
    case mouseClicks(@Sendable (MouseClickEvent) -> Void)
    case keyboard(@Sendable (KeyboardEvent) -> Void)
    case gestures(@Sendable (GestureEvent) -> Void)
}

// MARK: - Configuration Extensions

extension InteractionDetectionConfig {
    /// Convert to InteractionConfiguration for the detector
    func toInteractionConfiguration() -> InteractionConfiguration {
        // Map to the actual InteractionConfiguration parameters
        return InteractionConfiguration(
            enabledTypes: [.mouseMove, .mouseClick, .keyPress, .gesture],
            sensitivity: self.mouseSensitivity,
            minimumConfidence: 0.5,
            debounceInterval: self.eventProcessingInterval,
            maxEventRate: 120.0,
            enableGestures: true,
            gestureConfiguration: GestureConfiguration()
        )
    }
}

// MARK: - Factory Implementation

/// Factory for creating UnifiedInteractionEventProvider instances
public struct UnifiedInteractionEventProviderFactory: InteractionEventProviderFactory {
    
    public init() {}
    
    @MainActor
    public func createEventProvider() -> InteractionEventProviderProtocol {
        return UnifiedInteractionEventProvider()
    }
}