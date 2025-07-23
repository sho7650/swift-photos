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
    private weak var slideshowViewModel: SlideshowViewModel?
    
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
        startHideTimer()
        
        print("🎮 UIControlStateManager: Initialized with controls visible: \(isControlsVisible)")
    }
    
    deinit {
        // Cleanup non-MainActor resources
        hideTimer?.invalidate()
        minimumVisibilityTimer?.invalidate()
        
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
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
        
        stopHideTimer()
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
        recordInteraction()
        
        if uiControlSettings.settings.showOnMouseMovement {
            showControls()
        }
        
        onMouseInteraction?()
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
        
        if !inWindow {
            // Mouse left window - start faster hide timer if playing
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
        // Set up global mouse monitoring
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.handleGlobalMouseEvent(event)
            }
        }
    }
    
    private func handleGlobalMouseEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        handleMouseInteraction(at: mouseLocation)
    }
    
    private func recordInteraction() {
        lastInteractionTime = Date()
        hasRecentInteraction = true
        
        // Clear recent interaction flag after a delay
        Task {
            try? await Task.sleep(nanoseconds: UInt64(uiControlSettings.settings.minimumVisibilityDuration * 1_000_000_000))
            await MainActor.run {
                self.hasRecentInteraction = false
            }
        }
    }
    
    private func startHideTimer() {
        resetHideTimer()
    }
    
    private func resetHideTimer(withDelay delay: Double? = nil) {
        stopHideTimer()
        
        let hideDelay = delay ?? getCurrentHideDelay()
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideControls()
            }
        }
    }
    
    private func stopHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
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
        
        // Reset timer with new delay
        if isControlsVisible {
            resetHideTimer()
        }
    }
    
}