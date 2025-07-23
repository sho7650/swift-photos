import SwiftUI
import AppKit

/// Standalone settings window for PhotoSlideshow
public struct SettingsWindow: View {
    @ObservedObject var performanceSettings: PerformanceSettingsManager
    @ObservedObject var blurSettings: BlurSettingsManager
    @ObservedObject var slideshowSettings: SlideshowSettingsManager
    
    @State private var selectedTab: SettingsTab = .performance
    
    public init(performanceSettings: PerformanceSettingsManager, blurSettings: BlurSettingsManager, slideshowSettings: SlideshowSettingsManager) {
        self.performanceSettings = performanceSettings
        self.blurSettings = blurSettings
        self.slideshowSettings = slideshowSettings
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.displayName)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == tab ? Color.accentColor : Color.clear)
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .bottom)
            
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .performance:
                        PerformanceSettingsView(settings: performanceSettings)
                    case .blur:
                        BlurSettingsView(settings: blurSettings)
                    case .slideshow:
                        SlideshowSettingsView(settings: slideshowSettings)
                    case .keyboard:
                        KeyboardShortcutsView()
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom buttons
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                
                Spacer()
                
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .top)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func resetToDefaults() {
        performanceSettings.resetToDefault()
        blurSettings.resetToDefault()
        slideshowSettings.resetToDefault()
    }
}

/// Settings tabs
private enum SettingsTab: CaseIterable {
    case performance
    case blur
    case slideshow
    case keyboard
    
    var displayName: String {
        switch self {
        case .performance:
            return "Performance"
        case .blur:
            return "Visual Effects"
        case .slideshow:
            return "Slideshow"
        case .keyboard:
            return "Keyboard"
        }
    }
}

/// Slideshow settings view
private struct SlideshowSettingsView: View {
    @ObservedObject var settings: SlideshowSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Slideshow Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure automatic slideshow behavior and timing.")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                // Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Button("Default") { settings.applyPreset(.default) }
                            .buttonStyle(.bordered)
                        Button("Quick") { settings.applyPreset(.quick) }
                            .buttonStyle(.bordered)
                        Button("Slow") { settings.applyPreset(.slow) }
                            .buttonStyle(.bordered)
                        Button("Random") { settings.applyPreset(.random) }
                            .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // Slideshow interval
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Slide Duration")
                        Spacer()
                        Text(String(format: "%.1f seconds", settings.settings.slideDuration))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.settings.slideDuration },
                            set: { newValue in
                                let newSettings = SlideshowSettings(
                                    slideDuration: newValue,
                                    autoStart: settings.settings.autoStart,
                                    randomOrder: settings.settings.randomOrder,
                                    loopSlideshow: settings.settings.loopSlideshow
                                )
                                settings.updateSettings(newSettings)
                            }
                        ),
                        in: 1.0...30.0
                    )
                }
                
                Divider()
                
                // Auto start
                Toggle("Auto-start slideshow when folder is selected", isOn: Binding(
                    get: { settings.settings.autoStart },
                    set: { newValue in
                        let newSettings = SlideshowSettings(
                            slideDuration: settings.settings.slideDuration,
                            autoStart: newValue,
                            randomOrder: settings.settings.randomOrder,
                            loopSlideshow: settings.settings.loopSlideshow
                        )
                        settings.updateSettings(newSettings)
                    }
                ))
                
                // Random order
                Toggle("Random order", isOn: Binding(
                    get: { settings.settings.randomOrder },
                    set: { newValue in
                        let newSettings = SlideshowSettings(
                            slideDuration: settings.settings.slideDuration,
                            autoStart: settings.settings.autoStart,
                            randomOrder: newValue,
                            loopSlideshow: settings.settings.loopSlideshow
                        )
                        settings.updateSettings(newSettings)
                    }
                ))
                
                // Loop slideshow
                Toggle("Loop slideshow", isOn: Binding(
                    get: { settings.settings.loopSlideshow },
                    set: { newValue in
                        let newSettings = SlideshowSettings(
                            slideDuration: settings.settings.slideDuration,
                            autoStart: settings.settings.autoStart,
                            randomOrder: settings.settings.randomOrder,
                            loopSlideshow: newValue
                        )
                        settings.updateSettings(newSettings)
                    }
                ))
                
                Divider()
                
                Text("Slideshow Controls")
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Space: Play/Pause slideshow")
                    Text("• → ↓: Next photo")
                    Text("• ← ↑: Previous photo")
                    Text("• Esc: Stop slideshow")
                }
                .foregroundColor(.secondary)
                .font(.caption)
            }
        }
    }
}

/// Performance settings view
private struct PerformanceSettingsView: View {
    @ObservedObject var settings: PerformanceSettingsManager
    @State private var selectedPreset: String = "Custom"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Optimize slideshow performance for different collection sizes and system capabilities.")
                .foregroundColor(.secondary)
            
            // Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .fontWeight(.medium)
                
                VStack(spacing: 4) {
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
            
            Divider()
            
            // Manual settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Manual Configuration")
                    .fontWeight(.medium)
                
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
    }
}

/// Blur settings view
private struct BlurSettingsView: View {
    @ObservedObject var settings: BlurSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Effects")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure background blur effects for a more immersive viewing experience.")
                .foregroundColor(.secondary)
            
            // Enable/Disable
            Toggle("Enable Background Blur", isOn: Binding(
                get: { settings.settings.isEnabled },
                set: { newValue in
                    let newSettings = BlurSettings(
                        isEnabled: newValue,
                        intensity: settings.settings.intensity,
                        style: settings.settings.style,
                        backgroundOpacity: settings.settings.backgroundOpacity
                    )
                    settings.updateSettings(newSettings)
                }
            ))
            
            if settings.settings.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presets")
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            Button("Subtle") { settings.applyPreset(.subtle) }
                                .buttonStyle(.bordered)
                            Button("Medium") { settings.applyPreset(.medium) }
                                .buttonStyle(.bordered)
                            Button("Strong") { settings.applyPreset(.strong) }
                                .buttonStyle(.bordered)
                        }
                    }
                    
                    Divider()
                    
                    // Manual controls
                    SettingSlider(
                        title: "Blur Intensity",
                        value: Binding(
                            get: { settings.settings.intensity },
                            set: { newValue in
                                let newSettings = BlurSettings(
                                    isEnabled: settings.settings.isEnabled,
                                    intensity: newValue,
                                    style: settings.settings.style,
                                    backgroundOpacity: settings.settings.backgroundOpacity
                                )
                                settings.updateSettings(newSettings)
                            }
                        ),
                        range: 0.0...1.0,
                        format: "%.1f"
                    )
                    
                    SettingSlider(
                        title: "Background Opacity",
                        value: Binding(
                            get: { settings.settings.backgroundOpacity },
                            set: { newValue in
                                let newSettings = BlurSettings(
                                    isEnabled: settings.settings.isEnabled,
                                    intensity: settings.settings.intensity,
                                    style: settings.settings.style,
                                    backgroundOpacity: newValue
                                )
                                settings.updateSettings(newSettings)
                            }
                        ),
                        range: 0.0...1.0,
                        format: "%.1f"
                    )
                    
                    // Blur style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Blur Style")
                            .fontWeight(.medium)
                        
                        Picker("Blur Style", selection: Binding(
                            get: { settings.settings.style },
                            set: { newValue in
                                let newSettings = BlurSettings(
                                    isEnabled: settings.settings.isEnabled,
                                    intensity: settings.settings.intensity,
                                    style: newValue,
                                    backgroundOpacity: settings.settings.backgroundOpacity
                                )
                                settings.updateSettings(newSettings)
                            }
                        )) {
                            ForEach(BlurSettings.BlurStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }
        }
    }
}

/// Keyboard shortcuts view
private struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Control your slideshow using these keyboard shortcuts.")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRow(key: "Space", description: "Play/Pause slideshow")
                ShortcutRow(key: "→ ↓", description: "Next photo")
                ShortcutRow(key: "← ↑", description: "Previous photo")
                ShortcutRow(key: "Esc", description: "Stop slideshow")
                
                Divider()
                
                Text("Blur Controls")
                    .fontWeight(.medium)
                ShortcutRow(key: "B", description: "Toggle background blur")
                ShortcutRow(key: "+", description: "Increase blur intensity")
                ShortcutRow(key: "-", description: "Decrease blur intensity")
                
                Divider()
                
                Text("Settings")
                    .fontWeight(.medium)
                ShortcutRow(key: "⌘,", description: "Open settings (this window)")
            }
        }
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

private struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
                .frame(minWidth: 60)
            
            Text(description)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsWindow(
        performanceSettings: PerformanceSettingsManager(),
        blurSettings: BlurSettingsManager(),
        slideshowSettings: SlideshowSettingsManager()
    )
}