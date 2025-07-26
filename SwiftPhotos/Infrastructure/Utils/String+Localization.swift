import Foundation
import SwiftUI

// MARK: - Dynamic Localized String Helpers

extension String {
    
    // MARK: - Dynamic Localization Methods
    
    /// Get localized string using current system locale
    static func localized(_ key: String) -> String {
        return String(localized: String.LocalizationValue(key))
    }
    
    /// Get localized string using specific locale
    static func localized(_ key: String, locale: Locale) -> String {
        return String(localized: String.LocalizationValue(key), locale: locale)
    }
    
    /// Get localized string using LocalizationService (preferred method for runtime switching)
    @MainActor
    static func localized(_ key: String, service: LocalizationService?) -> String {
        ProductionLogger.debug("String+Localization: Requesting key '\(key)' via service=\(service != nil ? "available" : "nil")")
        
        if let service = service {
            let result = service.localizedString(for: key)
            ProductionLogger.debug("String+Localization: Service returned '\(result)' for key '\(key)'")
            return result
        } else {
            let fallback = String(localized: String.LocalizationValue(key))
            ProductionLogger.debug("String+Localization: Using fallback '\(fallback)' for key '\(key)' (no service)")
            return fallback
        }
    }
    
    // MARK: - Convenience Methods for Common UI Elements
    
    /// Get localized string for slideshow controls
    @MainActor
    static func slideshowControl(_ action: String, service: LocalizationService? = nil) -> String {
        return localized("slideshow.button.\(action)", service: service)
    }
    
    /// Get localized string for navigation actions
    @MainActor
    static func navigation(_ action: String, service: LocalizationService? = nil) -> String {
        return localized("slideshow.navigation.\(action)", service: service)
    }
    
    /// Get localized string for settings sections
    @MainActor
    static func settingsSection(_ section: String, service: LocalizationService? = nil) -> String {
        return localized("settings.\(section).title", service: service)
    }
    
    /// Get localized string for keyboard shortcuts
    @MainActor
    static func keyboardShortcut(_ action: String, service: LocalizationService? = nil) -> String {
        return localized("shortcut.\(action)", service: service)
    }
    
    /// Get localized string for tooltips
    @MainActor
    static func tooltip(_ type: String, service: LocalizationService? = nil) -> String {
        return localized("tooltip.\(type)", service: service)
    }
    
    /// Get localized string for buttons
    @MainActor
    static func button(_ type: String, service: LocalizationService? = nil) -> String {
        return localized("button.\(type)", service: service)
    }
    
    /// Get localized string for loading states
    @MainActor
    static func loading(_ state: String, service: LocalizationService? = nil) -> String {
        return localized("loading.\(state)", service: service)
    }
    
    /// Get localized string for error messages
    @MainActor
    static func error(_ type: String, service: LocalizationService? = nil) -> String {
        return localized("error.\(type)", service: service)
    }
    
    /// Get localized string for presets
    @MainActor
    static func preset(_ type: String, service: LocalizationService? = nil) -> String {
        return localized("presets.\(type)", service: service)
    }
    
    /// Get localized string for duration formatting
    @MainActor
    static func duration(_ type: String, service: LocalizationService? = nil) -> String {
        return localized("duration.\(type)", service: service)
    }
    
    /// Get localized string for language names
    @MainActor
    static func language(_ type: String, service: LocalizationService? = nil) -> String {
        return localized("language.\(type)", service: service)
    }
    
    // MARK: - Backward Compatibility Properties (Deprecated)
    // These provide fallback for existing code, but should be replaced with dynamic methods
    
    @available(*, deprecated, message: "Use String.slideshowControl('play', service: localizationService) instead")
    static var playButton: String { localized("slideshow.button.play") }
    
    @available(*, deprecated, message: "Use String.slideshowControl('pause', service: localizationService) instead")
    static var pauseButton: String { localized("slideshow.button.pause") }
    
    @available(*, deprecated, message: "Use String.slideshowControl('stop', service: localizationService) instead")
    static var stopButton: String { localized("slideshow.button.stop") }
    
    @available(*, deprecated, message: "Use String.button('select_folder', service: localizationService) instead")
    static var selectFolderButton: String { localized("button.select_folder") }
    
    @available(*, deprecated, message: "Use String.tooltip('tap_for_info', service: localizationService) instead")
    static var tooltipTapForInfo: String { localized("tooltip.tap_for_info") }
    
    @available(*, deprecated, message: "Use String.tooltip('previous', service: localizationService) instead")
    static var tooltipPrevious: String { localized("tooltip.previous") }
    
    @available(*, deprecated, message: "Use String.tooltip('next', service: localizationService) instead")
    static var tooltipNext: String { localized("tooltip.next") }
    
    @available(*, deprecated, message: "Use String.error('title', service: localizationService) instead")
    static var errorTitle: String { localized("error.title") }
    
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

/// Helper struct for creating localized alerts with recovery suggestions
public struct AlertError: LocalizedError {
    public let title: String
    public let message: String
    public let underlying: Error?
    public let recoveryKey: String?
    
    public init(title: String, message: String, underlying: Error? = nil, recoveryKey: String? = nil) {
        self.title = title
        self.message = message
        self.underlying = underlying
        self.recoveryKey = recoveryKey
    }
    
    public var errorDescription: String? { message }
    public var failureReason: String? { underlying?.localizedDescription }
    public var recoverySuggestion: String? { 
        if let recoveryKey = recoveryKey {
            return String(localized: String.LocalizationValue(recoveryKey))
        }
        return String(localized: String.LocalizationValue("error.recovery.general_suggestion"))
    }
    
    // MARK: - Convenience Factory Methods
    
    /// Create error for no images found in folder
    @MainActor
    public static func noImagesFound(service: LocalizationService? = nil) -> AlertError {
        AlertError(
            title: String.error("title", service: service),
            message: String.localized("error.no_images_found", service: service),
            recoveryKey: "error.recovery.no_images"
        )
    }
    
    /// Create error for folder access denied
    @MainActor
    public static func folderAccessDenied(service: LocalizationService? = nil) -> AlertError {
        AlertError(
            title: String.error("title", service: service),
            message: String.localized("error.folder_access_denied", service: service),
            recoveryKey: "error.recovery.folder_access"
        )
    }
    
    /// Create error for image loading failure
    @MainActor
    public static func imageLoadFailed(fileName: String, service: LocalizationService? = nil) -> AlertError {
        AlertError(
            title: String.error("title", service: service),
            message: String.localized("error.image_load_failed", service: service),
            recoveryKey: "error.recovery.general_suggestion"
        )
    }
    
    /// Create error for memory warning
    @MainActor
    public static func memoryWarning(service: LocalizationService? = nil) -> AlertError {
        AlertError(
            title: String.error("title", service: service),
            message: String.localized("error.memory_warning", service: service),
            recoveryKey: "error.recovery.memory_low"
        )
    }
    
    /// Create error for unsupported format
    @MainActor
    public static func unsupportedFormat(fileName: String, service: LocalizationService? = nil) -> AlertError {
        AlertError(
            title: String.error("title", service: service),
            message: String.localized("error.unsupported_format", service: service),
            recoveryKey: "error.recovery.general_suggestion"
        )
    }
    
    /// Create error for corrupted file
    @MainActor
    public static func fileCorrupted(fileName: String, service: LocalizationService? = nil) -> AlertError {
        AlertError(
            title: String.error("title", service: service),
            message: String.localized("error.file_corrupted", service: service),
            recoveryKey: "error.recovery.restart_app"
        )
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