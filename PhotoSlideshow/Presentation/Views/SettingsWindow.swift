import SwiftUI
import AppKit

/// Standalone settings window for PhotoSlideshow
public struct SettingsWindow: View {
    @ObservedObject var performanceSettings: PerformanceSettingsManager
    @ObservedObject var slideshowSettings: SlideshowSettingsManager
    @ObservedObject var sortSettings: SortSettingsManager
    @ObservedObject var transitionSettings: TransitionSettingsManager
    
    @State private var selectedTab: SettingsTab = .performance
    
    public init(performanceSettings: PerformanceSettingsManager, slideshowSettings: SlideshowSettingsManager, sortSettings: SortSettingsManager, transitionSettings: TransitionSettingsManager) {
        self.performanceSettings = performanceSettings
        self.slideshowSettings = slideshowSettings
        self.sortSettings = sortSettings
        self.transitionSettings = transitionSettings
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
                    case .slideshow:
                        SlideshowSettingsView(settings: slideshowSettings)
                    case .sorting:
                        SortSettingsView(settings: sortSettings)
                    case .transitions:
                        TransitionSettingsView(settings: transitionSettings)
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
        slideshowSettings.resetToDefault()
        sortSettings.resetToDefault()
        transitionSettings.resetToDefault()
    }
}

/// Settings tabs
private enum SettingsTab: CaseIterable {
    case performance
    case slideshow
    case sorting
    case transitions
    case keyboard
    
    var displayName: String {
        switch self {
        case .performance:
            return "Performance"
        case .slideshow:
            return "Slideshow"
        case .sorting:
            return "Sorting"
        case .transitions:
            return "Transitions"
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

/// Sort settings view
private struct SortSettingsView: View {
    @ObservedObject var settings: SortSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Sorting")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure how photos are ordered in the slideshow. Pre-sorting improves cache efficiency.")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                // Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Button("Alphabetical") { settings.applyPreset(.alphabetical) }
                            .buttonStyle(.bordered)
                        Button("Chronological") { settings.applyPreset(.chronological) }
                            .buttonStyle(.bordered)
                        Button("Newest First") { settings.applyPreset(.newestFirst) }
                            .buttonStyle(.bordered)
                        Button("Largest First") { settings.applyPreset(.largestFirst) }
                            .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Button("Random") { settings.applyPreset(.randomized) }
                            .buttonStyle(.bordered)
                        
                        if settings.settings.order == .random {
                            Button("New Random Order") {
                                settings.regenerateRandomSeed()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                Divider()
                
                // Sort Order
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort By")
                        .fontWeight(.medium)
                    
                    Picker("Sort Order", selection: Binding(
                        get: { settings.settings.order },
                        set: { newOrder in
                            let newSettings = SortSettings(
                                order: newOrder,
                                direction: settings.settings.direction,
                                randomSeed: newOrder == .random ? UInt64.random(in: 0...UInt64.max) : settings.settings.randomSeed
                            )
                            settings.updateSettings(newSettings)
                        }
                    )) {
                        ForEach(SortSettings.SortOrder.allCases, id: \.self) { order in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.displayName)
                                Text(order.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(order)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Sort Direction (not applicable for random)
                if settings.settings.order != .random {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Direction")
                            .fontWeight(.medium)
                        
                        Picker("Sort Direction", selection: Binding(
                            get: { settings.settings.direction },
                            set: { newDirection in
                                let newSettings = SortSettings(
                                    order: settings.settings.order,
                                    direction: newDirection,
                                    randomSeed: settings.settings.randomSeed
                                )
                                settings.updateSettings(newSettings)
                            }
                        )) {
                            ForEach(SortSettings.SortDirection.allCases, id: \.self) { direction in
                                HStack {
                                    Text(direction.symbol)
                                    Text(direction.displayName)
                                }
                                .tag(direction)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Divider()
                
                // Current Settings Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Settings")
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Order:")
                            .foregroundColor(.secondary)
                        Text("\(settings.settings.order.displayName) \(settings.settings.order != .random ? settings.settings.direction.symbol : "")")
                            .fontWeight(.medium)
                    }
                    
                    if settings.settings.order == .random {
                        HStack {
                            Text("Seed:")
                                .foregroundColor(.secondary)
                            Text(String(settings.settings.randomSeed))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Performance Note
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 Performance Tip")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text("Sorting files before slideshow improves image caching efficiency. Random sorting with a fixed seed ensures consistent order across sessions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// Transition settings view
private struct TransitionSettingsView: View {
    @ObservedObject var settings: TransitionSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transition Effects")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure smooth transition effects between photos during slideshow.")
                .foregroundColor(.secondary)
            
            Toggle("Enable Transition Effects", isOn: Binding(
                get: { settings.settings.isEnabled },
                set: { isEnabled in
                    let newSettings = TransitionSettings(
                        effectType: settings.settings.effectType,
                        duration: settings.settings.duration,
                        easing: settings.settings.easing,
                        intensity: settings.settings.intensity,
                        isEnabled: isEnabled
                    )
                    settings.updateSettings(newSettings)
                }
            ))
            .toggleStyle(SwitchToggleStyle())
            
            if settings.settings.isEnabled {
                Text("Effect: \(settings.settings.effectType.displayName)")
                Text("Duration: \(String(format: "%.1f", settings.settings.duration)) seconds")
            }
        }
    }
}

#Preview {
    SettingsWindow(
        performanceSettings: PerformanceSettingsManager(),
        slideshowSettings: SlideshowSettingsManager(),
        sortSettings: SortSettingsManager(),
        transitionSettings: TransitionSettingsManager()
    )
}