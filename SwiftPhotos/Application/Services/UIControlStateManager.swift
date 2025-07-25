import Foundation
import SwiftUI
import AppKit

/// Centralized state manager for UI control visibility and interaction tracking
@MainActor
public class UIControlStateManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether controls are currently visible
    @Published public var isControlsVisible: Bool = true
    
    /// Whether detailed info panel is visible
    @Published public var isDetailedInfoVisible: Bool = false
    
    /// Current mouse position in global coordinates
    @Published public var mousePosition: CGPoint = .zero
    
    /// Whether mouse is currently within the application window
    @Published public var isMouseInWindow: Bool = false
    
    /// Whether any interaction has occurred recently
    @Published public var hasRecentInteraction: Bool = false
    
    // MARK: - Private Properties
    
    private let uiControlSettings: ModernUIControlSettingsManager
    private var hideTimer: AdaptiveTimer?
    private var mouseTrackingArea: NSTrackingArea?
    private var globalMouseMonitor: Any?
    private var lastInteractionTime: Date = Date()
    private var minimumVisibilityTimer: AdaptiveTimer?
    private var interactionClearTimer: AdaptiveTimer?
    private weak var slideshowViewModel: ModernSlideshowViewModel?
    
    // Cursor auto-hide functionality
    private var cursorHideTimer: AdaptiveTimer?
    private var lastMouseMovementTime: Date = Date()
    private var isCursorHidden: Bool = false
    private static let cursorHideDelay: Double = 3.0 // Hide cursor after 3 seconds of inactivity
    
    // Enhanced interaction detection
    private var mouseTracker: MouseTracker?
    private var interactionDetector: InteractionDetector?
    
    // MARK: - Callbacks
    
    /// Callback for keyboard interaction events
    public var onKeyboardInteraction: (() -> Void)?
    
    /// Callback for mouse interaction events
    public var onMouseInteraction: (() -> Void)?
    
    /// Callback for gesture interaction events
    public var onGestureInteraction: (() -> Void)?
    
    // MARK: - Initialization
    
    public init(uiControlSettings: ModernUIControlSettingsManager, slideshowViewModel: ModernSlideshowViewModel? = nil) {
        self.uiControlSettings = uiControlSettings
        self.slideshowViewModel = slideshowViewModel
        self.isDetailedInfoVisible = uiControlSettings.settings.showDetailedInfoByDefault
        
        setupNotificationObservers()
        setupMouseTracking()
        setupEnhancedMouseTracker()
        setupUnifiedInteractionDetector()
        startHideTimer()
        setupSlideshowStateMonitoring()
        
        ProductionLogger.lifecycle("UIControlStateManager: Initialized with controls visible: \(isControlsVisible)")
    }
    
    deinit {
        // Ensure cursor is visible before cleanup
        if isCursorHidden {
            NSCursor.unhide()
        }
        
        // Cleanup is handled automatically by ARC
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Stop all timers
        stopCursorHideTimer()
        stopAllTimers()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Manually show controls (e.g., called by user interaction)
    public func showControls(withMinimumDuration: Bool = true) {
        guard !isControlsVisible else {
            // If already visible, reset the timer
            resetHideTimer()
            return
        }
        
        ProductionLogger.debug("UIControlStateManager: Showing controls")
        
        withAnimation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration)) {
            isControlsVisible = true
        }
        
        // Enable mouse monitoring when controls become visible
        enableMouseMonitoring()
        
        recordInteraction()
        
        if withMinimumDuration {
            ensureMinimumVisibility()
        }
        
        resetHideTimer()
    }
    
    /// Manually hide controls
    public func hideControls(force: Bool = false) {
        guard isControlsVisible else { return }
        
        // Don't hide if we're within minimum visibility duration (unless forced)
        if !force && minimumVisibilityTimer?.isRunning == true {
            ProductionLogger.debug("UIControlStateManager: Hide blocked - within minimum visibility duration")
            return
        }
        
        // Don't hide if slideshow is not playing and hideOnPlay is false
        if !force && !uiControlSettings.settings.hideOnPlay {
            if slideshowViewModel?.slideshow?.isPlaying != true {
                ProductionLogger.debug("UIControlStateManager: Hide blocked - slideshow not playing and hideOnPlay is disabled")
                return
            }
        }
        
        ProductionLogger.debug("UIControlStateManager: Hiding controls")
        
        withAnimation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration)) {
            isControlsVisible = false
        }
        
        // Disable mouse monitoring when controls are hidden (unless show on mouse movement is enabled)
        if !uiControlSettings.settings.showOnMouseMovement {
            disableMouseMonitoring()
        }
        
        stopHideTimer()
        stopAllTimers() // Clean up all active timers when controls are hidden
    }
    
    /// Toggle detailed info visibility
    public func toggleDetailedInfo() {
        withAnimation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration)) {
            isDetailedInfoVisible.toggle()
        }
        recordInteraction()
        showControls()
    }
    
    /// Record keyboard interaction
    public func handleKeyboardInteraction() {
        ProductionLogger.debug("UIControlStateManager: Keyboard interaction detected")
        recordInteraction()
        showControls()
        onKeyboardInteraction?()
    }
    
    /// Record mouse interaction
    public func handleMouseInteraction(at position: CGPoint) {
        mousePosition = position
        
        // Handle cursor auto-hide functionality
        handleMouseMovementForCursor()
        
        // Only record interaction and process if controls need to be shown or are visible
        let shouldShowControls = uiControlSettings.settings.showOnMouseMovement && !isControlsVisible
        let shouldProcessInteraction = isControlsVisible || shouldShowControls
        
        if shouldProcessInteraction {
            recordInteraction()
            
            if shouldShowControls {
                showControls()
            }
            
            onMouseInteraction?()
        }
    }
    
    /// Record gesture interaction
    public func handleGestureInteraction() {
        ProductionLogger.debug("UIControlStateManager: Gesture interaction detected")
        recordInteraction()
        showControls()
        onGestureInteraction?()
    }
    
    /// Update mouse window status
    public func updateMouseInWindow(_ inWindow: Bool) {
        isMouseInWindow = inWindow
        
        if !inWindow && isControlsVisible {
            // Mouse left window - start faster hide timer if playing (only if controls are visible)
            if slideshowViewModel?.slideshow?.isPlaying == true {
                resetHideTimer(withDelay: uiControlSettings.settings.playingAutoHideDelay)
            }
        }
    }
    
    // MARK: - Cursor Control Methods
    
    /// Handle mouse movement for cursor auto-hide functionality
    private func handleMouseMovementForCursor() {
        lastMouseMovementTime = Date()
        
        // Show cursor if it was hidden
        if isCursorHidden {
            showCursor()
        }
        
        // Reset cursor hide timer only during slideshow playback
        if slideshowViewModel?.slideshow?.isPlaying == true {
            resetCursorHideTimer()
        }
    }
    
    /// Show cursor and cancel hide timer
    private func showCursor() {
        if isCursorHidden {
            NSCursor.unhide()
            isCursorHidden = false
            ProductionLogger.debug("UIControlStateManager: Cursor shown")
        }
        stopCursorHideTimer()
    }
    
    /// Hide cursor during slideshow playback
    private func hideCursor() {
        // Only hide cursor during slideshow playback
        guard slideshowViewModel?.slideshow?.isPlaying == true else {
            ProductionLogger.debug("UIControlStateManager: Cursor hide skipped - slideshow not playing")
            return
        }
        
        if !isCursorHidden {
            NSCursor.hide()
            isCursorHidden = true
            ProductionLogger.debug("UIControlStateManager: Cursor hidden during slideshow")
        }
    }
    
    /// Start or reset the cursor hide timer
    private func resetCursorHideTimer() {
        stopCursorHideTimer()
        
        // Only start timer during slideshow playback
        guard slideshowViewModel?.slideshow?.isPlaying == true else {
            return
        }
        
        let config = TimerConfiguration(
            baseDuration: Self.cursorHideDelay,
            learningEnabled: false,
            coalescingEnabled: false,
            backgroundOptimization: true
        )
        
        cursorHideTimer = AdaptiveTimer(configuration: config)
        cursorHideTimer?.delegate = self
        
        do {
            try cursorHideTimer?.start(with: config)
            ProductionLogger.debug("UIControlStateManager: Cursor hide timer set for \(Self.cursorHideDelay)s")
        } catch {
            ProductionLogger.error("UIControlStateManager: Failed to start cursor hide timer: \(error)")
        }
    }
    
    /// Stop cursor hide timer
    private func stopCursorHideTimer() {
        cursorHideTimer?.stop()
        cursorHideTimer = nil
    }
    
    /// Handle slideshow state changes for cursor management
    private func handleSlideshowStateChange() {
        if let slideshow = slideshowViewModel?.slideshow {
            if slideshow.isPlaying {
                // Start cursor hide timer for slideshow playback
                resetCursorHideTimer()
                ProductionLogger.debug("UIControlStateManager: Slideshow started - cursor auto-hide enabled")
            } else {
                // Show cursor and stop timer when not playing
                showCursor()
                ProductionLogger.debug("UIControlStateManager: Slideshow stopped - cursor always visible")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .uiControlSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSettingsChanged()
        }
    }
    
    private func setupSlideshowStateMonitoring() {
        // Monitor slideshow state changes
        if let slideshowViewModel = slideshowViewModel {
            // Use a timer to periodically check slideshow state
            // This could be improved with KVO or Combine in a future version
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                // Check if slideshow state has changed
                let isCurrentlyPlaying = slideshowViewModel.slideshow?.isPlaying ?? false
                static var wasPlaying = false
                
                if isCurrentlyPlaying != wasPlaying {
                    self.handleSlideshowStateChange()
                    wasPlaying = isCurrentlyPlaying
                }
            }
        }
    }
    
    private func setupMouseTracking() {
        // Start with mouse monitoring enabled (controls are initially visible)
        enableMouseMonitoring()
    }
    
    private func enableMouseMonitoring() {
        guard globalMouseMonitor == nil else { return }
        
        // Set up global mouse monitoring only when needed
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleGlobalMouseEvent(event)
            }
        }
        
        // Start enhanced mouse tracker
        do {
            try mouseTracker?.startTracking()
        } catch {
            ProductionLogger.error("UIControlStateManager: Failed to start enhanced mouse tracking: \(error)")
        }
        
        ProductionLogger.debug("UIControlStateManager: Mouse monitoring enabled")
    }
    
    private func disableMouseMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
            ProductionLogger.debug("UIControlStateManager: Mouse monitoring disabled")
        }
        
        // Also disable enhanced mouse tracker when not needed
        mouseTracker?.stopTracking()
    }
    
    private func setupEnhancedMouseTracker() {
        // Create mouse tracker with configuration based on UI settings
        let config = MouseTrackingConfiguration(
            sensitivity: uiControlSettings.settings.mouseSensitivity / 10.0, // Convert to 0.1-10.0 range
            velocitySmoothing: 0.8,
            accelerationThreshold: 100.0,
            samplingRate: 60.0,
            enableZoneDetection: false, // Not needed for basic UI controls
            enableVelocityTracking: true,
            historyDuration: 1.0
        )
        
        mouseTracker = MouseTracker(configuration: config)
        mouseTracker?.delegate = self
        
        ProductionLogger.debug("UIControlStateManager: Enhanced mouse tracker configured")
    }
    
    
    private func handleGlobalMouseEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        handleMouseInteraction(at: mouseLocation)
    }
    
    private func recordInteraction() {
        lastInteractionTime = Date()
        hasRecentInteraction = true
        
        // Update timer context based on new interaction
        updateTimerContext()
        
        // Use a more efficient timer for clearing the interaction flag
        scheduleInteractionFlagClear()
    }
    
    private func scheduleInteractionFlagClear() {
        // Cancel any existing interaction clear timer to avoid accumulation
        interactionClearTimer?.stop()
        
        let config = TimerConfiguration(
            baseDuration: uiControlSettings.settings.minimumVisibilityDuration,
            learningEnabled: false,
            coalescingEnabled: true
        )
        
        interactionClearTimer = AdaptiveTimer(configuration: config)
        interactionClearTimer?.delegate = self
        
        do {
            try interactionClearTimer?.start(with: config)
        } catch {
            ProductionLogger.error("UIControlStateManager: Failed to start interaction clear timer: \(error)")
            // Fallback: clear flag immediately
            hasRecentInteraction = false
        }
    }
    
    private func startHideTimer() {
        resetHideTimer()
    }
    
    private func resetHideTimer(withDelay delay: Double? = nil) {
        // Only create hide timer if controls are visible
        guard isControlsVisible else {
            ProductionLogger.debug("UIControlStateManager: Skipping hide timer - controls already hidden")
            return
        }
        
        stopHideTimer()
        
        let hideDelay = delay ?? getCurrentHideDelay()
        
        // Avoid creating timer for very long delays (effectively "never hide")
        guard hideDelay < 100.0 else {
            ProductionLogger.debug("UIControlStateManager: Skipping hide timer - delay too long (\(hideDelay)s)")
            return
        }
        
        let config = TimerConfiguration.autoHide(duration: hideDelay)
        hideTimer = AdaptiveTimer(configuration: config)
        hideTimer?.delegate = self
        hideTimer?.adaptationEnabled = true // Enable context-aware adaptation
        
        do {
            try hideTimer?.start(with: config)
            ProductionLogger.debug("UIControlStateManager: Adaptive hide timer set for \(hideDelay)s")
        } catch {
            ProductionLogger.error("UIControlStateManager: Failed to start hide timer: \(error)")
        }
    }
    
    private func stopHideTimer() {
        hideTimer?.stop()
        hideTimer = nil
    }
    
    private func stopAllTimers() {
        hideTimer?.stop()
        hideTimer = nil
        minimumVisibilityTimer?.stop()
        minimumVisibilityTimer = nil
        interactionClearTimer?.stop()
        interactionClearTimer = nil
        ProductionLogger.debug("UIControlStateManager: All adaptive timers stopped")
    }
    
    private func getCurrentHideDelay() -> Double {
        guard let slideshow = slideshowViewModel?.slideshow else {
            return uiControlSettings.settings.autoHideDelay
        }
        
        if slideshow.isPlaying {
            return uiControlSettings.settings.playingAutoHideDelay
        } else {
            return uiControlSettings.settings.pausedAutoHideDelay
        }
    }
    
    private func ensureMinimumVisibility() {
        minimumVisibilityTimer?.stop()
        
        let config = TimerConfiguration(
            baseDuration: uiControlSettings.settings.minimumVisibilityDuration,
            learningEnabled: false,
            coalescingEnabled: false,
            backgroundOptimization: true
        )
        
        minimumVisibilityTimer = AdaptiveTimer(configuration: config)
        minimumVisibilityTimer?.delegate = self
        minimumVisibilityTimer?.adaptationEnabled = false // Keep minimum visibility consistent
        
        do {
            try minimumVisibilityTimer?.start(with: config)
            ProductionLogger.debug("UIControlStateManager: Minimum visibility timer set for \(config.baseDuration)s")
        } catch {
            ProductionLogger.error("UIControlStateManager: Failed to start minimum visibility timer: \(error)")
        }
    }
    
    private func handleSettingsChanged() {
        ProductionLogger.debug("UIControlStateManager: Settings changed, updating behavior")
        
        // Update detailed info visibility if default changed
        if !hasRecentInteraction {
            withAnimation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration)) {
                isDetailedInfoVisible = uiControlSettings.settings.showDetailedInfoByDefault
            }
        }
        
        // Update mouse tracking configuration
        updateMouseTrackerConfiguration()
        
        // Update timer context with new settings
        updateTimerContext()
        
        // Update mouse monitoring based on new settings
        if isControlsVisible {
            enableMouseMonitoring()
            // Reset timer with new delay only if controls are visible
            resetHideTimer()
        } else if uiControlSettings.settings.showOnMouseMovement {
            // Enable mouse monitoring even when hidden if showOnMouseMovement is enabled
            enableMouseMonitoring()
        } else {
            // Disable mouse monitoring if not needed
            disableMouseMonitoring()
        }
    }
    
    private func updateMouseTrackerConfiguration() {
        guard let mouseTracker = mouseTracker else { return }
        
        let newConfig = MouseTrackingConfiguration(
            sensitivity: uiControlSettings.settings.mouseSensitivity / 10.0, // Convert to 0.1-10.0 range
            velocitySmoothing: 0.8,
            accelerationThreshold: 100.0,
            samplingRate: 60.0,
            enableZoneDetection: false, // Not needed for basic UI controls
            enableVelocityTracking: true,
            historyDuration: 1.0
        )
        
        mouseTracker.configuration = newConfig
        ProductionLogger.debug("UIControlStateManager: Mouse tracker configuration updated")
    }
    
    // MARK: - Context-Aware Timer Adaptation
    
    private func updateTimerContext() {
        let context = createCurrentTimingContext()
        
        // Update hide timer with current context for adaptive behavior
        if hideTimer?.isRunning == true {
            hideTimer?.adaptTiming(based: context)
        }
    }
    
    private func createCurrentTimingContext() -> TimingContext {
        // Determine user activity level based on recent interactions
        let userActivity: UserActivityLevel
        if hasRecentInteraction {
            userActivity = .active
        } else if lastInteractionTime.timeIntervalSinceNow > -30 {
            userActivity = .moderate
        } else if lastInteractionTime.timeIntervalSinceNow > -120 {
            userActivity = .light
        } else {
            userActivity = .idle
        }
        
        // Determine app state based on slideshow status
        let appState: AppState
        if let slideshow = slideshowViewModel?.slideshow {
            if slideshow.isPlaying {
                appState = .slideshow
            } else {
                appState = .foreground
            }
        } else {
            appState = .foreground
        }
        
        // Create interaction count based on recent activity
        let interactionCount = hasRecentInteraction ? 1 : 0
        
        // Add custom factors based on UI control settings
        var customFactors: [String: Double] = [:]
        
        // Adjust based on mouse sensitivity (higher sensitivity = more responsive user)
        customFactors["mouseSensitivity"] = uiControlSettings.settings.mouseSensitivity / 50.0 // Normalize to ~1.0
        
        // Adjust based on whether mouse tracking is enabled
        customFactors["showOnMouseMovement"] = uiControlSettings.settings.showOnMouseMovement ? 0.8 : 1.0
        
        // Create empty interactions array but with the correct count for context
        let mockInteractions = Array(repeating: Interaction(
            type: .mouseMove,
            data: InteractionData(),
            source: .mouse
        ), count: interactionCount)
        
        return TimingContext(
            userActivity: userActivity,
            appState: appState,
            systemLoad: .normal, // Could be enhanced with actual system monitoring
            batteryLevel: nil,   // Could be enhanced with battery level detection
            recentInteractions: mockInteractions,
            customFactors: customFactors
        )
    }
}

// MARK: - MouseTrackingDelegate

extension UIControlStateManager: MouseTrackingDelegate {
    public func mouseTrackingDidStart(_ tracker: MouseTracker) {
        ProductionLogger.debug("UIControlStateManager: Enhanced mouse tracking started")
    }
    
    public func mouseTrackingDidStop(_ tracker: MouseTracker) {
        ProductionLogger.debug("UIControlStateManager: Enhanced mouse tracking stopped")
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didUpdatePosition position: CGPoint, velocity: CGVector) {
        // Update position with enhanced tracking
        mousePosition = position
        
        // Only process if controls need to be shown or are visible (optimization from previous work)
        let shouldShowControls = uiControlSettings.settings.showOnMouseMovement && !isControlsVisible
        let shouldProcessInteraction = isControlsVisible || shouldShowControls
        
        if shouldProcessInteraction {
            recordInteraction()
            
            if shouldShowControls {
                showControls()
            }
            
            onMouseInteraction?()
        }
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didDetectHighVelocity velocity: CGVector) {
        // Handle high-velocity mouse movements for more responsive UI
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        
        if speed > 50.0 && !isControlsVisible { // Use fixed threshold since velocity is already processed
            // Fast mouse movement detected - show controls immediately
            if uiControlSettings.settings.showOnMouseMovement {
                ProductionLogger.debug("UIControlStateManager: Fast mouse movement detected - showing controls")
                showControls()
            }
        }
    }
    
    // MARK: - Optional delegate methods (not used for basic UI controls)
    
    public func mouseTracker(_ tracker: MouseTracker, didEnterZone zone: MouseTrackingZone) {
        // Zone detection not currently used for UI controls
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didExitZone zone: MouseTrackingZone) {
        // Zone detection not currently used for UI controls
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didAddZone zone: MouseTrackingZone) {
        // Zone management not currently used for UI controls
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didRemoveZoneWithId id: UUID) {
        // Zone management not currently used for UI controls
    }
    
    public func mouseTrackerDidClearAllZones(_ tracker: MouseTracker) {
        // Zone management not currently used for UI controls
    }
    
    public func mouseTracker(_ tracker: MouseTracker, didUpdateConfiguration configuration: MouseTrackingConfiguration) {
        ProductionLogger.debug("UIControlStateManager: Enhanced mouse tracker configuration updated")
    }
}

// MARK: - AdaptiveTimerDelegate

extension UIControlStateManager: AdaptiveTimerDelegate {
    public func timerDidFire(_ timer: AdaptiveTimerProviding) {
        // Determine which timer fired and handle appropriately
        if timer === hideTimer {
            ProductionLogger.debug("UIControlStateManager: Hide timer fired - hiding controls")
            hideControls()
            hideTimer = nil
        } else if timer === interactionClearTimer {
            ProductionLogger.debug("UIControlStateManager: Interaction clear timer fired")
            hasRecentInteraction = false
            interactionClearTimer = nil
        } else if timer === minimumVisibilityTimer {
            ProductionLogger.debug("UIControlStateManager: Minimum visibility timer completed")
            minimumVisibilityTimer = nil
        } else if timer === cursorHideTimer {
            ProductionLogger.debug("UIControlStateManager: Cursor hide timer fired - hiding cursor")
            hideCursor()
            cursorHideTimer = nil
        }
    }
    
    public func timerDidAdapt(_ timer: AdaptiveTimerProviding, newDuration: TimeInterval, reason: AdaptationReason) {
        if timer === hideTimer {
            ProductionLogger.debug("UIControlStateManager: Hide timer adapted to \(String(format: "%.1f", newDuration))s (reason: \(reason.rawValue))")
        }
    }
    
    public func timerWasPaused(_ timer: AdaptiveTimerProviding) {
        if timer === hideTimer {
            ProductionLogger.debug("UIControlStateManager: Hide timer paused")
        }
    }
    
    public func timerWasResumed(_ timer: AdaptiveTimerProviding) {
        if timer === hideTimer {
            ProductionLogger.debug("UIControlStateManager: Hide timer resumed")
        }
    }
    
    public func timerWasStopped(_ timer: AdaptiveTimerProviding) {
        if timer === hideTimer {
            ProductionLogger.debug("UIControlStateManager: Hide timer stopped")
        } else if timer === cursorHideTimer {
            ProductionLogger.debug("UIControlStateManager: Cursor hide timer stopped")
        }
    }
    
    public func timerDidEncounterError(_ timer: AdaptiveTimerProviding, error: TimerError) {
        ProductionLogger.error("UIControlStateManager: Timer error - \(error.localizedDescription)")
        
        // Handle timer errors gracefully
        if timer === hideTimer {
            ProductionLogger.warning("UIControlStateManager: Hide timer error - controls will remain visible")
            hideTimer = nil
        } else if timer === interactionClearTimer {
            // Fallback: clear interaction flag immediately
            hasRecentInteraction = false
            interactionClearTimer = nil
        }
    }
    
    // MARK: - Unified Interaction Detection Setup
    
    private func setupUnifiedInteractionDetector() {
        // Create configuration based on UI control settings
        let config = InteractionConfiguration(
            enabledTypes: [.mouseMove, .mouseClick, .keyPress, .gesture],
            sensitivity: uiControlSettings.settings.mouseSensitivity / 50.0,
            minimumConfidence: 0.7,
            debounceInterval: 0.05, // Smooth but responsive
            maxEventRate: 120.0, // High rate for responsive UI
            enableGestures: true
        )
        
        interactionDetector = InteractionDetector(configuration: config)
        interactionDetector?.delegate = self
        interactionDetector?.addObserver(self)
        
        // Start detection
        do {
            try interactionDetector?.startDetection()
            ProductionLogger.debug("UIControlStateManager: Unified interaction detection started")
        } catch {
            ProductionLogger.error("UIControlStateManager: Failed to start unified interaction detection: \(error)")
        }
    }
}

// MARK: - InteractionObserver

extension UIControlStateManager: InteractionObserver {
    public func interactionOccurred(_ interaction: Interaction) {
        // Handle different types of interactions
        switch interaction.type {
        case .mouseMove, .mouseClick:
            if let position = interaction.data.position {
                handleMouseInteraction(at: position)
            }
        case .keyPress:
            handleKeyboardInteraction()
        case .gesture:
            handleGestureInteraction()
        default:
            // Record general interaction
            recordInteraction()
        }
    }
    
    public func interactionDetectionFailed(_ error: InteractionError) {
        ProductionLogger.error("UIControlStateManager: Interaction detection failed: \(error.localizedDescription)")
    }
    
    public func interactionConfigurationDidChange(_ configuration: InteractionConfiguration) {
        ProductionLogger.debug("UIControlStateManager: Interaction configuration updated")
    }
}

// MARK: - InteractionDetectorDelegate

extension UIControlStateManager: InteractionDetectorDelegate {
    public func detectorDidDetectInteraction(_ detector: InteractionDetecting, interaction: Interaction) {
        // This provides another layer of interaction handling if needed
        // Currently delegated to InteractionObserver methods
    }
    
    public func detectorDidEncounterError(_ detector: InteractionDetecting, error: InteractionError) {
        ProductionLogger.error("UIControlStateManager: InteractionDetector error: \(error.localizedDescription)")
        
        // Try to restart detection if possible
        if error == .systemPermissionDenied(permission: "Accessibility permissions required for global event monitoring") {
            ProductionLogger.warning("UIControlStateManager: Please grant accessibility permissions in System Preferences")
        }
    }
    
    public func detectorDidStartDetection(_ detector: InteractionDetecting) {
        ProductionLogger.debug("UIControlStateManager: InteractionDetector started successfully")
    }
    
    public func detectorDidStopDetection(_ detector: InteractionDetecting) {
        ProductionLogger.debug("UIControlStateManager: InteractionDetector stopped")
    }
    
    public func detectorDidUpdateConfiguration(_ detector: InteractionDetecting, configuration: InteractionConfiguration) {
        ProductionLogger.debug("UIControlStateManager: InteractionDetector configuration updated")
    }
}