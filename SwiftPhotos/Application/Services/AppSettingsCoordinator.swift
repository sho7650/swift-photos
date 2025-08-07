import Foundation
import SwiftUI
import Observation

/// Central coordinator for all application settings
/// Provides unified settings management, import/export, and coordination between different setting types
@Observable
@MainActor
public final class AppSettingsCoordinator {
    
    // MARK: - Settings Managers
    public let performance: ModernPerformanceSettingsManager
    public let slideshow: ModernSlideshowSettingsManager
    public let sort: ModernSortSettingsManager
    public let transition: ModernTransitionSettingsManager
    public let uiControl: ModernUIControlSettingsManager
    
    // MARK: - Coordination Properties
    public var isResettingAll = false
    public var lastExportDate: Date?
    public var lastImportDate: Date?
    
    // MARK: - Initialization
    
    public init() {
        self.performance = ModernPerformanceSettingsManager()
        self.slideshow = ModernSlideshowSettingsManager()
        self.sort = ModernSortSettingsManager()
        self.transition = ModernTransitionSettingsManager()
        self.uiControl = ModernUIControlSettingsManager()
        
        ProductionLogger.lifecycle("AppSettingsCoordinator initialized with all settings managers")
        
        // Setup cross-setting coordination
        setupSettingsCoordination()
    }
    
    // MARK: - Unified Settings Operations
    
    /// Reset all settings to their default values
    public func resetAllToDefaults() {
        ProductionLogger.userAction("Resetting all settings to defaults")
        isResettingAll = true
        
        performance.resetToDefaults()
        slideshow.resetToDefaults()
        sort.resetToDefaults()
        transition.resetToDefaults()
        uiControl.resetToDefaults()
        
        isResettingAll = false
        ProductionLogger.lifecycle("All settings reset to defaults completed")
    }
    
    /// Export all settings to a Data object
    public func exportAllSettings() throws -> Data {
        ProductionLogger.userAction("Exporting all settings")
        
        let exportData = SettingsExportData(
            performance: performance.settings,
            slideshow: slideshow.settings,
            sort: sort.settings,
            transition: transition.settings,
            uiControl: uiControl.settings,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
        
        let data = try JSONEncoder().encode(exportData)
        lastExportDate = Date()
        
        ProductionLogger.lifecycle("Settings export completed - size: \(data.count) bytes")
        return data
    }
    
    /// Import settings from a Data object
    public func importAllSettings(from data: Data, merge: Bool = false) throws {
        ProductionLogger.userAction("Importing settings - merge: \(merge)")
        
        let importData = try JSONDecoder().decode(SettingsExportData.self, from: data)
        
        // Validate version compatibility if needed
        validateImportCompatibility(importData)
        
        if !merge {
            // Replace all settings
            performance.updateSettings(importData.performance)
            slideshow.updateSettings(importData.slideshow)
            sort.updateSettings(importData.sort)
            transition.updateSettings(importData.transition)
            uiControl.updateSettings(importData.uiControl)
        } else {
            // Merge settings (only update non-default values)
            mergeImportedSettings(importData)
        }
        
        lastImportDate = Date()
        ProductionLogger.lifecycle("Settings import completed from export date: \(importData.exportDate)")
    }
    
    /// Get comprehensive settings summary for debugging or display
    public func getSettingsSummary() -> SettingsSummary {
        return SettingsSummary(
            performance: SettingsSummary.PerformanceSummary(
                memoryWindowSize: performance.settings.memoryWindowSize,
                maxMemoryUsageMB: performance.settings.maxMemoryUsageMB,
                maxConcurrentLoads: performance.settings.maxConcurrentLoads,
                largeCollectionThreshold: performance.settings.largeCollectionThreshold
            ),
            slideshow: SettingsSummary.SlideshowSummary(
                slideDuration: slideshow.settings.slideDuration,
                autoStart: slideshow.settings.autoStart,
                loop: slideshow.settings.loopSlideshow
            ),
            sort: SettingsSummary.SortSummary(
                order: sort.settings.order,
                ascending: sort.settings.direction == .ascending,
                randomSeed: Int(sort.settings.randomSeed)
            ),
            transition: SettingsSummary.TransitionSummary(
                effectType: transition.settings.effectType,
                duration: transition.settings.duration,
                intensity: transition.settings.intensity
            ),
            uiControl: SettingsSummary.UIControlSummary(
                autoHideDelay: uiControl.settings.autoHideDelay,
                showOnHover: uiControl.settings.showOnMouseMovement,
                blurIntensity: uiControl.settings.backgroundBlurIntensity
            )
        )
    }
    
    // MARK: - Cross-Settings Coordination
    
    /// Apply performance recommendations based on current collection size
    public func optimizeForCollection(size: Int) {
        ProductionLogger.performance("Optimizing settings for collection size: \(size)")
        
        let recommendedPerformance = performance.recommendedSettings(for: size)
        
        // Only update if significantly different
        if recommendedPerformance != performance.settings {
            performance.updateSettings(recommendedPerformance)
            ProductionLogger.performance("Performance settings auto-optimized for \(size) photos")
        }
        
        // Adjust UI settings for large collections
        if size > 10000 {
            let optimizedUISettings = UIControlSettings(
                autoHideDelay: 3.0,
                playingAutoHideDelay: uiControl.settings.playingAutoHideDelay,
                pausedAutoHideDelay: uiControl.settings.pausedAutoHideDelay,
                fadeAnimationDuration: uiControl.settings.fadeAnimationDuration,
                backgroundBlurIntensity: uiControl.settings.backgroundBlurIntensity,
                backgroundOpacity: uiControl.settings.backgroundOpacity,
                showDetailedInfoByDefault: uiControl.settings.showDetailedInfoByDefault,
                hideOnPlay: uiControl.settings.hideOnPlay,
                minimumVisibilityDuration: uiControl.settings.minimumVisibilityDuration,
                showOnMouseMovement: uiControl.settings.showOnMouseMovement,
                mouseSensitivity: uiControl.settings.mouseSensitivity,
                bottomOffset: uiControl.settings.bottomOffset
            )
            uiControl.updateSettings(optimizedUISettings)
            ProductionLogger.performance("UI settings optimized for large collection")
        }
    }
    
    /// Validate settings consistency and fix conflicts
    public func validateAndFixConsistency() -> [String] {
        var issues: [String] = []
        
        // Check performance vs collection size consistency
        if performance.settings.memoryWindowSize > performance.settings.maxMemoryUsageMB * 10 {
            issues.append("Memory window size too large for memory limit")
            let fixedSettings = PerformanceSettings(
                memoryWindowSize: performance.settings.maxMemoryUsageMB * 8,
                maxMemoryUsageMB: performance.settings.maxMemoryUsageMB,
                maxConcurrentLoads: performance.settings.maxConcurrentLoads,
                largeCollectionThreshold: performance.settings.largeCollectionThreshold,
                aggressiveMemoryManagement: performance.settings.aggressiveMemoryManagement,
                preloadDistance: performance.settings.preloadDistance
            )
            performance.updateSettings(fixedSettings)
        }
        
        // Check slideshow timing consistency
        if slideshow.settings.slideDuration < 0.5 {
            issues.append("Slide duration too short, adjusted to minimum")
            let fixedSettings = SlideshowSettings(
                slideDuration: 0.5,
                autoStart: slideshow.settings.autoStart,
                randomOrder: slideshow.settings.randomOrder,
                loopSlideshow: slideshow.settings.loopSlideshow
            )
            slideshow.updateSettings(fixedSettings)
        }
        
        // Check transition duration vs slide duration
        if transition.settings.duration >= slideshow.settings.slideDuration {
            issues.append("Transition duration longer than slide duration")
            let fixedSettings = TransitionSettings(
                effectType: transition.settings.effectType,
                duration: min(transition.settings.duration, slideshow.settings.slideDuration * 0.8),
                easing: transition.settings.easing,
                intensity: transition.settings.intensity,
                isEnabled: transition.settings.isEnabled
            )
            transition.updateSettings(fixedSettings)
        }
        
        if !issues.isEmpty {
            ProductionLogger.warning("Settings inconsistencies fixed: \(issues.joined(separator: ", "))")
        }
        
        return issues
    }
    
    // MARK: - Preset Management
    
    /// Apply coordinated preset configurations
    public func applyPresetConfiguration(_ preset: PresetConfiguration) {
        ProductionLogger.userAction("Applying preset configuration: \(preset)")
        
        switch preset {
        case .highPerformance:
            performance.updateSettings(.highPerformance)
            slideshow.updateSettings(.quick)
            transition.updateSettings(.simpleFade)
            uiControl.updateSettings(.minimal)
            
        case .balanced:
            performance.updateSettings(.default)
            slideshow.updateSettings(.default)
            transition.updateSettings(.default)
            uiControl.updateSettings(.default)
            
        case .highQuality:
            performance.updateSettings(.unlimited)
            slideshow.updateSettings(.slow)
            transition.updateSettings(.smoothCrossfade)
            uiControl.updateSettings(.alwaysVisible)
            
        case .minimal:
            performance.updateSettings(.memoryConstrained)
            slideshow.updateSettings(.quick)
            transition.updateSettings(.none)
            uiControl.updateSettings(.minimal)
        }
        
        ProductionLogger.lifecycle("Preset configuration '\(preset)' applied successfully")
    }
    
    // MARK: - Private Methods
    
    private func setupSettingsCoordination() {
        // This could be expanded to listen for cross-setting dependencies
        // For now, we mainly rely on the validateAndFixConsistency method
        ProductionLogger.debug("Settings coordination established")
    }
    
    private func validateImportCompatibility(_ importData: SettingsExportData) {
        // Check if import data is from a compatible version
        // For now, we accept all versions but could add version-specific logic here
        ProductionLogger.debug("Import data validated - version: \(importData.appVersion), date: \(importData.exportDate)")
    }
    
    private func mergeImportedSettings(_ importData: SettingsExportData) {
        // Merge logic - only update settings that are different from defaults
        // This is a simplified version; could be made more sophisticated
        
        if importData.performance != .default {
            performance.updateSettings(importData.performance)
        }
        
        if importData.slideshow != .default {
            slideshow.updateSettings(importData.slideshow)
        }
        
        if importData.sort != .default {
            sort.updateSettings(importData.sort)
        }
        
        if importData.transition != .default {
            transition.updateSettings(importData.transition)
        }
        
        if importData.uiControl != .default {
            uiControl.updateSettings(importData.uiControl)
        }
        
        ProductionLogger.debug("Settings merge completed")
    }
}

// MARK: - Supporting Data Structures

/// Data structure for exporting/importing all settings
public struct SettingsExportData: Codable, Sendable {
    public let performance: PerformanceSettings
    public let slideshow: SlideshowSettings
    public let sort: SortSettings
    public let transition: TransitionSettings
    public let uiControl: UIControlSettings
    public let exportDate: Date
    public let appVersion: String
}

/// Comprehensive settings summary for debugging and display
public struct SettingsSummary: Sendable {
    public let performance: PerformanceSummary
    public let slideshow: SlideshowSummary
    public let sort: SortSummary
    public let transition: TransitionSummary
    public let uiControl: UIControlSummary
    
    public struct PerformanceSummary: Sendable {
        public let memoryWindowSize: Int
        public let maxMemoryUsageMB: Int
        public let maxConcurrentLoads: Int
        public let largeCollectionThreshold: Int
    }
    
    public struct SlideshowSummary: Sendable {
        public let slideDuration: TimeInterval
        public let autoStart: Bool
        public let loop: Bool
    }
    
    public struct SortSummary: Sendable {
        public let order: SortSettings.SortOrder
        public let ascending: Bool
        public let randomSeed: Int
    }
    
    public struct TransitionSummary: Sendable {
        public let effectType: TransitionSettings.TransitionEffectType
        public let duration: TimeInterval
        public let intensity: Double
    }
    
    public struct UIControlSummary: Sendable {
        public let autoHideDelay: TimeInterval
        public let showOnHover: Bool
        public let blurIntensity: Double
    }
}

/// Preset configuration types for coordinated settings
public enum PresetConfiguration: String, CaseIterable, Sendable {
    case highPerformance = "High Performance"
    case balanced = "Balanced"
    case highQuality = "High Quality"
    case minimal = "Minimal"
    
    public var description: String {
        switch self {
        case .highPerformance:
            return "Optimized for speed and responsiveness"
        case .balanced:
            return "Good balance of performance and quality"
        case .highQuality:
            return "Best visual quality and smooth transitions"
        case .minimal:
            return "Minimal resource usage"
        }
    }
}

// MARK: - Settings Extensions for Presets
// Note: Using existing presets defined in the respective ValueObjects files

// MARK: - Sendable Conformance

extension AppSettingsCoordinator: @unchecked Sendable {
    // @MainActor ensures thread safety
}