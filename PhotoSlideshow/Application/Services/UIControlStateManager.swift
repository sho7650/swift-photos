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
    
    private let uiControlSettings: UIControlSettingsManager
    private var hideTimer: Timer?
    private var mouseTrackingArea: NSTrackingArea?
    private var globalMouseMonitor: Any?
    private var lastInteractionTime: Date = Date()
    private var minimumVisibilityTimer: Timer?
    private var interactionClearTimer: Timer?
    private weak var slideshowViewModel: SlideshowViewModel?
    
    // Enhanced mouse tracking
    private var mouseTracker: MouseTracker?
    
    // MARK: - Callbacks
    
    /// Callback for keyboard interaction events
    public var onKeyboardInteraction: (() -> Void)?
    
    /// Callback for mouse interaction events
    public var onMouseInteraction: (() -> Void)?
    
    /// Callback for gesture interaction events
    public var onGestureInteraction: (() -> Void)?
    
    // MARK: - Initialization
    
    public init(uiControlSettings: UIControlSettingsManager, slideshowViewModel: SlideshowViewModel? = nil) {
        self.uiControlSettings = uiControlSettings
        self.slideshowViewModel = slideshowViewModel
        self.isDetailedInfoVisible = uiControlSettings.settings.showDetailedInfoByDefault
        
        setupNotificationObservers()
        setupMouseTracking()
        setupEnhancedMouseTracker()
        startHideTimer()
        
        print("🎮 UIControlStateManager: Initialized with controls visible: \(isControlsVisible)")
    }
    
    deinit {
        // Cleanup non-MainActor resources directly
        hideTimer?.invalidate()
        minimumVisibilityTimer?.invalidate()
        interactionClearTimer?.invalidate()
        
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        Task { @MainActor in
            mouseTracker?.stopTracking()
        }
        
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
        
        print("🎮 UIControlStateManager: Showing controls")
        
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
        if !force && minimumVisibilityTimer?.isValid == true {
            print("🎮 UIControlStateManager: Hide blocked - within minimum visibility duration")
            return
        }
        
        // Don't hide if slideshow is not playing and hideOnPlay is false
        if !force && !uiControlSettings.settings.hideOnPlay {
            if slideshowViewModel?.slideshow?.isPlaying != true {
                print("🎮 UIControlStateManager: Hide blocked - slideshow not playing and hideOnPlay is disabled")
                return
            }
        }
        
        print("🎮 UIControlStateManager: Hiding controls")
        
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
        print("🎮 UIControlStateManager: Keyboard interaction detected")
        recordInteraction()
        showControls()
        onKeyboardInteraction?()
    }
    
    /// Record mouse interaction
    public func handleMouseInteraction(at position: CGPoint) {
        mousePosition = position
        
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
        print("🎮 UIControlStateManager: Gesture interaction detected")
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
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .uiControlSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSettingsChanged()
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
            Task { @MainActor in
                self?.handleGlobalMouseEvent(event)
            }
        }
        
        // Start enhanced mouse tracker
        do {
            try mouseTracker?.startTracking()
        } catch {
            print("🎮 UIControlStateManager: Failed to start enhanced mouse tracking: \(error)")
        }
        
        print("🎮 UIControlStateManager: Mouse monitoring enabled")
    }
    
    private func disableMouseMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
            print("🎮 UIControlStateManager: Mouse monitoring disabled")
        }
        
        // Also disable enhanced mouse tracker when not needed
        Task { @MainActor in
            mouseTracker?.stopTracking()
        }
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
        
        print("🎮 UIControlStateManager: Enhanced mouse tracker configured")
    }
    
    
    private func handleGlobalMouseEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        handleMouseInteraction(at: mouseLocation)
    }
    
    private func recordInteraction() {
        lastInteractionTime = Date()
        hasRecentInteraction = true
        
        // Use a more efficient timer for clearing the interaction flag
        scheduleInteractionFlagClear()
    }
    
    private func scheduleInteractionFlagClear() {
        // Cancel any existing interaction clear timer to avoid accumulation
        interactionClearTimer?.invalidate()
        
        interactionClearTimer = Timer.scheduledTimer(withTimeInterval: uiControlSettings.settings.minimumVisibilityDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hasRecentInteraction = false
                self?.interactionClearTimer = nil
            }
        }
    }
    
    private func startHideTimer() {
        resetHideTimer()
    }
    
    private func resetHideTimer(withDelay delay: Double? = nil) {
        // Only create hide timer if controls are visible
        guard isControlsVisible else {
            print("🎮 UIControlStateManager: Skipping hide timer - controls already hidden")
            return
        }
        
        stopHideTimer()
        
        let hideDelay = delay ?? getCurrentHideDelay()
        
        // Avoid creating timer for very long delays (effectively "never hide")
        guard hideDelay < 100.0 else {
            print("🎮 UIControlStateManager: Skipping hide timer - delay too long (\(hideDelay)s)")
            return
        }
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideControls()
            }
        }
        print("🎮 UIControlStateManager: Hide timer set for \(hideDelay)s")
    }
    
    private func stopHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    private func stopAllTimers() {
        hideTimer?.invalidate()
        hideTimer = nil
        minimumVisibilityTimer?.invalidate()
        minimumVisibilityTimer = nil
        interactionClearTimer?.invalidate()
        interactionClearTimer = nil
        print("🎮 UIControlStateManager: All timers stopped")
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
        minimumVisibilityTimer?.invalidate()
        minimumVisibilityTimer = Timer.scheduledTimer(
            withTimeInterval: uiControlSettings.settings.minimumVisibilityDuration,
            repeats: false
        ) { _ in
            // Timer completion handled automatically
        }
    }
    
    private func handleSettingsChanged() {
        print("🎮 UIControlStateManager: Settings changed, updating behavior")
        
        // Update detailed info visibility if default changed
        if !hasRecentInteraction {
            withAnimation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration)) {
                isDetailedInfoVisible = uiControlSettings.settings.showDetailedInfoByDefault
            }
        }
        
        // Update mouse tracking configuration
        updateMouseTrackerConfiguration()
        
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
        print("🎮 UIControlStateManager: Mouse tracker configuration updated")
    }
}

// MARK: - MouseTrackingDelegate

extension UIControlStateManager: MouseTrackingDelegate {
    public func mouseTrackingDidStart(_ tracker: MouseTracker) {
        print("🎮 UIControlStateManager: Enhanced mouse tracking started")
    }
    
    public func mouseTrackingDidStop(_ tracker: MouseTracker) {
        print("🎮 UIControlStateManager: Enhanced mouse tracking stopped")
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
                print("🎮 UIControlStateManager: Fast mouse movement detected - showing controls")
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
        print("🎮 UIControlStateManager: Enhanced mouse tracker configuration updated")
    }
}