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
            return String(localized: "language.spanish")
        case .french:
            return String(localized: "language.french")  
        case .german:
            return String(localized: "language.german")
        case .chineseSimplified:
            return String(localized: "language.chinese_simplified")
        case .chineseTraditional:
            return String(localized: "language.chinese_traditional")
        case .korean:
            return String(localized: "language.korean")
        case .portuguese:
            return String(localized: "language.portuguese")
        case .italian:
            return String(localized: "language.italian")
        case .russian:
            return String(localized: "language.russian")
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

/// Simplified Swift 6 compliant LocalizationService using native SwiftUI patterns
@Observable
@MainActor  
public final class LocalizationService: @unchecked Sendable {
    
    // MARK: - Observable Properties
    
    /// Current selected language for the application
    public var currentLanguage: SupportedLanguage = .system {
        didSet {
            if currentLanguage != oldValue {
                ProductionLogger.debug("LocalizationService: Language changed from \(oldValue.rawValue) to \(currentLanguage.rawValue)")
                saveLanguageSettings()
                notifyLanguageChange()
            }
        }
    }
    
    /// Current effective locale - this drives SwiftUI's environment
    public var currentLocale: Locale {
        currentLanguage.locale
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "SwiftPhotos.SelectedLanguage"
    
    // MARK: - Initialization
    
    public init() {
        loadSavedLanguageSettings()
        ProductionLogger.lifecycle("LocalizationService: ✅ Initialized with language: \(currentLanguage.rawValue)")
    }
    
    // MARK: - Public Methods
    
    /// Set language and trigger environment update
    public func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        ProductionLogger.userAction("Language changed to: \(language.displayName)")
    }
    
    /// Check if a specific language is supported
    public func isLanguageSupported(_ languageCode: String) -> Bool {
        return SupportedLanguage.allCases.contains { $0.rawValue == languageCode }
    }
    
    // MARK: - Private Methods
    
    private func loadSavedLanguageSettings() {
        if let savedLanguageString = userDefaults.string(forKey: languageKey),
           let savedLanguage = SupportedLanguage(rawValue: savedLanguageString) {
            currentLanguage = savedLanguage
        }
    }
    
    private func saveLanguageSettings() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
        ProductionLogger.debug("LocalizationService: Saved language settings")
    }
    
    private func notifyLanguageChange() {
        NotificationCenter.default.post(
            name: .languageChanged,
            object: currentLanguage,
            userInfo: ["locale": currentLocale]
        )
        ProductionLogger.debug("LocalizationService: ✅ Posted languageChanged notification - language: \(currentLanguage.rawValue)")
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when the application language changes
    public static let languageChanged = Notification.Name("SwiftPhotos.LanguageChanged")
}

// MARK: - Environment Support

/// Environment key for LocalizationService
private struct LocalizationServiceKey: EnvironmentKey {
    static let defaultValue: LocalizationService? = nil
}

extension EnvironmentValues {
    /// Access to LocalizationService through SwiftUI environment
    var localizationService: LocalizationService? {
        get { self[LocalizationServiceKey.self] }
        set { self[LocalizationServiceKey.self] = newValue }
    }
}

extension View {
    /// Modifier to provide LocalizationService to the environment
    public func localizationService(_ service: LocalizationService) -> some View {
        environment(\.localizationService, service)
    }
}