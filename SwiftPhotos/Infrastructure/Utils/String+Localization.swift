import Foundation
import SwiftUI

// MARK: - L10n Namespace for Type-Safe Localization (Swift 6 Best Practice)

/// Type-safe localization namespace following Swift 6 best practices
public enum L10n {
    
    // MARK: - Actions
    public enum Action {
        nonisolated(unsafe) public static let play: LocalizedStringKey = LocalizedStringKey("slideshow.button.play")
        nonisolated(unsafe) public static let pause: LocalizedStringKey = LocalizedStringKey("slideshow.button.pause")
        nonisolated(unsafe) public static let stop: LocalizedStringKey = LocalizedStringKey("slideshow.button.stop")
        nonisolated(unsafe) public static let next: LocalizedStringKey = LocalizedStringKey("slideshow.navigation.next")
        nonisolated(unsafe) public static let previous: LocalizedStringKey = LocalizedStringKey("slideshow.navigation.previous")
        nonisolated(unsafe) public static let selectFolder: LocalizedStringKey = LocalizedStringKey("button.select_folder")
        nonisolated(unsafe) public static let settings: LocalizedStringKey = LocalizedStringKey("button.settings")
        nonisolated(unsafe) public static let cancel: LocalizedStringKey = LocalizedStringKey("button.cancel")
        nonisolated(unsafe) public static let reset: LocalizedStringKey = LocalizedStringKey("button.reset")
        nonisolated(unsafe) public static let save: LocalizedStringKey = LocalizedStringKey("button.save")
    }
    
    // MARK: - Settings
    public enum Settings {
        nonisolated(unsafe) public static let applicationLanguage: LocalizedStringKey = LocalizedStringKey("settings.application_language")
        nonisolated(unsafe) public static let changesImmediate: LocalizedStringKey = LocalizedStringKey("settings.changes_immediate")
        nonisolated(unsafe) public static let performance: LocalizedStringKey = LocalizedStringKey("settings.performance.title")
        nonisolated(unsafe) public static let performanceDescription: LocalizedStringKey = LocalizedStringKey("settings.performance.description")
        nonisolated(unsafe) public static let performancePresets: LocalizedStringKey = LocalizedStringKey("settings.performance.presets")
        nonisolated(unsafe) public static let slideshow: LocalizedStringKey = LocalizedStringKey("settings.slideshow.title")
        nonisolated(unsafe) public static let sorting: LocalizedStringKey = LocalizedStringKey("settings.sorting.title")
        nonisolated(unsafe) public static let transitions: LocalizedStringKey = LocalizedStringKey("settings.transitions.title")
        nonisolated(unsafe) public static let uiControls: LocalizedStringKey = LocalizedStringKey("settings.ui_controls.title")
        nonisolated(unsafe) public static let language: LocalizedStringKey = LocalizedStringKey("settings.language.title")
        nonisolated(unsafe) public static let languageDescription: LocalizedStringKey = LocalizedStringKey("settings.language.description")
        
        // Sort Settings
        nonisolated(unsafe) public static let sortPresets: LocalizedStringKey = LocalizedStringKey("settings.sort.presets")
        nonisolated(unsafe) public static let sortPresetsDescription: LocalizedStringKey = LocalizedStringKey("settings.sort.presets.description")
        nonisolated(unsafe) public static let sortOrder: LocalizedStringKey = LocalizedStringKey("settings.sort.order")
        nonisolated(unsafe) public static let sortOrderDescription: LocalizedStringKey = LocalizedStringKey("settings.sort.order.description")
        nonisolated(unsafe) public static let sortDirection: LocalizedStringKey = LocalizedStringKey("settings.sort.direction")
        nonisolated(unsafe) public static let sortDirectionDescription: LocalizedStringKey = LocalizedStringKey("settings.sort.direction.description")
        nonisolated(unsafe) public static let currentSettings: LocalizedStringKey = LocalizedStringKey("settings.current_settings")
        nonisolated(unsafe) public static let currentSettingsDescription: LocalizedStringKey = LocalizedStringKey("settings.current_settings.description")
        nonisolated(unsafe) public static let performanceInformation: LocalizedStringKey = LocalizedStringKey("settings.performance_information")
        nonisolated(unsafe) public static let performanceInformationDescription: LocalizedStringKey = LocalizedStringKey("settings.performance_information.description")
        
        // Interface Settings
        nonisolated(unsafe) public static let autoHide: LocalizedStringKey = LocalizedStringKey("settings.interface.auto_hide")
        nonisolated(unsafe) public static let autoHideDescription: LocalizedStringKey = LocalizedStringKey("settings.interface.auto_hide.description")
        nonisolated(unsafe) public static let mouseInteraction: LocalizedStringKey = LocalizedStringKey("settings.interface.mouse_interaction")
        nonisolated(unsafe) public static let mouseInteractionDescription: LocalizedStringKey = LocalizedStringKey("settings.interface.mouse_interaction.description")
        nonisolated(unsafe) public static let appearance: LocalizedStringKey = LocalizedStringKey("settings.interface.appearance")
        nonisolated(unsafe) public static let appearanceDescription: LocalizedStringKey = LocalizedStringKey("settings.interface.appearance.description")
        nonisolated(unsafe) public static let informationDisplay: LocalizedStringKey = LocalizedStringKey("settings.interface.information_display")
        nonisolated(unsafe) public static let informationDisplayDescription: LocalizedStringKey = LocalizedStringKey("settings.interface.information_display.description")
        nonisolated(unsafe) public static let presets: LocalizedStringKey = LocalizedStringKey("settings.interface.presets")
        nonisolated(unsafe) public static let presetsDescription: LocalizedStringKey = LocalizedStringKey("settings.interface.presets.description")
        
        // Advanced Settings
        nonisolated(unsafe) public static let debugSettings: LocalizedStringKey = LocalizedStringKey("settings.advanced.debug")
        nonisolated(unsafe) public static let debugSettingsDescription: LocalizedStringKey = LocalizedStringKey("settings.advanced.debug.description")
        nonisolated(unsafe) public static let experimentalFeatures: LocalizedStringKey = LocalizedStringKey("settings.advanced.experimental")
        nonisolated(unsafe) public static let experimentalFeaturesDescription: LocalizedStringKey = LocalizedStringKey("settings.advanced.experimental.description")
        nonisolated(unsafe) public static let performanceMonitoring: LocalizedStringKey = LocalizedStringKey("settings.advanced.performance_monitoring")
        nonisolated(unsafe) public static let performanceMonitoringDescription: LocalizedStringKey = LocalizedStringKey("settings.advanced.performance_monitoring.description")
        nonisolated(unsafe) public static let systemInformation: LocalizedStringKey = LocalizedStringKey("settings.advanced.system_information")
        nonisolated(unsafe) public static let systemInformationDescription: LocalizedStringKey = LocalizedStringKey("settings.advanced.system_information.description")
        nonisolated(unsafe) public static let maintenance: LocalizedStringKey = LocalizedStringKey("settings.advanced.maintenance")
        nonisolated(unsafe) public static let maintenanceDescription: LocalizedStringKey = LocalizedStringKey("settings.advanced.maintenance.description")
        nonisolated(unsafe) public static let about: LocalizedStringKey = LocalizedStringKey("settings.advanced.about")
        nonisolated(unsafe) public static let aboutDescription: LocalizedStringKey = LocalizedStringKey("settings.advanced.about.description")
    }
    
    // MARK: - Loading States
    public enum Loading {
        nonisolated(unsafe) public static let scanningFolder: LocalizedStringKey = LocalizedStringKey("loading.scanning_folder")
        nonisolated(unsafe) public static let loadingImages: LocalizedStringKey = LocalizedStringKey("loading.loading_images")
        nonisolated(unsafe) public static let preparingSlideshow: LocalizedStringKey = LocalizedStringKey("loading.preparing_slideshow")
        
        public static func scanningFolderProgress(_ count: Int) -> LocalizedStringKey {
            LocalizedStringKey("loading.scanning_folder \(count)")
        }
    }
    
    // MARK: - Error Messages
    public enum Error {
        nonisolated(unsafe) public static let title: LocalizedStringKey = LocalizedStringKey("error.title")
        nonisolated(unsafe) public static let noImagesFound: LocalizedStringKey = LocalizedStringKey("error.no_images_found")
        nonisolated(unsafe) public static let folderAccessDenied: LocalizedStringKey = LocalizedStringKey("error.folder_access_denied")
        nonisolated(unsafe) public static let imageLoadFailed: LocalizedStringKey = LocalizedStringKey("error.image_load_failed")
        nonisolated(unsafe) public static let memoryWarning: LocalizedStringKey = LocalizedStringKey("error.memory_warning")
        nonisolated(unsafe) public static let unsupportedFormat: LocalizedStringKey = LocalizedStringKey("error.unsupported_format")
        nonisolated(unsafe) public static let fileCorrupted: LocalizedStringKey = LocalizedStringKey("error.file_corrupted")
    }
    
    // MARK: - Tooltips
    public enum Tooltip {
        nonisolated(unsafe) public static let tapForInfo: LocalizedStringKey = LocalizedStringKey("tooltip.tap_for_info")
        nonisolated(unsafe) public static let previous: LocalizedStringKey = LocalizedStringKey("tooltip.previous")
        nonisolated(unsafe) public static let next: LocalizedStringKey = LocalizedStringKey("tooltip.next")
        nonisolated(unsafe) public static let playPause: LocalizedStringKey = LocalizedStringKey("tooltip.play_pause")
        nonisolated(unsafe) public static let settings: LocalizedStringKey = LocalizedStringKey("tooltip.settings")
    }
    
    // MARK: - Language Names
    public enum Language {
        nonisolated(unsafe) public static let system: LocalizedStringKey = LocalizedStringKey("language.system")
        nonisolated(unsafe) public static let english: LocalizedStringKey = LocalizedStringKey("language.english")
        nonisolated(unsafe) public static let japanese: LocalizedStringKey = LocalizedStringKey("language.japanese")
        nonisolated(unsafe) public static let spanish: LocalizedStringKey = LocalizedStringKey("language.spanish")
        nonisolated(unsafe) public static let french: LocalizedStringKey = LocalizedStringKey("language.french")
        nonisolated(unsafe) public static let german: LocalizedStringKey = LocalizedStringKey("language.german")
        nonisolated(unsafe) public static let chineseSimplified: LocalizedStringKey = LocalizedStringKey("language.chinese_simplified")
        nonisolated(unsafe) public static let chineseTraditional: LocalizedStringKey = LocalizedStringKey("language.chinese_traditional")
        nonisolated(unsafe) public static let korean: LocalizedStringKey = LocalizedStringKey("language.korean")
        nonisolated(unsafe) public static let portuguese: LocalizedStringKey = LocalizedStringKey("language.portuguese")
        nonisolated(unsafe) public static let italian: LocalizedStringKey = LocalizedStringKey("language.italian")
        nonisolated(unsafe) public static let russian: LocalizedStringKey = LocalizedStringKey("language.russian")
    }
    
    // MARK: - Search and UI
    public enum UI {
        nonisolated(unsafe) public static let searchPlaceholder: LocalizedStringKey = LocalizedStringKey("search.placeholder")
        nonisolated(unsafe) public static let appVersion: LocalizedStringKey = LocalizedStringKey("app.version")
        nonisolated(unsafe) public static let photoCounter: LocalizedStringKey = LocalizedStringKey("ui.photo_counter")
        
        // Interface Labels
        nonisolated(unsafe) public static let duringSlideshow: LocalizedStringKey = LocalizedStringKey("ui.during_slideshow")
        nonisolated(unsafe) public static let whenPaused: LocalizedStringKey = LocalizedStringKey("ui.when_paused")
        nonisolated(unsafe) public static let mouseSensitivity: LocalizedStringKey = LocalizedStringKey("ui.mouse_sensitivity")
        nonisolated(unsafe) public static let minimumVisibilityDuration: LocalizedStringKey = LocalizedStringKey("ui.minimum_visibility_duration")
        nonisolated(unsafe) public static let backgroundBlurIntensity: LocalizedStringKey = LocalizedStringKey("ui.background_blur_intensity")
        nonisolated(unsafe) public static let backgroundOpacity: LocalizedStringKey = LocalizedStringKey("ui.background_opacity")
        nonisolated(unsafe) public static let fadeAnimationDuration: LocalizedStringKey = LocalizedStringKey("ui.fade_animation_duration")
        nonisolated(unsafe) public static let controlsPositionFromBottom: LocalizedStringKey = LocalizedStringKey("ui.controls_position_from_bottom")
        
        // Advanced Labels
        nonisolated(unsafe) public static let performanceTip: LocalizedStringKey = LocalizedStringKey("ui.performance_tip")
        nonisolated(unsafe) public static let verboseLogging: LocalizedStringKey = LocalizedStringKey("ui.verbose_logging")
        nonisolated(unsafe) public static let debugInformation: LocalizedStringKey = LocalizedStringKey("ui.debug_information")
        nonisolated(unsafe) public static let performanceEnhancements: LocalizedStringKey = LocalizedStringKey("ui.performance_enhancements")
        nonisolated(unsafe) public static let interfaceImprovements: LocalizedStringKey = LocalizedStringKey("ui.interface_improvements")
        nonisolated(unsafe) public static let currentPerformanceMetrics: LocalizedStringKey = LocalizedStringKey("ui.current_performance_metrics")
        nonisolated(unsafe) public static let memoryUsage: LocalizedStringKey = LocalizedStringKey("ui.memory_usage")
        nonisolated(unsafe) public static let cpuUsage: LocalizedStringKey = LocalizedStringKey("ui.cpu_usage")
        nonisolated(unsafe) public static let diskUsage: LocalizedStringKey = LocalizedStringKey("ui.disk_usage")
        nonisolated(unsafe) public static let keyFeatures: LocalizedStringKey = LocalizedStringKey("ui.key_features")
        
        // System Information Labels
        nonisolated(unsafe) public static let application: LocalizedStringKey = LocalizedStringKey("ui.application")
        nonisolated(unsafe) public static let system: LocalizedStringKey = LocalizedStringKey("ui.system")
        nonisolated(unsafe) public static let hardware: LocalizedStringKey = LocalizedStringKey("ui.hardware")
        nonisolated(unsafe) public static let version: LocalizedStringKey = LocalizedStringKey("ui.version")
        nonisolated(unsafe) public static let build: LocalizedStringKey = LocalizedStringKey("ui.build")
        nonisolated(unsafe) public static let bundleId: LocalizedStringKey = LocalizedStringKey("ui.bundle_id")
        nonisolated(unsafe) public static let macOS: LocalizedStringKey = LocalizedStringKey("ui.macos")
        nonisolated(unsafe) public static let architecture: LocalizedStringKey = LocalizedStringKey("ui.architecture")
        nonisolated(unsafe) public static let model: LocalizedStringKey = LocalizedStringKey("ui.model")
        nonisolated(unsafe) public static let totalMemory: LocalizedStringKey = LocalizedStringKey("ui.total_memory")
        nonisolated(unsafe) public static let availableMemory: LocalizedStringKey = LocalizedStringKey("ui.available_memory")
        nonisolated(unsafe) public static let processor: LocalizedStringKey = LocalizedStringKey("ui.processor")
    }
    
    // MARK: - App Information  
    public enum App {
        nonisolated(unsafe) public static let name: LocalizedStringKey = LocalizedStringKey("app.name")
        nonisolated(unsafe) public static let version: LocalizedStringKey = LocalizedStringKey("app.version")
    }
    
    // MARK: - Window Titles
    public enum Window {
        nonisolated(unsafe) public static let settingsTitle: LocalizedStringKey = LocalizedStringKey("window.settings_title")
        nonisolated(unsafe) public static let settingsDescription: LocalizedStringKey = LocalizedStringKey("window.settings_description")
        nonisolated(unsafe) public static let quickActions: LocalizedStringKey = LocalizedStringKey("window.quick_actions")
        
        public static func settingsNotImplemented(for categoryName: String) -> String {
            String(localized: "Settings for \(categoryName) will be implemented here.")
        }
    }
    
    // MARK: - Categories
    public enum Category {
        nonisolated(unsafe) public static let performance: LocalizedStringKey = LocalizedStringKey("category.performance")
        nonisolated(unsafe) public static let performanceDescription: LocalizedStringKey = LocalizedStringKey("category.performance.description")
        nonisolated(unsafe) public static let slideshow: LocalizedStringKey = LocalizedStringKey("category.slideshow")
        nonisolated(unsafe) public static let slideshowDescription: LocalizedStringKey = LocalizedStringKey("category.slideshow.description")
        nonisolated(unsafe) public static let transitions: LocalizedStringKey = LocalizedStringKey("category.transitions")
        nonisolated(unsafe) public static let transitionsDescription: LocalizedStringKey = LocalizedStringKey("category.transitions.description")
        
        // String versions for Swift API compatibility
        public static func performanceString() -> String {
            String(localized: "category.performance")
        }
        public static func performanceDescriptionString() -> String {
            String(localized: "category.performance.description")
        }
        public static func slideshowString() -> String {
            String(localized: "category.slideshow")
        }
        public static func slideshowDescriptionString() -> String {
            String(localized: "category.slideshow.description")
        }
        public static func transitionsString() -> String {
            String(localized: "category.transitions")
        }
        public static func transitionsDescriptionString() -> String {
            String(localized: "category.transitions.description")
        }
    }
    
    // MARK: - Settings String Helpers
    public enum SettingsString {
        public static func sortPresets() -> String {
            String(localized: "settings.sort.presets")
        }
        public static func sortPresetsDescription() -> String {
            String(localized: "settings.sort.presets.description")
        }
        public static func sortOrder() -> String {
            String(localized: "settings.sort.order")
        }
        public static func sortOrderDescription() -> String {
            String(localized: "settings.sort.order.description")
        }
        public static func sortDirection() -> String {
            String(localized: "settings.sort.direction")
        }
        public static func sortDirectionDescription() -> String {
            String(localized: "settings.sort.direction.description")
        }
        public static func currentSettings() -> String {
            String(localized: "settings.current_settings")
        }
        public static func currentSettingsDescription() -> String {
            String(localized: "settings.current_settings.description")
        }
        public static func performanceInformation() -> String {
            String(localized: "settings.performance_information")
        }
        public static func performanceInformationDescription() -> String {
            String(localized: "settings.performance_information.description")
        }
        
        // Interface Settings
        public static func autoHide() -> String {
            String(localized: "settings.interface.auto_hide")
        }
        public static func autoHideDescription() -> String {
            String(localized: "settings.interface.auto_hide.description")
        }
        public static func mouseInteraction() -> String {
            String(localized: "settings.interface.mouse_interaction")
        }
        public static func mouseInteractionDescription() -> String {
            String(localized: "settings.interface.mouse_interaction.description")
        }
        public static func appearance() -> String {
            String(localized: "settings.interface.appearance")
        }
        public static func appearanceDescription() -> String {
            String(localized: "settings.interface.appearance.description")
        }
        public static func informationDisplay() -> String {
            String(localized: "settings.interface.information_display")
        }
        public static func informationDisplayDescription() -> String {
            String(localized: "settings.interface.information_display.description")
        }
        public static func presets() -> String {
            String(localized: "settings.interface.presets")
        }
        public static func presetsDescription() -> String {
            String(localized: "settings.interface.presets.description")
        }
        
        // Advanced Settings
        public static func debugSettings() -> String {
            String(localized: "settings.advanced.debug")
        }
        public static func debugSettingsDescription() -> String {
            String(localized: "settings.advanced.debug.description")
        }
        
        // Performance Settings
        public static func performancePresets() -> String {
            String(localized: "performance.presets")
        }
        public static func performancePresetsDescription() -> String {
            String(localized: "performance.presets_description")
        }
        public static func manualConfiguration() -> String {
            String(localized: "performance.manual_configuration")
        }
        public static func manualConfigurationDescription() -> String {
            String(localized: "performance.manual_configuration_description")
        }
        public static func advancedSettings() -> String {
            String(localized: "performance.advanced_settings")
        }
        public static func advancedSettingsDescription() -> String {
            String(localized: "performance.advanced_settings_description")
        }
        
        // Setting labels
        public static func memoryWindowSize() -> String {
            String(localized: "performance.memory_window_size")
        }
        public static func maxMemoryUsage() -> String {
            String(localized: "performance.max_memory_usage")
        }
        public static func concurrentLoads() -> String {
            String(localized: "performance.concurrent_loads")
        }
        public static func aggressiveMemoryManagement() -> String {
            String(localized: "performance.aggressive_memory_management")
        }
        public static func largeCollectionThreshold() -> String {
            String(localized: "performance.large_collection_threshold")
        }
        public static func preloadDistance() -> String {
            String(localized: "performance.preload_distance")
        }
        
        // Format strings
        public static func imagesFormat() -> String {
            String(localized: "performance.format.images")
        }
        public static func mbFormat() -> String {
            String(localized: "performance.format.mb")
        }
        public static func numberFormat() -> String {
            String(localized: "performance.format.number")
        }
        
        // Preset names
        public static func customName() -> String {
            String(localized: "performance.name.custom")
        }
        public static func defaultName() -> String {
            String(localized: "performance.name.default")
        }
        public static func highPerformanceName() -> String {
            String(localized: "performance.name.high_performance")
        }
        public static func unlimitedName() -> String {
            String(localized: "performance.name.unlimited")
        }
        public static func massiveName() -> String {
            String(localized: "performance.name.massive")
        }
        public static func extremeName() -> String {
            String(localized: "performance.name.extreme")
        }
    }
    
    // MARK: - Button String Helpers
    public enum ButtonString {
        public static func alphabetical() -> String {
            String(localized: "button.sort.alphabetical")
        }
        public static func chronological() -> String {
            String(localized: "button.sort.chronological")
        }
        public static func newestFirst() -> String {
            String(localized: "button.sort.newest_first")
        }
        public static func largestFirst() -> String {
            String(localized: "button.sort.largest_first")
        }
        public static func random() -> String {
            String(localized: "button.sort.random")
        }
        public static func newRandomOrder() -> String {
            String(localized: "button.sort.new_random_order")
        }
        public static func defaultPreset() -> String {
            String(localized: "button.interface.default")
        }
        public static func minimal() -> String {
            String(localized: "button.interface.minimal")
        }
        public static func alwaysVisible() -> String {
            String(localized: "button.interface.always_visible")
        }
        public static func subtle() -> String {
            String(localized: "button.interface.subtle")
        }
        
        // Performance Preset Buttons
        public static func performanceDefault() -> String {
            String(localized: "performance.preset.default")
        }
        public static func performanceHighPerformance() -> String {
            String(localized: "performance.preset.high_performance")
        }
        public static func performanceUnlimited() -> String {
            String(localized: "performance.preset.unlimited")
        }
        public static func performanceMassive() -> String {
            String(localized: "performance.preset.massive")
        }
        public static func performanceExtreme() -> String {
            String(localized: "performance.preset.extreme")
        }
    }
    
    // MARK: - Toggle String Helpers
    public enum ToggleString {
        public static func hideControlsCompletely() -> String {
            String(localized: "toggle.hide_controls_completely")
        }
        public static func showControlsOnMouseMovement() -> String {
            String(localized: "toggle.show_controls_on_mouse_movement")
        }
        public static func showDetailedPhotoInformation() -> String {
            String(localized: "toggle.show_detailed_photo_information")
        }
        public static func enableDebugLogging() -> String {
            String(localized: "toggle.enable_debug_logging")
        }
    }
    
    // MARK: - Buttons
    public enum Button {
        nonisolated(unsafe) public static let resetAllSettings: LocalizedStringKey = LocalizedStringKey("button.reset_all_settings")
        
        // Sort Settings Buttons
        nonisolated(unsafe) public static let alphabetical: LocalizedStringKey = LocalizedStringKey("button.sort.alphabetical")
        nonisolated(unsafe) public static let chronological: LocalizedStringKey = LocalizedStringKey("button.sort.chronological")
        nonisolated(unsafe) public static let newestFirst: LocalizedStringKey = LocalizedStringKey("button.sort.newest_first")
        nonisolated(unsafe) public static let largestFirst: LocalizedStringKey = LocalizedStringKey("button.sort.largest_first")
        nonisolated(unsafe) public static let random: LocalizedStringKey = LocalizedStringKey("button.sort.random")
        nonisolated(unsafe) public static let newRandomOrder: LocalizedStringKey = LocalizedStringKey("button.sort.new_random_order")
        
        // Interface Settings Buttons
        nonisolated(unsafe) public static let defaultPreset: LocalizedStringKey = LocalizedStringKey("button.interface.default")
        nonisolated(unsafe) public static let minimal: LocalizedStringKey = LocalizedStringKey("button.interface.minimal")
        nonisolated(unsafe) public static let alwaysVisible: LocalizedStringKey = LocalizedStringKey("button.interface.always_visible")
        nonisolated(unsafe) public static let subtle: LocalizedStringKey = LocalizedStringKey("button.interface.subtle")
        
        // Advanced Settings Buttons
        nonisolated(unsafe) public static let showSystemInfo: LocalizedStringKey = LocalizedStringKey("button.advanced.show_system_info")
        nonisolated(unsafe) public static let exportLogs: LocalizedStringKey = LocalizedStringKey("button.advanced.export_logs")
        nonisolated(unsafe) public static let clearCache: LocalizedStringKey = LocalizedStringKey("button.advanced.clear_cache")
        nonisolated(unsafe) public static let refreshMetrics: LocalizedStringKey = LocalizedStringKey("button.advanced.refresh_metrics")
        nonisolated(unsafe) public static let performanceReport: LocalizedStringKey = LocalizedStringKey("button.advanced.performance_report")
        nonisolated(unsafe) public static let loadSystemInfo: LocalizedStringKey = LocalizedStringKey("button.advanced.load_system_info")
        nonisolated(unsafe) public static let resetAllSettingsAdvanced: LocalizedStringKey = LocalizedStringKey("button.advanced.reset_all_settings")
        nonisolated(unsafe) public static let clearAllCaches: LocalizedStringKey = LocalizedStringKey("button.advanced.clear_all_caches")
        nonisolated(unsafe) public static let resetWindowPositions: LocalizedStringKey = LocalizedStringKey("button.advanced.reset_window_positions")
        nonisolated(unsafe) public static let clearRecentFiles: LocalizedStringKey = LocalizedStringKey("button.advanced.clear_recent_files")
    }
    
    // MARK: - Alerts
    public enum Alert {
        nonisolated(unsafe) public static let resetAllSettingsTitle: LocalizedStringKey = LocalizedStringKey("alert.reset_all_settings.title")
        nonisolated(unsafe) public static let resetAllSettingsMessage: LocalizedStringKey = LocalizedStringKey("alert.reset_all_settings.message")
    }
    
    // MARK: - Toggle Labels
    public enum Toggle {
        nonisolated(unsafe) public static let hideControlsCompletely: LocalizedStringKey = LocalizedStringKey("toggle.hide_controls_completely")
        nonisolated(unsafe) public static let showControlsOnMouseMovement: LocalizedStringKey = LocalizedStringKey("toggle.show_controls_on_mouse_movement")
        nonisolated(unsafe) public static let showDetailedPhotoInformation: LocalizedStringKey = LocalizedStringKey("toggle.show_detailed_photo_information")
        nonisolated(unsafe) public static let enableDebugLogging: LocalizedStringKey = LocalizedStringKey("toggle.enable_debug_logging")
        nonisolated(unsafe) public static let verboseLogging: LocalizedStringKey = LocalizedStringKey("toggle.verbose_logging")
    }
    
    // MARK: - Feature Descriptions
    public enum Features {
        nonisolated(unsafe) public static let unlimitedPhotoCollections: LocalizedStringKey = LocalizedStringKey("features.unlimited_photo_collections")
        nonisolated(unsafe) public static let advancedMemoryManagement: LocalizedStringKey = LocalizedStringKey("features.advanced_memory_management")
        nonisolated(unsafe) public static let smoothTransitionsAndEffects: LocalizedStringKey = LocalizedStringKey("features.smooth_transitions_and_effects")
        nonisolated(unsafe) public static let performanceOptimization: LocalizedStringKey = LocalizedStringKey("features.performance_optimization")
        nonisolated(unsafe) public static let nativeMacOSExperience: LocalizedStringKey = LocalizedStringKey("features.native_macos_experience")
        nonisolated(unsafe) public static let advancedMemoryManagementDesc: LocalizedStringKey = LocalizedStringKey("features.advanced_memory_management_desc")
        nonisolated(unsafe) public static let optimizedImageLoading: LocalizedStringKey = LocalizedStringKey("features.optimized_image_loading")
        nonisolated(unsafe) public static let smartCachingSystem: LocalizedStringKey = LocalizedStringKey("features.smart_caching_system")
        nonisolated(unsafe) public static let touchBarSupport: LocalizedStringKey = LocalizedStringKey("features.touch_bar_support")
        nonisolated(unsafe) public static let enhancedGestures: LocalizedStringKey = LocalizedStringKey("features.enhanced_gestures")
        nonisolated(unsafe) public static let advancedTransitions: LocalizedStringKey = LocalizedStringKey("features.advanced_transitions")
    }
    
    // MARK: - File Management
    public enum FileManagement {
        nonisolated(unsafe) public static let recentFolders: LocalizedStringKey = LocalizedStringKey("file_management.recent_folders")
        nonisolated(unsafe) public static let maximumRecentFolders: LocalizedStringKey = LocalizedStringKey("file_management.maximum_recent_folders")
        nonisolated(unsafe) public static let cleanUpInvalidFolders: LocalizedStringKey = LocalizedStringKey("file_management.clean_up_invalid")
        nonisolated(unsafe) public static let exportRecentFolders: LocalizedStringKey = LocalizedStringKey("file_management.export_recent")
        nonisolated(unsafe) public static let importRecentFolders: LocalizedStringKey = LocalizedStringKey("file_management.import_recent")
        nonisolated(unsafe) public static let clearAllRecentFolders: LocalizedStringKey = LocalizedStringKey("file_management.clear_all")
        nonisolated(unsafe) public static let appSandboxProtection: LocalizedStringKey = LocalizedStringKey("file_management.app_sandbox_protection")
        nonisolated(unsafe) public static let appSandboxProtectionEnabled: LocalizedStringKey = LocalizedStringKey("file_management.app_sandbox_protection_enabled")
        nonisolated(unsafe) public static let statistics: LocalizedStringKey = LocalizedStringKey("file_management.statistics")
        nonisolated(unsafe) public static let management: LocalizedStringKey = LocalizedStringKey("file_management.management")
        nonisolated(unsafe) public static let securityAccess: LocalizedStringKey = LocalizedStringKey("file_management.security_access")
        nonisolated(unsafe) public static let refreshStatistics: LocalizedStringKey = LocalizedStringKey("file_management.refresh_statistics")
        nonisolated(unsafe) public static let conservative: LocalizedStringKey = LocalizedStringKey("file_management.conservative")
        nonisolated(unsafe) public static let balanced: LocalizedStringKey = LocalizedStringKey("file_management.balanced")
        nonisolated(unsafe) public static let extensive: LocalizedStringKey = LocalizedStringKey("file_management.extensive")
        nonisolated(unsafe) public static let presets: LocalizedStringKey = LocalizedStringKey("file_management.presets")
        nonisolated(unsafe) public static let sandboxDescription: LocalizedStringKey = LocalizedStringKey("file_management.sandbox_description")
        nonisolated(unsafe) public static let externalVolumesSupported: LocalizedStringKey = LocalizedStringKey("file_management.external_volumes_supported")
        nonisolated(unsafe) public static let clearAllConfirmation: LocalizedStringKey = LocalizedStringKey("file_management.clear_all_confirmation")
        nonisolated(unsafe) public static let andMoreCount: LocalizedStringKey = LocalizedStringKey("file_management.and_more_count")
    }
    
    // MARK: - Keyboard Shortcuts  
    public enum KeyboardShortcuts {
        nonisolated(unsafe) public static let slideshowControls: LocalizedStringKey = LocalizedStringKey("keyboard.slideshow_controls")
        nonisolated(unsafe) public static let interfaceControls: LocalizedStringKey = LocalizedStringKey("keyboard.interface_controls")
        nonisolated(unsafe) public static let applicationControls: LocalizedStringKey = LocalizedStringKey("keyboard.application_controls")
        nonisolated(unsafe) public static let fileNavigation: LocalizedStringKey = LocalizedStringKey("keyboard.file_navigation")
        nonisolated(unsafe) public static let quickTips: LocalizedStringKey = LocalizedStringKey("keyboard.quick_tips")
        nonisolated(unsafe) public static let accessibility: LocalizedStringKey = LocalizedStringKey("keyboard.accessibility")
        nonisolated(unsafe) public static let performanceTips: LocalizedStringKey = LocalizedStringKey("keyboard.performance_tips")
        nonisolated(unsafe) public static let tipsAndInformation: LocalizedStringKey = LocalizedStringKey("keyboard.tips_and_information")
        nonisolated(unsafe) public static let quickTipsContent1: LocalizedStringKey = LocalizedStringKey("keyboard.quick_tips_content1")
        nonisolated(unsafe) public static let quickTipsContent2: LocalizedStringKey = LocalizedStringKey("keyboard.quick_tips_content2")
        nonisolated(unsafe) public static let quickTipsContent3: LocalizedStringKey = LocalizedStringKey("keyboard.quick_tips_content3")
        nonisolated(unsafe) public static let accessibilityContent1: LocalizedStringKey = LocalizedStringKey("keyboard.accessibility_content1")
        nonisolated(unsafe) public static let accessibilityContent2: LocalizedStringKey = LocalizedStringKey("keyboard.accessibility_content2")
        nonisolated(unsafe) public static let accessibilityContent3: LocalizedStringKey = LocalizedStringKey("keyboard.accessibility_content3")
        nonisolated(unsafe) public static let performanceContent1: LocalizedStringKey = LocalizedStringKey("keyboard.performance_content1")
        nonisolated(unsafe) public static let performanceContent2: LocalizedStringKey = LocalizedStringKey("keyboard.performance_content2")
        nonisolated(unsafe) public static let performanceContent3: LocalizedStringKey = LocalizedStringKey("keyboard.performance_content3")
    }
    
    // MARK: - Transitions
    public enum Transitions {
        nonisolated(unsafe) public static let transitionEffects: LocalizedStringKey = LocalizedStringKey("transitions.effects")
        nonisolated(unsafe) public static let effectPresets: LocalizedStringKey = LocalizedStringKey("transitions.presets")
        nonisolated(unsafe) public static let simpleFade: LocalizedStringKey = LocalizedStringKey("transitions.simple_fade")
        nonisolated(unsafe) public static let elegantSlide: LocalizedStringKey = LocalizedStringKey("transitions.elegant_slide")
        nonisolated(unsafe) public static let dynamicZoom: LocalizedStringKey = LocalizedStringKey("transitions.dynamic_zoom")
        nonisolated(unsafe) public static let smoothCrossfade: LocalizedStringKey = LocalizedStringKey("transitions.smooth_crossfade")
        nonisolated(unsafe) public static let cinematicPush: LocalizedStringKey = LocalizedStringKey("transitions.cinematic_push")
        nonisolated(unsafe) public static let duration: LocalizedStringKey = LocalizedStringKey("transitions.duration")
        nonisolated(unsafe) public static let animationEasing: LocalizedStringKey = LocalizedStringKey("transitions.animation_easing")
        nonisolated(unsafe) public static let effectIntensity: LocalizedStringKey = LocalizedStringKey("transitions.effect_intensity")
        nonisolated(unsafe) public static let effectType: LocalizedStringKey = LocalizedStringKey("transitions.effect_type")
        nonisolated(unsafe) public static let timingSettings: LocalizedStringKey = LocalizedStringKey("transitions.timing_settings")
        nonisolated(unsafe) public static let currentSettings: LocalizedStringKey = LocalizedStringKey("transitions.current_settings")
        nonisolated(unsafe) public static let performanceInformation: LocalizedStringKey = LocalizedStringKey("transitions.performance_information")
        nonisolated(unsafe) public static let performanceTip: LocalizedStringKey = LocalizedStringKey("transitions.performance_tip")
        nonisolated(unsafe) public static let performanceTipDescription: LocalizedStringKey = LocalizedStringKey("transitions.performance_tip_description")
        nonisolated(unsafe) public static let fadeEffectTip: LocalizedStringKey = LocalizedStringKey("transitions.fade_effect_tip")
        nonisolated(unsafe) public static let zoomEffectTip: LocalizedStringKey = LocalizedStringKey("transitions.zoom_effect_tip")
        nonisolated(unsafe) public static let pushEffectTip: LocalizedStringKey = LocalizedStringKey("transitions.push_effect_tip")
        nonisolated(unsafe) public static let effectLabel: LocalizedStringKey = LocalizedStringKey("transitions.effect_label")
        nonisolated(unsafe) public static let durationLabel: LocalizedStringKey = LocalizedStringKey("transitions.duration_label")
        nonisolated(unsafe) public static let easingLabel: LocalizedStringKey = LocalizedStringKey("transitions.easing_label")
        nonisolated(unsafe) public static let intensityLabel: LocalizedStringKey = LocalizedStringKey("transitions.intensity_label")
    }
    
    // MARK: - Slideshow Settings
    public enum Slideshow {
        nonisolated(unsafe) public static let slideDuration: LocalizedStringKey = LocalizedStringKey("slideshow.slide_duration")
        nonisolated(unsafe) public static let slideshowPresets: LocalizedStringKey = LocalizedStringKey("slideshow.presets")
        nonisolated(unsafe) public static let timingSettings: LocalizedStringKey = LocalizedStringKey("slideshow.timing_settings")
        nonisolated(unsafe) public static let playbackBehavior: LocalizedStringKey = LocalizedStringKey("slideshow.playback_behavior")
        nonisolated(unsafe) public static let keyboardControls: LocalizedStringKey = LocalizedStringKey("slideshow.keyboard_controls")
        nonisolated(unsafe) public static let defaultPreset: LocalizedStringKey = LocalizedStringKey("slideshow.preset.default")
        nonisolated(unsafe) public static let quickPreset: LocalizedStringKey = LocalizedStringKey("slideshow.preset.quick")
        nonisolated(unsafe) public static let slowPreset: LocalizedStringKey = LocalizedStringKey("slideshow.preset.slow")
        nonisolated(unsafe) public static let randomPreset: LocalizedStringKey = LocalizedStringKey("slideshow.preset.random")
    }
    
    // MARK: - Interface Settings
    public enum Interface {
        nonisolated(unsafe) public static let generalAutoHideDelay: LocalizedStringKey = LocalizedStringKey("interface.general_auto_hide_delay")
        nonisolated(unsafe) public static let duringSlideshow: LocalizedStringKey = LocalizedStringKey("interface.during_slideshow")
        nonisolated(unsafe) public static let whenPaused: LocalizedStringKey = LocalizedStringKey("interface.when_paused")
        nonisolated(unsafe) public static let mouseSensitivity: LocalizedStringKey = LocalizedStringKey("interface.mouse_sensitivity")
        nonisolated(unsafe) public static let minimumVisibilityDuration: LocalizedStringKey = LocalizedStringKey("interface.minimum_visibility_duration")
        nonisolated(unsafe) public static let backgroundBlurIntensity: LocalizedStringKey = LocalizedStringKey("interface.background_blur_intensity")
        nonisolated(unsafe) public static let backgroundOpacity: LocalizedStringKey = LocalizedStringKey("interface.background_opacity")
        nonisolated(unsafe) public static let fadeAnimationDuration: LocalizedStringKey = LocalizedStringKey("interface.fade_animation_duration")
        nonisolated(unsafe) public static let controlsPositionFromBottom: LocalizedStringKey = LocalizedStringKey("interface.controls_position_from_bottom")
        nonisolated(unsafe) public static let infoToggleHint: LocalizedStringKey = LocalizedStringKey("interface.info_toggle_hint")
        nonisolated(unsafe) public static let infoDisplayDetails: LocalizedStringKey = LocalizedStringKey("interface.info_display_details")
    }
    
    // MARK: - Region Names
    public enum Region {
        nonisolated(unsafe) public static let unitedStates: LocalizedStringKey = LocalizedStringKey("region.united_states")
        nonisolated(unsafe) public static let japan: LocalizedStringKey = LocalizedStringKey("region.japan")
        nonisolated(unsafe) public static let unitedKingdom: LocalizedStringKey = LocalizedStringKey("region.united_kingdom")
        nonisolated(unsafe) public static let germany: LocalizedStringKey = LocalizedStringKey("region.germany")
        nonisolated(unsafe) public static let france: LocalizedStringKey = LocalizedStringKey("region.france")
        nonisolated(unsafe) public static let spain: LocalizedStringKey = LocalizedStringKey("region.spain")
        nonisolated(unsafe) public static let china: LocalizedStringKey = LocalizedStringKey("region.china")
        nonisolated(unsafe) public static let korea: LocalizedStringKey = LocalizedStringKey("region.korea")
        nonisolated(unsafe) public static let region: LocalizedStringKey = LocalizedStringKey("region.region")
        nonisolated(unsafe) public static let affectsFormatting: LocalizedStringKey = LocalizedStringKey("region.affects_formatting")
    }
    
    // MARK: - Date and Time
    public enum DateTime {
        nonisolated(unsafe) public static let dateFormat: LocalizedStringKey = LocalizedStringKey("datetime.date_format")
        nonisolated(unsafe) public static let numberFormat: LocalizedStringKey = LocalizedStringKey("datetime.number_format")
        nonisolated(unsafe) public static let timeFormat: LocalizedStringKey = LocalizedStringKey("datetime.time_format")
        nonisolated(unsafe) public static let preview: LocalizedStringKey = LocalizedStringKey("datetime.preview")
        nonisolated(unsafe) public static let affectsTimeDisplay: LocalizedStringKey = LocalizedStringKey("datetime.affects_time_display")
        nonisolated(unsafe) public static let affectsFileSize: LocalizedStringKey = LocalizedStringKey("datetime.affects_file_size")
        nonisolated(unsafe) public static let improvesAccessibility: LocalizedStringKey = LocalizedStringKey("datetime.improves_accessibility")
        nonisolated(unsafe) public static let sortLocale: LocalizedStringKey = LocalizedStringKey("datetime.sort_locale")
        nonisolated(unsafe) public static let firstDayOfWeek: LocalizedStringKey = LocalizedStringKey("datetime.first_day_of_week")
        nonisolated(unsafe) public static let rightToLeftLayout: LocalizedStringKey = LocalizedStringKey("datetime.right_to_left_layout")
        nonisolated(unsafe) public static let yes: LocalizedStringKey = LocalizedStringKey("datetime.yes")
        nonisolated(unsafe) public static let no: LocalizedStringKey = LocalizedStringKey("datetime.no")
    }
    
    // MARK: - Performance Settings
    public enum Performance {
        // Section titles and descriptions
        nonisolated(unsafe) public static let performancePresets: LocalizedStringKey = LocalizedStringKey("performance.presets")
        nonisolated(unsafe) public static let performancePresetsDescription: LocalizedStringKey = LocalizedStringKey("performance.presets_description")
        nonisolated(unsafe) public static let manualConfiguration: LocalizedStringKey = LocalizedStringKey("performance.manual_configuration")
        nonisolated(unsafe) public static let manualConfigurationDescription: LocalizedStringKey = LocalizedStringKey("performance.manual_configuration_description")
        nonisolated(unsafe) public static let advancedSettings: LocalizedStringKey = LocalizedStringKey("performance.advanced_settings")
        nonisolated(unsafe) public static let advancedSettingsDescription: LocalizedStringKey = LocalizedStringKey("performance.advanced_settings_description")
        
        // Preset button titles
        nonisolated(unsafe) public static let defaultPreset: LocalizedStringKey = LocalizedStringKey("performance.preset.default")
        nonisolated(unsafe) public static let highPerformancePreset: LocalizedStringKey = LocalizedStringKey("performance.preset.high_performance")
        nonisolated(unsafe) public static let unlimitedPreset: LocalizedStringKey = LocalizedStringKey("performance.preset.unlimited")
        nonisolated(unsafe) public static let massivePreset: LocalizedStringKey = LocalizedStringKey("performance.preset.massive")
        nonisolated(unsafe) public static let extremePreset: LocalizedStringKey = LocalizedStringKey("performance.preset.extreme")
        
        // Setting labels
        nonisolated(unsafe) public static let memoryWindowSize: LocalizedStringKey = LocalizedStringKey("performance.memory_window_size")
        nonisolated(unsafe) public static let maxMemoryUsage: LocalizedStringKey = LocalizedStringKey("performance.max_memory_usage")
        nonisolated(unsafe) public static let concurrentLoads: LocalizedStringKey = LocalizedStringKey("performance.concurrent_loads")
        nonisolated(unsafe) public static let aggressiveMemoryManagement: LocalizedStringKey = LocalizedStringKey("performance.aggressive_memory_management")
        nonisolated(unsafe) public static let largeCollectionThreshold: LocalizedStringKey = LocalizedStringKey("performance.large_collection_threshold")
        nonisolated(unsafe) public static let preloadDistance: LocalizedStringKey = LocalizedStringKey("performance.preload_distance")
        
        // Preset names (for selectedPreset)
        nonisolated(unsafe) public static let defaultName: LocalizedStringKey = LocalizedStringKey("performance.name.default")
        nonisolated(unsafe) public static let highPerformanceName: LocalizedStringKey = LocalizedStringKey("performance.name.high_performance")
        nonisolated(unsafe) public static let unlimitedName: LocalizedStringKey = LocalizedStringKey("performance.name.unlimited")
        nonisolated(unsafe) public static let massiveName: LocalizedStringKey = LocalizedStringKey("performance.name.massive")
        nonisolated(unsafe) public static let extremeName: LocalizedStringKey = LocalizedStringKey("performance.name.extreme")
        nonisolated(unsafe) public static let customName: LocalizedStringKey = LocalizedStringKey("performance.name.custom")
        
        // Format strings
        nonisolated(unsafe) public static let imagesFormat: LocalizedStringKey = LocalizedStringKey("performance.format.images")
        nonisolated(unsafe) public static let mbFormat: LocalizedStringKey = LocalizedStringKey("performance.format.mb")
        nonisolated(unsafe) public static let numberFormat: LocalizedStringKey = LocalizedStringKey("performance.format.number")
        
        // Legacy keys (keeping for compatibility)
        nonisolated(unsafe) public static let preloadAhead: LocalizedStringKey = LocalizedStringKey("performance.preload_ahead")
        nonisolated(unsafe) public static let preloadBehind: LocalizedStringKey = LocalizedStringKey("performance.preload_behind")
        nonisolated(unsafe) public static let maxConcurrentLoads: LocalizedStringKey = LocalizedStringKey("performance.max_concurrent_loads")
        nonisolated(unsafe) public static let cacheSizeMB: LocalizedStringKey = LocalizedStringKey("performance.cache_size_mb")
        nonisolated(unsafe) public static let memoryManagement: LocalizedStringKey = LocalizedStringKey("performance.memory_management")
        nonisolated(unsafe) public static let aggressiveMemoryCleanup: LocalizedStringKey = LocalizedStringKey("performance.aggressive_memory_cleanup")
        nonisolated(unsafe) public static let enableDebugLogging: LocalizedStringKey = LocalizedStringKey("performance.enable_debug_logging")
        nonisolated(unsafe) public static let defaultImages: LocalizedStringKey = LocalizedStringKey("performance.default_images")
        nonisolated(unsafe) public static let highPerformanceImages: LocalizedStringKey = LocalizedStringKey("performance.high_performance_images")
        nonisolated(unsafe) public static let unlimitedImages: LocalizedStringKey = LocalizedStringKey("performance.unlimited_images")
        nonisolated(unsafe) public static let massiveImages: LocalizedStringKey = LocalizedStringKey("performance.massive_images")
        nonisolated(unsafe) public static let extremeImages: LocalizedStringKey = LocalizedStringKey("performance.extreme_images")
        nonisolated(unsafe) public static let currentSettings: LocalizedStringKey = LocalizedStringKey("performance.current_settings")
        nonisolated(unsafe) public static let memoryWindowImagesLabel: LocalizedStringKey = LocalizedStringKey("performance.memory_window_images_label")
        nonisolated(unsafe) public static let preloadLabel: LocalizedStringKey = LocalizedStringKey("performance.preload_label")
        nonisolated(unsafe) public static let cacheSizeLabel: LocalizedStringKey = LocalizedStringKey("performance.cache_size_label")
        nonisolated(unsafe) public static let concurrentLoadsLabel: LocalizedStringKey = LocalizedStringKey("performance.concurrent_loads_label")
        nonisolated(unsafe) public static let memoryModeLabel: LocalizedStringKey = LocalizedStringKey("performance.memory_mode_label")
        nonisolated(unsafe) public static let memoryTips: LocalizedStringKey = LocalizedStringKey("performance.memory_tips")
        nonisolated(unsafe) public static let memoryUsageInfo: LocalizedStringKey = LocalizedStringKey("performance.memory_usage_info")
        nonisolated(unsafe) public static let optimalSettings: LocalizedStringKey = LocalizedStringKey("performance.optimal_settings")
        nonisolated(unsafe) public static let smallCollections: LocalizedStringKey = LocalizedStringKey("performance.small_collections")
        nonisolated(unsafe) public static let mediumCollections: LocalizedStringKey = LocalizedStringKey("performance.medium_collections")
        nonisolated(unsafe) public static let largeCollections: LocalizedStringKey = LocalizedStringKey("performance.large_collections")
        nonisolated(unsafe) public static let resetConfiguration: LocalizedStringKey = LocalizedStringKey("performance.reset_configuration")
    }
    
    // MARK: - Measurement System
    public enum Measurement {
        nonisolated(unsafe) public static let system: LocalizedStringKey = LocalizedStringKey("measurement.system")
        nonisolated(unsafe) public static let automatic: LocalizedStringKey = LocalizedStringKey("measurement.automatic")
        nonisolated(unsafe) public static let metric: LocalizedStringKey = LocalizedStringKey("measurement.metric")
        nonisolated(unsafe) public static let imperial: LocalizedStringKey = LocalizedStringKey("measurement.imperial")
    }
    
    // MARK: - Accessibility
    public enum Accessibility {
        nonisolated(unsafe) public static let enableFeatures: LocalizedStringKey = LocalizedStringKey("accessibility.enable_features")
        nonisolated(unsafe) public static let title: LocalizedStringKey = LocalizedStringKey("accessibility.title")
        nonisolated(unsafe) public static let description: LocalizedStringKey = LocalizedStringKey("accessibility.description")
    }
}

// MARK: - Legacy Compatibility Extensions (Deprecated)

extension String {
    
    /// Get localized string using current system locale (Swift 6 native pattern)
    static func localized(_ key: String) -> String {
        return String(localized: String.LocalizationValue(key))
    }
    
    /// Get localized string using specific locale (Swift 6 native pattern)
    static func localized(_ key: String, locale: Locale) -> String {
        return String(localized: String.LocalizationValue(key), locale: locale)
    }
}

// MARK: - SwiftUI Text Extensions for Convenience
// Note: Text already has built-in LocalizedStringKey support in SwiftUI

// MARK: - AlertError for Localized Error Handling

/// Helper struct for creating localized alerts following Swift 6 patterns
public struct AlertError: LocalizedError, @unchecked Sendable {
    public let titleKey: String
    public let messageKey: String
    public let underlying: Error?
    
    public init(titleKey: String, messageKey: String, underlying: Error? = nil) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.underlying = underlying
    }
    
    public var errorDescription: String? { 
        String(localized: String.LocalizationValue(messageKey))
    }
    
    public var failureReason: String? { 
        underlying?.localizedDescription 
    }
    
    // MARK: - Convenience Factory Methods (Swift 6 Pattern)
    
    public static func noImagesFound() -> AlertError {
        AlertError(
            titleKey: "error.title",
            messageKey: "error.no_images_found"
        )
    }
    
    public static func folderAccessDenied() -> AlertError {
        AlertError(
            titleKey: "error.title",
            messageKey: "error.folder_access_denied"
        )
    }
    
    public static func imageLoadFailed() -> AlertError {
        AlertError(
            titleKey: "error.title",
            messageKey: "error.image_load_failed"
        )
    }
    
    public static func memoryWarning() -> AlertError {
        AlertError(
            titleKey: "error.title",
            messageKey: "error.memory_warning"
        )
    }
}