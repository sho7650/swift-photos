import SwiftUI

/// Performance settings view for slideshow optimization and memory management
/// Provides controls for adjusting performance parameters for different collection sizes
struct PerformanceSettingsView: View {
    @ObservedObject var settings: PerformanceSettingsManager
    @State private var selectedPreset: String = "Custom"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Performance Presets Section
            PerformanceSettingsSection(
                title: "Performance Presets",
                icon: "gauge.high",
                description: "Optimize slideshow performance for different collection sizes and system capabilities"
            ) {
                VStack(spacing: 8) {
                    PresetButton(title: "Default (0-100 images)", preset: .default, current: settings.settings) {
                        settings.applyPreset(.default)
                        selectedPreset = "Default"
                    }
                    
                    PresetButton(title: "High Performance (101-1,000 images)", preset: .highPerformance, current: settings.settings) {
                        settings.applyPreset(.highPerformance)
                        selectedPreset = "High Performance"
                    }
                    
                    PresetButton(title: "Unlimited (1,001-10,000 images)", preset: .unlimited, current: settings.settings) {
                        settings.applyPreset(.unlimited)
                        selectedPreset = "Unlimited"
                    }
                    
                    PresetButton(title: "Massive (10,001-50,000 images)", preset: .massive, current: settings.settings) {
                        settings.applyPreset(.massive)
                        selectedPreset = "Massive"
                    }
                    
                    PresetButton(title: "Extreme (50,001+ images)", preset: .extreme, current: settings.settings) {
                        settings.applyPreset(.extreme)
                        selectedPreset = "Extreme"
                    }
                }
            }
            
            // Manual Configuration Section
            PerformanceSettingsSection(
                title: "Manual Configuration",
                icon: "slider.horizontal.3",
                description: "Fine-tune performance settings for your specific needs"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    SettingSlider(
                        title: "Memory Window Size",
                        value: Binding(
                            get: { Double(settings.settings.memoryWindowSize) },
                            set: { newValue in
                                let newSettings = PerformanceSettings(
                                    memoryWindowSize: Int(newValue),
                                    maxMemoryUsageMB: settings.settings.maxMemoryUsageMB,
                                    maxConcurrentLoads: settings.settings.maxConcurrentLoads,
                                    largeCollectionThreshold: settings.settings.largeCollectionThreshold,
                                    aggressiveMemoryManagement: settings.settings.aggressiveMemoryManagement,
                                    preloadDistance: settings.settings.preloadDistance
                                )
                                settings.updateSettings(newSettings)
                                selectedPreset = "Custom"
                            }
                        ),
                        range: 10...5000,
                        format: "%.0f images"
                    )
                    
                    SettingSlider(
                        title: "Max Memory Usage",
                        value: Binding(
                            get: { Double(settings.settings.maxMemoryUsageMB) },
                            set: { newValue in
                                let newSettings = PerformanceSettings(
                                    memoryWindowSize: settings.settings.memoryWindowSize,
                                    maxMemoryUsageMB: Int(newValue),
                                    maxConcurrentLoads: settings.settings.maxConcurrentLoads,
                                    largeCollectionThreshold: settings.settings.largeCollectionThreshold,
                                    aggressiveMemoryManagement: settings.settings.aggressiveMemoryManagement,
                                    preloadDistance: settings.settings.preloadDistance
                                )
                                settings.updateSettings(newSettings)
                                selectedPreset = "Custom"
                            }
                        ),
                        range: 500...32000,
                        format: "%.0f MB"
                    )
                    
                    SettingSlider(
                        title: "Concurrent Loads",
                        value: Binding(
                            get: { Double(settings.settings.maxConcurrentLoads) },
                            set: { newValue in
                                let newSettings = PerformanceSettings(
                                    memoryWindowSize: settings.settings.memoryWindowSize,
                                    maxMemoryUsageMB: settings.settings.maxMemoryUsageMB,
                                    maxConcurrentLoads: Int(newValue),
                                    largeCollectionThreshold: settings.settings.largeCollectionThreshold,
                                    aggressiveMemoryManagement: settings.settings.aggressiveMemoryManagement,
                                    preloadDistance: settings.settings.preloadDistance
                                )
                                settings.updateSettings(newSettings)
                                selectedPreset = "Custom"
                            }
                        ),
                        range: 1...50,
                        format: "%.0f"
                    )
                }
            }
            
            // Advanced Settings Section
            PerformanceSettingsSection(
                title: "Advanced Settings",
                icon: "gear.circle",
                description: "Additional performance and memory management options"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Aggressive Memory Management", isOn: Binding(
                        get: { settings.settings.aggressiveMemoryManagement },
                        set: { newValue in
                            let newSettings = PerformanceSettings(
                                memoryWindowSize: settings.settings.memoryWindowSize,
                                maxMemoryUsageMB: settings.settings.maxMemoryUsageMB,
                                maxConcurrentLoads: settings.settings.maxConcurrentLoads,
                                largeCollectionThreshold: settings.settings.largeCollectionThreshold,
                                aggressiveMemoryManagement: newValue,
                                preloadDistance: settings.settings.preloadDistance
                            )
                            settings.updateSettings(newSettings)
                            selectedPreset = "Custom"
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    
                    SettingSlider(
                        title: "Large Collection Threshold",
                        value: Binding(
                            get: { Double(settings.settings.largeCollectionThreshold) },
                            set: { newValue in
                                let newSettings = PerformanceSettings(
                                    memoryWindowSize: settings.settings.memoryWindowSize,
                                    maxMemoryUsageMB: settings.settings.maxMemoryUsageMB,
                                    maxConcurrentLoads: settings.settings.maxConcurrentLoads,
                                    largeCollectionThreshold: Int(newValue),
                                    aggressiveMemoryManagement: settings.settings.aggressiveMemoryManagement,
                                    preloadDistance: settings.settings.preloadDistance
                                )
                                settings.updateSettings(newSettings)
                                selectedPreset = "Custom"
                            }
                        ),
                        range: 100...10000,
                        format: "%.0f images"
                    )
                    
                    SettingSlider(
                        title: "Preload Distance",
                        value: Binding(
                            get: { Double(settings.settings.preloadDistance) },
                            set: { newValue in
                                let newSettings = PerformanceSettings(
                                    memoryWindowSize: settings.settings.memoryWindowSize,
                                    maxMemoryUsageMB: settings.settings.maxMemoryUsageMB,
                                    maxConcurrentLoads: settings.settings.maxConcurrentLoads,
                                    largeCollectionThreshold: settings.settings.largeCollectionThreshold,
                                    aggressiveMemoryManagement: settings.settings.aggressiveMemoryManagement,
                                    preloadDistance: Int(newValue)
                                )
                                settings.updateSettings(newSettings)
                                selectedPreset = "Custom"
                            }
                        ),
                        range: 1...20,
                        format: "%.0f images"
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}

/// Reusable settings section component for performance settings
private struct PerformanceSettingsSection<Content: View>: View {
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

/// Helper views
private struct PresetButton: View {
    let title: String
    let preset: PerformanceSettings
    let current: PerformanceSettings
    let action: () -> Void
    
    private var isSelected: Bool {
        preset == current
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
        }
    }
}

#Preview {
    PerformanceSettingsView(settings: PerformanceSettingsManager())
        .frame(width: 500, height: 600)
}