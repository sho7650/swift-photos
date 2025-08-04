import Foundation
import SwiftUI
import Combine
import os.log

/// Unified interaction manager that provides a clean interface to UIControlStateManager
/// Simplified from previous enhanced interaction coordinator system
@MainActor
public final class UnifiedInteractionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isControlsVisible: Bool = true
    
    // MARK: - Core Components
    
    /// UI control state manager (primary interface)
    public let uiControlManager: UIControlStateManager
    
    // MARK: - Configuration
    
    /// Access to UI control settings (read-only)
    public let uiControlSettings: ModernUIControlSettingsManager
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UnifiedInteractionManager")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with UI control settings
    public init(
        uiControlSettings: ModernUIControlSettingsManager,
        enableEnhancedFeatures: Bool = false, // Ignored - enhanced coordinator removed
        interactionConfiguration: Any? = nil // Ignored - enhanced coordinator removed
    ) {
        // Store reference to settings
        self.uiControlSettings = uiControlSettings
        
        // Initialize UI control manager (this handles all interaction features directly)
        self.uiControlManager = UIControlStateManager(uiControlSettings: uiControlSettings)
        
        setupBindings()
        
        logger.info("UnifiedInteractionManager initialized (EnhancedInteractionCoordinator removed for simplified architecture)")
    }
    
    // MARK: - Public Interface
    
    /// Handle user interaction (unified interface)
    public func handleUserInteraction() {
        // Delegate to UI control manager
        uiControlManager.handleMouseInteraction(at: .zero)
    }
    
    /// Handle keyboard interaction (unified interface) 
    public func handleKeyboardInteraction() {
        // Delegate to UI control manager
        uiControlManager.handleKeyboardInteraction()
    }
    
    /// Show/hide controls (unified interface)
    public func setControlsVisible(_ visible: Bool) {
        if visible {
            uiControlManager.showControls()
        } else {
            uiControlManager.hideControls()
        }
        
        logger.debug("Controls visibility set to: \\(visible)")
    }
    
    // MARK: - Backward Compatibility (Deprecated)
    
    /// Legacy method for compatibility - use uiControlManager directly instead
    @available(*, deprecated, message: "Use uiControlManager directly")
    public func setEnhancedFeaturesEnabled(_ enabled: Bool) {
        logger.warning("setEnhancedFeaturesEnabled called but enhanced features have been removed")
    }
    
    /// Legacy method for compatibility - use uiControlManager directly instead
    @available(*, deprecated, message: "Use uiControlManager directly")
    public func setInteractionMode(_ mode: Any) {
        logger.warning("setInteractionMode called but interaction modes have been simplified")
    }
    
    /// Legacy method for compatibility - returns nil as adaptive timers were removed
    @available(*, deprecated, message: "Adaptive timers removed - use standard Swift timers")
    public func createAdaptiveTimer(for purpose: Any) -> Any? {
        logger.warning("createAdaptiveTimer called but adaptive timers have been removed")
        return nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind UI control state to our published properties
        uiControlManager.$isControlsVisible
            .receive(on: DispatchQueue.main)
            .assign(to: &$isControlsVisible)
        
        logger.debug("UnifiedInteractionManager: Bindings established")
    }
}

// MARK: - Legacy Types for Compatibility

/// Deprecated interaction mode enum - kept for compilation compatibility
@available(*, deprecated, message: "Interaction modes have been simplified")
public enum InteractionMode: String {
    case standard = "standard"
    case enhanced = "enhanced" 
    case adaptive = "adaptive"
}

/// Deprecated timer purpose enum - kept for compilation compatibility
@available(*, deprecated, message: "Adaptive timers have been removed")
public enum TimerPurpose: String {
    case autoHide = "autoHide"
    case animation = "animation"
    case interaction = "interaction"
    case performance = "performance"
}