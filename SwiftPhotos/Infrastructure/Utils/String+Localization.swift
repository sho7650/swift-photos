import Foundation
import SwiftUI

// MARK: - L10n Namespace for Type-Safe Localization (Swift 6 Best Practice)

/// Type-safe localization namespace following Swift 6 best practices
public enum L10n {
    
    // MARK: - Actions
    public enum Action {
        public static let play: LocalizedStringKey = LocalizedStringKey("slideshow.button.play")
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
        public static let performanceDescription = LocalizedStringKey("settings.performance.description")
        public static let performancePresets = LocalizedStringKey("settings.performance.presets")
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
    
    // MARK: - File Management
    public enum FileManagement {
        public static let recentFolders = LocalizedStringKey("file_management.recent_folders")
        public static let maximumRecentFolders = LocalizedStringKey("file_management.maximum_recent_folders")
        public static let cleanUpInvalidFolders = LocalizedStringKey("file_management.clean_up_invalid")
        public static let exportRecentFolders = LocalizedStringKey("file_management.export_recent")
        public static let importRecentFolders = LocalizedStringKey("file_management.import_recent")
        public static let clearAllRecentFolders = LocalizedStringKey("file_management.clear_all")
        public static let appSandboxProtection = LocalizedStringKey("file_management.app_sandbox_protection")
        public static let appSandboxProtectionEnabled = LocalizedStringKey("file_management.app_sandbox_protection_enabled")
        public static let statistics = LocalizedStringKey("file_management.statistics")
        public static let management = LocalizedStringKey("file_management.management")
        public static let securityAccess = LocalizedStringKey("file_management.security_access")
        public static let refreshStatistics = LocalizedStringKey("file_management.refresh_statistics")
        public static let conservative = LocalizedStringKey("file_management.conservative")
        public static let balanced = LocalizedStringKey("file_management.balanced")
        public static let extensive = LocalizedStringKey("file_management.extensive")
        public static let presets = LocalizedStringKey("file_management.presets")
        public static let sandboxDescription = LocalizedStringKey("file_management.sandbox_description")
        public static let externalVolumesSupported = LocalizedStringKey("file_management.external_volumes_supported")
        public static let clearAllConfirmation = LocalizedStringKey("file_management.clear_all_confirmation")
        public static let andMoreCount = LocalizedStringKey("file_management.and_more_count")
    }
    
    // MARK: - Keyboard Shortcuts  
    public enum KeyboardShortcuts {
        public static let slideshowControls = LocalizedStringKey("keyboard.slideshow_controls")
        public static let interfaceControls = LocalizedStringKey("keyboard.interface_controls")
        public static let applicationControls = LocalizedStringKey("keyboard.application_controls")
        public static let fileNavigation = LocalizedStringKey("keyboard.file_navigation")
        public static let quickTips = LocalizedStringKey("keyboard.quick_tips")
        public static let accessibility = LocalizedStringKey("keyboard.accessibility")
        public static let performanceTips = LocalizedStringKey("keyboard.performance_tips")
        public static let tipsAndInformation = LocalizedStringKey("keyboard.tips_and_information")
        public static let quickTipsContent1 = LocalizedStringKey("keyboard.quick_tips_content1")
        public static let quickTipsContent2 = LocalizedStringKey("keyboard.quick_tips_content2")
        public static let quickTipsContent3 = LocalizedStringKey("keyboard.quick_tips_content3")
        public static let accessibilityContent1 = LocalizedStringKey("keyboard.accessibility_content1")
        public static let accessibilityContent2 = LocalizedStringKey("keyboard.accessibility_content2")
        public static let accessibilityContent3 = LocalizedStringKey("keyboard.accessibility_content3")
        public static let performanceContent1 = LocalizedStringKey("keyboard.performance_content1")
        public static let performanceContent2 = LocalizedStringKey("keyboard.performance_content2")
        public static let performanceContent3 = LocalizedStringKey("keyboard.performance_content3")
    }
    
    // MARK: - Transitions
    public enum Transitions {
        public static let transitionEffects = LocalizedStringKey("transitions.effects")
        public static let effectPresets = LocalizedStringKey("transitions.presets")
        public static let simpleFade = LocalizedStringKey("transitions.simple_fade")
        public static let elegantSlide = LocalizedStringKey("transitions.elegant_slide")
        public static let dynamicZoom = LocalizedStringKey("transitions.dynamic_zoom")
        public static let smoothCrossfade = LocalizedStringKey("transitions.smooth_crossfade")
        public static let cinematicPush = LocalizedStringKey("transitions.cinematic_push")
        public static let duration = LocalizedStringKey("transitions.duration")
        public static let animationEasing = LocalizedStringKey("transitions.animation_easing")
        public static let effectIntensity = LocalizedStringKey("transitions.effect_intensity")
        public static let effectType = LocalizedStringKey("transitions.effect_type")
        public static let timingSettings = LocalizedStringKey("transitions.timing_settings")
        public static let currentSettings = LocalizedStringKey("transitions.current_settings")
        public static let performanceInformation = LocalizedStringKey("transitions.performance_information")
        public static let performanceTip = LocalizedStringKey("transitions.performance_tip")
        public static let performanceTipDescription = LocalizedStringKey("transitions.performance_tip_description")
        public static let fadeEffectTip = LocalizedStringKey("transitions.fade_effect_tip")
        public static let zoomEffectTip = LocalizedStringKey("transitions.zoom_effect_tip")
        public static let pushEffectTip = LocalizedStringKey("transitions.push_effect_tip")
        public static let effectLabel = LocalizedStringKey("transitions.effect_label")
        public static let durationLabel = LocalizedStringKey("transitions.duration_label")
        public static let easingLabel = LocalizedStringKey("transitions.easing_label")
        public static let intensityLabel = LocalizedStringKey("transitions.intensity_label")
    }
    
    // MARK: - Slideshow Settings
    public enum Slideshow {
        public static let slideDuration = LocalizedStringKey("slideshow.slide_duration")
        public static let slideshowPresets = LocalizedStringKey("slideshow.presets")
        public static let timingSettings = LocalizedStringKey("slideshow.timing_settings")
        public static let playbackBehavior = LocalizedStringKey("slideshow.playback_behavior")
        public static let keyboardControls = LocalizedStringKey("slideshow.keyboard_controls")
        public static let defaultPreset = LocalizedStringKey("slideshow.preset.default")
        public static let quickPreset = LocalizedStringKey("slideshow.preset.quick")
        public static let slowPreset = LocalizedStringKey("slideshow.preset.slow")
        public static let randomPreset = LocalizedStringKey("slideshow.preset.random")
    }
    
    // MARK: - Interface Settings
    public enum Interface {
        public static let generalAutoHideDelay = LocalizedStringKey("interface.general_auto_hide_delay")
        public static let duringSlideshow = LocalizedStringKey("interface.during_slideshow")
        public static let whenPaused = LocalizedStringKey("interface.when_paused")
        public static let mouseSensitivity = LocalizedStringKey("interface.mouse_sensitivity")
        public static let minimumVisibilityDuration = LocalizedStringKey("interface.minimum_visibility_duration")
        public static let backgroundBlurIntensity = LocalizedStringKey("interface.background_blur_intensity")
        public static let backgroundOpacity = LocalizedStringKey("interface.background_opacity")
        public static let fadeAnimationDuration = LocalizedStringKey("interface.fade_animation_duration")
        public static let controlsPositionFromBottom = LocalizedStringKey("interface.controls_position_from_bottom")
        public static let infoToggleHint = LocalizedStringKey("interface.info_toggle_hint")
        public static let infoDisplayDetails = LocalizedStringKey("interface.info_display_details")
    }
    
    // MARK: - Region Names
    public enum Region {
        public static let unitedStates = LocalizedStringKey("region.united_states")
        public static let japan = LocalizedStringKey("region.japan")
        public static let unitedKingdom = LocalizedStringKey("region.united_kingdom")
        public static let germany = LocalizedStringKey("region.germany")
        public static let france = LocalizedStringKey("region.france")
        public static let spain = LocalizedStringKey("region.spain")
        public static let china = LocalizedStringKey("region.china")
        public static let korea = LocalizedStringKey("region.korea")
        public static let region = LocalizedStringKey("region.region")
        public static let affectsFormatting = LocalizedStringKey("region.affects_formatting")
    }
    
    // MARK: - Date and Time
    public enum DateTime {
        public static let dateFormat = LocalizedStringKey("datetime.date_format")
        public static let numberFormat = LocalizedStringKey("datetime.number_format")
        public static let timeFormat = LocalizedStringKey("datetime.time_format")
        public static let preview = LocalizedStringKey("datetime.preview")
        public static let affectsTimeDisplay = LocalizedStringKey("datetime.affects_time_display")
        public static let affectsFileSize = LocalizedStringKey("datetime.affects_file_size")
        public static let improvesAccessibility = LocalizedStringKey("datetime.improves_accessibility")
        public static let sortLocale = LocalizedStringKey("datetime.sort_locale")
        public static let firstDayOfWeek = LocalizedStringKey("datetime.first_day_of_week")
        public static let rightToLeftLayout = LocalizedStringKey("datetime.right_to_left_layout")
        public static let yes = LocalizedStringKey("datetime.yes")
        public static let no = LocalizedStringKey("datetime.no")
    }
    
    // MARK: - Performance Settings
    public enum Performance {
        // Section titles and descriptions
        public static let performancePresets = LocalizedStringKey("performance.presets")
        public static let performancePresetsDescription = LocalizedStringKey("performance.presets_description")
        public static let manualConfiguration = LocalizedStringKey("performance.manual_configuration")
        public static let manualConfigurationDescription = LocalizedStringKey("performance.manual_configuration_description")
        public static let advancedSettings = LocalizedStringKey("performance.advanced_settings")
        public static let advancedSettingsDescription = LocalizedStringKey("performance.advanced_settings_description")
        
        // Preset button titles
        public static let defaultPreset = LocalizedStringKey("performance.preset.default")
        public static let highPerformancePreset = LocalizedStringKey("performance.preset.high_performance")
        public static let unlimitedPreset = LocalizedStringKey("performance.preset.unlimited")
        public static let massivePreset = LocalizedStringKey("performance.preset.massive")
        public static let extremePreset = LocalizedStringKey("performance.preset.extreme")
        
        // Setting labels
        public static let memoryWindowSize = LocalizedStringKey("performance.memory_window_size")
        public static let maxMemoryUsage = LocalizedStringKey("performance.max_memory_usage")
        public static let concurrentLoads = LocalizedStringKey("performance.concurrent_loads")
        public static let aggressiveMemoryManagement = LocalizedStringKey("performance.aggressive_memory_management")
        public static let largeCollectionThreshold = LocalizedStringKey("performance.large_collection_threshold")
        public static let preloadDistance = LocalizedStringKey("performance.preload_distance")
        
        // Preset names (for selectedPreset)
        public static let defaultName = LocalizedStringKey("performance.name.default")
        public static let highPerformanceName = LocalizedStringKey("performance.name.high_performance")
        public static let unlimitedName = LocalizedStringKey("performance.name.unlimited")
        public static let massiveName = LocalizedStringKey("performance.name.massive")
        public static let extremeName = LocalizedStringKey("performance.name.extreme")
        public static let customName = LocalizedStringKey("performance.name.custom")
        
        // Format strings
        public static let imagesFormat = LocalizedStringKey("performance.format.images")
        public static let mbFormat = LocalizedStringKey("performance.format.mb")
        public static let numberFormat = LocalizedStringKey("performance.format.number")
        
        // Legacy keys (keeping for compatibility)
        public static let preloadAhead = LocalizedStringKey("performance.preload_ahead")
        public static let preloadBehind = LocalizedStringKey("performance.preload_behind")
        public static let maxConcurrentLoads = LocalizedStringKey("performance.max_concurrent_loads")
        public static let cacheSizeMB = LocalizedStringKey("performance.cache_size_mb")
        public static let memoryManagement = LocalizedStringKey("performance.memory_management")
        public static let aggressiveMemoryCleanup = LocalizedStringKey("performance.aggressive_memory_cleanup")
        public static let enableDebugLogging = LocalizedStringKey("performance.enable_debug_logging")
        public static let defaultImages = LocalizedStringKey("performance.default_images")
        public static let highPerformanceImages = LocalizedStringKey("performance.high_performance_images")
        public static let unlimitedImages = LocalizedStringKey("performance.unlimited_images")
        public static let massiveImages = LocalizedStringKey("performance.massive_images")
        public static let extremeImages = LocalizedStringKey("performance.extreme_images")
        public static let currentSettings = LocalizedStringKey("performance.current_settings")
        public static let memoryWindowImagesLabel = LocalizedStringKey("performance.memory_window_images_label")
        public static let preloadLabel = LocalizedStringKey("performance.preload_label")
        public static let cacheSizeLabel = LocalizedStringKey("performance.cache_size_label")
        public static let concurrentLoadsLabel = LocalizedStringKey("performance.concurrent_loads_label")
        public static let memoryModeLabel = LocalizedStringKey("performance.memory_mode_label")
        public static let memoryTips = LocalizedStringKey("performance.memory_tips")
        public static let memoryUsageInfo = LocalizedStringKey("performance.memory_usage_info")
        public static let optimalSettings = LocalizedStringKey("performance.optimal_settings")
        public static let smallCollections = LocalizedStringKey("performance.small_collections")
        public static let mediumCollections = LocalizedStringKey("performance.medium_collections")
        public static let largeCollections = LocalizedStringKey("performance.large_collections")
        public static let resetConfiguration = LocalizedStringKey("performance.reset_configuration")
    }
    
    // MARK: - Measurement System
    public enum Measurement {
        public static let system = LocalizedStringKey("measurement.system")
        public static let automatic = LocalizedStringKey("measurement.automatic")
        public static let metric = LocalizedStringKey("measurement.metric")
        public static let imperial = LocalizedStringKey("measurement.imperial")
    }
    
    // MARK: - Accessibility
    public enum Accessibility {
        public static let enableFeatures = LocalizedStringKey("accessibility.enable_features")
        public static let title = LocalizedStringKey("accessibility.title")
        public static let description = LocalizedStringKey("accessibility.description")
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