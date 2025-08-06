import Foundation

// MARK: - Core Event Types for Unified Event System

/// Base implementation for all events
public struct BaseEvent: Event {
    public let timestamp: Date
    public let source: String
    public let eventId: UUID
    
    public init(source: String = "Unknown") {
        self.timestamp = Date()
        self.source = source
        self.eventId = UUID()
    }
}

// MARK: - Slideshow Events

/// Events related to slideshow playback and navigation
public struct SlideshowPlaybackEvent: Event, HighPriorityEvent {
    public let timestamp: Date = Date()
    public let source: String = "SlideshowService"
    public let eventId: UUID = UUID()
    
    public let action: PlaybackAction
    public let slideshowId: UUID?
    public let photoIndex: Int?
    
    public enum PlaybackAction {
        case play
        case pause
        case stop
        case next
        case previous
        case jump(to: Int)
        case modeChange(SlideshowMode)
    }
    
    public enum SlideshowMode {
        case sequential
        case random
        case loop
    }
}

/// Events for photo loading and state changes
public struct PhotoLoadEvent: Event, BatchableEvent {
    public let timestamp: Date = Date()
    public let source: String = "ImageService"
    public let eventId: UUID = UUID()
    
    public let photoId: UUID
    public let action: LoadAction
    public let error: Error?
    
    public enum LoadAction {
        case started
        case progress(Double)
        case completed
        case failed
        case cached
    }
}

/// Events for slideshow collection changes
public struct SlideshowCollectionEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "SlideshowService"
    public let eventId: UUID = UUID()
    
    public let action: CollectionAction
    public let photoCount: Int
    public let folderURL: URL?
    
    public enum CollectionAction {
        case created
        case updated
        case cleared
        case sorted(by: SortOrder)
        case filtered
    }
}

// MARK: - Settings Events

/// Events for settings changes
public struct SettingsChangeEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "SettingsService"
    public let eventId: UUID = UUID()
    
    public let category: SettingsCategory
    public let action: SettingsAction
    public let oldValue: Any?
    public let newValue: Any?
    
    public enum SettingsCategory {
        case performance
        case slideshow
        case transition
        case sort
        case uiControl
        case all
    }
    
    public enum SettingsAction {
        case changed
        case reset
        case imported
        case exported
        case validated
    }
}

// MARK: - UI Events

/// Events for UI interactions and state changes
public struct UIInteractionEvent: Event, BatchableEvent {
    public let timestamp: Date = Date()
    public let source: String = "UIService"
    public let eventId: UUID = UUID()
    
    public let interaction: InteractionType
    public let location: CGPoint?
    public let context: UIContext?
    
    public enum InteractionType {
        case mouseMove
        case mouseClick
        case mouseHover
        case keyPress(key: String)
        case gesture(GestureType)
        case windowEvent(WindowEventType)
    }
    
    public enum WindowEventType {
        case resize
        case move
        case minimize
        case maximize
        case fullscreen
        case focus
        case blur
    }
    
    public enum UIContext {
        case slideshow
        case settings
        case menu
        case toolbar
    }
}

/// Events for visual effects and transitions
public struct VisualEffectEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "VisualEffectsService"
    public let eventId: UUID = UUID()
    
    public let effect: EffectType
    public let duration: TimeInterval?
    public let intensity: Double?
    
    public enum EffectType {
        case transition(TransitionType)
        case blur(BlurType)
        case animation(AnimationType)
        case theme(ThemeType)
    }
    
    public enum TransitionType {
        case fade
        case slide
        case zoom
        case custom(name: String)
    }
    
    public enum BlurType {
        case background
        case controls
        case overlay
    }
    
    public enum AnimationType {
        case entrance
        case exit
        case hover
        case selection
    }
    
    public enum ThemeType {
        case light
        case dark
        case auto
    }
}

// MARK: - Performance Events

/// Events for performance monitoring and metrics
public struct PerformanceEvent: Event, BatchableEvent {
    public let timestamp: Date = Date()
    public let source: String = "PerformanceMonitor"
    public let eventId: UUID = UUID()
    
    public let metric: MetricType
    public let value: Double
    public let unit: String
    public let category: PerformanceCategory
    
    public enum MetricType {
        case memoryUsage
        case loadTime
        case cacheHitRate
        case renderTime
        case cpuUsage
        case diskIO
        case networkLatency
    }
    
    public enum PerformanceCategory {
        case imageLoading
        case caching
        case rendering
        case userInterface
        case system
    }
}

/// Events for system resource and memory management
public struct SystemResourceEvent: Event, HighPriorityEvent {
    public let timestamp: Date = Date()
    public let source: String = "SystemMonitor"
    public let eventId: UUID = UUID()
    
    public let resource: ResourceType
    public let level: ResourceLevel
    public let action: ResourceAction
    
    public enum ResourceType {
        case memory
        case cpu
        case disk
        case network
    }
    
    public enum ResourceLevel {
        case low
        case normal
        case high
        case critical
    }
    
    public enum ResourceAction {
        case warning
        case cleanup
        case optimization
        case throttling
    }
}

// MARK: - Error and Debug Events

/// Events for error handling and debugging
public struct ErrorEvent: Event, HighPriorityEvent {
    public let timestamp: Date = Date()
    public let source: String
    public let eventId: UUID = UUID()
    
    public let error: Error
    public let severity: ErrorSeverity
    public let context: String?
    public let recoveryAction: String?
    
    public enum ErrorSeverity {
        case info
        case warning
        case error
        case critical
    }
    
    public init(error: Error, severity: ErrorSeverity, source: String, context: String? = nil, recoveryAction: String? = nil) {
        self.error = error
        self.severity = severity
        self.source = source
        self.context = context
        self.recoveryAction = recoveryAction
    }
}

/// Events for debug information and development
public struct DebugEvent: Event, BatchableEvent {
    public let timestamp: Date = Date()
    public let source: String
    public let eventId: UUID = UUID()
    
    public let level: DebugLevel
    public let message: String
    public let data: [String: Any]?
    
    public enum DebugLevel {
        case trace
        case debug
        case info
        case warn
        case error
    }
    
    public init(level: DebugLevel, message: String, source: String, data: [String: Any]? = nil) {
        self.level = level
        self.message = message
        self.source = source
        self.data = data
    }
}

// MARK: - File and Security Events

/// Events for file operations and security
public struct FileSecurityEvent: Event {
    public let timestamp: Date = Date()
    public let source: String = "FileSecurityService"
    public let eventId: UUID = UUID()
    
    public let action: SecurityAction
    public let fileURL: URL?
    public let success: Bool
    public let error: Error?
    
    public enum SecurityAction {
        case bookmarkCreated
        case bookmarkResolved
        case accessRequested
        case accessGranted
        case accessDenied
        case permissionChanged
    }
}

// MARK: - Application Lifecycle Events

/// Events for application state and lifecycle
public struct AppLifecycleEvent: Event, HighPriorityEvent {
    public let timestamp: Date = Date()
    public let source: String = "ApplicationService"
    public let eventId: UUID = UUID()
    
    public let phase: LifecyclePhase
    public let context: String?
    
    public enum LifecyclePhase {
        case willLaunch
        case didLaunch
        case willTerminate
        case didTerminate
        case willEnterBackground
        case didEnterBackground
        case willEnterForeground
        case didEnterForeground
        case memoryWarning
    }
}

// MARK: - Event Factory

/// Factory for creating standardized events
public struct EventFactory {
    
    /// Create slideshow playback event
    public static func slideshowPlayback(
        action: SlideshowPlaybackEvent.PlaybackAction,
        slideshowId: UUID? = nil,
        photoIndex: Int? = nil
    ) -> SlideshowPlaybackEvent {
        return SlideshowPlaybackEvent(
            action: action,
            slideshowId: slideshowId,
            photoIndex: photoIndex
        )
    }
    
    /// Create photo load event
    public static func photoLoad(
        photoId: UUID,
        action: PhotoLoadEvent.LoadAction,
        error: Error? = nil
    ) -> PhotoLoadEvent {
        return PhotoLoadEvent(
            photoId: photoId,
            action: action,
            error: error
        )
    }
    
    /// Create settings change event
    public static func settingsChange(
        category: SettingsChangeEvent.SettingsCategory,
        action: SettingsChangeEvent.SettingsAction,
        oldValue: Any? = nil,
        newValue: Any? = nil
    ) -> SettingsChangeEvent {
        return SettingsChangeEvent(
            category: category,
            action: action,
            oldValue: oldValue,
            newValue: newValue
        )
    }
    
    /// Create UI interaction event
    public static func uiInteraction(
        interaction: UIInteractionEvent.InteractionType,
        location: CGPoint? = nil,
        context: UIInteractionEvent.UIContext? = nil
    ) -> UIInteractionEvent {
        return UIInteractionEvent(
            interaction: interaction,
            location: location,
            context: context
        )
    }
    
    /// Create performance event
    public static func performance(
        metric: PerformanceEvent.MetricType,
        value: Double,
        unit: String,
        category: PerformanceEvent.PerformanceCategory
    ) -> PerformanceEvent {
        return PerformanceEvent(
            metric: metric,
            value: value,
            unit: unit,
            category: category
        )
    }
    
    /// Create error event
    public static func error(
        error: Error,
        severity: ErrorEvent.ErrorSeverity,
        source: String,
        context: String? = nil,
        recoveryAction: String? = nil
    ) -> ErrorEvent {
        return ErrorEvent(
            error: error,
            severity: severity,
            source: source,
            context: context,
            recoveryAction: recoveryAction
        )
    }
    
    /// Create debug event
    public static func debug(
        level: DebugEvent.DebugLevel,
        message: String,
        source: String,
        data: [String: Any]? = nil
    ) -> DebugEvent {
        return DebugEvent(
            level: level,
            message: message,
            source: source,
            data: data
        )
    }
}

// MARK: - Event Extensions

public extension Event {
    /// Convenience property to check if event should be processed immediately
    var isHighPriority: Bool {
        return self is HighPriorityEvent
    }
    
    /// Convenience property to check if event can be batched
    var isBatchable: Bool {
        return self is BatchableEvent
    }
    
    /// Get event age in seconds
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    /// Create a formatted description for logging
    var logDescription: String {
        return "[\(type(of: self))] \(source) @ \(timestamp.formatted()) - \(eventId.uuidString.prefix(8))"
    }
}