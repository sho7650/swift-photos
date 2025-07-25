//
//  CursorManager.swift
//  Swift Photos
//
//  Created by Claude on 2025/07/25.
//

import Foundation
import AppKit
import CoreGraphics
import os.log

/// Cursor manager for hiding cursor when hovering over images with movement detection
/// Shows cursor when mouse moves, hides after inactivity
@MainActor
public class CursorManager: ObservableObject {
    
    // MARK: - Public Properties
    
    /// Current cursor visibility state
    @Published public private(set) var isHidden: Bool = false
    
    /// Whether debug logging is enabled
    public var debugLoggingEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private static var sharedInstance: CursorManager?
    private let logger = Logger(subsystem: "SwiftPhotos", category: "CursorManager")
    
    // Movement detection properties
    private var isHoveringOverImage: Bool = false
    private var lastMousePosition: CGPoint = .zero
    private var lastMovementTime: Date = Date()
    private var hideTimer: Timer?
    private var cursorStateMonitor: Timer? // Monitor cursor state to prevent unwanted reappearance
    private var cursorHideCount: Int = 0 // Track NSCursor.hide() calls
    private let movementThreshold: CGFloat = 3.0 // Minimum movement to detect
    private let hideDelay: TimeInterval = 2.0 // Hide cursor after 2 seconds of no movement
    private let stateMonitorInterval: TimeInterval = 0.1 // Check cursor state every 100ms as requested
    
    // Transition detection to prevent false exit/enter during image changes
    private var isInTransition: Bool = false
    private var transitionStartTime: Date?
    
    // Enhanced logging properties
    private var lastLoggedState: Bool = false
    private var stateChangeCount: Int = 0
    private var lastHideTime: Date?
    private var lastShowTime: Date?
    
    // System-level cursor monitoring
    private var systemEventMonitor: Any?
    private var useCGDisplayCursor: Bool = false // Flag to use CGDisplay APIs when needed
    
    // MARK: - Singleton Access
    
    /// Shared instance for centralized cursor management
    public static func shared() -> CursorManager {
        if let existing = sharedInstance {
            return existing
        }
        let newInstance = CursorManager()
        sharedInstance = newInstance
        return newInstance
    }
    
    // MARK: - Initialization
    
    public init() {
        // Initialize with NSCursor API for better SwiftUI compatibility
        useCGDisplayCursor = false
        logger.info("🖱️ CursorManager: Initialized for image hover functionality with NSCursor API")
        setupSystemEventMonitoring()
    }
    
    deinit {
        // Cleanup timers and monitors
        hideTimer?.invalidate()
        cursorStateMonitor?.invalidate()
        
        if let monitor = systemEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        logger.info("🖱️ CursorManager: Deinit cleanup completed")
    }
    
    // MARK: - Public Methods
    
    /// Handle mouse entering image area
    public func handleMouseEnteredImage() {
        // If we're in a transition and already hovering, this is a false re-enter
        if isInTransition && isHoveringOverImage {
            logSystemEvent("Mouse re-enter during transition - maintaining hover state", additionalInfo: "preventing timer reset")
            return
        }
        
        isHoveringOverImage = true
        lastMousePosition = NSEvent.mouseLocation
        lastMovementTime = Date()
        
        // Start monitoring cursor state to prevent unwanted reappearance
        startCursorStateMonitoring()
        
        // Start hide timer for initial hover
        startHideTimer()
        logDetailedState("handleMouseEnteredImage")
        logSystemEvent("Mouse entered image area", additionalInfo: "starting hover management")
    }
    
    /// Handle mouse exiting image area
    public func handleMouseExitedImage() {
        // Check if this is a false exit during a transition
        if isInTransition {
            logSystemEvent("Mouse exit during transition - ignoring", additionalInfo: "preventing false cursor show")
            return
        }
        
        isHoveringOverImage = false
        stopHideTimer()
        stopCursorStateMonitoring()
        showCursor()
        logDetailedState("handleMouseExitedImage")
        logSystemEvent("Mouse exited image area", additionalInfo: "stopping hover management")
    }
    
    /// Handle mouse movement over image
    public func handleMouseMovement(at position: CGPoint) {
        guard isHoveringOverImage else { return }
        
        let distance = sqrt(pow(position.x - lastMousePosition.x, 2) + pow(position.y - lastMousePosition.y, 2))
        
        if distance >= movementThreshold {
            lastMousePosition = position
            lastMovementTime = Date()
            
            // Show cursor on movement and restart timer
            showCursor()
            startHideTimer()
            logDetailedState("handleMouseMovement", source: "movement detected (\(String(format: "%.1f", distance))px)")
        }
    }
    
    /// Force cursor to visible state for cleanup
    public func forceShow() {
        stopHideTimer()
        stopCursorStateMonitoring()
        showCursor()
        logDetailedState("forceShow")
    }
    
    /// Handle image redraw/transition - immediately hide cursor if it should be hidden
    public func handleImageRedraw() {
        // Mark that we're in a transition to prevent false exit/enter cycles
        isInTransition = true
        transitionStartTime = Date()
        
        // Clear transition flag after a reasonable delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.clearTransitionFlag()
        }
        
        guard isHoveringOverImage else { 
            logDetailedState("handleImageRedraw", source: "skipped - not hovering")
            return 
        }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= hideDelay
        
        logSystemEvent("Image redraw detected", additionalInfo: "timeSinceMovement: \(String(format: "%.2f", timeSinceLastMovement))s, shouldHide: \(shouldBeHidden)")
        
        if shouldBeHidden {
            // Immediately hide cursor on image redraw
            forceHideCursor()
            logDetailedState("handleImageRedraw", source: "cursor hidden after \(String(format: "%.2f", timeSinceLastMovement))s")
        } else {
            logDetailedState("handleImageRedraw", source: "cursor kept visible - recent movement")
        }
        
        // Always schedule multiple cursor state checks after redraw completes
        // This catches cases where SwiftUI resets cursor during the redraw process
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
    
    /// Check cursor state after redraw to detect unwanted reappearance
    private func checkCursorStateAfterRedraw() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= hideDelay
        
        if shouldBeHidden {
            // If cursor should be hidden, force hide regardless of our state tracking
            // This handles SwiftUI resetting cursor visibility during transitions
            forceHideCursor()
            logSystemEvent("Post-redraw enforcing cursor hide", additionalInfo: "timeSince: \(String(format: "%.2f", timeSinceLastMovement))s")
        }
    }
    
    // MARK: - Private Methods
    
    /// Show cursor if currently hidden
    private func showCursor() {
        guard isHidden else { return }
        
        let unhideCount = max(1, cursorHideCount)
        logSystemEvent("About to call cursor show", additionalInfo: "method: \(useCGDisplayCursor ? "CGDisplay" : "NSCursor"), count: \(unhideCount)")
        
        if useCGDisplayCursor {
            // Use CGDisplay API for more reliable cursor control
            CGDisplayShowCursor(CGMainDisplayID())
            logSystemEvent("Called CGDisplayShowCursor", additionalInfo: "displayID: \(CGMainDisplayID())")
        } else {
            // Call unhide() for each hide() call to ensure cursor is visible
            for _ in 0..<unhideCount {
                NSCursor.unhide()
            }
        }
        
        cursorHideCount = 0
        isHidden = false
        lastShowTime = Date()
        
        logDetailedState("showCursor")
        
        // Check if cursor should immediately be hidden again
        scheduleRehideCheckIfNeeded()
    }
    
    /// Schedule a check to re-hide cursor if it should be hidden
    private func scheduleRehideCheckIfNeeded() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        if timeSinceLastMovement >= hideDelay {
            // Cursor was shown but should be hidden - schedule immediate re-hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.rehideCursorIfNeeded()
            }
            logSystemEvent("Scheduled cursor re-hide check", additionalInfo: "timeSince: \(String(format: "%.2f", timeSinceLastMovement))s")
        }
    }
    
    /// Re-hide cursor if it should be hidden
    private func rehideCursorIfNeeded() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        if timeSinceLastMovement >= hideDelay && !isHidden {
            logSystemEvent("Re-hiding cursor after control show", additionalInfo: "timeSince: \(String(format: "%.2f", timeSinceLastMovement))s")
            hideCursor()
        }
    }
    
    /// Hide cursor if currently visible
    private func hideCursor() {
        guard !isHidden else { return }
        
        logSystemEvent("About to call cursor hide", additionalInfo: "method: \(useCGDisplayCursor ? "CGDisplay" : "NSCursor"), hideCount: \(cursorHideCount)")
        
        if useCGDisplayCursor {
            // Use CGDisplay API for more reliable cursor control
            CGDisplayHideCursor(CGMainDisplayID())
            logSystemEvent("Called CGDisplayHideCursor", additionalInfo: "displayID: \(CGMainDisplayID())")
        } else {
            NSCursor.hide()
        }
        
        cursorHideCount += 1
        isHidden = true
        lastHideTime = Date()
        
        logDetailedState("hideCursor")
    }
    
    /// Force hide cursor aggressively (for redraw scenarios)
    private func forceHideCursor() {
        // Allow multiple force hide calls for transition scenarios, but limit to prevent runaway
        if !useCGDisplayCursor && cursorHideCount >= 3 {
            logSystemEvent("Limiting excessive NSCursor.hide() calls", additionalInfo: "hideCount=\(cursorHideCount), resetting")
            // Reset by showing and hiding once
            for _ in 0..<cursorHideCount {
                NSCursor.unhide()
            }
            cursorHideCount = 0
            isHidden = false
        }
        
        logSystemEvent("About to force hide cursor", additionalInfo: "method: \(useCGDisplayCursor ? "CGDisplay" : "NSCursor"), currentState: hidden=\(isHidden), hideCount=\(cursorHideCount)")
        
        if useCGDisplayCursor {
            // CGDisplay API is more reliable and doesn't accumulate
            CGDisplayHideCursor(CGMainDisplayID())
            logSystemEvent("Force called CGDisplayHideCursor", additionalInfo: "displayID: \(CGMainDisplayID())")
            cursorHideCount = 1 // Reset count for CGDisplay
        } else {
            NSCursor.hide()
            cursorHideCount += 1
        }
        
        isHidden = true
        lastHideTime = Date()
        
        logDetailedState("forceHideCursor")
    }
    
    /// Start timer to hide cursor after delay
    private func startHideTimer() {
        stopHideTimer()
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideCursor()
                self?.logDebug("Hide timer fired - cursor hidden")
            }
        }
        logDebug("Hide timer started (\(hideDelay)s)")
    }
    
    /// Stop hide timer
    private func stopHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    /// Start monitoring cursor state to prevent unwanted reappearance during image redraws
    private func startCursorStateMonitoring() {
        stopCursorStateMonitoring()
        
        cursorStateMonitor = Timer.scheduledTimer(withTimeInterval: stateMonitorInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.enforceCursorState()
            }
        }
        logDebug("Cursor state monitoring started")
    }
    
    /// Stop cursor state monitoring
    private func stopCursorStateMonitoring() {
        cursorStateMonitor?.invalidate()
        cursorStateMonitor = nil
    }
    
    /// Enforce cursor state - hide cursor if it should be hidden but appears visible
    private func enforceCursorState() {
        guard isHoveringOverImage else { return }
        
        // Check if we should hide cursor (no recent movement and enough time has passed)
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= hideDelay
        
        if shouldBeHidden && !isHidden {
            // Only force hide if we think cursor is visible but it should be hidden
            hideCursor()
            logDebug("Enforced cursor hide during state monitoring (normal hide)")
        } else if shouldBeHidden && isHidden {
            // Cursor should be hidden and we think it is - verify it stays hidden
            logDebug("Cursor state verified as hidden during monitoring")
        }
    }
    
    private func logDebug(_ message: String) {
        if debugLoggingEnabled {
            logger.debug("🖱️ CursorManager: \(message)")
        }
    }
    
    /// Enhanced logging with detailed state information
    private func logDetailedState(_ operation: String, source: String = #function) {
        guard debugLoggingEnabled else { return }
        
        let timestamp = Date()
        let timeSinceLastMovement = timestamp.timeIntervalSince(lastMovementTime)
        let timeSinceHide = lastHideTime?.timeIntervalSince(timestamp) ?? -1
        let timeSinceShow = lastShowTime?.timeIntervalSince(timestamp) ?? -1
        
        stateChangeCount += 1
        
        let detailedInfo = """
        [\(stateChangeCount)] \(operation) from \(source)
        ├─ State: hidden=\(isHidden), hovering=\(isHoveringOverImage), hideCount=\(cursorHideCount)
        ├─ Timing: lastMovement=\(String(format: "%.2fs", timeSinceLastMovement))ago, hide=\(String(format: "%.2fs", timeSinceHide))ago, show=\(String(format: "%.2fs", timeSinceShow))ago
        ├─ Position: \(lastMousePosition)
        └─ Thread: \(Thread.isMainThread ? "main" : "background")
        """
        
        logger.debug("🖱️ CursorManager: \(detailedInfo)")
        
        // Log state changes
        if lastLoggedState != isHidden {
            lastLoggedState = isHidden
            logger.info("🖱️ CursorManager: STATE CHANGE - Cursor \(self.isHidden ? "HIDDEN" : "VISIBLE") via \(operation)")
        }
    }
    
    /// Log system-level cursor events
    private func logSystemEvent(_ event: String, additionalInfo: String = "") {
        guard debugLoggingEnabled else { return }
        let info = additionalInfo.isEmpty ? "" : " - \(additionalInfo)"
        logger.info("🖱️ CursorManager: SYSTEM EVENT - \(event)\(info)")
    }
    
    // MARK: - System Event Monitoring
    
    /// Setup system event monitoring to detect external cursor changes
    private func setupSystemEventMonitoring() {
        systemEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.cursorUpdate, .flagsChanged, .systemDefined]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleSystemEvent(event)
            }
        }
        logSystemEvent("System event monitoring started", additionalInfo: "events: cursorUpdate, flagsChanged, systemDefined")
    }
    
    /// Handle system events that might affect cursor state
    private func handleSystemEvent(_ event: NSEvent) {
        switch event.type {
        case .cursorUpdate:
            logSystemEvent("Cursor update event detected", additionalInfo: "type: \(event.type.rawValue)")
            // This indicates the system changed the cursor
            if isHoveringOverImage {
                // Schedule a check after a brief delay to see if we need to re-hide
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.checkAndEnforceCursorState()
                }
            }
        case .flagsChanged:
            // Modifier key changes might affect cursor
            logSystemEvent("Flags changed event", additionalInfo: "modifierFlags: \(event.modifierFlags.rawValue)")
        case .systemDefined:
            logSystemEvent("System defined event", additionalInfo: "subtype: \(event.subtype.rawValue)")
        default:
            break
        }
    }
    
    /// Check current cursor state and enforce if needed
    private func checkAndEnforceCursorState() {
        guard isHoveringOverImage else { return }
        
        let timeSinceLastMovement = Date().timeIntervalSince(lastMovementTime)
        let shouldBeHidden = timeSinceLastMovement >= hideDelay
        
        if shouldBeHidden && !isHidden {
            logSystemEvent("Detected cursor reappearance after system event", additionalInfo: "enforcing hide")
            forceHideCursor()
        }
    }
    
    /// Clear the transition flag after transition completes
    private func clearTransitionFlag() {
        if isInTransition {
            if let startTime = transitionStartTime {
                let duration = Date().timeIntervalSince(startTime)
                logSystemEvent("Transition period ended", additionalInfo: "duration: \(String(format: "%.2f", duration))s")
            }
            isInTransition = false
            transitionStartTime = nil
        }
    }
    
    /// Switch to CGDisplay cursor control for more reliability
    public func enableCGDisplayCursorControl() {
        let wasHidden = isHidden
        
        // Show cursor first to reset any accumulated NSCursor.hide() calls
        if wasHidden {
            showCursor()
        }
        
        useCGDisplayCursor = true
        cursorHideCount = 0 // Reset count when switching APIs
        logSystemEvent("Switched to CGDisplay cursor control", additionalInfo: "more reliable for system interference, resetCount")
        
        // If should be hidden and hovering, hide with new API
        if wasHidden && isHoveringOverImage {
            logSystemEvent("Re-applying cursor hide with CGDisplay API", additionalInfo: "ensuring consistency")
            forceHideCursor()
        }
    }
    
    /// Switch back to NSCursor control
    public func enableNSCursorControl() {
        useCGDisplayCursor = false
        logSystemEvent("Switched to NSCursor control", additionalInfo: "standard cursor management")
    }
}