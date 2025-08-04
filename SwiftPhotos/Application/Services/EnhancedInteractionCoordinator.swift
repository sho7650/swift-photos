import Foundation
import SwiftUI
import Combine
import os.log

/// Central coordinator that integrates all enhanced interaction components
/// Provides a unified interface for managing advanced UI interactions
@MainActor
public class EnhancedInteractionCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var currentConfiguration: InteractionSystemConfiguration
    @Published public private(set) var activeInteractions: Set<InteractionType> = []
    @Published public private(set) var performanceMetrics: InteractionPerformanceMetrics
    
    // MARK: - Component References
    
    public let interactionDetector: InteractionDetector
    public let mouseTracker: MouseTracker
    public let adaptiveTimerManager: AdaptiveTimerManager
    public let positionManager: OverlayPositionManager
    public let effectManager: BlurEffectManager
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "EnhancedInteractionCoordinator")
    private var cancellables = Set<AnyCancellable>()
    private var featureFlags: FeatureFlags
    private var interactionHistory: [InteractionEvent] = []
    private let maxHistorySize = 100
    
    // Component integration
    private var isInitialized = false
    
    // MARK: - Initialization
    
    public init(configuration: InteractionSystemConfiguration? = nil, featureFlags: FeatureFlags? = nil) {
        // Initialize configuration
        let config = configuration ?? InteractionSystemConfiguration.default
        self.currentConfiguration = config
        self.featureFlags = featureFlags ?? FeatureFlags.default
        self.performanceMetrics = InteractionPerformanceMetrics()
        
        // Initialize components
        self.interactionDetector = InteractionDetector(configuration: config.interactionConfig)
        self.mouseTracker = MouseTracker(configuration: config.mouseTracking)
        self.adaptiveTimerManager = AdaptiveTimerManager()
        self.positionManager = OverlayPositionManager(
            configuration: config.positioning
        )
        self.effectManager = BlurEffectManager()
        
        logger.info("🎯 EnhancedInteractionCoordinator: Initialized")
        
        setupComponentIntegration()
        setupObservers()
    }
    
    // MARK: - Public Interface
    
    /// Enable the enhanced interaction system
    public func enable() {
        guard !isEnabled else { return }
        
        logger.info("🎯 EnhancedInteractionCoordinator: Enabling enhanced interactions")
        
        do {
            // Enable components based on feature flags
            if featureFlags.enableAdvancedGestures {
                try interactionDetector.startDetection()
            }
            
            if featureFlags.enableMouseTracking {
                try mouseTracker.startTracking()
            }
            
            if featureFlags.enableAdaptiveTiming {
                adaptiveTimerManager.enableAdaptation()
            }
            
            isEnabled = true
            
            // Start performance monitoring
            startPerformanceMonitoring()
            
            logger.info("🎯 EnhancedInteractionCoordinator: Successfully enabled all components")
            
        } catch {
            logger.error("🎯 EnhancedInteractionCoordinator: Failed to enable - \(error.localizedDescription)")
            disable()
        }
    }
    
    /// Disable the enhanced interaction system
    public func disable() {
        guard isEnabled else { return }
        
        logger.info("🎯 EnhancedInteractionCoordinator: Disabling enhanced interactions")
        
        interactionDetector.stopDetection()
        mouseTracker.stopTracking()
        adaptiveTimerManager.disableAdaptation()
        
        isEnabled = false
        activeInteractions.removeAll()
        
        stopPerformanceMonitoring()
    }
    
    /// Update system configuration
    public func updateConfiguration(_ configuration: InteractionSystemConfiguration) {
        logger.info("🎯 EnhancedInteractionCoordinator: Updating configuration")
        
        let wasEnabled = isEnabled
        if wasEnabled {
            disable()
        }
        
        currentConfiguration = configuration
        
        // Update component configurations
        do {
            try interactionDetector.updateConfiguration(configuration.interactionConfig)
            mouseTracker.configuration = configuration.mouseTracking
            positionManager.configuration = configuration.positioning
            adaptiveTimerManager.updateGlobalConfiguration(configuration.adaptiveTiming)
            
            if wasEnabled {
                enable()
            }
        } catch {
            logger.error("🎯 EnhancedInteractionCoordinator: Configuration update failed - \(error.localizedDescription)")
        }
    }
    
    /// Update feature flags
    public func updateFeatureFlags(_ flags: FeatureFlags) {
        logger.info("🎯 EnhancedInteractionCoordinator: Updating feature flags")
        
        featureFlags = flags
        
        // Re-enable with new flags
        if isEnabled {
            disable()
            enable()
        }
    }
    
    /// Create an adaptive timer with coordinated behavior
    public func createAdaptiveTimer(for purpose: TimerPurpose, configuration: TimerConfiguration? = nil) -> UnifiedAdaptiveTimer {
        let config = configuration ?? currentConfiguration.adaptiveTiming
        let timer = adaptiveTimerManager.createTimer(purpose: purpose, configuration: config)
        
        // Set up timer integration
        timer.delegate = AdaptiveTimerCoordinatorDelegate(coordinator: self, purpose: purpose)
        
        return timer
    }
    
    /// Get current blur effect for an overlay
    public func getBlurEffect(for overlay: OverlayType) -> some View {
        effectManager.createBlurView(for: overlay)
    }
    
    /// Calculate optimal position for an overlay
    public func calculatePosition(for overlay: OverlayType, in bounds: CGRect) -> CGPoint {
        return positionManager.calculatePosition(for: overlay, in: bounds)
    }
    
    /// Get performance report
    public func getPerformanceReport() -> InteractionPerformanceReport {
        return InteractionPerformanceReport(
            metrics: performanceMetrics,
            interactionHistory: Array(interactionHistory.suffix(50)),
            componentStatus: getComponentStatus(),
            timestamp: Date()
        )
    }
    
    // MARK: - Private Setup
    
    private func setupComponentIntegration() {
        // Set up interaction detector integration
        interactionDetector.delegate = self
        interactionDetector.addObserver(self)
        
        // Set up mouse tracker integration
        mouseTracker.delegate = self
        
        // Set up position manager observers
        positionManager.addPositionObserver(self)
        
        // Set up timer manager integration
        adaptiveTimerManager.globalDelegate = self
        
        logger.debug("🎯 EnhancedInteractionCoordinator: Component integration complete")
    }
    
    private func setupObservers() {
        // Observe interaction detector state
        interactionDetector.$isEnabled
            .sink { [weak self] isEnabled in
                self?.handleComponentStateChange(component: .interactionDetector, isEnabled: isEnabled)
            }
            .store(in: &cancellables)
        
        // Observe mouse tracker state
        mouseTracker.$isTracking
            .sink { [weak self] isTracking in
                self?.handleComponentStateChange(component: .mouseTracker, isEnabled: isTracking)
            }
            .store(in: &cancellables)
        
        // Observe blur effect changes
        effectManager.$currentStyle
            .sink { [weak self] style in
                self?.logger.debug("🎯 EnhancedInteractionCoordinator: Blur style changed to \(style.rawValue)")
            }
            .store(in: &cancellables)
    }
    
    private func handleComponentStateChange(component: ComponentType, isEnabled: Bool) {
        logger.debug("🎯 EnhancedInteractionCoordinator: \(component.rawValue) state changed to \(isEnabled ? "enabled" : "disabled")")
        
        // Update performance metrics
        performanceMetrics.updateComponentState(component: component, isEnabled: isEnabled)
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        performanceMetrics.startMonitoring()
        
        // Monitor interaction frequency
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func stopPerformanceMonitoring() {
        performanceMetrics.stopMonitoring()
    }
    
    private func updatePerformanceMetrics() {
        // Calculate interactions per second
        let recentInteractions = interactionHistory.filter { event in
            Date().timeIntervalSince(event.timestamp) < 1.0
        }
        
        performanceMetrics.interactionsPerSecond = Double(recentInteractions.count)
        
        // Update active interaction types
        activeInteractions = Set(recentInteractions.map { $0.interaction.type })
    }
    
    private func recordInteractionEvent(_ interaction: Interaction) {
        let event = InteractionEvent(
            interaction: interaction,
            timestamp: Date(),
            processingTime: 0.0 // Would be calculated in real implementation
        )
        
        interactionHistory.append(event)
        
        // Limit history size
        if interactionHistory.count > maxHistorySize {
            interactionHistory.removeFirst(interactionHistory.count - maxHistorySize)
        }
    }
    
    private func getComponentStatus() -> ComponentStatus {
        return ComponentStatus(
            interactionDetector: interactionDetector.isEnabled,
            mouseTracker: mouseTracker.isTracking,
            adaptiveTimers: adaptiveTimerManager.activeTimerCount,
            blurEffectsActive: effectManager.isPerformanceMode,
            positionConflicts: positionManager.hasPositionConflicts()
        )
    }
}

// MARK: - InteractionDetectorDelegate

extension EnhancedInteractionCoordinator: InteractionDetectorDelegate {
    public func detectorDidDetectInteraction(_ detector: InteractionDetecting, interaction: Interaction) {
        recordInteractionEvent(interaction)
        
        // Route to appropriate handler based on interaction type
        switch interaction.type {
        case .mouseMove, .mouseClick, .mouseScroll:
            handleMouseInteraction(interaction)
        case .keyPress:
            handleKeyboardInteraction(interaction)
        case .gesture, .touch:
            handleGestureInteraction(interaction)
        default:
            handleGenericInteraction(interaction)
        }
    }
    
    public func detectorDidEncounterError(_ detector: InteractionDetecting, error: InteractionError) {
        logger.error("🎯 EnhancedInteractionCoordinator: Interaction detection error - \(error.localizedDescription)")
        performanceMetrics.recordError(error)
    }
    
    public func detectorDidStartDetection(_ detector: InteractionDetecting) {
        logger.info("🎯 EnhancedInteractionCoordinator: Interaction detection started")
    }
    
    public func detectorDidStopDetection(_ detector: InteractionDetecting) {
        logger.info("🎯 EnhancedInteractionCoordinator: Interaction detection stopped")
    }
    
    public func detectorDidUpdateConfiguration(_ detector: InteractionDetecting, configuration: InteractionConfiguration) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Interaction configuration updated")
    }
}

// MARK: - InteractionObserver

extension EnhancedInteractionCoordinator: InteractionObserver {
    public func interactionOccurred(_ interaction: Interaction) {
        // Additional processing for observed interactions
        performanceMetrics.recordInteraction(interaction)
    }
    
    public func interactionDetectionFailed(_ error: InteractionError) {
        performanceMetrics.recordError(error)
    }
    
    public func interactionConfigurationDidChange(_ configuration: InteractionConfiguration) {
        // Configuration changes are handled through the delegate
    }
}

// MARK: - MouseTrackingDelegate

extension EnhancedInteractionCoordinator: MouseTrackingDelegate {
    public func mouseTrackingDidStart(_ tracker: MouseTracker) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Mouse tracking started")
    }
    
    public func mouseTrackingDidStop(_ tracker: MouseTracker) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Mouse tracking stopped")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didUpdatePosition position: CGPoint, velocity: CGVector) {
        // Update position-dependent components
        logger.debug("🎯 EnhancedInteractionCoordinator: Mouse position updated")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didDetectHighVelocity velocity: CGVector) {
        logger.debug("🎯 EnhancedInteractionCoordinator: High velocity mouse movement detected")
        
        // Trigger fast response mode
        if featureFlags.enableAdaptiveTiming {
            adaptiveTimerManager.enterFastResponseMode()
        }
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didEnterZone zone: MouseTrackingZone) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Mouse entered zone")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didExitZone zone: MouseTrackingZone) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Mouse exited zone")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didAddZone zone: MouseTrackingZone) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Zone added")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didRemoveZoneWithId id: UUID) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Zone removed")
    }
    
    public func mouseTrackerDidClearAllZones(_ tracker: MouseTracker) {
        logger.debug("🎯 EnhancedInteractionCoordinator: All zones cleared")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didUpdateConfiguration configuration: MouseTrackingConfiguration) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Mouse tracking configuration updated")
    }
}

// MARK: - PositionObserver

extension EnhancedInteractionCoordinator: PositionObserver {
    public func positionDidChange(overlay: OverlayType, from oldPosition: CGPoint, to newPosition: CGPoint) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Position changed for \(overlay.rawValue)")
    }
    
    public func positionValidationFailed(overlay: OverlayType, invalidPosition: CGPoint, reason: String) {
        logger.warning("🎯 EnhancedInteractionCoordinator: Position validation failed for \(overlay.rawValue): \(reason)")
    }
}

// MARK: - AdaptiveTimerManagerDelegate

extension EnhancedInteractionCoordinator: @preconcurrency AdaptiveTimerManagerDelegate {
    nonisolated public func timerManager(_ manager: AdaptiveTimerManager, didCreateTimer timer: UnifiedAdaptiveTimer, purpose: TimerPurpose) {
        let purposeValue = purpose.rawValue
        Task { @MainActor in
            logger.debug("🎯 EnhancedInteractionCoordinator: Timer created for \(purposeValue)")
        }
    }
    
    nonisolated public func timerManager(_ manager: AdaptiveTimerManager, didAdaptTimer timer: UnifiedAdaptiveTimer, newDuration: TimeInterval) {
        Task { @MainActor in
            logger.debug("🎯 EnhancedInteractionCoordinator: Timer adapted to \(String(format: "%.1f", newDuration))s")
        }
    }
    
    nonisolated public func timerManagerDidEnterFastResponseMode(_ manager: AdaptiveTimerManager) {
        Task { @MainActor in
            logger.info("🎯 EnhancedInteractionCoordinator: Entered fast response mode")
            // Adjust other components for fast response
            effectManager.setPerformanceMode(true)
        }
    }
    
    // MARK: - Timer Event Handlers
    
    public func handleTimerFired(purpose: TimerPurpose, timer: AdaptiveTimerProviding) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Timer fired for purpose: \(purpose.rawValue)")
        
        switch purpose {
        case .autoHide:
            // Handle auto-hide timer
            break
        case .animation:
            // Handle animation timer
            break
        case .interaction:
            // Handle interaction timer
            break
        case .performance:
            // Handle performance timer
            break
        }
    }
    
    public func handleTimerAdapted(purpose: TimerPurpose, timer: AdaptiveTimerProviding, newDuration: TimeInterval, reason: AdaptationReason) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Timer adapted for purpose: \(purpose.rawValue), new duration: \(newDuration)s, reason: \(reason.rawValue)")
        
        // Update performance metrics
        performanceMetrics.adaptationCount += 1
    }
    
    public func handleTimerError(purpose: TimerPurpose, timer: AdaptiveTimerProviding, error: TimerError) {
        logger.error("🎯 EnhancedInteractionCoordinator: Timer error for purpose: \(purpose.rawValue), error: \(error.localizedDescription)")
        
        // Update performance metrics
        performanceMetrics.errorCount += 1
    }
}

// MARK: - Interaction Handlers

extension EnhancedInteractionCoordinator {
    private func handleMouseInteraction(_ interaction: Interaction) {
        // Mouse-specific handling
        logger.debug("🎯 EnhancedInteractionCoordinator: Handling mouse interaction")
    }
    
    private func handleKeyboardInteraction(_ interaction: Interaction) {
        // Keyboard-specific handling
        if interaction.data.keyCode == 0x31 { // Space key
            // Example: Toggle play/pause
            logger.debug("🎯 EnhancedInteractionCoordinator: Space key pressed")
        }
    }
    
    private func handleGestureInteraction(_ interaction: Interaction) {
        // Gesture-specific handling
        if let gestureData = interaction.data.gestureData {
            switch gestureData.gestureType {
            case .magnify:
                handlePinchGesture(scale: gestureData.scale ?? 1.0)
            case .swipeLeft, .swipeRight:
                handleSwipeGesture(direction: gestureData.gestureType)
            default:
                break
            }
        }
    }
    
    private func handleGenericInteraction(_ interaction: Interaction) {
        // Generic interaction handling
        logger.debug("🎯 EnhancedInteractionCoordinator: Generic interaction of type \(interaction.type.rawValue)")
    }
    
    private func handlePinchGesture(scale: Double) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Pinch gesture with scale \(scale)")
        // Implement pinch handling
    }
    
    private func handleSwipeGesture(direction: GestureType) {
        logger.debug("🎯 EnhancedInteractionCoordinator: Swipe gesture in direction \(direction.rawValue)")
        // Implement swipe handling
    }
    
    private func resolvePositionConflicts(_ overlays: [OverlayType]) {
        // Simple conflict resolution: reposition overlays with lower priority
        logger.debug("🎯 EnhancedInteractionCoordinator: Resolving position conflicts")
    }
}

// MARK: - Supporting Types

/// System-wide interaction configuration
public struct InteractionSystemConfiguration: Sendable {
    public let interactionConfig: InteractionConfiguration
    public let mouseTracking: MouseTrackingConfiguration
    public let gestureRecognition: GestureConfiguration
    public let adaptiveTiming: TimerConfiguration
    public let positioning: PositionConfiguration
    
    public static let `default` = InteractionSystemConfiguration(
        interactionConfig: InteractionConfiguration(),
        mouseTracking: MouseTrackingConfiguration(),
        gestureRecognition: GestureConfiguration(),
        adaptiveTiming: TimerConfiguration(baseDuration: 5.0),
        positioning: PositionConfiguration()
    )
}

/// Feature flags for enabling/disabling functionality
public struct FeatureFlags: Codable, Sendable {
    public let enableAdvancedGestures: Bool
    public let enableAdaptiveTiming: Bool
    public let enableMultiMonitorSupport: Bool
    public let enableAccessibilityEnhancements: Bool
    public let enableMouseTracking: Bool
    public let enableDynamicPositioning: Bool
    public let enableAutoConflictResolution: Bool
    
    public static let `default` = FeatureFlags(
        enableAdvancedGestures: true,
        enableAdaptiveTiming: true,
        enableMultiMonitorSupport: false,
        enableAccessibilityEnhancements: true,
        enableMouseTracking: true,
        enableDynamicPositioning: true,
        enableAutoConflictResolution: true
    )
}

/// Performance metrics for the interaction system
public struct InteractionPerformanceMetrics {
    public var interactionsPerSecond: Double = 0
    public var averageProcessingTime: TimeInterval = 0
    public var errorCount: Int = 0
    public var adaptationCount: Int = 0
    public var componentStates: [ComponentType: Bool] = [:]
    
    mutating func startMonitoring() {
        // Reset metrics
        interactionsPerSecond = 0
        averageProcessingTime = 0
        errorCount = 0
        adaptationCount = 0
    }
    
    mutating func stopMonitoring() {
        // Final cleanup
    }
    
    mutating func recordInteraction(_ interaction: Interaction) {
        // Update metrics
    }
    
    mutating func recordError(_ error: Error) {
        errorCount += 1
    }
    
    mutating func updateComponentState(component: ComponentType, isEnabled: Bool) {
        componentStates[component] = isEnabled
    }
}

/// Component types in the system
public enum ComponentType: String {
    case interactionDetector = "InteractionDetector"
    case mouseTracker = "MouseTracker"
    case adaptiveTimer = "AdaptiveTimer"
    case positionManager = "PositionManager"
    case effectManager = "EffectManager"
}

/// Interaction event for history tracking
public struct InteractionEvent {
    let interaction: Interaction
    let timestamp: Date
    let processingTime: TimeInterval
}

/// Performance report
public struct InteractionPerformanceReport {
    let metrics: InteractionPerformanceMetrics
    let interactionHistory: [InteractionEvent]
    let componentStatus: ComponentStatus
    let timestamp: Date
}

/// Component status
public struct ComponentStatus {
    let interactionDetector: Bool
    let mouseTracker: Bool
    let adaptiveTimers: Int
    let blurEffectsActive: Bool
    let positionConflicts: Bool
}

/// Timer purposes for adaptive timing
public enum TimerPurpose: String {
    case autoHide = "autoHide"
    case animation = "animation"
    case interaction = "interaction"
    case performance = "performance"
}

/// Adaptive timer manager for coordinated timing
@MainActor
public class AdaptiveTimerManager: ObservableObject {
    @Published public private(set) var activeTimerCount: Int = 0
    public weak var globalDelegate: AdaptiveTimerManagerDelegate?
    
    private var timers: [UUID: UnifiedAdaptiveTimer] = [:]
    private var adaptationEnabled: Bool = false
    private var fastResponseMode: Bool = false
    
    public func createTimer(purpose: TimerPurpose, configuration: TimerConfiguration) -> UnifiedAdaptiveTimer {
        let timer = UnifiedAdaptiveTimer(configuration: configuration)
        let timerId = UUID()
        timers[timerId] = timer
        activeTimerCount = timers.count
        
        globalDelegate?.timerManager(self, didCreateTimer: timer, purpose: purpose)
        
        return timer
    }
    
    public func enableAdaptation() {
        adaptationEnabled = true
        timers.values.forEach { $0.adaptationEnabled = true }
    }
    
    public func disableAdaptation() {
        adaptationEnabled = false
        timers.values.forEach { $0.adaptationEnabled = false }
    }
    
    public func updateGlobalConfiguration(_ config: TimerConfiguration) {
        timers.values.forEach { timer in
            try? timer.updateConfiguration(config)
        }
    }
    
    public func enterFastResponseMode() {
        fastResponseMode = true
        globalDelegate?.timerManagerDidEnterFastResponseMode(self)
        
        // Reduce all timer durations temporarily
        timers.values.forEach { timer in
            timer.extend(by: -timer.remainingTime * 0.5)
        }
    }
}

/// Delegate for adaptive timer manager
public protocol AdaptiveTimerManagerDelegate: AnyObject {
    func timerManager(_ manager: AdaptiveTimerManager, didCreateTimer timer: UnifiedAdaptiveTimer, purpose: TimerPurpose)
    func timerManager(_ manager: AdaptiveTimerManager, didAdaptTimer timer: UnifiedAdaptiveTimer, newDuration: TimeInterval)
    func timerManagerDidEnterFastResponseMode(_ manager: AdaptiveTimerManager)
}

/// Delegate wrapper for adaptive timers
private class AdaptiveTimerCoordinatorDelegate: AdaptiveTimerDelegate {
    weak var coordinator: EnhancedInteractionCoordinator?
    let purpose: TimerPurpose
    
    init(coordinator: EnhancedInteractionCoordinator, purpose: TimerPurpose) {
        self.coordinator = coordinator
        self.purpose = purpose
    }
    
    func timerDidFire(_ timer: AdaptiveTimerProviding) {
        // Handle timer firing
        Task { @MainActor in
            coordinator?.handleTimerFired(purpose: purpose, timer: timer)
        }
    }
    
    func timerDidAdapt(_ timer: AdaptiveTimerProviding, newDuration: TimeInterval, reason: AdaptationReason) {
        // Log timer adaptation
        Task { @MainActor in
            coordinator?.handleTimerAdapted(purpose: purpose, timer: timer, newDuration: newDuration, reason: reason)
        }
    }
    
    func timerWasPaused(_ timer: AdaptiveTimerProviding) {
        // Handle timer pause
    }
    
    func timerWasResumed(_ timer: AdaptiveTimerProviding) {
        // Handle timer resume
    }
    
    func timerWasStopped(_ timer: AdaptiveTimerProviding) {
        // Handle timer stop
    }
    
    func timerDidEncounterError(_ timer: AdaptiveTimerProviding, error: TimerError) {
        // Handle timer error
        Task { @MainActor in
            coordinator?.handleTimerError(purpose: purpose, timer: timer, error: error)
        }
    }
}