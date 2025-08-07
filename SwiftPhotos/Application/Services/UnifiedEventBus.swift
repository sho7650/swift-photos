import Foundation
import SwiftUI
import Observation

// MARK: - Event Protocols

/// Base protocol for all events
public protocol Event: Sendable {
    var timestamp: Date { get }
    var source: String { get }
    var eventId: UUID { get }
}

/// High-priority events for immediate processing
public protocol HighPriorityEvent: Event {}

/// Events that can be batched for performance
public protocol BatchableEvent: Event {}

/// Enhanced Observer pattern with EventBus for decoupled communication
/// Replaces scattered NotificationCenter usage with type-safe event system
@MainActor
public class UnifiedEventBus {
    
    // MARK: - Observer Management
    
    /// Type-erased observer wrapper
    private class AnyObserver {
        let id: UUID
        let priority: EventPriority
        private let _notify: (any Event) async -> Void
        private let _canHandle: (any Event) -> Bool
        
        init<E: Event>(
            id: UUID = UUID(),
            priority: EventPriority = .normal,
            eventType: E.Type,
            handler: @escaping (E) async -> Void
        ) {
            self.id = id
            self.priority = priority
            self._notify = { event in
                if let typedEvent = event as? E {
                    await handler(typedEvent)
                }
            }
            self._canHandle = { event in
                return event is E
            }
        }
        
        func notify(event: any Event) async {
            await _notify(event)
        }
        
        func canHandle(event: any Event) -> Bool {
            return _canHandle(event)
        }
    }
    
    // MARK: - Event Priority
    
    public enum EventPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Properties
    
    private var observers: [String: [AnyObserver]] = [:]
    private var batchedEvents: [any BatchableEvent] = []
    private var eventHistory: [any Event] = []
    private let maxHistorySize: Int = 1000
    
    // Performance metrics
    private var eventCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    private var lastCleanupTime: Date = Date()
    
    // Batch processing
    private var batchProcessingTask: Task<Void, Never>?
    private let batchProcessingInterval: TimeInterval = 0.1
    
    public static let shared = UnifiedEventBus()
    
    // MARK: - Initialization
    
    private init() {
        startBatchProcessing()
        ProductionLogger.lifecycle("UnifiedEventBus: Enhanced Observer pattern initialized")
    }
    
    deinit {
        batchProcessingTask?.cancel()
    }
    
    // MARK: - Observer Registration
    
    /// Register an observer for a specific event type
    @discardableResult
    public func observe<E: Event>(
        _ eventType: E.Type,
        priority: EventPriority = .normal,
        handler: @escaping (E) async -> Void
    ) -> UUID {
        let observer = AnyObserver(
            priority: priority,
            eventType: eventType,
            handler: handler
        )
        
        let eventKey = String(describing: eventType)
        if observers[eventKey] == nil {
            observers[eventKey] = []
        }
        
        observers[eventKey]?.append(observer)
        
        // Sort by priority (highest first)
        observers[eventKey]?.sort { $0.priority > $1.priority }
        
        ProductionLogger.debug("EventBus: Observer registered for \(eventKey) with priority \(priority)")
        return observer.id
    }
    
    /// Remove an observer by ID
    public func removeObserver(id: UUID) async {
        for (eventKey, observerList) in observers {
            observers[eventKey] = observerList.filter { $0.id != id }
            if observers[eventKey]?.isEmpty == true {
                observers[eventKey] = nil
            }
        }
        ProductionLogger.debug("EventBus: Observer removed: \(id)")
    }
    
    /// Remove all observers for a specific event type
    public func removeAllObservers<E: Event>(for eventType: E.Type) {
        let eventKey = String(describing: eventType)
        observers[eventKey] = nil
        ProductionLogger.debug("EventBus: All observers removed for \(eventKey)")
    }
    
    // MARK: - Event Publishing
    
    /// Publish an event to all registered observers
    public func publish<E: Event>(_ event: E) async {
        let startTime = Date()
        eventCount += 1
        
        // Add to history
        eventHistory.append(event)
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst()
        }
        
        // Handle high-priority events immediately
        if event is HighPriorityEvent {
            await processEventImmediately(event)
        }
        // Batch batchable events
        else if let batchableEvent = event as? BatchableEvent {
            batchedEvents.append(batchableEvent)
        }
        // Process normal events immediately
        else {
            await processEventImmediately(event)
        }
        
        // Update performance metrics
        let processingTime = Date().timeIntervalSince(startTime)
        totalProcessingTime += processingTime
        
        ProductionLogger.debug("EventBus: Published \(type(of: event)) in \(String(format: "%.3f", processingTime))s")
    }
    
    /// Publish an event synchronously (fire-and-forget)
    public func publishSync<E: Event>(_ event: E) {
        Task {
            await publish(event)
        }
    }
    
    // MARK: - Event Processing
    
    private func processEventImmediately(_ event: any Event) async {
        let eventKey = String(describing: type(of: event))
        guard let observerList = observers[eventKey] else { return }
        
        // Process observers by priority
        for observer in observerList {
            if observer.canHandle(event: event) {
                await observer.notify(event: event)
            }
        }
    }
    
    private func startBatchProcessing() {
        batchProcessingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.batchProcessingInterval ?? 0.1))
                
                await self?.processBatchedEvents()
            }
        }
    }
    
    private func processBatchedEvents() async {
        guard !batchedEvents.isEmpty else { return }
        
        let eventsToProcess = batchedEvents
        batchedEvents.removeAll()
        
        // Group events by type for more efficient processing
        let groupedEvents = Dictionary(grouping: eventsToProcess) { String(describing: type(of: $0)) }
        
        for (eventType, events) in groupedEvents {
            guard let observerList = observers[eventType] else { continue }
            
            for observer in observerList {
                for event in events {
                    if observer.canHandle(event: event) {
                        await observer.notify(event: event)
                    }
                }
            }
        }
        
        ProductionLogger.debug("EventBus: Processed \(eventsToProcess.count) batched events")
    }
    
    // MARK: - Event History and Debugging
    
    /// Get recent event history
    public func getEventHistory(limit: Int = 100) -> [any Event] {
        return Array(eventHistory.suffix(limit))
    }
    
    /// Get observer statistics
    public func getObserverStatistics() -> [String: Int] {
        var stats: [String: Int] = [:]
        for (eventType, observerList) in observers {
            stats[eventType] = observerList.count
        }
        return stats
    }
    
    /// Get performance metrics
    public func getPerformanceMetrics() -> EventBusMetrics {
        let averageProcessingTime = eventCount > 0 ? totalProcessingTime / Double(eventCount) : 0
        return EventBusMetrics(
            totalEvents: eventCount,
            averageProcessingTime: averageProcessingTime,
            totalObservers: observers.values.flatMap { $0 }.count,
            batchedEventsCount: batchedEvents.count,
            historySize: eventHistory.count
        )
    }
    
    /// Clear event history (for memory management)
    public func clearHistory() {
        eventHistory.removeAll()
        ProductionLogger.debug("EventBus: Event history cleared")
    }
    
    /// Cleanup old events and perform maintenance
    public func performMaintenance() {
        let now = Date()
        
        // Only perform maintenance if it's been more than 5 minutes
        guard now.timeIntervalSince(lastCleanupTime) > 300 else { return }
        
        // Clear old history
        if eventHistory.count > maxHistorySize / 2 {
            eventHistory = Array(eventHistory.suffix(maxHistorySize / 2))
        }
        
        // Remove empty observer lists
        observers = observers.compactMapValues { observerList in
            observerList.isEmpty ? nil : observerList
        }
        
        lastCleanupTime = now
        ProductionLogger.debug("EventBus: Maintenance completed")
    }
}

// MARK: - Specific Event Definitions

/// Slideshow-related events
public struct SlideshowEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "SlideshowViewModel"
    public let eventId: UUID = UUID()
    
    public let action: Action
    public let photoId: UUID?
    public let index: Int?
    
    public enum Action: Sendable {
        case started, paused, stopped, photoChanged, settingsChanged
    }
    
    public init(action: Action, photoId: UUID? = nil, index: Int? = nil) {
        self.action = action
        self.photoId = photoId
        self.index = index
    }
}

/// UI state events
public struct UIStateEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "UI"
    public let eventId: UUID = UUID()
    
    public let component: String
    public let state: UIState
    public let data: [String: String]?
    
    public enum UIState: Sendable {
        case shown, hidden, focused, blurred, pressed, released
    }
    
    public init(component: String, state: UIState, data: [String: String]? = nil) {
        self.component = component
        self.state = state
        self.data = data
    }
}

/// Performance-related events (batchable)
public struct PerformanceEvent: BatchableEvent {
    public let timestamp: Date = Date()
    public let source: String = "PerformanceMonitor"
    public let eventId: UUID = UUID()
    
    public let metric: String
    public let value: Double
    public let unit: String
    
    public init(metric: String, value: Double, unit: String = "") {
        self.metric = metric
        self.value = value
        self.unit = unit
    }
}

/// System events (high priority)
public struct SystemEvent: HighPriorityEvent {
    public let timestamp: Date = Date()
    public let source: String = "System"
    public let eventId: UUID = UUID()
    
    public let type: SystemEventType
    public let message: String
    public let severity: Severity
    
    public enum SystemEventType: Sendable {
        case memoryWarning, error, crash, startup, shutdown
    }
    
    public enum Severity: Sendable {
        case info, warning, error, critical
    }
    
    public init(type: SystemEventType, message: String, severity: Severity = .info) {
        self.type = type
        self.message = message
        self.severity = severity
    }
}

/// Settings change events
public struct SettingsEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "SettingsManager"
    public let eventId: UUID = UUID()
    
    public let settingsType: String
    public let changedKeys: [String]
    public let oldValues: [String: String]?
    public let newValues: [String: String]?
    
    public init(settingsType: String, changedKeys: [String], oldValues: [String: String]? = nil, newValues: [String: String]? = nil) {
        self.settingsType = settingsType
        self.changedKeys = changedKeys
        self.oldValues = oldValues
        self.newValues = newValues
    }
}

// MARK: - Event Bus Metrics

public struct EventBusMetrics {
    public let totalEvents: Int
    public let averageProcessingTime: TimeInterval
    public let totalObservers: Int
    public let batchedEventsCount: Int
    public let historySize: Int
    
    public var processingTimeMS: Double {
        averageProcessingTime * 1000
    }
}

// MARK: - Convenience Extensions

extension UnifiedEventBus {
    
    /// Publish slideshow events
    public func publishSlideshow(action: SlideshowEvent.Action, photoId: UUID? = nil, index: Int? = nil) {
        publishSync(SlideshowEvent(action: action, photoId: photoId, index: index))
    }
    
    /// Publish UI state events
    public func publishUIState(component: String, state: UIStateEvent.UIState, data: [String: String]? = nil) {
        publishSync(UIStateEvent(component: component, state: state, data: data))
    }
    
    /// Publish performance metrics
    public func publishPerformance(metric: String, value: Double, unit: String = "") {
        publishSync(PerformanceEvent(metric: metric, value: value, unit: unit))
    }
    
    /// Publish system events
    public func publishSystem(type: SystemEvent.SystemEventType, message: String, severity: SystemEvent.Severity = .info) {
        publishSync(SystemEvent(type: type, message: message, severity: severity))
    }
    
    /// Publish settings changes
    public func publishSettings(type: String, changedKeys: [String], oldValues: [String: String]? = nil, newValues: [String: String]? = nil) {
        publishSync(SettingsEvent(settingsType: type, changedKeys: changedKeys, oldValues: oldValues, newValues: newValues))
    }
}

// MARK: - SwiftUI Integration

/// Observable wrapper for EventBus integration with SwiftUI
@MainActor
@Observable
public class EventBusObserver {
    
    private let eventBus: UnifiedEventBus
    private var observerIds: [UUID] = []
    
    public init(eventBus: UnifiedEventBus = .shared) {
        self.eventBus = eventBus
    }
    
    deinit {
        // Cannot access main actor properties from deinit
        // Objects will be cleaned up automatically when deallocated
    }
    
    /// Observe events with automatic cleanup
    public func observe<E: Event>(
        _ eventType: E.Type,
        priority: UnifiedEventBus.EventPriority = .normal,
        handler: @escaping (E) async -> Void
    ) {
        let observerId = eventBus.observe(eventType, priority: priority, handler: handler)
        observerIds.append(observerId)
    }
    
    /// Cleanup all observers
    public func cleanup() async {
        for observerId in observerIds {
            await eventBus.removeObserver(id: observerId)
        }
        observerIds.removeAll()
    }
}

// MARK: - View Modifier for Event Bus Integration

public struct EventBusModifier: ViewModifier {
    
    @State private var eventObserver = EventBusObserver()
    private let eventBus: UnifiedEventBus
    
    public init(eventBus: UnifiedEventBus = .shared) {
        self.eventBus = eventBus
    }
    
    public func body(content: Content) -> some View {
        content
            .environment(\.eventBus, eventBus)
            .environment(\.eventObserver, eventObserver)
    }
}

// MARK: - Environment Integration

private struct EventBusEnvironmentKey: EnvironmentKey {
    static let defaultValue: UnifiedEventBus? = nil
}

private struct EventObserverEnvironmentKey: EnvironmentKey {
    static let defaultValue: EventBusObserver? = nil
}

extension EnvironmentValues {
    public var eventBus: UnifiedEventBus? {
        get { self[EventBusEnvironmentKey.self] }
        set { self[EventBusEnvironmentKey.self] = newValue }
    }
    
    public var eventObserver: EventBusObserver? {
        get { self[EventObserverEnvironmentKey.self] }
        set { self[EventObserverEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Add EventBus support to a view
    public func eventBus(_ eventBus: UnifiedEventBus = .shared) -> some View {
        modifier(EventBusModifier(eventBus: eventBus))
    }
}

// MARK: - Migration Helper

/// Helper class to migrate from NotificationCenter to EventBus
public class EventBusMigrationHelper {
    
    /// Map NotificationCenter notifications to EventBus events
    public static func migrateNotification(
        name: Notification.Name,
        object: Any?,
        userInfo: [AnyHashable: Any]?
    ) -> (any Event)? {
        
        switch name.rawValue {
        case "slideshowSettingsChanged":
            var newValuesDict: [String: String]? = nil
            if let userInfo = userInfo {
                var dict: [String: String] = [:]
                for (key, value) in userInfo {
                    dict[String(describing: key)] = String(describing: value)
                }
                newValuesDict = dict
            }
            return SettingsEvent(
                settingsType: "SlideshowSettings",
                changedKeys: ["settings"],
                oldValues: nil,
                newValues: newValuesDict
            )
            
        case "sortSettingsChanged":
            var newValuesDict: [String: String]? = nil
            if let userInfo = userInfo {
                var dict: [String: String] = [:]
                for (key, value) in userInfo {
                    dict[String(describing: key)] = String(describing: value)
                }
                newValuesDict = dict
            }
            return SettingsEvent(
                settingsType: "SortSettings", 
                changedKeys: ["settings"],
                oldValues: nil,
                newValues: newValuesDict
            )
            
        case "transitionSettingsChanged":
            var newValuesDict: [String: String]? = nil
            if let userInfo = userInfo {
                var dict: [String: String] = [:]
                for (key, value) in userInfo {
                    dict[String(describing: key)] = String(describing: value)
                }
                newValuesDict = dict
            }
            return SettingsEvent(
                settingsType: "TransitionSettings",
                changedKeys: ["settings"],
                oldValues: nil,
                newValues: newValuesDict
            )
            
        default:
            return nil
        }
    }
    
    /// Setup migration from NotificationCenter
    @MainActor
    public static func setupMigration(eventBus: UnifiedEventBus? = nil) {
        let targetEventBus = eventBus ?? .shared
        let notificationNames: [Notification.Name] = [
            .init("slideshowSettingsChanged"),
            .init("sortSettingsChanged"),
            .init("transitionSettingsChanged")
        ]
        
        for name in notificationNames {
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { notification in
                if let event = migrateNotification(
                    name: notification.name,
                    object: notification.object,
                    userInfo: notification.userInfo
                ) {
                    Task { @MainActor in
                        await targetEventBus.publish(event)
                    }
                }
            }
        }
        
        ProductionLogger.debug("EventBusMigrationHelper: NotificationCenter migration setup completed")
    }
}