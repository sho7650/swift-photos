import SwiftUI
import Combine
import os.log

// MARK: - Blur Effect Integration Manager

/// Integration manager for migrating from legacy blur systems to BlurEffectManager
@MainActor
public class BlurEffectIntegration: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var isLegacyMode: Bool = false
    @Published public var migrationProgress: Double = 0.0
    
    private let blurManager: BlurEffectManager
    private let uiControlSettings: ModernUIControlSettingsManager
    private let logger = Logger(subsystem: "SwiftPhotos", category: "BlurEffectIntegration")
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        blurManager: BlurEffectManager,
        uiControlSettings: ModernUIControlSettingsManager
    ) {
        self.blurManager = blurManager
        self.uiControlSettings = uiControlSettings
        
        setupIntegration()
        logger.info("🔄 BlurEffectIntegration: Initialized with blur manager integration")
    }
    
    // MARK: - Public Interface
    
    /// Get compatible blur view for existing UI components
    public func getCompatibleBlurView(
        for overlayType: OverlayType,
        legacyIntensity: Double,
        legacyOpacity: Double
    ) -> some View {
        Group {
            if isLegacyMode {
                LegacyCompatibleBlurView(
                    intensity: legacyIntensity,
                    opacity: legacyOpacity
                )
            } else {
                MigratedBlurView(
                    blurManager: blurManager,
                    overlayType: overlayType,
                    legacyIntensity: legacyIntensity,
                    legacyOpacity: legacyOpacity
                )
            }
        }
    }
    
    /// Create blur configuration from legacy settings
    public func createConfigurationFromLegacy(
        intensity: Double,
        opacity: Double,
        overlayType: OverlayType = .controls
    ) -> BlurEffectConfiguration {
        // Map legacy values to new configuration
        let mappedIntensity = mapLegacyIntensity(intensity)
        let mappedStyle = selectStyleFromLegacyValues(intensity: intensity, opacity: opacity)
        
        return blurManager.createCustomConfiguration(
            material: mappedStyle.material,
            intensity: mappedIntensity,
            tintColor: .black,
            tintOpacity: opacity * 0.5, // Adjust legacy opacity mapping
            animationDuration: 0.3,
            cornerRadius: getCornerRadiusForOverlay(overlayType)
        )
    }
    
    /// Migrate a view from legacy blur to managed blur
    public func migrateView<Content: View>(
        _ content: Content,
        overlayType: OverlayType,
        legacyIntensity: Double,
        legacyOpacity: Double
    ) -> some View {
        content
            .background {
                getCompatibleBlurView(
                    for: overlayType,
                    legacyIntensity: legacyIntensity,
                    legacyOpacity: legacyOpacity
                )
            }
    }
    
    /// Enable or disable legacy mode
    public func setLegacyMode(_ enabled: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLegacyMode = enabled
        }
        
        logger.info("🔄 BlurEffectIntegration: Legacy mode \(enabled ? "enabled" : "disabled")")
    }
    
    /// Perform gradual migration to new system
    public func performGradualMigration() async {
        logger.info("🔄 BlurEffectIntegration: Starting gradual migration")
        
        await MainActor.run {
            migrationProgress = 0.0
        }
        
        // Step 1: Initialize new blur manager
        await MainActor.run {
            migrationProgress = 0.2
        }
        
        // Step 2: Sync settings
        await syncUIControlSettings()
        await MainActor.run {
            migrationProgress = 0.5
        }
        
        // Step 3: Update global blur intensity
        await updateGlobalBlurSettings()
        await MainActor.run {
            migrationProgress = 0.8
        }
        
        // Step 4: Complete migration
        await MainActor.run {
            isLegacyMode = false
            migrationProgress = 1.0
        }
        
        logger.info("🔄 BlurEffectIntegration: Migration completed successfully")
    }
    
    // MARK: - Private Methods
    
    private func setupIntegration() {
        // Listen to UIControlSettings changes and sync with BlurEffectManager
        // Listen to UIControlSettings changes and sync with BlurEffectManager
        // Note: ModernUIControlSettingsManager uses NotificationCenter pattern
        NotificationCenter.default.publisher(for: .uiControlSettingsChanged)
            .compactMap { _ in self.uiControlSettings.settings }
            .sink { [weak self] settings in
                self?.syncBlurManagerSettings(settings)
            }
            .store(in: &cancellables)
        
        // Monitor performance and auto-enable legacy mode if needed
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkPerformanceAndAdjust()
            }
            .store(in: &cancellables)
    }
    
    private func syncBlurManagerSettings(_ settings: UIControlSettings) {
        // Update global blur intensity from UI settings
        blurManager.updateGlobalIntensity(settings.backgroundBlurIntensity, animated: false)
        
        // Adjust blur style based on settings preset
        let newStyle = mapUIControlSettingsToBlurStyle(settings)
        if newStyle != blurManager.currentStyle {
            blurManager.animateToStyle(newStyle, duration: 0.3)
        }
    }
    
    private func mapUIControlSettingsToBlurStyle(_ settings: UIControlSettings) -> BlurStyle {
        // Map based on blur intensity and opacity combinations
        let intensity = settings.backgroundBlurIntensity
        let opacity = settings.backgroundOpacity
        
        if intensity < 0.3 {
            return .light
        } else if intensity < 0.6 {
            return .regular
        } else if intensity < 0.8 {
            return .prominent
        } else {
            return opacity > 0.5 ? .ultraThick : .thick
        }
    }
    
    private func mapLegacyIntensity(_ intensity: Double) -> Double {
        // Legacy intensity was often used differently, apply mapping
        return min(1.0, max(0.0, intensity * 1.2))
    }
    
    private func selectStyleFromLegacyValues(intensity: Double, opacity: Double) -> (material: Material, style: BlurStyle) {
        let combinedValue = intensity + opacity
        
        if combinedValue < 0.5 {
            return (.ultraThinMaterial, .light)
        } else if combinedValue < 1.0 {
            return (.regularMaterial, .regular)
        } else if combinedValue < 1.5 {
            return (.thickMaterial, .prominent)
        } else {
            return (.ultraThickMaterial, .ultraThick)
        }
    }
    
    private func getCornerRadiusForOverlay(_ overlayType: OverlayType) -> Double {
        switch overlayType {
        case .controls: return 12
        case .information: return 16
        case .progress: return 8
        case .menu: return 10
        case .tooltip: return 8
        case .notification: return 12
        }
    }
    
    private func checkPerformanceAndAdjust() {
        // Monitor system performance and auto-adjust settings
        let processInfo = ProcessInfo.processInfo
        
        if processInfo.thermalState == .critical || processInfo.isLowPowerModeEnabled {
            logger.warning("🔄 BlurEffectIntegration: Performance constraints detected, enabling performance mode")
            blurManager.setPerformanceMode(true)
        }
    }
    
    private func syncUIControlSettings() async {
        await MainActor.run {
            let currentSettings = uiControlSettings.settings
            blurManager.updateGlobalIntensity(currentSettings.backgroundBlurIntensity)
        }
    }
    
    private func updateGlobalBlurSettings() async {
        await MainActor.run {
            // Apply optimal blur style based on current settings
            let optimalStyle: BlurStyle = determineOptimalBlurStyle()
            blurManager.animateToStyle(optimalStyle)
        }
    }
    
    private func determineOptimalBlurStyle() -> BlurStyle {
        let settings = uiControlSettings.settings
        
        // Determine optimal style based on system capabilities and user preferences
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .light
        }
        
        return mapUIControlSettingsToBlurStyle(settings)
    }
}

// MARK: - Compatibility Views

/// Legacy-compatible blur view for smooth migration
private struct LegacyCompatibleBlurView: View {
    let intensity: Double
    let opacity: Double
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(intensity)
            
            Rectangle()
                .fill(Color.black.opacity(opacity * 0.3))
        }
    }
}

/// Migrated blur view using new BlurEffectManager
private struct MigratedBlurView: View {
    let blurManager: BlurEffectManager
    let overlayType: OverlayType
    let legacyIntensity: Double
    let legacyOpacity: Double
    
    var body: some View {
        blurManager.createBlurView(
            for: overlayType,
            customIntensity: legacyIntensity
        )
    }
}

// MARK: - Migration Helpers

/// Helper for migrating existing BlurredBackground views
public struct BlurMigrationHelper {
    
    /// Replace legacy BlurredBackground with enhanced version
    @MainActor
    public static func enhancedBlurredBackground(
        intensity: Double,
        opacity: Double,
        blurManager: BlurEffectManager,
        overlayType: OverlayType = .controls
    ) -> some View {
        blurManager.createBlurView(
            for: overlayType,
            customIntensity: intensity
        )
    }
    
    /// Replace legacy BlurredDetailedBackground with enhanced version
    @MainActor
    public static func enhancedDetailedBackground(
        intensity: Double,
        opacity: Double,
        blurManager: BlurEffectManager
    ) -> some View {
        blurManager.createBlurView(
            for: .information,
            style: .prominent,
            customIntensity: intensity
        )
    }
    
    /// Create transition animation from legacy to new blur
    public static func createMigrationTransition(
        duration: TimeInterval = 0.5
    ) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 1.05))
        )
        .animation(.easeInOut(duration: duration))
    }
}

// MARK: - Environment Integration

/// Environment key for BlurEffectIntegration
private struct BlurIntegrationEnvironmentKey: EnvironmentKey {
    static let defaultValue: BlurEffectIntegration? = nil
}

public extension EnvironmentValues {
    var blurIntegration: BlurEffectIntegration? {
        get { self[BlurIntegrationEnvironmentKey.self] }
        set { self[BlurIntegrationEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func blurIntegration(_ integration: BlurEffectIntegration) -> some View {
        environment(\.blurIntegration, integration)
    }
}

// MARK: - View Modifiers for Migration

/// View modifier to gradually migrate blur effects
public struct GradualBlurMigration: ViewModifier {
    @ObservedObject private var integration: BlurEffectIntegration
    
    private let overlayType: OverlayType
    private let legacyIntensity: Double
    private let legacyOpacity: Double
    
    public init(
        integration: BlurEffectIntegration,
        overlayType: OverlayType,
        legacyIntensity: Double,
        legacyOpacity: Double
    ) {
        self.integration = integration
        self.overlayType = overlayType
        self.legacyIntensity = legacyIntensity
        self.legacyOpacity = legacyOpacity
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                integration.getCompatibleBlurView(
                    for: overlayType,
                    legacyIntensity: legacyIntensity,
                    legacyOpacity: legacyOpacity
                )
            }
            .transition(BlurMigrationHelper.createMigrationTransition())
    }
}

public extension View {
    /// Apply gradual blur migration to this view
    func gradualBlurMigration(
        integration: BlurEffectIntegration,
        overlayType: OverlayType,
        legacyIntensity: Double,
        legacyOpacity: Double
    ) -> some View {
        modifier(GradualBlurMigration(
            integration: integration,
            overlayType: overlayType,
            legacyIntensity: legacyIntensity,
            legacyOpacity: legacyOpacity
        ))
    }
}

// MARK: - Performance Monitoring

/// Performance monitor for blur effects
public class BlurPerformanceMonitor: ObservableObject {
    @Published public var averageRenderTime: TimeInterval = 0
    @Published public var isPerformanceOptimal: Bool = true
    
    private var renderTimes: [TimeInterval] = []
    private let maxSamples = 30
    private let optimalThreshold: TimeInterval = 0.016 // 60fps
    
    public func recordRenderTime(_ time: TimeInterval) {
        renderTimes.append(time)
        
        if renderTimes.count > maxSamples {
            renderTimes.removeFirst()
        }
        
        updateMetrics()
    }
    
    private func updateMetrics() {
        guard !renderTimes.isEmpty else { return }
        
        averageRenderTime = renderTimes.reduce(0, +) / Double(renderTimes.count)
        isPerformanceOptimal = averageRenderTime <= optimalThreshold
    }
}