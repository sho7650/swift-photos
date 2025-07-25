import SwiftUI

/// Slideshow settings view for configuring automatic slideshow behavior and timing
/// Provides controls for slideshow duration, auto-start, ordering, and other playback options
struct SlideshowSettingsView: View {
    var settings: ModernSlideshowSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Slideshow Presets Section
            SlideshowSettingsSection(
                title: "Slideshow Presets",
                icon: "play.circle",
                description: "Quick configurations for common slideshow scenarios"
            ) {
                HStack(spacing: 12) {
                    Button("Default") { settings.updateSettings(.default) }
                        .buttonStyle(.bordered)
                    Button("Quick") { settings.updateSettings(.quick) }
                        .buttonStyle(.bordered)
                    Button("Slow") { settings.updateSettings(.slow) }
                        .buttonStyle(.bordered)
                    Button("Random") { settings.updateSettings(.random) }
                        .buttonStyle(.bordered)
                }
            }
            
            // Timing Settings Section
            SlideshowSettingsSection(
                title: "Timing Settings",
                icon: "timer",
                description: "Configure how long each photo is displayed"
            ) {
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
            }
            
            // Playback Behavior Section
            SlideshowSettingsSection(
                title: "Playback Behavior",
                icon: "gearshape",
                description: "Control how slideshows start and play"
            ) {
                VStack(alignment: .leading, spacing: 16) {
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
                    .toggleStyle(.switch)
                    
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
                    .toggleStyle(.switch)
                    
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
                    .toggleStyle(.switch)
                }
            }
            
            // Keyboard Controls Section
            SlideshowSettingsSection(
                title: "Keyboard Controls",
                icon: "keyboard",
                description: "Available keyboard shortcuts during slideshow"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "Space", description: "Play/Pause slideshow")
                    ShortcutRow(key: "→ ↓", description: "Next photo")
                    ShortcutRow(key: "← ↑", description: "Previous photo")
                    ShortcutRow(key: "Esc", description: "Stop slideshow")
                    ShortcutRow(key: "I", description: "Toggle detailed info")
                    ShortcutRow(key: "H", description: "Toggle controls visibility")
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}

/// Reusable settings section component for slideshow settings
private struct SlideshowSettingsSection<Content: View>: View {
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

/// Helper view for keyboard shortcut display
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
        .font(.caption)
    }
}

#Preview {
    SlideshowSettingsView(settings: ModernSlideshowSettingsManager())
        .frame(width: 500, height: 600)
}