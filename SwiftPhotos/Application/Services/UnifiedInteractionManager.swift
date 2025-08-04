import Foundation
import SwiftUI
import Combine
import os.log

/// Unified interaction manager that combines UIControlStateManager with EnhancedInteractionCoordinator
/// Provides a seamless bridge between existing UI controls and advanced interaction features
@MainActor
public final class UnifiedInteractionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isControlsVisible: Bool = true
    @Published public private(set) var isEnhancedFeaturesEnabled: Bool = false
    @Published public private(set) var currentInteractionMode: InteractionMode = .standard
    
    // MARK: - Core Components
    
    /// Legacy UI control state manager (for backward compatibility)
    public let legacyUIControlManager: UIControlStateManager
    
    /// Enhanced interaction coordinator (for advanced features)
    public let enhancedInteractionCoordinator: EnhancedInteractionCoordinator
    
    // MARK: - Configuration
    
    /// Access to UI control settings (read-only)
    public var uiControlSettings: ModernUIControlSettingsManager? {
        // UIControlStateManager's uiControlSettings is private, so we store our own reference
        return _uiControlSettings
    }
    
    private let _uiControlSettings: ModernUIControlSettingsManager
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UnifiedInteractionManager")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with existing UI control settings and optional enhanced features
    public init(
        uiControlSettings: ModernUIControlSettingsManager,
        enableEnhancedFeatures: Bool = true,
        interactionConfiguration: InteractionSystemConfiguration? = nil
    ) {
        // Store reference to UI control settings
        self._uiControlSettings = uiControlSettings
        
        // Initialize legacy UI control manager
        self.legacyUIControlManager = UIControlStateManager(uiControlSettings: uiControlSettings)
        
        // Initialize enhanced interaction coordinator
        let config = interactionConfiguration ?? InteractionSystemConfiguration.default
        self.enhancedInteractionCoordinator = EnhancedInteractionCoordinator(configuration: config)
        
        self.isEnhancedFeaturesEnabled = enableEnhancedFeatures
        
        setupBindings()
        
        logger.info("UnifiedInteractionManager initialized with enhanced features: \(enableEnhancedFeatures)")
    }
    
    // MARK: - Public Interface
    
    /// Enable or disable enhanced interaction features
    public func setEnhancedFeaturesEnabled(_ enabled: Bool) {
        guard isEnhancedFeaturesEnabled != enabled else { return }
        
        isEnhancedFeaturesEnabled = enabled
        
        if enabled {
            enhancedInteractionCoordinator.enable()
            logger.info("Enhanced interaction features enabled")
        } else {
            enhancedInteractionCoordinator.disable()
            logger.info("Enhanced interaction features disabled")
        }
    }
    
    /// Switch between interaction modes
    public func setInteractionMode(_ mode: InteractionMode) {
        currentInteractionMode = mode
        
        switch mode {
        case .standard:
            // Use legacy UI controls only
            setEnhancedFeaturesEnabled(false)
        case .enhanced:
            // Use enhanced interaction features
            setEnhancedFeaturesEnabled(true)
        case .adaptive:
            // Intelligently switch based on context
            adaptInteractionMode()
        }
        
        logger.info("Interaction mode set to: \(mode.rawValue)")
    }
    
    /// Handle user interaction (unified interface)
    public func handleUserInteraction() {
        // Update legacy UI control manager with generic mouse interaction
        legacyUIControlManager.handleMouseInteraction(at: .zero)
        
        // If enhanced features are enabled, also notify enhanced coordinator
        if isEnhancedFeaturesEnabled {
            enhancedInteractionCoordinator.interactionOccurred(
                Interaction(
                    type: .mouseMove,
                    data: InteractionData(position: .zero),
                    source: .systemAPI
                )
            )
        }
    }
    
    /// Handle keyboard interaction (unified interface) 
    public func handleKeyboardInteraction() {
        // Update legacy UI control manager
        legacyUIControlManager.handleKeyboardInteraction()
        
        // If enhanced features are enabled, also notify enhanced coordinator
        if isEnhancedFeaturesEnabled {
            enhancedInteractionCoordinator.interactionOccurred(
                Interaction(
                    type: .keyPress,
                    data: InteractionData(keyCode: 0),
                    source: .systemAPI
                )
            )
        }
    }
    
    /// Show/hide controls (unified interface)
    public func setControlsVisible(_ visible: Bool) {
        legacyUIControlManager.showControls()
        isControlsVisible = visible
        
        logger.debug("Controls visibility set to: \(visible)")
    }
    
    /// Get adaptive timer for UI control timing
    public func createAdaptiveTimer(for purpose: TimerPurpose) -> UnifiedAdaptiveTimer? {
        guard isEnhancedFeaturesEnabled else { return nil }
        return enhancedInteractionCoordinator.createAdaptiveTimer(for: purpose)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind legacy UI control state to our published properties
        legacyUIControlManager.$isControlsVisible
            .receive(on: DispatchQueue.main)
            .assign(to: &$isControlsVisible)
        
        // Bind enhanced coordinator state if needed
        if isEnhancedFeaturesEnabled {
            enhancedInteractionCoordinator.$activeInteractions
                .receive(on: DispatchQueue.main)
                .sink { [weak self] interactions in
                    self?.handleActiveInteractionsChanged(interactions)
                }
                .store(in: &cancellables)
        }
    }
    
    private func handleActiveInteractionsChanged(_ interactions: Set<InteractionType>) {
        // Adapt behavior based on active interactions
        if interactions.contains(.gesture) || interactions.contains(.touch) {
            // Switch to enhanced mode for advanced interactions
            if currentInteractionMode == .adaptive {
                setEnhancedFeaturesEnabled(true)
            }
        }
    }
    
    private func adaptInteractionMode() {
        // Intelligent mode switching based on context
        // This could consider factors like:
        // - Device capabilities (touch screen, mouse, trackpad)
        // - User preferences
        // - Current application state
        // - Performance considerations
        
        // For now, default to enhanced features if available
        setEnhancedFeaturesEnabled(true)
    }
}

// MARK: - Supporting Types

/// Interaction modes for the unified manager
public enum InteractionMode: String, CaseIterable, Codable {
    case standard = "standard"     // Legacy UI controls only
    case enhanced = "enhanced"     // Enhanced interaction features
    case adaptive = "adaptive"     // Intelligent switching
    
    public var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .enhanced:
            return "Enhanced"
        case .adaptive:
            return "Adaptive"
        }
    }
    
    public var description: String {
        switch self {
        case .standard:
            return "Use traditional UI controls only"
        case .enhanced:
            return "Enable advanced interaction features"
        case .adaptive:
            return "Intelligently adapt to user context"
        }
    }
}

// MARK: - Convenience Extensions

extension UnifiedInteractionManager {
    /// Convenience method to handle mouse interaction
    public func handleMouseInteraction(at position: CGPoint) {
        handleUserInteraction()
        
        if isEnhancedFeaturesEnabled {
            enhancedInteractionCoordinator.interactionOccurred(
                Interaction(
                    type: .mouseMove,
                    data: InteractionData(position: position),
                    source: .systemAPI
                )
            )
        }
    }
    
    /// Convenience method to handle gesture interaction
    public func handleGesture(_ gestureType: GestureType, data: GestureData) {
        if isEnhancedFeaturesEnabled {
            enhancedInteractionCoordinator.interactionOccurred(
                Interaction(
                    type: .gesture,
                    data: InteractionData(gestureData: data),
                    source: .systemAPI
                )
            )
        }
    }
}