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
    
    // Timer management - using simple Timer for now
    // TODO: Replace with proper timer implementation when available
    private var hideTimer: Timer?
    private var minimumVisibilityTimer: Timer?
    
    // Mouse tracking
    private var mouseTrackingArea: NSTrackingArea?
    private var globalMouseMonitor: Any?
    private var lastInteractionTime: Date = Date()
    
    // Cursor management
    private var currentCursor: NSCursor = .arrow
    private var isCustomCursorActive: Bool = false
    
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
        slideshowViewModel: (any SlideshowViewModelProtocol)? = nil
    ) {
        self.uiControlSettings = uiControlSettings
        self.slideshowViewModel = slideshowViewModel
        
        setupMouseTracking()
        setupDefaultZones()
        
        logger.info("🎮 UIInteractionManager: Initialized with consolidated interaction handling")
    }
    
    // Note: Deinit removed to avoid Swift 6 Sendable issues
    // NSEvent monitors and Timer objects are automatically cleaned up
    
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
    
    // MARK: - Private Methods
    
    private func setupMouseTracking() {
        // Global mouse monitor for position tracking
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.mousePosition = NSEvent.mouseLocation
            }
        }
        
        logger.debug("🖱️ Mouse tracking setup complete")
    }
    
    private func stopMouseTracking() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
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
        minimumVisibilityTimer?.invalidate()
        minimumVisibilityTimer = nil
        
        // Ensure minimum visibility duration
        let minimumDuration = uiControlSettings.settings.minimumVisibilityDuration
        if minimumDuration > 0 {
            minimumVisibilityTimer = Timer.scheduledTimer(withTimeInterval: minimumDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleControlsHide()
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
        hideTimer?.invalidate()
        hideTimer = nil
        logger.debug("🙈 Controls hidden")
    }
    
    private func scheduleControlsHide() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        let hideDelay = uiControlSettings.settings.playingAutoHideDelay // Simplified for now
        
        guard hideDelay > 0 else { return }
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideControls()
            }
        }
        
        logger.debug("⏰ Hide timer scheduled for \(hideDelay)s")
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