import Foundation
import SwiftUI
import AppKit
import Combine
import os.log

// MARK: - Domain Imports
// Import existing Domain types to avoid redefinition
// InteractionZone is defined in Domain/Services/InteractionProtocols.swift
// GestureType is defined in Domain/ValueObjects/InteractionTypes.swift

/// Consolidated UI interaction manager combining controls visibility, interaction tracking, zones, and cursor management
/// Replaces: UIControlStateManager, UnifiedInteractionManager, InteractionZoneManager (UI parts), CursorManager
@MainActor
public final class UIInteractionManager: ObservableObject {
    
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
    
    /// Active interaction zones
    @Published public var zones: [InteractionZone] = []
    
    /// Whether zone interactions are enabled
    @Published public var isZoneInteractionEnabled: Bool = true
    
    // MARK: - Private Properties
    
    private let uiControlSettings: ModernUIControlSettingsManager
    private weak var slideshowViewModel: (any SlideshowViewModelProtocol)?
    
    // Timer management - using unified timer interface
    private let timerManager: TimerManagementProtocol
    private var hideTimerId: UUID?
    private var minimumVisibilityTimerId: UUID?
    
    // Interaction event provider - using unified interaction interface
    private let interactionEventProvider: InteractionEventProviderProtocol
    private var mouseMovementSubscriptionId: UUID?
    private var mouseClickSubscriptionId: UUID?
    private var keyboardSubscriptionId: UUID?
    private var lastInteractionTime: Date = Date()
    
    // Cursor management
    private var currentCursor: NSCursor = .arrow
    private var isCustomCursorActive: Bool = false
    
    // Advanced cursor auto-hide functionality (from CursorManager)
    @Published public private(set) var isCursorHidden: Bool = false
    private var isHoveringOverImage: Bool = false
    private var lastMouseMovementPosition: CGPoint = .zero
    private var lastMovementTime: Date = Date()
    private var cursorHideTimerId: UUID?
    private var cursorStateMonitorId: UUID?
    private var cursorHideCount: Int = 0
    private let movementThreshold: CGFloat = 3.0
    private let cursorHideDelay: TimeInterval = 2.0
    private let stateMonitorInterval: TimeInterval = 0.1
    
    // Transition detection for cursor management
    private var isInImageTransition: Bool = false
    private var transitionStartTime: Date?
    
    // Zone management
    private var activeZones: Set<UUID> = []
    private var zoneStates: [UUID: ZoneInteractionState] = [:]
    
    // Callbacks
    public var onKeyboardInteraction: (() -> Void)?
    public var onMouseInteraction: (() -> Void)?
    public var onGestureInteraction: ((GestureType) -> Void)?
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UIInteractionManager")
    
    // MARK: - Initialization
    
    public init(
        uiControlSettings: ModernUIControlSettingsManager,
        slideshowViewModel: (any SlideshowViewModelProtocol)? = nil,
        timerManager: TimerManagementProtocol = UnifiedTimerManager(),
        interactionEventProvider: InteractionEventProviderProtocol = UnifiedInteractionEventProvider()
    ) {
        self.uiControlSettings = uiControlSettings
        self.slideshowViewModel = slideshowViewModel
        self.timerManager = timerManager
        self.interactionEventProvider = interactionEventProvider
        
        Task {
            await setupInteractionSubscriptions()
        }
        setupDefaultZones()
        
        logger.info("🎮 UIInteractionManager: Initialized with consolidated interaction handling")
    }
    
    // Note: Deinit removed to avoid Swift 6 Sendable issues with async cleanup
    // Subscriptions are automatically cleaned up when the object is deallocated
    
    // MARK: - Public Interface
    
    /// Handle any user interaction
    public func handleUserInteraction() {
        lastInteractionTime = Date()
        hasRecentInteraction = true
        
        // Show controls if hidden
        if !isControlsVisible && shouldShowControls() {
            showControls()
        }
        
        // Reset hide timer
        scheduleControlsHide()
        
        logger.debug("🎮 User interaction handled")
    }
    
    /// Handle keyboard interaction
    public func handleKeyboardInteraction() {
        handleUserInteraction()
        onKeyboardInteraction?()
        logger.debug("⌨️ Keyboard interaction")
    }
    
    /// Handle mouse interaction
    public func handleMouseInteraction(at location: CGPoint) {
        mousePosition = location
        handleUserInteraction()
        onMouseInteraction?()
        
        // Update mouse in window status
        Task {
            isMouseInWindow = await interactionEventProvider.isMouseInApplicationWindow()
        }
        
        // Check zone interactions
        if isZoneInteractionEnabled {
            checkZoneInteractions(at: location)
        }
        
        logger.debug("🖱️ Mouse interaction detected")
    }
    
    /// Toggle controls visibility
    public func toggleControls() {
        if isControlsVisible {
            hideControls()
        } else {
            showControls()
        }
    }
    
    /// Toggle detailed info visibility
    public func toggleDetailedInfo() {
        isDetailedInfoVisible.toggle()
        logger.debug("📊 Detailed info toggled: \(self.isDetailedInfoVisible)")
    }
    
    // MARK: - Zone Management
    
    /// Add an interaction zone
    public func addZone(_ zone: InteractionZone) {
        zones.append(zone)
        zones.sort { $0.priority > $1.priority }
        logger.debug("➕ Added zone: \(zone.id)")
    }
    
    /// Remove an interaction zone
    public func removeZone(_ zone: InteractionZone) {
        zones.removeAll { $0.id == zone.id }
        activeZones.remove(zone.id)
        zoneStates.removeValue(forKey: zone.id)
        logger.debug("➖ Removed zone: \(zone.id)")
    }
    
    /// Get zone at location
    public func zone(at location: CGPoint, in bounds: CGRect) -> InteractionZone? {
        for zone in zones where zone.isEnabled {
            // Domain InteractionZone uses frame directly, not rect(in:) method
            if zone.frame.contains(location) {
                return zone
            }
        }
        return nil
    }
    
    // MARK: - Cursor Management
    
    /// Set custom cursor
    public func setCursor(_ cursor: NSCursor) {
        currentCursor = cursor
        isCustomCursorActive = true
        cursor.set()
        logger.debug("🎯 Cursor set to custom")
    }
    
    /// Reset to default cursor
    public func resetCursor() {
        isCustomCursorActive = false
        NSCursor.arrow.set()
        logger.debug("🎯 Cursor reset to default")
    }
    
    /// Update cursor for image hover
    public func updateCursorForImageHover(_ isHovering: Bool) {
        if isHovering && !isCustomCursorActive {
            NSCursor.pointingHand.set()
        } else if !isCustomCursorActive {
            NSCursor.arrow.set()
        }
    }
    
    // MARK: - Advanced Cursor Auto-Hide (from CursorManager)
    
    /// Handle mouse entering image area - starts auto-hide management
    public func handleMouseEnteredImage() {
        // If we're in a transition and already hovering, this is a false re-enter
        if isInImageTransition && isHoveringOverImage {
            logger.debug("🖱️ Mouse re-enter during transition - maintaining hover state")
            return
        }
        
        isHoveringOverImage = true
        lastMouseMovementPosition = NSEvent.mouseLocation
        lastMovementTime = Date()
        
        // Start monitoring cursor state to prevent unwanted reappearance
        startCursorStateMonitoring()
        
        // Start hide timer for initial hover
        startCursorHideTimer()
        logger.debug("🖱️ Mouse entered image area - starting cursor auto-hide")
    }
    
    /// Handle mouse exiting image area - stops auto-hide management
    public func handleMouseExitedImage() {
        // Check if this is a false exit during a transition
        if isInImageTransition {
            logger.debug("🖱️ Mouse exit during transition - ignoring")
            return
        }
        
        isHoveringOverImage = false
        stopCursorHideTimer()
        stopCursorStateMonitoring()
        showCursor()
        logger.debug("🖱️ Mouse exited image area - stopping cursor auto-hide")
    }
    
    /// Handle mouse movement over image with auto-hide detection
    public func handleMouseMovementOverImage(at position: CGPoint) {
        guard isHoveringOverImage else { return }
        
        let distance = sqrt(pow(position.x - lastMouseMovementPosition.x, 2) + pow(position.y - lastMouseMovementPosition.y, 2))
        
        if distance >= movementThreshold {
            lastMouseMovementPosition = position
            lastMovementTime = Date()
            
            // Show cursor on movement and restart timer
            showCursor()
            startCursorHideTimer()
            logger.debug("🖱️ Mouse movement detected (\(String(format: "%.1f", distance))px) - cursor shown")
        }
    }
    
    /// Force cursor to visible state
    public func forceCursorVisible() {
        stopCursorHideTimer()
        stopCursorStateMonitoring()
        showCursor()
        logger.debug("👁️ Cursor forced visible")
    }
    
    /// Handle image redraw/transition - manages cursor state during transitions
    public func handleImageRedraw() {
        // Mark that we're in a transition to prevent false exit/enter cycles
        isInImageTransition = true
        transitionStartTime = Date()
        
        // Clear transition flag after a reasonable delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.clearImageTransitionFlag()
        }
        
        guard isHoveringOverImage else { 
            logger.debug("🖼️ Image redraw - skipped, not hovering")
            return 
        }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= cursorHideDelay
        
        logger.debug("🖼️ Image redraw - time since movement: \(String(format: "%.2f", timeSinceLastMovement))s, should hide: \(shouldBeHidden)")
        
        if shouldBeHidden {
            // Immediately hide cursor on image redraw
            forceHideCursor()
        }
        
        // Schedule cursor state checks after redraw completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.checkCursorStateAfterRedraw()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkCursorStateAfterRedraw()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.checkCursorStateAfterRedraw()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInteractionSubscriptions() async {
        // Subscribe to mouse movement for position tracking
        mouseMovementSubscriptionId = await interactionEventProvider.subscribeToMouseMovement { [weak self] position in
            Task { @MainActor in
                self?.mousePosition = position
                self?.handleMouseInteraction(at: position)
            }
        }
        
        // Subscribe to mouse clicks
        mouseClickSubscriptionId = await interactionEventProvider.subscribeToMouseClicks { [weak self] clickEvent in
            Task { @MainActor in
                self?.handleMouseInteraction(at: clickEvent.position)
            }
        }
        
        // Subscribe to keyboard events
        keyboardSubscriptionId = await interactionEventProvider.subscribeToKeyboardEvents { [weak self] keyboardEvent in
            Task { @MainActor in
                self?.handleKeyboardInteraction()
            }
        }
        
        // Enable interaction detection
        await interactionEventProvider.setDetectionEnabled(true)
        
        logger.debug("🖱️ Interaction subscriptions setup complete")
    }
    
    private func cancelInteractionSubscriptions() async {
        if let id = mouseMovementSubscriptionId {
            await interactionEventProvider.cancelSubscription(id)
            mouseMovementSubscriptionId = nil
        }
        
        if let id = mouseClickSubscriptionId {
            await interactionEventProvider.cancelSubscription(id)
            mouseClickSubscriptionId = nil
        }
        
        if let id = keyboardSubscriptionId {
            await interactionEventProvider.cancelSubscription(id)
            keyboardSubscriptionId = nil
        }
        
        logger.debug("🖱️ Interaction subscriptions cancelled")
    }
    
    private func setupDefaultZones() {
        // Add default interaction zones if needed
        // For example: top/bottom zones for controls
    }
    
    private func checkZoneInteractions(at location: CGPoint) {
        // Check if location is within any active zones
        for zone in zones where zone.isEnabled {
            if zone.frame.contains(location) {
                // Handle zone interaction based on allowedGestures
                logger.debug("🎯 Zone interaction detected: \(zone.name)")
                // Future: trigger zone-specific actions
            }
        }
    }
    
    private func shouldShowControls() -> Bool {
        return uiControlSettings.settings.showOnMouseMovement || !isMouseInWindow
    }
    
    private func showControls() {
        guard !isControlsVisible else { return }
        
        isControlsVisible = true
        if let timerId = minimumVisibilityTimerId {
            Task { await timerManager.cancelTimer(timerId) }
            minimumVisibilityTimerId = nil
        }
        
        // Ensure minimum visibility duration
        let minimumDuration = uiControlSettings.settings.minimumVisibilityDuration
        if minimumDuration > 0 {
            Task { [weak self] in
                guard let self = self else { return }
                let timerId = await self.timerManager.scheduleTimer(duration: minimumDuration) { [weak self] in
                    Task { @MainActor in
                        self?.scheduleControlsHide()
                    }
                }
                await MainActor.run {
                    self.minimumVisibilityTimerId = timerId
                }
            }
        } else {
            scheduleControlsHide()
        }
        
        logger.debug("👁️ Controls shown")
    }
    
    private func hideControls() {
        guard isControlsVisible else { return }
        
        isControlsVisible = false
        if let timerId = hideTimerId {
            Task { await timerManager.cancelTimer(timerId) }
            hideTimerId = nil
        }
        logger.debug("🙈 Controls hidden")
    }
    
    private func scheduleControlsHide() {
        if let timerId = hideTimerId {
            Task { await timerManager.cancelTimer(timerId) }
            hideTimerId = nil
        }
        
        let hideDelay = uiControlSettings.settings.playingAutoHideDelay // Simplified for now
        
        guard hideDelay > 0 else { return }
        
        Task { [weak self] in
            guard let self = self else { return }
            let timerId = await self.timerManager.scheduleTimer(duration: hideDelay) { [weak self] in
                Task { @MainActor in
                    self?.hideControls()
                }
            }
            await MainActor.run {
                self.hideTimerId = timerId
            }
        }
        
        logger.debug("⏰ Hide timer scheduled for \(hideDelay)s")
    }
    
    // MARK: - Private Cursor Helper Methods
    
    private func startCursorHideTimer() {
        stopCursorHideTimer()
        
        Task { [weak self] in
            guard let self = self else { return }
            let timerId = await self.timerManager.scheduleTimer(duration: cursorHideDelay) { [weak self] in
                Task { @MainActor in
                    self?.hideCursorAfterTimeout()
                }
            }
            await MainActor.run {
                self.cursorHideTimerId = timerId
            }
        }
    }
    
    private func stopCursorHideTimer() {
        if let timerId = cursorHideTimerId {
            Task { await timerManager.cancelTimer(timerId) }
            cursorHideTimerId = nil
        }
    }
    
    private func startCursorStateMonitoring() {
        stopCursorStateMonitoring()
        
        Task { [weak self] in
            guard let self = self else { return }
            let timerId = await self.timerManager.scheduleRepeatingTimer(interval: stateMonitorInterval) { [weak self] in
                Task { @MainActor in
                    self?.monitorCursorState()
                }
            }
            await MainActor.run {
                self.cursorStateMonitorId = timerId
            }
        }
    }
    
    private func stopCursorStateMonitoring() {
        if let timerId = cursorStateMonitorId {
            Task { await timerManager.cancelTimer(timerId) }
            cursorStateMonitorId = nil
        }
    }
    
    private func hideCursorAfterTimeout() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        if timeSinceLastMovement >= cursorHideDelay {
            forceHideCursor()
            logger.debug("⏰ Cursor hidden after timeout (\(String(format: "%.2f", timeSinceLastMovement))s)")
        }
    }
    
    private func forceHideCursor() {
        NSCursor.hide()
        cursorHideCount += 1
        isCursorHidden = true
        logger.debug("🙈 Cursor force hidden (count: \(self.cursorHideCount))")
    }
    
    private func showCursor() {
        // Only call NSCursor.unhide() if we've called NSCursor.hide()
        if cursorHideCount > 0 {
            NSCursor.unhide()
            cursorHideCount -= 1
        } else {
            // Use set() to ensure cursor is visible without unbalanced hide/unhide calls
            NSCursor.arrow.set()
        }
        
        isCursorHidden = false
        logger.debug("👁️ Cursor shown (hide count: \(self.cursorHideCount))")
    }
    
    private func monitorCursorState() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= cursorHideDelay
        
        // If cursor should be hidden but isn't, force hide it
        if shouldBeHidden && !isCursorHidden {
            forceHideCursor()
            logger.debug("🔍 Monitor detected cursor should be hidden - forcing hide")
        }
    }
    
    private func checkCursorStateAfterRedraw() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= cursorHideDelay
        
        if shouldBeHidden {
            // Force hide regardless of current state to handle SwiftUI cursor resets
            forceHideCursor()
            logger.debug("🖼️ Post-redraw check: cursor force hidden")
        }
    }
    
    private func clearImageTransitionFlag() {
        isInImageTransition = false
        transitionStartTime = nil
        logger.debug("🖼️ Image transition flag cleared")
    }
}

// MARK: - Supporting Types

// Note: InteractionZone is imported from Domain layer (InteractionProtocols.swift)
// Removed duplicate definition to use existing Domain type

/// Zone interaction state
private struct ZoneInteractionState {
    let enteredAt: Date
    var lastInteractionAt: Date
    var interactionCount: Int = 0
}

// Note: GestureType is imported from Domain layer (InteractionTypes.swift)
// Removed duplicate definition to use existing Domain type

// MARK: - Protocol Conformance Removed
// Note: Removed SlideshowViewModelProtocol conformance as it was adding unnecessary complexity
// UIInteractionManager should focus on interaction management, not slideshow control
// Direct slideshow control should be handled by the actual slideshow view model