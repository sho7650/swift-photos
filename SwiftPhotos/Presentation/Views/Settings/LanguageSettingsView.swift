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
                        Text(L10n.Settings.applicationLanguage)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Language", selection: Binding(
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
                        
                        Text(L10n.Settings.changesImmediate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Region Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Region")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Region", selection: Binding(
                            get: { localizationSettings.settings.region },
                            set: { newRegion in
                                localizationSettings.updateRegion(newRegion)
                            }
                        )) {
                            Text("United States").tag("US")
                            Text("Japan").tag("JP")
                            Text("United Kingdom").tag("GB")
                            Text("Germany").tag("DE")
                            Text("France").tag("FR")
                            Text("Spain").tag("ES")
                            Text("China").tag("CN")
                            Text("Korea").tag("KR")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text("Affects number and date formatting")
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
                        Text("Date Format")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Date Format", selection: Binding(
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
                        
                        Text("Preview: \(localizationSettings.formatDate(previewDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    // Number Format
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number Format")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Number Format", selection: Binding(
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
                        
                        Text("Preview: \(localizationSettings.formatNumber(previewNumber))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    // Time Format
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Format")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Time Format", selection: Binding(
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
                        
                        Text("Affects time display in photo metadata")
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
                    Picker("Measurement System", selection: Binding(
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
                    
                    Text("Affects file size and dimension displays")
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
                    Toggle("Enable accessibility features for localization", isOn: Binding(
                        get: { localizationSettings.settings.accessibilityEnabled },
                        set: { newValue in
                            localizationSettings.updateAccessibilityEnabled(newValue)
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    Text("Improves screen reader support and keyboard navigation")
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
                        Text("Sort Locale: \(localizationSettings.settings.sortLocale)")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("First Day of Week: \(WeekdayHelper.displayName(for: localizationSettings.settings.firstDayOfWeek))")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Right-to-Left Layout: \(localizationSettings.settings.isRightToLeft ? "Yes" : "No")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                    
                    Button("Reset to Defaults") {
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