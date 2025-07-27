import SwiftUI
import Combine

/// Language and localization settings view for configuring multi-language support
/// Integrates with ModernLocalizationSettingsManager for comprehensive language preferences
struct LanguageSettingsView: View {
    var localizationSettings: ModernLocalizationSettingsManager
    
    @State private var previewDate = Date()
    @State private var previewNumber = 1234.56
    @State private var languageUpdateTrigger = 0
    
    // Access the localization service for dynamic strings
    private var localizationService: LocalizationService {
        localizationSettings.localizationService
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Language Selection Section
            LanguageSettingsSection(
                title: String(localized: "settings.language.title"),
                icon: "globe",
                description: String(localized: "settings.language.description")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Primary Language Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.application_language"))
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker(String(localized: "settings.language"), selection: Binding(
                            get: { 
                                let currentLang = localizationSettings.settings.language
                                ProductionLogger.debug("LanguageSettingsView: Picker get - current language: \(currentLang.rawValue)")
                                return currentLang
                            },
                            set: { (newLanguage: SupportedLanguage) in
                                ProductionLogger.userAction("LanguageSettingsView: 🌍 User selected language: \(newLanguage.displayName) (\(newLanguage.rawValue))")
                                
                                let oldLanguage = localizationSettings.settings.language
                                ProductionLogger.debug("LanguageSettingsView: Language change request - from \(oldLanguage.rawValue) to \(newLanguage.rawValue)")
                                
                                localizationSettings.updateLanguage(newLanguage)
                                
                                // Force UI update trigger
                                languageUpdateTrigger += 1
                                
                                ProductionLogger.debug("LanguageSettingsView: Language update completed, trigger: \(languageUpdateTrigger)")
                            }
                        )) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                                Text(language.displayName)
                                    .tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text(String(localized: "settings.changes_immediate"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Region Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "region.region"))
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker(String(localized: "region.region"), selection: Binding(
                            get: { localizationSettings.settings.region },
                            set: { newRegion in
                                localizationSettings.updateRegion(newRegion)
                            }
                        )) {
                            Text(String(localized: "region.united_states")).tag("US")
                            Text(String(localized: "region.japan")).tag("JP")
                            Text(String(localized: "region.united_kingdom")).tag("GB")
                            Text(String(localized: "region.germany")).tag("DE")
                            Text(String(localized: "region.france")).tag("FR")
                            Text(String(localized: "region.spain")).tag("ES")
                            Text(String(localized: "region.china")).tag("CN")
                            Text(String(localized: "region.korea")).tag("KR")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text(String(localized: "region.affects_formatting"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Regional Formatting Section
            LanguageSettingsSection(
                title: String(localized: "settings.regional_formatting.title"),
                icon: "textformat.123",
                description: String(localized: "settings.regional_formatting.description")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Date Format
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "datetime.date_format"))
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker(String(localized: "datetime.date_format"), selection: Binding(
                            get: { localizationSettings.settings.dateFormatStyle },
                            set: { newStyle in
                                localizationSettings.updateDateFormatStyle(newStyle)
                            }
                        )) {
                            ForEach(DateFormatStyle.allCases, id: \.self) { style in
                                Text(style.displayName)
                                    .tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text(String(localized: "datetime.preview").replacingOccurrences(of: "%@", with: localizationSettings.formatDate(previewDate)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    // Number Format
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "datetime.number_format"))
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker(String(localized: "datetime.number_format"), selection: Binding(
                            get: { localizationSettings.settings.numberFormatStyle },
                            set: { newStyle in
                                var newSettings = localizationSettings.settings
                                newSettings.numberFormatStyle = newStyle
                                localizationSettings.updateSettings(newSettings)
                            }
                        )) {
                            ForEach(NumberFormatStyle.allCases, id: \.self) { style in
                                Text(style.displayName)
                                    .tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text(String(localized: "datetime.preview").replacingOccurrences(of: "%@", with: localizationSettings.formatNumber(previewNumber)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    // Time Format
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "datetime.time_format"))
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker(String(localized: "datetime.time_format"), selection: Binding(
                            get: { localizationSettings.settings.timeFormat },
                            set: { newFormat in
                                var newSettings = localizationSettings.settings
                                newSettings.timeFormat = newFormat
                                localizationSettings.updateSettings(newSettings)
                            }
                        )) {
                            ForEach(TimeFormat.allCases, id: \.self) { format in
                                Text(format.displayName)
                                    .tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text(String(localized: "datetime.affects_time_display"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Measurement System Section
            LanguageSettingsSection(
                title: String(localized: "settings.measurement_system.title"),
                icon: "ruler",
                description: String(localized: "settings.measurement_system.description")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(String(localized: "measurement.system"), selection: Binding(
                        get: { localizationSettings.settings.measurementSystem },
                        set: { newSystem in
                            var newSettings = localizationSettings.settings
                            newSettings.measurementSystem = newSystem
                            localizationSettings.updateSettings(newSettings)
                        }
                    )) {
                        ForEach(MeasurementSystem.allCases, id: \.self) { system in
                            Text(system.displayName)
                                .tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    
                    Text(String(localized: "datetime.affects_file_size"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Accessibility Section
            LanguageSettingsSection(
                title: String(localized: "settings.accessibility.title"),
                icon: "accessibility",
                description: String(localized: "settings.accessibility.description")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(String(localized: "accessibility.enable_features"), isOn: Binding(
                        get: { localizationSettings.settings.accessibilityEnabled },
                        set: { newValue in
                            localizationSettings.updateAccessibilityEnabled(newValue)
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    Text(String(localized: "datetime.improves_accessibility"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Preset Configurations Section
            LanguageSettingsSection(
                title: String(localized: "settings.quick_presets.title"),
                icon: "speedometer",
                description: String(localized: "settings.quick_presets.description")
            ) {
                HStack(spacing: 12) {
                    Button("🇺🇸 US English") {
                        localizationSettings.applyUSEnglishPreset()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("🇯🇵 Japanese") {
                        localizationSettings.applyJapanesePreset()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("🇪🇺 European") {
                        localizationSettings.applyEuropeanPreset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Advanced Options Section
            LanguageSettingsSection(
                title: String(localized: "settings.localization_advanced.title"),
                icon: "gearshape.2",
                description: String(localized: "settings.localization_advanced.description")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "datetime.sort_locale").replacingOccurrences(of: "%@", with: localizationSettings.settings.sortLocale))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(String(localized: "datetime.first_day_of_week").replacingOccurrences(of: "%@", with: String(describing: localizationSettings.settings.firstDayOfWeek)))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(String(localized: "datetime.right_to_left_layout").replacingOccurrences(of: "%@", with: localizationSettings.settings.isRightToLeft ? String(localized: "datetime.yes") : String(localized: "datetime.no")))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                    
                    Button(String(localized: "button.reset_to_defaults")) {
                        localizationSettings.resetToDefaults()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .onAppear {
            // Update preview values periodically
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                previewDate = Date()
            }
        }
        .environment(\.locale, localizationSettings.environmentLocale) // Swift 6 native pattern
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            languageUpdateTrigger += 1
        }
    }
}

/// Reusable settings section component for language settings
private struct LanguageSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let description: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            content()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    LanguageSettingsView(localizationSettings: ModernLocalizationSettingsManager())
        .frame(width: 600, height: 800)
}