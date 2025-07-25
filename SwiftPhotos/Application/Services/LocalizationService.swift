import Foundation
import SwiftUI
import Observation

/// Supported languages for the application
public enum SupportedLanguage: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case english = "en"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case korean = "ko"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    
    public var displayName: String {
        switch self {
        case .system:
            return String(localized: "language.system")
        case .english:
            return String(localized: "language.english")
        case .japanese:
            return String(localized: "language.japanese")
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
        case .chineseSimplified:
            return "简体中文"
        case .chineseTraditional:
            return "繁體中文"
        case .korean:
            return "한국어"
        case .portuguese:
            return "Português"
        case .italian:
            return "Italiano"
        case .russian:
            return "Русский"
        }
    }
    
    public var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        default:
            return Locale(identifier: rawValue)
        }
    }
    
    public var isRightToLeft: Bool {
        return Locale.Language(identifier: locale.language.languageCode?.identifier ?? "en").characterDirection == .rightToLeft
    }
}

/// Service for managing application localization and language switching
@Observable
public final class LocalizationService: @unchecked Sendable {
    
    // MARK: - Published Properties
    
    /// Current selected language for the application
    @MainActor
    public var currentLanguage: SupportedLanguage = .system {
        didSet {
            if currentLanguage != oldValue {
                updateApplicationLanguage()
                notifyLanguageChange()
            }
        }
    }
    
    /// List of preferred languages in order of preference
    @MainActor
    public var preferredLanguages: [SupportedLanguage] = []
    
    /// Current effective locale being used
    @MainActor
    public private(set) var effectiveLocale: Locale = Locale.current
    
    /// Whether the current language uses right-to-left layout
    @MainActor
    public var isRightToLeft: Bool {
        Locale.Language(identifier: effectiveLocale.language.languageCode?.identifier ?? "en").characterDirection == .rightToLeft
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "SwiftPhotos.SelectedLanguage"
    private let preferredLanguagesKey = "SwiftPhotos.PreferredLanguages"
    
    // MARK: - Initialization
    
    @MainActor
    public init() {
        loadSavedLanguageSettings()
        updateApplicationLanguage()
        
        ProductionLogger.lifecycle("LocalizationService: Initialized with language: \(currentLanguage.rawValue)")
    }
    
    // MARK: - Public Methods
    
    /// Get localized string for the given key
    @MainActor
    public func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key), locale: effectiveLocale)
        return String(format: format, arguments: arguments)
    }
    
    /// Get localized string with explicit locale
    public func localizedString(for key: String, locale: Locale, arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key), locale: locale)
        return String(format: format, arguments: arguments)
    }
    
    /// Set language and save to preferences
    @MainActor
    public func setLanguage(_ language: SupportedLanguage, saveToPreferences: Bool = true) {
        currentLanguage = language
        
        if saveToPreferences {
            saveLanguageSettings()
        }
        
        ProductionLogger.userAction("Language changed to: \(language.displayName)")
    }
    
    /// Add language to preferred languages list
    @MainActor
    public func addPreferredLanguage(_ language: SupportedLanguage) {
        if !preferredLanguages.contains(language) {
            preferredLanguages.append(language)
            saveLanguageSettings()
        }
    }
    
    /// Remove language from preferred languages list  
    @MainActor
    public func removePreferredLanguage(_ language: SupportedLanguage) {
        preferredLanguages.removeAll { $0 == language }
        saveLanguageSettings()
    }
    
    /// Get the best available language for the current system
    @MainActor
    public func bestAvailableLanguage() -> SupportedLanguage {
        // If system language is selected, try to match system locale
        if currentLanguage == .system {
            let systemLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
            
            // Try to find exact match
            for language in SupportedLanguage.allCases {
                if language.rawValue == systemLanguageCode {
                    return language
                }
            }
            
            // Try to find language family match (e.g., "zh" for Chinese)
            for language in SupportedLanguage.allCases {
                if language.rawValue.hasPrefix(systemLanguageCode) {
                    return language
                }
            }
            
            // Fallback to English
            return .english
        }
        
        return currentLanguage
    }
    
    /// Check if a specific language is supported
    public func isLanguageSupported(_ languageCode: String) -> Bool {
        return SupportedLanguage.allCases.contains { $0.rawValue == languageCode }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func updateApplicationLanguage() {
        let effectiveLanguage = bestAvailableLanguage()
        effectiveLocale = effectiveLanguage.locale
        
        // Update bundle localization if needed
        if effectiveLanguage != .system {
            updateBundleLocalization(for: effectiveLanguage)
        }
        
        ProductionLogger.debug("LocalizationService: Updated to language: \(effectiveLanguage.displayName), locale: \(effectiveLocale.identifier)")
    }
    
    private func updateBundleLocalization(for language: SupportedLanguage) {
        // For runtime language switching, we primarily rely on the effectiveLocale
        // and pass it to String(localized:locale:) calls
        
        // Note: Full bundle localization switching requires app restart in most cases
        // Our approach using effectiveLocale provides runtime switching without restart
    }
    
    @MainActor
    private func loadSavedLanguageSettings() {
        // Load current language
        if let savedLanguageString = userDefaults.string(forKey: languageKey),
           let savedLanguage = SupportedLanguage(rawValue: savedLanguageString) {
            currentLanguage = savedLanguage
        }
        
        // Load preferred languages
        if let savedPreferredLanguages = userDefaults.array(forKey: preferredLanguagesKey) as? [String] {
            preferredLanguages = savedPreferredLanguages.compactMap { SupportedLanguage(rawValue: $0) }
        }
        
        // Initialize with system preferences if no saved preferences
        if preferredLanguages.isEmpty {
            preferredLanguages = [.system, .english]
        }
    }
    
    @MainActor
    private func saveLanguageSettings() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
        userDefaults.set(preferredLanguages.map { $0.rawValue }, forKey: preferredLanguagesKey)
        
        ProductionLogger.debug("LocalizationService: Saved language settings")
    }
    
    @MainActor
    private func notifyLanguageChange() {
        // Post notification for components that need to react to language changes
        NotificationCenter.default.post(
            name: .languageChanged,
            object: currentLanguage,
            userInfo: ["effectiveLocale": effectiveLocale]
        )
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when the application language changes
    public static let languageChanged = Notification.Name("SwiftPhotos.LanguageChanged")
}

// MARK: - String Extensions for Localization

extension String {
    /// Convenience initializer for localized strings
    init(localizedKey key: String) {
        // Use the default localization without requiring async access
        let format = String(localized: String.LocalizationValue(key))
        self = format
    }
    
    /// Convenience method for formatted localized strings
    static func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key))
        return String(format: format, arguments: arguments)
    }
}

// MARK: - SwiftUI Integration

extension EnvironmentValues {
    /// Environment key for LocalizationService
    @Entry var localizationService: LocalizationService? = nil
}

extension View {
    /// Modifier to provide LocalizationService to the environment
    public func localizationService(_ service: LocalizationService) -> some View {
        environment(\.localizationService, service)
    }
}