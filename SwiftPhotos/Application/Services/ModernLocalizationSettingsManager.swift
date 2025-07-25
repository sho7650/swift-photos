import Foundation
import SwiftUI
import Observation

/// Localization-specific settings for regional preferences and formatting
public struct LocalizationSettings: Codable, Sendable, Equatable {
    
    // MARK: - Equatable Implementation
    
    public static func == (lhs: LocalizationSettings, rhs: LocalizationSettings) -> Bool {
        return lhs.language == rhs.language &&
               lhs.region == rhs.region &&
               lhs.fallbackLanguages == rhs.fallbackLanguages &&
               lhs.dateFormatStyle == rhs.dateFormatStyle &&
               lhs.numberFormatStyle == rhs.numberFormatStyle &&
               lhs.timeFormat == rhs.timeFormat &&
               lhs.sortLocale == rhs.sortLocale &&
               lhs.firstDayOfWeek == rhs.firstDayOfWeek &&
               lhs.measurementSystem == rhs.measurementSystem &&
               lhs.accessibilityEnabled == rhs.accessibilityEnabled &&
               lhs.voiceOverLanguage == rhs.voiceOverLanguage
    }
    
    // MARK: - Language Settings
    
    /// Selected application language
    public var language: SupportedLanguage
    
    /// Region/country code for regional formatting
    public var region: String
    
    /// List of fallback languages in order of preference
    public var fallbackLanguages: [SupportedLanguage]
    
    // MARK: - Formatting Settings
    
    /// Date formatting style preference
    public var dateFormatStyle: DateFormatStyle
    
    /// Number formatting style preference
    public var numberFormatStyle: NumberFormatStyle
    
    /// Time formatting (12-hour vs 24-hour)
    public var timeFormat: TimeFormat
    
    // MARK: - Locale-Specific Settings
    
    /// Locale for sorting operations (affects file name sorting)
    public var sortLocale: String
    
    /// First day of week (affects date displays)
    public var firstDayOfWeek: Int
    
    /// Measurement system (metric vs imperial)
    public var measurementSystem: MeasurementSystem
    
    // MARK: - Accessibility Settings
    
    /// Enable accessibility features for localization
    public var accessibilityEnabled: Bool
    
    /// VoiceOver language override (if different from app language)
    public var voiceOverLanguage: SupportedLanguage?
    
    // MARK: - Default Configuration
    
    public static let `default` = LocalizationSettings(
        language: .system,
        region: Locale.current.region?.identifier ?? "US",
        fallbackLanguages: [.english],
        dateFormatStyle: .automatic,
        numberFormatStyle: .automatic,
        timeFormat: .automatic,
        sortLocale: Locale.current.identifier,
        firstDayOfWeek: Calendar.current.firstWeekday,
        measurementSystem: .automatic,
        accessibilityEnabled: true,
        voiceOverLanguage: nil
    )
    
    // MARK: - Computed Properties
    
    /// Get effective locale based on language and region
    public var effectiveLocale: Locale {
        let localeIdentifier = language == .system ? 
            Locale.current.identifier : 
            "\(language.rawValue)_\(region)"
        return Locale(identifier: localeIdentifier)
    }
    
    /// Check if current settings use right-to-left layout
    public var isRightToLeft: Bool {
        Locale.Language(identifier: effectiveLocale.language.languageCode?.identifier ?? "en").characterDirection == .rightToLeft
    }
}

// MARK: - Supporting Enums

public enum DateFormatStyle: String, CaseIterable, Codable, Sendable {
    case automatic = "automatic"
    case short = "short"
    case medium = "medium"
    case long = "long"
    case full = "full"
    case relative = "relative"
    
    public var displayName: String {
        switch self {
        case .automatic: return String(localized: "date_format.automatic")
        case .short: return String(localized: "date_format.short")
        case .medium: return String(localized: "date_format.medium")
        case .long: return String(localized: "date_format.long")
        case .full: return String(localized: "date_format.full")
        case .relative: return String(localized: "date_format.relative")
        }
    }
}

public enum NumberFormatStyle: String, CaseIterable, Codable, Sendable {
    case automatic = "automatic"
    case decimal = "decimal"
    case currency = "currency"
    case percent = "percent"
    case scientific = "scientific"
    
    public var displayName: String {
        switch self {
        case .automatic: return String(localized: "number_format.automatic")
        case .decimal: return String(localized: "number_format.decimal")
        case .currency: return String(localized: "number_format.currency")
        case .percent: return String(localized: "number_format.percent")
        case .scientific: return String(localized: "number_format.scientific")
        }
    }
}

public enum TimeFormat: String, CaseIterable, Codable, Sendable {
    case automatic = "automatic"
    case twelveHour = "12"
    case twentyFourHour = "24"
    
    public var displayName: String {
        switch self {
        case .automatic: return String(localized: "time_format.automatic")
        case .twelveHour: return String(localized: "time_format.12_hour")
        case .twentyFourHour: return String(localized: "time_format.24_hour")
        }
    }
}

public enum MeasurementSystem: String, CaseIterable, Codable, Sendable {
    case automatic = "automatic"
    case metric = "metric"
    case imperial = "imperial"
    
    public var displayName: String {
        switch self {
        case .automatic: return String(localized: "measurement.automatic")
        case .metric: return String(localized: "measurement.metric")
        case .imperial: return String(localized: "measurement.imperial")
        }
    }
}

/// Modern Swift 6 compliant LocalizationSettingsManager using @Observable pattern
@Observable
@MainActor
public final class ModernLocalizationSettingsManager {
    
    // MARK: - Published Properties
    
    /// Current localization settings
    public private(set) var settings: LocalizationSettings
    
    /// Integration with LocalizationService
    public let localizationService: LocalizationService
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotos.LocalizationSettings"
    
    // MARK: - Initialization
    
    public init(localizationService: LocalizationService? = nil) {
        if let service = localizationService {
            self.localizationService = service
        } else {
            self.localizationService = LocalizationService()
        }
        self.settings = Self.loadSettings()
        
        // Sync with LocalizationService
        Task { @MainActor in
            self.localizationService.currentLanguage = self.settings.language
        }
        
        setupNotificationObservers()
        
        ProductionLogger.lifecycle("ModernLocalizationSettingsManager: Initialized with language: \(settings.language.displayName)")
    }
    
    // MARK: - Public Methods
    
    /// Update localization settings
    public func updateSettings(_ newSettings: LocalizationSettings) {
        let oldSettings = settings
        settings = newSettings
        
        // Update LocalizationService if language changed
        if oldSettings.language != newSettings.language {
            Task { @MainActor in
                self.localizationService.setLanguage(newSettings.language)
            }
        }
        
        saveSettings()
        notifySettingsChanged()
        
        ProductionLogger.debug("LocalizationSettings updated: language=\(newSettings.language.displayName), region=\(newSettings.region)")
    }
    
    /// Update only the language setting
    public func updateLanguage(_ language: SupportedLanguage) {
        var newSettings = settings
        newSettings.language = language
        updateSettings(newSettings)
    }
    
    /// Update region setting
    public func updateRegion(_ region: String) {
        var newSettings = settings
        newSettings.region = region
        updateSettings(newSettings)
    }
    
    /// Update date format style
    public func updateDateFormatStyle(_ style: DateFormatStyle) {
        var newSettings = settings
        newSettings.dateFormatStyle = style
        updateSettings(newSettings)
    }
    
    /// Update accessibility settings
    public func updateAccessibilityEnabled(_ enabled: Bool) {
        var newSettings = settings
        newSettings.accessibilityEnabled = enabled
        updateSettings(newSettings)
    }
    
    /// Reset to default settings
    public func resetToDefaults() {
        updateSettings(.default)
        ProductionLogger.userAction("LocalizationSettings reset to defaults")
    }
    
    /// Get formatted date string using current settings
    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.effectiveLocale
        
        switch settings.dateFormatStyle {
        case .automatic:
            formatter.dateStyle = .medium
        case .short:
            formatter.dateStyle = .short
        case .medium:
            formatter.dateStyle = .medium
        case .long:
            formatter.dateStyle = .long
        case .full:
            formatter.dateStyle = .full
        case .relative:
            formatter.doesRelativeDateFormatting = true
            formatter.dateStyle = .medium
        }
        
        return formatter.string(from: date)
    }
    
    /// Get formatted number string using current settings
    public func formatNumber(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = settings.effectiveLocale
        
        switch settings.numberFormatStyle {
        case .automatic, .decimal:
            formatter.numberStyle = .decimal
        case .currency:
            formatter.numberStyle = .currency
        case .percent:
            formatter.numberStyle = .percent
        case .scientific:
            formatter.numberStyle = .scientific
        }
        
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    /// Get locale-aware comparator for sorting
    public func sortComparator() -> (String, String) -> ComparisonResult {
        let locale = Locale(identifier: settings.sortLocale)
        return { string1, string2 in
            string1.localizedCompare(string2, locale: locale)
        }
    }
    
    // MARK: - Preset Configurations
    
    /// Apply preset configuration for Japanese users
    public func applyJapanesePreset() {
        var newSettings = settings
        newSettings.language = .japanese
        newSettings.region = "JP"
        newSettings.firstDayOfWeek = 2 // Monday (1=Sunday, 2=Monday, etc.)
        newSettings.measurementSystem = .metric
        newSettings.sortLocale = "ja_JP"
        updateSettings(newSettings)
    }
    
    /// Apply preset configuration for US English users
    public func applyUSEnglishPreset() {
        var newSettings = settings
        newSettings.language = .english
        newSettings.region = "US"
        newSettings.firstDayOfWeek = 1 // Sunday
        newSettings.measurementSystem = .imperial
        newSettings.sortLocale = "en_US"
        updateSettings(newSettings)
    }
    
    /// Apply preset configuration for European users
    public func applyEuropeanPreset() {
        var newSettings = settings
        newSettings.region = "EU"
        newSettings.firstDayOfWeek = 2 // Monday
        newSettings.measurementSystem = .metric
        newSettings.timeFormat = .twentyFourHour
        updateSettings(newSettings)
    }
    
    // MARK: - Private Methods
    
    private static func loadSettings() -> LocalizationSettings {
        guard let data = UserDefaults.standard.data(forKey: "SwiftPhotos.LocalizationSettings"),
              let settings = try? JSONDecoder().decode(LocalizationSettings.self, from: data) else {
            ProductionLogger.debug("LocalizationSettings: No saved settings found, using defaults")
            return .default
        }
        
        ProductionLogger.debug("LocalizationSettings: Loaded saved settings")
        return settings
    }
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("LocalizationSettings: Settings saved to UserDefaults")
        } catch {
            ProductionLogger.error("LocalizationSettings: Failed to save settings: \(error)")
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for system locale changes
        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemLocaleChange()
            }
        }
        
        // Listen for language changes from LocalizationService
        NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let language = notification.object as? SupportedLanguage {
                Task { @MainActor in
                    self?.handleLanguageChange(language)
                }
            }
        }
    }
    
    private func handleSystemLocaleChange() {
        if settings.language == .system {
            // Update region and other locale-dependent settings
            var newSettings = settings
            newSettings.region = Locale.current.region?.identifier ?? "US"
            newSettings.sortLocale = Locale.current.identifier
            updateSettings(newSettings)
        }
    }
    
    private func handleLanguageChange(_ language: SupportedLanguage) {
        if settings.language != language {
            updateLanguage(language)
        }
    }
    
    private func notifySettingsChanged() {
        NotificationCenter.default.post(
            name: .localizationSettingsChanged,
            object: settings
        )
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when localization settings change
    public static let localizationSettingsChanged = Notification.Name("SwiftPhotos.LocalizationSettingsChanged")
}

// MARK: - Weekday Helper

/// Helper for working with weekdays as integers
/// 1 = Sunday, 2 = Monday, ..., 7 = Saturday (following Calendar.firstWeekday convention)
public struct WeekdayHelper {
    public static let sunday = 1
    public static let monday = 2
    public static let tuesday = 3
    public static let wednesday = 4
    public static let thursday = 5
    public static let friday = 6
    public static let saturday = 7
    
    public static func displayName(for weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.weekdaySymbols = Calendar.current.weekdaySymbols
        let index = (weekday - 1) % 7
        return formatter.weekdaySymbols[index]
    }
}