import Foundation
import SwiftUI

// MARK: - L10n Namespace for Type-Safe Localization (Swift 6 Best Practice)

/// Type-safe localization namespace following Swift 6 best practices
public enum L10n {
    
    // MARK: - Actions
    public enum Action {
        public static let play = LocalizedStringKey("slideshow.button.play")
        public static let pause = LocalizedStringKey("slideshow.button.pause")
        public static let stop = LocalizedStringKey("slideshow.button.stop")
        public static let next = LocalizedStringKey("slideshow.navigation.next")
        public static let previous = LocalizedStringKey("slideshow.navigation.previous")
        public static let selectFolder = LocalizedStringKey("button.select_folder")
        public static let settings = LocalizedStringKey("button.settings")
        public static let cancel = LocalizedStringKey("button.cancel")
        public static let reset = LocalizedStringKey("button.reset")
        public static let save = LocalizedStringKey("button.save")
    }
    
    // MARK: - Settings
    public enum Settings {
        public static let applicationLanguage = LocalizedStringKey("settings.application_language")
        public static let changesImmediate = LocalizedStringKey("settings.changes_immediate")
        public static let performance = LocalizedStringKey("settings.performance.title")
        public static let slideshow = LocalizedStringKey("settings.slideshow.title")
        public static let sorting = LocalizedStringKey("settings.sorting.title")
        public static let transitions = LocalizedStringKey("settings.transitions.title")
        public static let uiControls = LocalizedStringKey("settings.ui_controls.title")
        public static let language = LocalizedStringKey("settings.language.title")
        public static let languageDescription = LocalizedStringKey("settings.language.description")
        
        // Sort Settings
        public static let sortPresets = LocalizedStringKey("settings.sort.presets")
        public static let sortPresetsDescription = LocalizedStringKey("settings.sort.presets.description")
        public static let sortOrder = LocalizedStringKey("settings.sort.order")
        public static let sortOrderDescription = LocalizedStringKey("settings.sort.order.description")
        public static let sortDirection = LocalizedStringKey("settings.sort.direction")
        public static let sortDirectionDescription = LocalizedStringKey("settings.sort.direction.description")
        public static let currentSettings = LocalizedStringKey("settings.current_settings")
        public static let currentSettingsDescription = LocalizedStringKey("settings.current_settings.description")
        public static let performanceInformation = LocalizedStringKey("settings.performance_information")
        public static let performanceInformationDescription = LocalizedStringKey("settings.performance_information.description")
        
        // Interface Settings
        public static let autoHide = LocalizedStringKey("settings.interface.auto_hide")
        public static let autoHideDescription = LocalizedStringKey("settings.interface.auto_hide.description")
        public static let mouseInteraction = LocalizedStringKey("settings.interface.mouse_interaction")
        public static let mouseInteractionDescription = LocalizedStringKey("settings.interface.mouse_interaction.description")
        public static let appearance = LocalizedStringKey("settings.interface.appearance")
        public static let appearanceDescription = LocalizedStringKey("settings.interface.appearance.description")
        public static let informationDisplay = LocalizedStringKey("settings.interface.information_display")
        public static let informationDisplayDescription = LocalizedStringKey("settings.interface.information_display.description")
        public static let presets = LocalizedStringKey("settings.interface.presets")
        public static let presetsDescription = LocalizedStringKey("settings.interface.presets.description")
        
        // Advanced Settings
        public static let debugSettings = LocalizedStringKey("settings.advanced.debug")
        public static let debugSettingsDescription = LocalizedStringKey("settings.advanced.debug.description")
        public static let experimentalFeatures = LocalizedStringKey("settings.advanced.experimental")
        public static let experimentalFeaturesDescription = LocalizedStringKey("settings.advanced.experimental.description")
        public static let performanceMonitoring = LocalizedStringKey("settings.advanced.performance_monitoring")
        public static let performanceMonitoringDescription = LocalizedStringKey("settings.advanced.performance_monitoring.description")
        public static let systemInformation = LocalizedStringKey("settings.advanced.system_information")
        public static let systemInformationDescription = LocalizedStringKey("settings.advanced.system_information.description")
        public static let maintenance = LocalizedStringKey("settings.advanced.maintenance")
        public static let maintenanceDescription = LocalizedStringKey("settings.advanced.maintenance.description")
        public static let about = LocalizedStringKey("settings.advanced.about")
        public static let aboutDescription = LocalizedStringKey("settings.advanced.about.description")
    }
    
    // MARK: - Loading States
    public enum Loading {
        public static let scanningFolder = LocalizedStringKey("loading.scanning_folder")
        public static let loadingImages = LocalizedStringKey("loading.loading_images")
        public static let preparingSlideshow = LocalizedStringKey("loading.preparing_slideshow")
        
        public static func scanningFolderProgress(_ count: Int) -> LocalizedStringKey {
            LocalizedStringKey("loading.scanning_folder \(count)")
        }
    }
    
    // MARK: - Error Messages
    public enum Error {
        public static let title = LocalizedStringKey("error.title")
        public static let noImagesFound = LocalizedStringKey("error.no_images_found")
        public static let folderAccessDenied = LocalizedStringKey("error.folder_access_denied")
        public static let imageLoadFailed = LocalizedStringKey("error.image_load_failed")
        public static let memoryWarning = LocalizedStringKey("error.memory_warning")
        public static let unsupportedFormat = LocalizedStringKey("error.unsupported_format")
        public static let fileCorrupted = LocalizedStringKey("error.file_corrupted")
    }
    
    // MARK: - Tooltips
    public enum Tooltip {
        public static let tapForInfo = LocalizedStringKey("tooltip.tap_for_info")
        public static let previous = LocalizedStringKey("tooltip.previous")
        public static let next = LocalizedStringKey("tooltip.next")
        public static let playPause = LocalizedStringKey("tooltip.play_pause")
        public static let settings = LocalizedStringKey("tooltip.settings")
    }
    
    // MARK: - Language Names
    public enum Language {
        public static let system = LocalizedStringKey("language.system")
        public static let english = LocalizedStringKey("language.english")
        public static let japanese = LocalizedStringKey("language.japanese")
        public static let spanish = LocalizedStringKey("language.spanish")
        public static let french = LocalizedStringKey("language.french")
        public static let german = LocalizedStringKey("language.german")
        public static let chineseSimplified = LocalizedStringKey("language.chinese_simplified")
        public static let chineseTraditional = LocalizedStringKey("language.chinese_traditional")
        public static let korean = LocalizedStringKey("language.korean")
        public static let portuguese = LocalizedStringKey("language.portuguese")
        public static let italian = LocalizedStringKey("language.italian")
        public static let russian = LocalizedStringKey("language.russian")
    }
    
    // MARK: - Search and UI
    public enum UI {
        public static let searchPlaceholder = LocalizedStringKey("search.placeholder")
        public static let appVersion = LocalizedStringKey("app.version")
        public static let photoCounter = LocalizedStringKey("ui.photo_counter")
        
        // Interface Labels
        public static let duringSlideshow = LocalizedStringKey("ui.during_slideshow")
        public static let whenPaused = LocalizedStringKey("ui.when_paused")
        public static let mouseSensitivity = LocalizedStringKey("ui.mouse_sensitivity")
        public static let minimumVisibilityDuration = LocalizedStringKey("ui.minimum_visibility_duration")
        public static let backgroundBlurIntensity = LocalizedStringKey("ui.background_blur_intensity")
        public static let backgroundOpacity = LocalizedStringKey("ui.background_opacity")
        public static let fadeAnimationDuration = LocalizedStringKey("ui.fade_animation_duration")
        public static let controlsPositionFromBottom = LocalizedStringKey("ui.controls_position_from_bottom")
        
        // Advanced Labels
        public static let performanceTip = LocalizedStringKey("ui.performance_tip")
        public static let verboseLogging = LocalizedStringKey("ui.verbose_logging")
        public static let debugInformation = LocalizedStringKey("ui.debug_information")
        public static let performanceEnhancements = LocalizedStringKey("ui.performance_enhancements")
        public static let interfaceImprovements = LocalizedStringKey("ui.interface_improvements")
        public static let currentPerformanceMetrics = LocalizedStringKey("ui.current_performance_metrics")
        public static let memoryUsage = LocalizedStringKey("ui.memory_usage")
        public static let cpuUsage = LocalizedStringKey("ui.cpu_usage")
        public static let diskUsage = LocalizedStringKey("ui.disk_usage")
        public static let keyFeatures = LocalizedStringKey("ui.key_features")
        
        // System Information Labels
        public static let application = LocalizedStringKey("ui.application")
        public static let system = LocalizedStringKey("ui.system")
        public static let hardware = LocalizedStringKey("ui.hardware")
        public static let version = LocalizedStringKey("ui.version")
        public static let build = LocalizedStringKey("ui.build")
        public static let bundleId = LocalizedStringKey("ui.bundle_id")
        public static let macOS = LocalizedStringKey("ui.macos")
        public static let architecture = LocalizedStringKey("ui.architecture")
        public static let model = LocalizedStringKey("ui.model")
        public static let totalMemory = LocalizedStringKey("ui.total_memory")
        public static let availableMemory = LocalizedStringKey("ui.available_memory")
        public static let processor = LocalizedStringKey("ui.processor")
    }
    
    // MARK: - App Information  
    public enum App {
        public static let name = LocalizedStringKey("app.name")
        public static let version = LocalizedStringKey("app.version")
    }
    
    // MARK: - Window Titles
    public enum Window {
        public static let settingsTitle = LocalizedStringKey("window.settings_title")
        public static let settingsDescription = LocalizedStringKey("window.settings_description")
        public static let quickActions = LocalizedStringKey("window.quick_actions")
        
        public static func settingsNotImplemented(for categoryName: String) -> String {
            String(localized: "Settings for \(categoryName) will be implemented here.")
        }
    }
    
    // MARK: - Categories
    public enum Category {
        public static let performance = LocalizedStringKey("category.performance")
        public static let performanceDescription = LocalizedStringKey("category.performance.description")
        public static let slideshow = LocalizedStringKey("category.slideshow")
        public static let slideshowDescription = LocalizedStringKey("category.slideshow.description")
        public static let transitions = LocalizedStringKey("category.transitions")
        public static let transitionsDescription = LocalizedStringKey("category.transitions.description")
        
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
        public static let resetAllSettings = LocalizedStringKey("button.reset_all_settings")
        
        // Sort Settings Buttons
        public static let alphabetical = LocalizedStringKey("button.sort.alphabetical")
        public static let chronological = LocalizedStringKey("button.sort.chronological")
        public static let newestFirst = LocalizedStringKey("button.sort.newest_first")
        public static let largestFirst = LocalizedStringKey("button.sort.largest_first")
        public static let random = LocalizedStringKey("button.sort.random")
        public static let newRandomOrder = LocalizedStringKey("button.sort.new_random_order")
        
        // Interface Settings Buttons
        public static let defaultPreset = LocalizedStringKey("button.interface.default")
        public static let minimal = LocalizedStringKey("button.interface.minimal")
        public static let alwaysVisible = LocalizedStringKey("button.interface.always_visible")
        public static let subtle = LocalizedStringKey("button.interface.subtle")
        
        // Advanced Settings Buttons
        public static let showSystemInfo = LocalizedStringKey("button.advanced.show_system_info")
        public static let exportLogs = LocalizedStringKey("button.advanced.export_logs")
        public static let clearCache = LocalizedStringKey("button.advanced.clear_cache")
        public static let refreshMetrics = LocalizedStringKey("button.advanced.refresh_metrics")
        public static let performanceReport = LocalizedStringKey("button.advanced.performance_report")
        public static let loadSystemInfo = LocalizedStringKey("button.advanced.load_system_info")
        public static let resetAllSettingsAdvanced = LocalizedStringKey("button.advanced.reset_all_settings")
        public static let clearAllCaches = LocalizedStringKey("button.advanced.clear_all_caches")
        public static let resetWindowPositions = LocalizedStringKey("button.advanced.reset_window_positions")
        public static let clearRecentFiles = LocalizedStringKey("button.advanced.clear_recent_files")
    }
    
    // MARK: - Alerts
    public enum Alert {
        public static let resetAllSettingsTitle = LocalizedStringKey("alert.reset_all_settings.title")
        public static let resetAllSettingsMessage = LocalizedStringKey("alert.reset_all_settings.message")
    }
    
    // MARK: - Toggle Labels
    public enum Toggle {
        public static let hideControlsCompletely = LocalizedStringKey("toggle.hide_controls_completely")
        public static let showControlsOnMouseMovement = LocalizedStringKey("toggle.show_controls_on_mouse_movement")
        public static let showDetailedPhotoInformation = LocalizedStringKey("toggle.show_detailed_photo_information")
        public static let enableDebugLogging = LocalizedStringKey("toggle.enable_debug_logging")
        public static let verboseLogging = LocalizedStringKey("toggle.verbose_logging")
    }
    
    // MARK: - Feature Descriptions
    public enum Features {
        public static let unlimitedPhotoCollections = LocalizedStringKey("features.unlimited_photo_collections")
        public static let advancedMemoryManagement = LocalizedStringKey("features.advanced_memory_management")
        public static let smoothTransitionsAndEffects = LocalizedStringKey("features.smooth_transitions_and_effects")
        public static let performanceOptimization = LocalizedStringKey("features.performance_optimization")
        public static let nativeMacOSExperience = LocalizedStringKey("features.native_macos_experience")
        public static let advancedMemoryManagementDesc = LocalizedStringKey("features.advanced_memory_management_desc")
        public static let optimizedImageLoading = LocalizedStringKey("features.optimized_image_loading")
        public static let smartCachingSystem = LocalizedStringKey("features.smart_caching_system")
        public static let touchBarSupport = LocalizedStringKey("features.touch_bar_support")
        public static let enhancedGestures = LocalizedStringKey("features.enhanced_gestures")
        public static let advancedTransitions = LocalizedStringKey("features.advanced_transitions")
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