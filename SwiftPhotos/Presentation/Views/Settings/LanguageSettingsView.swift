import SwiftUI

/// Language and localization settings view for configuring multi-language support
/// Integrates with ModernLocalizationSettingsManager for comprehensive language preferences
struct LanguageSettingsView: View {
    var localizationSettings: ModernLocalizationSettingsManager
    
    @State private var previewDate = Date()
    @State private var previewNumber = 1234.56
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Language Selection Section
            LanguageSettingsSection(
                title: String(localized: "settings.language.title"),
                icon: "globe",
                description: "Choose your preferred language for the application interface"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Primary Language Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Application Language")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Picker("Language", selection: Binding(
                            get: { localizationSettings.settings.language },
                            set: { newLanguage in
                                localizationSettings.updateLanguage(newLanguage)
                            }
                        )) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                                Text(language.displayName)
                                    .tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Text("Changes take effect immediately")
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
                title: "Regional Formatting",
                icon: "textformat.123",
                description: "Configure how dates, numbers, and times are displayed"
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
                title: "Measurement System",
                icon: "ruler",
                description: "Choose between metric and imperial units"
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
                title: "Accessibility",
                icon: "accessibility",
                description: "Language-specific accessibility options"
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
                title: "Quick Presets",
                icon: "speedometer",
                description: "Apply optimized settings for specific regions"
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
                title: "Advanced",
                icon: "gearshape.2",
                description: "Advanced localization configuration"
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