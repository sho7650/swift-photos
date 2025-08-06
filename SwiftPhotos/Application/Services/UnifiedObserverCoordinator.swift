import Foundation
import SwiftUI
import Observation

/// Enhanced Observer Pattern Coordinator that replaces scattered NotificationCenter usage
/// Provides type-safe, performance-optimized event handling with automatic cleanup
@MainActor
@Observable
public final class UnifiedObserverCoordinator {
    
    // MARK: - Singleton
    
    public static let shared = UnifiedObserverCoordinator()
    
    // MARK: - Properties
    
    /// Central event bus for all application events
    private let eventBus: UnifiedEventBus = UnifiedEventBus.shared
    
    /// Performance metrics for observer system
    public private(set) var observerCount: Int = 0
    public private(set) var eventCount: Int = 0
    public private(set) var averageProcessingTime: TimeInterval = 0
    
    /// Observer registration tracking for automatic cleanup
    private var registrations: [String: [UUID]] = [:]
    private var observerSources: [UUID: String] = [:]
    
    /// Batching configuration
    private let batchSize: Int = 50
    private let batchInterval: TimeInterval = 0.1
    
    // MARK: - Initialization
    
    private init() {
        setupEventBusObservers()
        ProductionLogger.lifecycle("🎯 UnifiedObserverCoordinator: Enhanced Observer pattern initialized")
    }
    
    // MARK: - High-Level Event Registration
    
    /// Register observer for slideshow events
    @discardableResult
    public func observeSlideshowEvents(
        source: String = "UnknownSource",
        handler: @escaping (SlideshowPlaybackEvent) async -> Void
    ) -> UUID {
        return registerObserver(
            eventType: SlideshowPlaybackEvent.self,
            source: source,
            priority: .high,
            handler: handler
        )
    }
    
    /// Register observer for photo loading events
    @discardableResult
    public func observePhotoEvents(
        source: String = "UnknownSource",
        handler: @escaping (PhotoLoadEvent) async -> Void
    ) -> UUID {
        return registerObserver(
            eventType: PhotoLoadEvent.self,
            source: source,
            priority: .normal,
            handler: handler
        )
    }
    
    /// Register observer for settings change events
    @discardableResult
    public func observeSettingsEvents(
        source: String = "UnknownSource",
        handler: @escaping (SettingsChangeEvent) async -> Void
    ) -> UUID {
        return registerObserver(
            eventType: SettingsChangeEvent.self,
            source: source,
            priority: .normal,
            handler: handler
        )
    }
    
    /// Register observer for UI interaction events
    @discardableResult
    public func observeUIEvents(
        source: String = "UnknownSource",
        handler: @escaping (UIInteractionEvent) async -> Void
    ) -> UUID {
        return registerObserver(
            eventType: UIInteractionEvent.self,
            source: source,
            priority: .low,
            handler: handler
        )
    }
    
    /// Register observer for performance events
    @discardableResult
    public func observePerformanceEvents(
        source: String = "UnknownSource",
        handler: @escaping (PerformanceEvent) async -> Void
    ) -> UUID {
        return registerObserver(
            eventType: PerformanceEvent.self,
            source: source,
            priority: .low,
            handler: handler
        )
    }
    
    /// Register observer for error events
    @discardableResult
    public func observeErrorEvents(
        source: String = "UnknownSource",
        handler: @escaping (ErrorEvent) async -> Void
    ) -> UUID {
        return registerObserver(
            eventType: ErrorEvent.self,
            source: source,
            priority: .critical,
            handler: handler
        )
    }
    
    // MARK: - Generic Event Registration
    
    /// Register observer for any event type
    @discardableResult
    public func registerObserver<E: Event>(
        eventType: E.Type,
        source: String,
        priority: UnifiedEventBus.EventPriority = .normal,
        handler: @escaping (E) async -> Void
    ) -> UUID {
        let observerId = eventBus.observe(eventType, priority: priority, handler: handler)
        
        // Track registration
        if registrations[source] == nil {
            registrations[source] = []
        }
        registrations[source]?.append(observerId)
        observerSources[observerId] = source
        
        observerCount += 1
        ProductionLogger.debug("🎯 Observer registered: \(E.self) for \(source)")
        
        return observerId
    }
    
    // MARK: - Event Publishing
    
    /// Publish slideshow playback event
    public func publishSlideshowEvent(
        action: SlideshowPlaybackEvent.PlaybackAction,
        slideshowId: UUID? = nil,
        photoIndex: Int? = nil
    ) {
        let event = EventFactory.slideshowPlayback(
            action: action,
            slideshowId: slideshowId,
            photoIndex: photoIndex
        )
        publishEvent(event)
    }
    
    /// Publish photo loading event
    public func publishPhotoEvent(
        photoId: UUID,
        action: PhotoLoadEvent.LoadAction,
        error: Error? = nil
    ) {
        let event = EventFactory.photoLoad(
            photoId: photoId,
            action: action,
            error: error
        )
        publishEvent(event)
    }
    
    /// Publish settings change event
    public func publishSettingsEvent(
        category: SettingsChangeEvent.SettingsCategory,
        action: SettingsChangeEvent.SettingsAction,
        oldValue: Any? = nil,
        newValue: Any? = nil
    ) {
        let event = EventFactory.settingsChange(
            category: category,
            action: action,
            oldValue: oldValue,
            newValue: newValue
        )
        publishEvent(event)
    }
    
    /// Publish UI interaction event
    public func publishUIEvent(
        interaction: UIInteractionEvent.InteractionType,
        location: CGPoint? = nil,
        context: UIInteractionEvent.UIContext? = nil
    ) {
        let event = EventFactory.uiInteraction(
            interaction: interaction,
            location: location,
            context: context
        )
        publishEvent(event)
    }
    
    /// Publish performance event
    public func publishPerformanceEvent(
        metric: PerformanceEvent.MetricType,
        value: Double,
        unit: String,
        category: PerformanceEvent.PerformanceCategory
    ) {
        let event = EventFactory.performance(
            metric: metric,
            value: value,
            unit: unit,
            category: category
        )
        publishEvent(event)
    }
    
    /// Publish error event
    public func publishErrorEvent(
        error: Error,
        severity: ErrorEvent.ErrorSeverity,
        source: String,
        context: String? = nil,
        recoveryAction: String? = nil
    ) {
        let event = EventFactory.error(
            error: error,
            severity: severity,
            source: source,
            context: context,
            recoveryAction: recoveryAction
        )
        publishEvent(event)
    }
    
    /// Publish debug event
    public func publishDebugEvent(
        level: DebugEvent.DebugLevel,
        message: String,
        source: String,
        data: [String: Any]? = nil
    ) {
        let event = EventFactory.debug(
            level: level,
            message: message,
            source: source,
            data: data
        )
        publishEvent(event)
    }
    
    /// Generic event publishing
    public func publishEvent<E: Event>(_ event: E) {
        Task {
            await eventBus.publish(event)
            await updateMetrics()
        }
    }
    
    // MARK: - Observer Management
    
    /// Remove observer by ID
    public func removeObserver(id: UUID) async {
        await eventBus.removeObserver(id: id)
        
        // Update tracking
        if let source = observerSources[id] {
            registrations[source]?.removeAll { $0 == id }
            if registrations[source]?.isEmpty == true {
                registrations[source] = nil
            }
        }
        observerSources[id] = nil
        
        observerCount = max(0, observerCount - 1)
        ProductionLogger.debug("🎯 Observer removed: \(id)")
    }
    
    /// Remove all observers for a source
    public func removeObservers(for source: String) async {
        guard let observerIds = registrations[source] else { return }
        
        for observerId in observerIds {
            await eventBus.removeObserver(id: observerId)
            observerSources[observerId] = nil
        }
        
        registrations[source] = nil
        observerCount = max(0, observerCount - observerIds.count)
        
        ProductionLogger.debug("🎯 All observers removed for source: \(source)")
    }
    
    /// Remove all observers for an event type
    public func removeObservers<E: Event>(for eventType: E.Type) {
        eventBus.removeAllObservers(for: eventType)
        ProductionLogger.debug("🎯 All observers removed for event type: \(E.self)")
    }
    
    // MARK: - Legacy NotificationCenter Migration
    
    /// Migration helper for legacy NotificationCenter.Name patterns
    public struct LegacyNotificationMapping {
        public static let sortSettingsChanged = "sortSettingsChanged"
        public static let transitionSettingsChanged = "transitionSettingsChanged"
        public static let performanceSettingsChanged = "performanceSettingsChanged"
        public static let slideshowSettingsChanged = "slideshowSettingsChanged"
        public static let uiControlSettingsChanged = "uiControlSettingsChanged"
    }
    
    /// Migrate from legacy NotificationCenter pattern
    public func migrateLegacyNotification(
        name: String,
        source: String,
        handler: @escaping () async -> Void
    ) -> UUID {
        // Convert legacy notification name to appropriate event type
        switch name {
        case LegacyNotificationMapping.sortSettingsChanged:
            return observeSettingsEvents(source: source) { event in
                if case .sort = event.category {
                    await handler()
                }
            }
            
        case LegacyNotificationMapping.transitionSettingsChanged:
            return observeSettingsEvents(source: source) { event in
                if case .transition = event.category {
                    await handler()
                }
            }
            
        case LegacyNotificationMapping.performanceSettingsChanged:
            return observeSettingsEvents(source: source) { event in
                if case .performance = event.category {
                    await handler()
                }
            }
            
        case LegacyNotificationMapping.slideshowSettingsChanged:
            return observeSettingsEvents(source: source) { event in
                if case .slideshow = event.category {
                    await handler()
                }
            }
            
        case LegacyNotificationMapping.uiControlSettingsChanged:
            return observeSettingsEvents(source: source) { event in
                if case .uiControl = event.category {
                    await handler()
                }
            }
            
        default:
            // Create a generic settings event observer for unknown legacy notifications
            return observeSettingsEvents(source: source) { _ in
                await handler()
            }
        }
    }
    
    // MARK: - Performance and Analytics
    
    /// Update performance metrics
    private func updateMetrics() async {
        eventCount += 1
        
        // Calculate average processing time
        let metrics = await eventBus.getMetrics()
        averageProcessingTime = metrics.averageProcessingTime
        
        // Emit performance event for monitoring
        if eventCount % 100 == 0 {
            publishPerformanceEvent(
                metric: .renderTime,
                value: averageProcessingTime * 1000, // Convert to milliseconds
                unit: "ms",
                category: .userInterface
            )
        }
    }
    
    /// Get detailed observer statistics
    public func getStatistics() -> ObserverStatistics {
        return ObserverStatistics(
            totalObservers: observerCount,
            totalEvents: eventCount,
            averageProcessingTime: averageProcessingTime,
            activeSourceCount: registrations.count,
            sourceBreakdown: registrations.mapValues { $0.count }
        )
    }
    
    // MARK: - Setup and Configuration
    
    private func setupEventBusObservers() {
        // Set up meta-observers for system monitoring
        Task {
            // Monitor error events for system health
            await eventBus.observe(ErrorEvent.self, priority: .critical) { [weak self] event in
                await self?.handleSystemError(event)
            }
            
            // Monitor performance events for optimization
            await eventBus.observe(PerformanceEvent.self, priority: .low) { [weak self] event in
                await self?.handlePerformanceMetric(event)
            }
        }
    }
    
    private func handleSystemError(_ event: ErrorEvent) async {
        // Log critical errors
        if event.severity == .critical {
            ProductionLogger.error("🚨 Critical error detected: \(event.error)")
            
            // Could trigger automatic error reporting or recovery actions
            if let recoveryAction = event.recoveryAction {
                ProductionLogger.info("🔧 Attempting recovery: \(recoveryAction)")
            }
        }
    }
    
    private func handlePerformanceMetric(_ event: PerformanceEvent) async {
        // Track performance trends
        if event.metric == .memoryUsage && event.value > 1024 * 1024 * 1024 { // 1GB
            ProductionLogger.warning("⚠️ High memory usage detected: \(event.value / 1024 / 1024)MB")
        }
    }
}

// MARK: - Statistics Structure

public struct ObserverStatistics {
    public let totalObservers: Int
    public let totalEvents: Int
    public let averageProcessingTime: TimeInterval
    public let activeSourceCount: Int
    public let sourceBreakdown: [String: Int]
    
    public var description: String {
        return """
        Observer System Statistics:
        - Total Observers: \(totalObservers)
        - Events Processed: \(totalEvents)
        - Average Processing Time: \(String(format: "%.2fms", averageProcessingTime * 1000))
        - Active Sources: \(activeSourceCount)
        - Source Breakdown: \(sourceBreakdown)
        """
    }
}

// MARK: - Convenience Extensions

public extension UnifiedObserverCoordinator {
    
    /// Quick setup for common slideshow observers
    func setupSlideshowObservers(viewModel: UnifiedSlideshowViewModel) {
        // Observe slideshow events
        observeSlideshowEvents(source: "SlideshowViewModel") { event in
            await viewModel.handleSlideshowEvent(event)
        }
        
        // Observe photo events
        observePhotoEvents(source: "SlideshowViewModel") { event in
            await viewModel.handlePhotoEvent(event)
        }
        
        // Observe settings events
        observeSettingsEvents(source: "SlideshowViewModel") { event in
            await viewModel.handleSettingsEvent(event)
        }
    }
    
    /// Quick setup for common UI observers
    func setupUIObservers(uiManager: UIInteractionManager) {
        // Observe UI events
        observeUIEvents(source: "UIManager") { event in
            await uiManager.handleUIEvent(event)
        }
        
        // Observe error events for UI feedback
        observeErrorEvents(source: "UIManager") { event in
            await uiManager.handleErrorEvent(event)
        }
    }
    
    /// Quick setup for performance monitoring
    func setupPerformanceObservers(monitor: PerformanceMetricsManager) {
        // Observe performance events
        observePerformanceEvents(source: "PerformanceMonitor") { event in
            await monitor.handlePerformanceEvent(event)
        }
        
        // Observe system resource events
        registerObserver(
            eventType: SystemResourceEvent.self,
            source: "PerformanceMonitor",
            priority: .high
        ) { event in
            await monitor.handleResourceEvent(event)
        }
    }
}

// MARK: - Protocol Extensions for Event Handling

public extension UnifiedSlideshowViewModel {
    func handleSlideshowEvent(_ event: SlideshowPlaybackEvent) async {
        // Handle slideshow events in ViewModel
        ProductionLogger.debug("📺 SlideshowViewModel: Handling \(event.action)")
    }
    
    func handlePhotoEvent(_ event: PhotoLoadEvent) async {
        // Handle photo events in ViewModel
        ProductionLogger.debug("🖼️ SlideshowViewModel: Photo \(event.action) for \(event.photoId)")
    }
    
    func handleSettingsEvent(_ event: SettingsChangeEvent) async {
        // Handle settings events in ViewModel
        ProductionLogger.debug("⚙️ SlideshowViewModel: Settings \(event.action) in \(event.category)")
    }
}

public extension UIInteractionManager {
    func handleUIEvent(_ event: UIInteractionEvent) async {
        // Handle UI events
        ProductionLogger.debug("🖱️ UIManager: Interaction \(event.interaction)")
    }
    
    func handleErrorEvent(_ event: ErrorEvent) async {
        // Handle error events for user feedback
        ProductionLogger.debug("❌ UIManager: Error \(event.severity) - \(event.error)")
    }
}

public extension PerformanceMetricsManager {
    func handlePerformanceEvent(_ event: PerformanceEvent) async {
        // Handle performance events
        ProductionLogger.debug("📊 PerformanceManager: \(event.metric) = \(event.value) \(event.unit)")
    }
    
    func handleResourceEvent(_ event: SystemResourceEvent) async {
        // Handle system resource events
        ProductionLogger.debug("🖥️ PerformanceManager: \(event.resource) \(event.level) - \(event.action)")
    }
}