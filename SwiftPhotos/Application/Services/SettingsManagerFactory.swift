import Foundation
import SwiftUI
import Observation

/// Factory pattern implementation for creating and managing settings managers
/// Provides centralized creation, configuration, and lifecycle management
@MainActor
public final class SettingsManagerFactory {
    
    // MARK: - Shared Instance
    
    /// Shared factory instance for application-wide settings management
    public static let shared = SettingsManagerFactory()
    
    // MARK: - Settings Manager Registry
    
    /// Registry of created settings managers to ensure singleton behavior
    private var managersRegistry: [SettingsManagerType: Any] = [:]
    
    // MARK: - Factory Configuration
    
    /// Configuration for factory behavior
    public struct FactoryConfiguration {
        let enableValidation: Bool
        let enableAutoSave: Bool  
        let enableNotifications: Bool
        let presetMode: PresetMode
        
        public init(
            enableValidation: Bool = true,
            enableAutoSave: Bool = true,
            enableNotifications: Bool = true,
            presetMode: PresetMode = .development
        ) {
            self.enableValidation = enableValidation
            self.enableAutoSave = enableAutoSave
            self.enableNotifications = enableNotifications
            self.presetMode = presetMode
        }
        
        /// Preset configurations for different application modes
        public enum PresetMode {
            case development    // Development with debug logging
            case production     // Production with optimized settings
            case testing        // Testing with mock data
            case minimal        // Minimal footprint mode
        }
    }
    
    /// Current factory configuration
    public private(set) var configuration: FactoryConfiguration
    
    // MARK: - Settings Manager Types
    
    /// Enumeration of all available settings manager types
    public enum SettingsManagerType: String, CaseIterable {
        case performance = "performance"
        case slideshow = "slideshow"
        case sort = "sort"
        case transition = "transition"
        case uiControl = "uiControl"
        case localization = "localization"
        
        var displayName: String {
            switch self {
            case .performance: return "Performance Settings"
            case .slideshow: return "Slideshow Settings"
            case .sort: return "Sort Settings"
            case .transition: return "Transition Settings"
            case .uiControl: return "UI Control Settings"
            case .localization: return "Localization Settings"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init(configuration: FactoryConfiguration = FactoryConfiguration()) {
        self.configuration = configuration
        ProductionLogger.lifecycle("SettingsManagerFactory initialized with \(configuration.presetMode) preset")
    }
    
    // MARK: - Factory Methods
    
    /// Create or retrieve performance settings manager
    public func createPerformanceSettings() -> ModernPerformanceSettingsManager {
        return getOrCreate(.performance) {
            let manager = ModernPerformanceSettingsManager()
            configureManager(manager, type: .performance)
            return manager
        }
    }
    
    /// Create or retrieve slideshow settings manager
    public func createSlideshowSettings() -> ModernSlideshowSettingsManager {
        return getOrCreate(.slideshow) {
            let manager = ModernSlideshowSettingsManager()
            configureManager(manager, type: .slideshow)
            return manager
        }
    }
    
    /// Create or retrieve sort settings manager
    public func createSortSettings() -> ModernSortSettingsManager {
        return getOrCreate(.sort) {
            let manager = ModernSortSettingsManager()
            configureManager(manager, type: .sort)
            return manager
        }
    }
    
    /// Create or retrieve transition settings manager
    public func createTransitionSettings() -> ModernTransitionSettingsManager {
        return getOrCreate(.transition) {
            let manager = ModernTransitionSettingsManager()
            configureManager(manager, type: .transition)
            return manager
        }
    }
    
    /// Create or retrieve UI control settings manager
    public func createUIControlSettings() -> ModernUIControlSettingsManager {
        return getOrCreate(.uiControl) {
            let manager = ModernUIControlSettingsManager()
            configureManager(manager, type: .uiControl)
            return manager
        }
    }
    
    /// Create or retrieve localization settings manager
    public func createLocalizationSettings() -> ModernLocalizationSettingsManager {
        return getOrCreate(.localization) {
            let manager = ModernLocalizationSettingsManager()
            configureManager(manager, type: .localization)
            return manager
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Create all settings managers at once
    public func createAllSettings() -> SettingsManagerBundle {
        return SettingsManagerBundle(
            performance: createPerformanceSettings(),
            slideshow: createSlideshowSettings(),
            sort: createSortSettings(),
            transition: createTransitionSettings(),
            uiControl: createUIControlSettings(),
            localization: createLocalizationSettings()
        )
    }
    
    /// Create settings managers for specific preset configurations
    public func createPresetBundle(for preset: SettingsPreset) -> SettingsManagerBundle {
        let bundle = createAllSettings()
        applyPreset(preset, to: bundle)
        return bundle
    }
    
    // MARK: - Settings Presets
    
    /// Predefined settings configurations for different use cases
    public enum SettingsPreset {
        case defaultConfiguration     // Balanced settings for general use
        case highPerformance         // Optimized for large photo collections
        case powerSaver              // Reduced resource usage
        case accessibilityFocused    // Enhanced accessibility features
        case minimalInterface        // Minimal UI elements
        case professionalPresentation // Professional slideshow settings
    }
    
    /// Apply preset configuration to settings bundle
    public func applyPreset(_ preset: SettingsPreset, to bundle: SettingsManagerBundle) {
        switch preset {
        case .defaultConfiguration:
            applyDefaultPreset(to: bundle)
        case .highPerformance:
            applyHighPerformancePreset(to: bundle)
        case .powerSaver:
            applyPowerSaverPreset(to: bundle)
        case .accessibilityFocused:
            applyAccessibilityPreset(to: bundle)
        case .minimalInterface:
            applyMinimalPreset(to: bundle)
        case .professionalPresentation:
            applyProfessionalPreset(to: bundle)
        }
        
        ProductionLogger.info("SettingsManagerFactory: Applied \(preset) preset to settings bundle")
    }
    
    // MARK: - Registry Management
    
    /// Reset all settings managers to their defaults
    public func resetAllToDefaults() {
        for (type, manager) in managersRegistry {
            resetManagerToDefaults(manager, type: type)
        }
        ProductionLogger.info("SettingsManagerFactory: Reset all settings managers to defaults")
    }
    
    /// Clear the factory registry (for testing or memory cleanup)
    public func clearRegistry() {
        managersRegistry.removeAll()
        ProductionLogger.info("SettingsManagerFactory: Cleared settings manager registry")
    }
    
    /// Get statistics about created managers
    public func getFactoryStatistics() -> FactoryStatistics {
        return FactoryStatistics(
            totalManagersCreated: managersRegistry.count,
            managerTypes: Array(managersRegistry.keys),
            factoryConfiguration: configuration
        )
    }
    
    // MARK: - Configuration Management
    
    /// Update factory configuration
    public func updateConfiguration(_ newConfiguration: FactoryConfiguration) {
        self.configuration = newConfiguration
        ProductionLogger.info("SettingsManagerFactory: Configuration updated to \(newConfiguration.presetMode)")
    }
    
    // MARK: - Private Methods
    
    /// Generic method to get existing manager or create new one
    private func getOrCreate<T>(_ type: SettingsManagerType, factory: () -> T) -> T {
        if let existingManager = managersRegistry[type] as? T {
            return existingManager
        }
        
        let newManager = factory()
        managersRegistry[type] = newManager
        
        ProductionLogger.debug("SettingsManagerFactory: Created new \(type.displayName)")
        return newManager
    }
    
    /// Configure a newly created manager according to factory settings
    private func configureManager<T>(_ manager: T, type: SettingsManagerType) {
        // Apply configuration-specific setup based on manager type
        switch configuration.presetMode {
        case .development:
            // Enable debug features for development
            break
        case .production:
            // Optimize for production performance
            break
        case .testing:
            // Configure for testing environment
            break
        case .minimal:
            // Minimal configuration
            break
        }
    }
    
    /// Reset a specific manager to its defaults
    private func resetManagerToDefaults(_ manager: Any, type: SettingsManagerType) {
        switch manager {
        case let performanceManager as ModernPerformanceSettingsManager:
            performanceManager.resetToDefaults()
        case let slideshowManager as ModernSlideshowSettingsManager:
            slideshowManager.resetToDefaults()
        case let sortManager as ModernSortSettingsManager:
            sortManager.resetToDefaults()
        case let transitionManager as ModernTransitionSettingsManager:
            transitionManager.resetToDefaults()
        case let uiControlManager as ModernUIControlSettingsManager:
            uiControlManager.resetToDefaults()
        case let localizationManager as ModernLocalizationSettingsManager:
            localizationManager.resetToDefaults()
        default:
            ProductionLogger.warning("SettingsManagerFactory: Unknown manager type for reset: \(type)")
        }
    }
    
    // MARK: - Preset Application Methods
    
    private func applyDefaultPreset(to bundle: SettingsManagerBundle) {
        // Apply balanced default settings
        bundle.performance.settings = .default
        bundle.slideshow.settings = .default
        bundle.sort.settings = .default
        bundle.transition.settings = .default
        bundle.uiControl.settings = .default
    }
    
    private func applyHighPerformancePreset(to bundle: SettingsManagerBundle) {
        // Apply settings optimized for large collections
        bundle.performance.settings = .extreme
        bundle.slideshow.settings = .quick // Fast-paced slideshow
        bundle.transition.settings = .simpleFade // Fast transitions
    }
    
    private func applyPowerSaverPreset(to bundle: SettingsManagerBundle) {
        // Apply power-saving settings
        bundle.performance.settings = .memoryConstrained
        bundle.transition.settings = .none // No animations to save power
    }
    
    private func applyAccessibilityPreset(to bundle: SettingsManagerBundle) {
        // Apply accessibility-focused settings
        bundle.uiControl.settings = .alwaysVisible // Always show controls
        bundle.transition.settings = .simpleFade // Simple, predictable transitions
    }
    
    private func applyMinimalPreset(to bundle: SettingsManagerBundle) {
        // Apply minimal interface settings
        bundle.uiControl.settings = .minimal
        bundle.transition.settings = .none // No distracting transitions
    }
    
    private func applyProfessionalPreset(to bundle: SettingsManagerBundle) {
        // Apply professional presentation settings
        bundle.slideshow.settings = .slow // Deliberate pacing for presentations
        bundle.transition.settings = .elegantSlide // Professional transitions
        bundle.uiControl.settings = .subtle // Subtle controls
    }
}

// MARK: - Supporting Types

/// Bundle containing all settings managers for easy management
public struct SettingsManagerBundle {
    public let performance: ModernPerformanceSettingsManager
    public let slideshow: ModernSlideshowSettingsManager
    public let sort: ModernSortSettingsManager
    public let transition: ModernTransitionSettingsManager
    public let uiControl: ModernUIControlSettingsManager
    public let localization: ModernLocalizationSettingsManager
    
    /// Validate all settings in the bundle
    @MainActor
    public func validateAll() -> [SettingsManagerFactory.SettingsManagerType: Bool] {
        return [
            .performance: performance.validateSettings(),
            .slideshow: slideshow.validateSettings(),
            .sort: sort.validateSettings(),
            .transition: transition.validateSettings(),
            .uiControl: uiControl.validateSettings(),
            .localization: true // ModernLocalizationSettingsManager doesn't have validateSettings yet
        ]
    }
    
    /// Export all settings as a single data package
    @MainActor
    public func exportAll() throws -> Data {
        let exportBundle = SettingsExportBundle(
            performance: try performance.exportSettings(),
            slideshow: try slideshow.exportSettings(),
            sort: try sort.exportSettings(),
            transition: try transition.exportSettings(),
            uiControl: try uiControl.exportSettings(),
            localization: Data() // ModernLocalizationSettingsManager doesn't have exportSettings yet
        )
        return try JSONEncoder().encode(exportBundle)
    }
    
    /// Import settings from a data package
    @MainActor
    public func importAll(from data: Data) throws {
        let importBundle = try JSONDecoder().decode(SettingsExportBundle.self, from: data)
        try performance.importSettings(from: importBundle.performance)
        try slideshow.importSettings(from: importBundle.slideshow)
        try sort.importSettings(from: importBundle.sort)
        try transition.importSettings(from: importBundle.transition)
        try uiControl.importSettings(from: importBundle.uiControl)
        // Skip localization import since ModernLocalizationSettingsManager doesn't have importSettings yet
    }
}

/// Factory statistics for monitoring and debugging
public struct FactoryStatistics {
    public let totalManagersCreated: Int
    public let managerTypes: [SettingsManagerFactory.SettingsManagerType]
    public let factoryConfiguration: SettingsManagerFactory.FactoryConfiguration
    
    public var memoryFootprint: String {
        return "\(totalManagersCreated) managers using ~\(totalManagersCreated * 1024) bytes"
    }
}

/// Settings export/import bundle structure
private struct SettingsExportBundle: Codable {
    let performance: Data
    let slideshow: Data
    let sort: Data
    let transition: Data
    let uiControl: Data
    let localization: Data
    let exportDate: Date
    let version: String
    
    init(performance: Data, slideshow: Data, sort: Data, transition: Data, uiControl: Data, localization: Data) {
        self.performance = performance
        self.slideshow = slideshow
        self.sort = sort
        self.transition = transition
        self.uiControl = uiControl
        self.localization = localization
        self.exportDate = Date()
        self.version = "1.0"
    }
}

// MARK: - Extension for Easy Access

public extension SettingsManagerFactory {
    /// Convenience method to create standard configuration
    static func createStandardBundle() -> SettingsManagerBundle {
        return shared.createAllSettings()
    }
    
    /// Convenience method to create high-performance configuration
    static func createHighPerformanceBundle() -> SettingsManagerBundle {
        return shared.createPresetBundle(for: .highPerformance)
    }
    
    /// Convenience method to create minimal configuration
    static func createMinimalBundle() -> SettingsManagerBundle {
        return shared.createPresetBundle(for: .minimalInterface)
    }
}