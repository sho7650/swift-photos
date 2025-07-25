import Foundation
import SwiftUI

// MARK: - Localized String Constants

extension String {
    
    // MARK: - Slideshow Controls
    
    /// Localized string for play button
    static let playButton = String(localized: "slideshow.button.play")
    
    /// Localized string for pause button  
    static let pauseButton = String(localized: "slideshow.button.pause")
    
    /// Localized string for stop button
    static let stopButton = String(localized: "slideshow.button.stop")
    
    /// Localized string for next photo navigation
    static let nextPhoto = String(localized: "slideshow.navigation.next")
    
    /// Localized string for previous photo navigation
    static let previousPhoto = String(localized: "slideshow.navigation.previous")
    
    // MARK: - Menu Items
    
    /// Localized string for open folder menu item
    static let openFolder = String(localized: "menu.file.open_folder")
    
    // MARK: - Settings UI
    
    /// Localized string for settings window title
    static let settingsTitle = String(localized: "settings.window.title")
    
    /// Localized string for performance settings tab
    static let performanceSettings = String(localized: "settings.performance.title")
    
    /// Localized string for slideshow settings tab
    static let slideshowSettings = String(localized: "settings.slideshow.title")
    
    /// Localized string for sort settings tab
    static let sortSettings = String(localized: "settings.sort.title")
    
    /// Localized string for transition settings tab
    static let transitionSettings = String(localized: "settings.transition.title")
    
    /// Localized string for language settings tab
    static let languageSettings = String(localized: "settings.language.title")
    
    // MARK: - Language Names
    
    /// Localized string for English language
    static let languageEnglish = String(localized: "language.english")
    
    /// Localized string for Japanese language
    static let languageJapanese = String(localized: "language.japanese")
    
    /// Localized string for system language option
    static let languageSystem = String(localized: "language.system")
    
    // MARK: - Keyboard Shortcuts
    
    /// Localized string for play/pause shortcut
    static let shortcutPlayPause = String(localized: "shortcut.play_pause")
    
    /// Localized string for next photo shortcut
    static let shortcutNextPhoto = String(localized: "shortcut.next_photo")
    
    /// Localized string for previous photo shortcut
    static let shortcutPreviousPhoto = String(localized: "shortcut.previous_photo")
    
    /// Localized string for toggle info shortcut
    static let shortcutToggleInfo = String(localized: "shortcut.toggle_info")
    
    /// Localized string for toggle controls shortcut
    static let shortcutToggleControls = String(localized: "shortcut.toggle_controls")
    
    /// Localized string for stop shortcut
    static let shortcutStop = String(localized: "shortcut.stop")
    
    /// Localized string for open settings shortcut
    static let shortcutOpenSettings = String(localized: "shortcut.open_settings")
    
    // MARK: - Buttons
    
    /// Localized string for select folder button
    static let selectFolderButton = String(localized: "button.select_folder")
    
    // MARK: - Loading States
    
    /// Localized string for folder selection loading
    static let loadingSelectingFolder = String(localized: "loading.selecting_folder")
    
    /// Localized string for first image loading
    static let loadingFirstImage = String(localized: "loading.first_image")
    
    /// Localized string for slideshow preparation
    static let loadingPreparingSlideshow = String(localized: "loading.preparing_slideshow")
    
    /// Localized string for loading images
    static let loadingImages = String(localized: "loading.loading_images")
    
    /// Localized string for short loading text
    static let loadingShort = String(localized: "loading.loading_short")
    
    // MARK: - Error Messages
    
    /// Localized string for error title
    static let errorTitle = String(localized: "error.title")
    
    // MARK: - Tooltips
    
    /// Localized string for previous tooltip
    static let tooltipPrevious = String(localized: "tooltip.previous")
    
    /// Localized string for next tooltip
    static let tooltipNext = String(localized: "tooltip.next")
    
    /// Localized string for tap for info tooltip
    static let tooltipTapForInfo = String(localized: "tooltip.tap_for_info")
    
    // MARK: - Settings Sections
    
    /// Localized string for slideshow presets section
    static let settingsSlideshowPresets = String(localized: "settings.slideshow_presets")
    
    /// Localized string for slideshow presets description
    static let settingsSlideshowPresetsDescription = String(localized: "settings.slideshow_presets.description")
    
    /// Localized string for timing settings section
    static let settingsTimingSettings = String(localized: "settings.timing_settings")
    
    /// Localized string for timing settings description
    static let settingsTimingSettingsDescription = String(localized: "settings.timing_settings.description")
    
    /// Localized string for playback behavior section
    static let settingsPlaybackBehavior = String(localized: "settings.playback_behavior")
    
    /// Localized string for playback behavior description
    static let settingsPlaybackBehaviorDescription = String(localized: "settings.playback_behavior.description")
    
    /// Localized string for keyboard controls section
    static let settingsKeyboardControls = String(localized: "settings.keyboard_controls")
    
    /// Localized string for keyboard controls description
    static let settingsKeyboardControlsDescription = String(localized: "settings.keyboard_controls.description")
    
    /// Localized string for slide duration setting
    static let settingsSlideDuration = String(localized: "settings.slide_duration")
    
    /// Localized string for auto start setting
    static let settingsAutoStart = String(localized: "settings.auto_start")
    
    /// Localized string for random order setting
    static let settingsRandomOrder = String(localized: "settings.random_order")
    
    /// Localized string for loop slideshow setting
    static let settingsLoopSlideshow = String(localized: "settings.loop_slideshow")
    
    // MARK: - Presets
    
    /// Localized string for default preset
    static let presetDefault = String(localized: "presets.default")
    
    /// Localized string for quick preset
    static let presetQuick = String(localized: "presets.quick")
    
    /// Localized string for slow preset
    static let presetSlow = String(localized: "presets.slow")
    
    /// Localized string for random preset
    static let presetRandom = String(localized: "presets.random")
    
    // MARK: - Duration Formatting
    
    /// Localized string for seconds
    static let durationSeconds = String(localized: "duration.seconds")
    
    /// Localized string for minute (singular)
    static let durationMinute = String(localized: "duration.minute")
    
    /// Localized string for minutes (plural)
    static let durationMinutes = String(localized: "duration.minutes")
    
    // MARK: - Shortcut Descriptions
    
    /// Localized string for play/pause shortcut description
    static let shortcutDescPlayPause = String(localized: "shortcut.desc.play_pause")
    
    /// Localized string for next photo shortcut description
    static let shortcutDescNextPhoto = String(localized: "shortcut.desc.next_photo")
    
    /// Localized string for previous photo shortcut description
    static let shortcutDescPreviousPhoto = String(localized: "shortcut.desc.previous_photo")
    
    /// Localized string for stop slideshow shortcut description
    static let shortcutDescStopSlideshow = String(localized: "shortcut.desc.stop_slideshow")
    
    /// Localized string for toggle info shortcut description
    static let shortcutDescToggleInfo = String(localized: "shortcut.desc.toggle_info")
    
    /// Localized string for toggle controls shortcut description
    static let shortcutDescToggleControls = String(localized: "shortcut.desc.toggle_controls")
    
    // MARK: - Error Messages with Parameters
    
    /// Localized string for file not found error
    static func fileNotFoundError(_ filename: String) -> String {
        String(localized: "error.file_not_found \(filename)")
    }
    
    /// Localized string for loading failed error
    static func loadingFailedError(_ description: String) -> String {
        String(localized: "error.loading_failed \(description)")
    }
    
    /// Localized string for invalid index error
    static func invalidIndexError(_ index: Int) -> String {
        String(localized: "error.invalid_index \(index)")
    }
    
    /// Localized string for scanning folder with count
    static func scanningFolderProgress(_ count: Int) -> String {
        String(localized: "loading.scanning_folder \(count)")
    }
}

// MARK: - LocalizationValue Extensions

extension String.LocalizationValue {
    
    // MARK: - Convenience Initializers
    
    /// Create LocalizationValue for slideshow controls
    static func slideshowControl(_ action: String) -> String.LocalizationValue {
        String.LocalizationValue("slideshow.button.\(action)")
    }
    
    /// Create LocalizationValue for navigation actions
    static func navigation(_ action: String) -> String.LocalizationValue {
        String.LocalizationValue("slideshow.navigation.\(action)")
    }
    
    /// Create LocalizationValue for settings sections
    static func settings(_ section: String) -> String.LocalizationValue {
        String.LocalizationValue("settings.\(section).title")
    }
    
    /// Create LocalizationValue for keyboard shortcuts
    static func shortcut(_ action: String) -> String.LocalizationValue {
        String.LocalizationValue("shortcut.\(action)")
    }
    
    /// Create LocalizationValue for error messages
    static func error(_ type: String) -> String.LocalizationValue {
        String.LocalizationValue("error.\(type)")
    }
    
    /// Create LocalizationValue for loading states
    static func loading(_ state: String) -> String.LocalizationValue {
        String.LocalizationValue("loading.\(state)")
    }
}

// MARK: - Locale-Aware String Extensions

extension String {
    
    /// Compare strings using the current localization locale
    func localizedCompare(_ other: String, locale: Locale = Locale.current) -> ComparisonResult {
        return self.compare(other, options: [.numeric, .caseInsensitive, .diacriticInsensitive], range: nil, locale: locale)
    }
    
    /// Get localized lowercase version
    func localizedLowercase(locale: Locale = Locale.current) -> String {
        return self.lowercased(with: locale)
    }
    
    /// Get localized uppercase version
    func localizedUppercase(locale: Locale = Locale.current) -> String {
        return self.uppercased(with: locale)
    }
    
    /// Get localized capitalized version
    func localizedCapitalized(locale: Locale = Locale.current) -> String {
        return self.capitalized(with: locale)
    }
}

// MARK: - SwiftUI Text Extensions

extension Text {
    
    /// Create localized Text with automatic locale detection
    init(localizedKey key: String) {
        self.init(String(localized: String.LocalizationValue(key)))
    }
    
    /// Create localized Text with specific locale
    init(localizedKey key: String, locale: Locale) {
        self.init(String(localized: String.LocalizationValue(key), locale: locale))
    }
    
    /// Create localized Text for slideshow controls
    static func slideshowControl(_ action: String) -> Text {
        Text(localizedKey: "slideshow.button.\(action)")
    }
    
    /// Create localized Text for settings sections
    static func settingsSection(_ section: String) -> Text {
        Text(localizedKey: "settings.\(section).title")
    }
    
    /// Create localized Text for keyboard shortcuts
    static func keyboardShortcut(_ action: String) -> Text {
        Text(localizedKey: "shortcut.\(action)")
    }
}

// MARK: - Label Extensions for SwiftUI

extension Label where Title == Text, Icon == Image {
    
    /// Create localized Label for settings tabs
    static func settingsTab(_ section: String, systemImage: String) -> Label<Text, Image> {
        Label {
            Text.settingsSection(section)
        } icon: {
            Image(systemName: systemImage)
        }
    }
    
    /// Create localized Label for slideshow controls
    static func slideshowControl(_ action: String, systemImage: String) -> Label<Text, Image> {
        Label {
            Text.slideshowControl(action)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

// MARK: - Alert Extensions

extension AlertError {
    
    /// Create localized error for file operations
    static func fileError(_ filename: String, underlying: Error) -> AlertError {
        AlertError(
            title: String(localized: "error.file_operation_failed"),
            message: String.fileNotFoundError(filename),
            underlying: underlying
        )
    }
    
    /// Create localized error for loading operations
    static func loadingError(_ description: String, underlying: Error) -> AlertError {
        AlertError(
            title: String(localized: "error.loading_failed"),
            message: String.loadingFailedError(description),
            underlying: underlying
        )
    }
}

// MARK: - Supporting Types

/// Helper struct for creating localized alerts
public struct AlertError: LocalizedError {
    public let title: String
    public let message: String
    public let underlying: Error?
    
    public init(title: String, message: String, underlying: Error? = nil) {
        self.title = title
        self.message = message
        self.underlying = underlying
    }
    
    public var errorDescription: String? { message }
    public var failureReason: String? { underlying?.localizedDescription }
    public var recoverySuggestion: String? { 
        String(localized: "error.recovery.general_suggestion")
    }
}

// MARK: - Performance Optimized String Cache

/// Cache for frequently used localized strings to improve performance
@MainActor
public final class LocalizedStringCache {
    
    private static var cache: [String: String] = [:]
    
    /// Get cached localized string or compute and cache it
    public static func string(for key: String, locale: Locale = Locale.current) -> String {
        let cacheKey = "\(key)_\(locale.identifier)"
        
        if let cached = cache[cacheKey] {
            return cached
        }
        
        let localized = String(localized: String.LocalizationValue(key), locale: locale)
        cache[cacheKey] = localized
        return localized
    }
    
    /// Clear the cache (useful when language changes)
    public static func clearCache() {
        cache.removeAll()
    }
    
    /// Clear cache for specific locale
    public static func clearCache(for locale: Locale) {
        let suffix = "_\(locale.identifier)"
        cache = cache.filter { !$0.key.hasSuffix(suffix) }
    }
}