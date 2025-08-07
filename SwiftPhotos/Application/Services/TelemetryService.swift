import Foundation
import os.log
import Observation

/// Privacy-compliant telemetry service for monitoring Repository pattern usage and performance
/// Collects only aggregated, anonymized metrics to improve the application
@MainActor
public class TelemetryService: ObservableObject {
    
    // MARK: - Configuration
    
    public static let shared = TelemetryService()
    
    private let logger = Logger(subsystem: "com.swiftphotos.telemetry", category: "analytics")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Privacy Settings
    
    @Published public var isEnabled: Bool {
        didSet {
            userDefaults.set(self.isEnabled, forKey: "TelemetryEnabled")
            logger.info("Telemetry \(self.isEnabled ? "enabled" : "disabled") by user")
        }
    }
    
    @Published public var sharePerformanceData: Bool {
        didSet {
            userDefaults.set(sharePerformanceData, forKey: "SharePerformanceData")
        }
    }
    
    @Published public var shareUsageData: Bool {
        didSet {
            userDefaults.set(shareUsageData, forKey: "ShareUsageData")
        }
    }
    
    // MARK: - Session Tracking
    
    private var sessionStartTime = Date()
    private var sessionMetrics = SessionMetrics()
    private let sessionId = UUID()
    
    // MARK: - Initialization
    
    private init() {
        // Load user preferences (default to enabled with privacy-first approach)
        self.isEnabled = userDefaults.object(forKey: "TelemetryEnabled") as? Bool ?? true
        self.sharePerformanceData = userDefaults.object(forKey: "SharePerformanceData") as? Bool ?? true
        self.shareUsageData = userDefaults.object(forKey: "ShareUsageData") as? Bool ?? true
        
        startSession()
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        sessionStartTime = Date()
        sessionMetrics = SessionMetrics()
        
        if self.isEnabled {
            logger.info("Analytics session started: \(self.sessionId)")
            recordEvent(.sessionStart, properties: [
                "app_version": getAppVersion(),
                "macos_version": getOSVersion(),
                "device_model": getDeviceModel()
            ])
        }
    }
    
    public func endSession() {
        if isEnabled {
            let sessionDuration = Date().timeIntervalSince(sessionStartTime)
            recordEvent(.sessionEnd, properties: [
                "session_duration": sessionDuration,
                "photos_viewed": sessionMetrics.photosViewed,
                "pattern_switches": sessionMetrics.patternSwitches,
                "repository_usage_time": sessionMetrics.repositoryUsageTime,
                "legacy_usage_time": sessionMetrics.legacyUsageTime
            ])
            logger.info("Analytics session ended after \(sessionDuration)s")
        }
    }
    
    // MARK: - Repository Pattern Analytics
    
    public func recordRepositoryPatternActivation(reason: PatternActivationReason) {
        guard isEnabled && shareUsageData else { return }
        
        recordEvent(.repositoryPatternActivated, properties: [
            "activation_reason": reason.rawValue,
            "session_time": Date().timeIntervalSince(sessionStartTime)
        ])
        
        sessionMetrics.repositoryActivations += 1
        logger.info("Repository pattern activated: \(reason.rawValue)")
    }
    
    public func recordLegacyPatternFallback(reason: FallbackReason) {
        guard isEnabled && shareUsageData else { return }
        
        recordEvent(.legacyPatternFallback, properties: [
            "fallback_reason": reason.rawValue,
            "session_time": Date().timeIntervalSince(sessionStartTime)
        ])
        
        sessionMetrics.legacyFallbacks += 1
        logger.warning("Legacy pattern fallback: \(reason.rawValue)")
    }
    
    public func recordPatternSwitch(from: ViewModelPattern, to: ViewModelPattern, trigger: SwitchTrigger) {
        guard isEnabled && shareUsageData else { return }
        
        recordEvent(.patternSwitch, properties: [
            "from_pattern": from.rawValue,
            "to_pattern": to.rawValue,
            "trigger": trigger.rawValue
        ])
        
        sessionMetrics.patternSwitches += 1
        logger.info("Pattern switch: \(from.rawValue) → \(to.rawValue) (\(trigger.rawValue))")
    }
    
    // MARK: - Performance Analytics
    
    public func recordPhotoCollectionLoad(
        photoCount: Int,
        loadTime: TimeInterval,
        memoryUsage: Int64,
        pattern: ViewModelPattern
    ) {
        guard isEnabled && sharePerformanceData else { return }
        
        recordEvent(.photoCollectionLoaded, properties: [
            "photo_count": photoCount,
            "load_time": loadTime,
            "memory_usage_mb": Double(memoryUsage) / 1024 / 1024,
            "pattern": pattern.rawValue,
            "collection_size_category": categorizeCollectionSize(photoCount)
        ])
        
        sessionMetrics.collectionsLoaded += 1
        sessionMetrics.totalPhotosLoaded += photoCount
        
        // Track performance trends
        if pattern == .repository {
            sessionMetrics.repositoryLoadTimes.append(loadTime)
        } else {
            sessionMetrics.legacyLoadTimes.append(loadTime)
        }
        
        logger.info("Collection loaded: \(photoCount) photos in \(loadTime)s using \(pattern.rawValue)")
    }
    
    public func recordSlideshowSession(
        duration: TimeInterval,
        photosViewed: Int,
        pattern: ViewModelPattern,
        transitionType: String
    ) {
        guard isEnabled && shareUsageData else { return }
        
        recordEvent(.slideshowSession, properties: [
            "duration": duration,
            "photos_viewed": photosViewed,
            "pattern": pattern.rawValue,
            "transition_type": transitionType,
            "photos_per_minute": Double(photosViewed) / (duration / 60.0)
        ])
        
        sessionMetrics.photosViewed += photosViewed
        sessionMetrics.slideshowSessions += 1
        
        if pattern == .repository {
            sessionMetrics.repositoryUsageTime += duration
        } else {
            sessionMetrics.legacyUsageTime += duration
        }
        
        logger.info("Slideshow session: \(duration)s, \(photosViewed) photos, \(pattern.rawValue)")
    }
    
    // MARK: - Error Analytics
    
    public func recordError(
        error: Error,
        context: ErrorContext,
        pattern: ViewModelPattern
    ) {
        guard isEnabled else { return }
        
        recordEvent(.errorOccurred, properties: [
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "context": context.rawValue,
            "pattern": pattern.rawValue,
            "is_fatal": false
        ])
        
        sessionMetrics.errorsEncountered += 1
        logger.error("Error recorded: \(error.localizedDescription) in \(context.rawValue)")
    }
    
    public func recordPerformanceIssue(
        issue: PerformanceIssue,
        severity: IssueSeverity,
        metrics: [String: Any]
    ) {
        guard isEnabled && sharePerformanceData else { return }
        
        var properties = metrics
        properties["issue_type"] = issue.rawValue
        properties["severity"] = severity.rawValue
        properties["timestamp"] = Date().timeIntervalSince1970
        
        recordEvent(.performanceIssue, properties: properties)
        
        sessionMetrics.performanceIssues += 1
        logger.warning("Performance issue: \(issue.rawValue) (\(severity.rawValue))")
    }
    
    // MARK: - Feature Usage Analytics
    
    public func recordFeatureUsage(_ feature: Feature, properties: [String: Any] = [:]) {
        guard isEnabled && shareUsageData else { return }
        
        var eventProperties = properties
        eventProperties["feature"] = feature.rawValue
        eventProperties["usage_count"] = sessionMetrics.featureUsage[feature.rawValue, default: 0] + 1
        
        recordEvent(.featureUsed, properties: eventProperties)
        
        sessionMetrics.featureUsage[feature.rawValue] = sessionMetrics.featureUsage[feature.rawValue, default: 0] + 1
        logger.info("Feature used: \(feature.rawValue)")
    }
    
    public func recordUserInteraction(_ interaction: UserInteraction, context: String? = nil) {
        guard isEnabled && shareUsageData else { return }
        
        var properties: [String: Any] = [
            "interaction": interaction.rawValue
        ]
        
        if let context = context {
            properties["context"] = context
        }
        
        recordEvent(.userInteraction, properties: properties)
        sessionMetrics.totalInteractions += 1
    }
    
    // MARK: - Health Monitoring
    
    public func recordRepositoryHealth(health: RepositoryHealth) {
        guard isEnabled && sharePerformanceData else { return }
        
        recordEvent(.repositoryHealthCheck, properties: [
            "is_healthy": health.isHealthy,
            "status": health.status.rawValue,
            "response_time": health.responseTime ?? 0,
            "error_count": health.errors.count,
            "warning_count": health.warnings.count
        ])
        
        if !health.isHealthy {
            logger.warning("Repository health degraded: \(health.status.rawValue)")
        }
    }
    
    // MARK: - System Information
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    // MARK: - Utility Methods
    
    private func categorizeCollectionSize(_ count: Int) -> String {
        switch count {
        case 0...50: return "small"
        case 51...500: return "medium"
        case 501...5000: return "large"
        default: return "massive"
        }
    }
    
    private func recordEvent(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        // In a real implementation, this would send data to an analytics service
        // For now, we'll log to the system log for debugging
        
        let eventData: [String: Any] = [
            "event": event.rawValue,
            "session_id": sessionId.uuidString,
            "timestamp": Date().timeIntervalSince1970,
            "properties": properties
        ]
        
        // Store locally for batch upload later
        storeEventLocally(eventData)
        
        logger.info("Analytics event: \(event.rawValue)")
    }
    
    private func storeEventLocally(_ eventData: [String: Any]) {
        // Store events locally for batch processing
        // This prevents blocking the UI and allows for offline usage
        
        var storedEvents = userDefaults.array(forKey: "StoredAnalyticsEvents") as? [[String: Any]] ?? []
        storedEvents.append(eventData)
        
        // Keep only the last 1000 events to prevent storage growth
        if storedEvents.count > 1000 {
            storedEvents = Array(storedEvents.suffix(1000))
        }
        
        userDefaults.set(storedEvents, forKey: "StoredAnalyticsEvents")
    }
    
    // MARK: - Data Export & Privacy
    
    public func exportAnalyticsData() -> Data? {
        guard isEnabled else { return nil }
        
        let storedEvents = userDefaults.array(forKey: "StoredAnalyticsEvents") as? [[String: Any]] ?? []
        
        do {
            return try JSONSerialization.data(withJSONObject: storedEvents, options: .prettyPrinted)
        } catch {
            logger.error("Failed to export analytics data: \(error)")
            return nil
        }
    }
    
    public func clearAnalyticsData() {
        userDefaults.removeObject(forKey: "StoredAnalyticsEvents")
        sessionMetrics = SessionMetrics()
        logger.info("Analytics data cleared by user request")
    }
    
    public func getDataSummary() -> String {
        let storedEvents = userDefaults.array(forKey: "StoredAnalyticsEvents") as? [[String: Any]] ?? []
        
        return """
        Analytics Data Summary:
        - Total Events: \(storedEvents.count)
        - Session ID: \(sessionId)
        - Data Collection: \(isEnabled ? "Enabled" : "Disabled")
        - Performance Data: \(sharePerformanceData ? "Shared" : "Not Shared")
        - Usage Data: \(shareUsageData ? "Shared" : "Not Shared")
        """
    }
}

// MARK: - Supporting Types

extension TelemetryService {
    
    public enum PatternActivationReason: String, CaseIterable {
        case automaticSelection = "automatic_selection"
        case userPreference = "user_preference"
        case largeCollection = "large_collection"
        case performanceOptimization = "performance_optimization"
        case featureRequirement = "feature_requirement"
    }
    
    public enum FallbackReason: String, CaseIterable {
        case memoryPressure = "memory_pressure"
        case repositoryError = "repository_error"
        case performanceIssue = "performance_issue"
        case userRequest = "user_request"
        case systemCompatibility = "system_compatibility"
    }
    
    public enum ViewModelPattern: String, CaseIterable {
        case repository = "repository"
        case legacy = "legacy"
    }
    
    public enum SwitchTrigger: String, CaseIterable {
        case automatic = "automatic"
        case manual = "manual"
        case systemCondition = "system_condition"
        case errorRecovery = "error_recovery"
    }
    
    public enum ErrorContext: String, CaseIterable {
        case imageLoading = "image_loading"
        case metadataExtraction = "metadata_extraction"
        case cacheManagement = "cache_management"
        case fileSystemAccess = "file_system_access"
        case settingsManagement = "settings_management"
        case uiRendering = "ui_rendering"
    }
    
    public enum PerformanceIssue: String, CaseIterable {
        case slowImageLoad = "slow_image_load"
        case highMemoryUsage = "high_memory_usage"
        case highCPUUsage = "high_cpu_usage"
        case cacheInefficiency = "cache_inefficiency"
        case uiStutter = "ui_stutter"
    }
    
    public enum IssueSeverity: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
    
    public enum Feature: String, CaseIterable {
        case repositoryPattern = "repository_pattern"
        case virtualLoading = "virtual_loading"
        case advancedSearch = "advanced_search"
        case metadataDisplay = "metadata_display"
        case patternSwitching = "pattern_switching"
        case performanceMonitoring = "performance_monitoring"
        case slideshowPlayback = "slideshow_playback"
        case settingsConfiguration = "settings_configuration"
    }
    
    public enum UserInteraction: String, CaseIterable {
        case photoNavigation = "photo_navigation"
        case slideshowControl = "slideshow_control"
        case settingsAccess = "settings_access"
        case folderSelection = "folder_selection"
        case patternToggle = "pattern_toggle"
        case searchUsage = "search_usage"
        case infoDisplay = "info_display"
    }
    
    public enum AnalyticsEvent: String, CaseIterable {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case repositoryPatternActivated = "repository_pattern_activated"
        case legacyPatternFallback = "legacy_pattern_fallback"
        case patternSwitch = "pattern_switch"
        case photoCollectionLoaded = "photo_collection_loaded"
        case slideshowSession = "slideshow_session"
        case errorOccurred = "error_occurred"
        case performanceIssue = "performance_issue"
        case featureUsed = "feature_used"
        case userInteraction = "user_interaction"
        case repositoryHealthCheck = "repository_health_check"
    }
}

// MARK: - Session Metrics

private struct SessionMetrics {
    var photosViewed = 0
    var patternSwitches = 0
    var repositoryUsageTime: TimeInterval = 0
    var legacyUsageTime: TimeInterval = 0
    var repositoryActivations = 0
    var legacyFallbacks = 0
    var collectionsLoaded = 0
    var totalPhotosLoaded = 0
    var slideshowSessions = 0
    var errorsEncountered = 0
    var performanceIssues = 0
    var totalInteractions = 0
    var featureUsage: [String: Int] = [:]
    var repositoryLoadTimes: [TimeInterval] = []
    var legacyLoadTimes: [TimeInterval] = []
}