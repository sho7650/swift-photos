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
                        Text(formatDuration(settings.settings.slideDuration))
                            .foregroundColor(.secondary)
                    }
                    
                    CustomDurationSlider(
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
                        )
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

/// Custom slider with variable step increments for duration
private struct CustomDurationSlider: View {
    @Binding var value: Double
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(height: 4)
                
                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: sliderPosition(in: geometry.size.width), height: 4)
                
                // Thumb
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 1)
                    .offset(x: sliderPosition(in: geometry.size.width) - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                updateValue(from: value.location.x, width: geometry.size.width)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .onTapGesture { location in
                updateValue(from: location.x, width: geometry.size.width)
            }
        }
        .frame(height: 16)
    }
    
    private func sliderPosition(in width: CGFloat) -> CGFloat {
        let normalizedValue = normalizeValue(value)
        return normalizedValue * width
    }
    
    private func updateValue(from x: CGFloat, width: CGFloat) {
        let normalizedX = max(0, min(1, x / width))
        value = denormalizeValue(normalizedX)
    }
    
    // Convert seconds to normalized 0-1 value
    private func normalizeValue(_ seconds: Double) -> Double {
        if seconds <= 15 {
            // 1-15 seconds: 0-0.2 range
            return (seconds - 1) / 14 * 0.2
        } else if seconds <= 30 {
            // 15-30 seconds: 0.2-0.3 range
            return 0.2 + (seconds - 15) / 15 * 0.1
        } else if seconds <= 60 {
            // 30-60 seconds: 0.3-0.4 range
            return 0.3 + (seconds - 30) / 30 * 0.1
        } else if seconds <= 180 {
            // 60-180 seconds (3 min): 0.4-0.6 range
            return 0.4 + (seconds - 60) / 120 * 0.2
        } else if seconds <= 600 {
            // 180-600 seconds (10 min): 0.6-0.8 range
            return 0.6 + (seconds - 180) / 420 * 0.2
        } else {
            // 600-1800 seconds (30 min): 0.8-1.0 range
            return 0.8 + (seconds - 600) / 1200 * 0.2
        }
    }
    
    // Convert normalized 0-1 value to seconds with stepping
    private func denormalizeValue(_ normalized: Double) -> Double {
        var seconds: Double
        
        if normalized <= 0.2 {
            // 1-15 seconds, 0.5 second steps
            seconds = 1 + (normalized / 0.2) * 14
            seconds = round(seconds * 2) / 2  // Round to nearest 0.5
        } else if normalized <= 0.3 {
            // 15-30 seconds, 5 second steps
            seconds = 15 + ((normalized - 0.2) / 0.1) * 15
            seconds = round(seconds / 5) * 5  // Round to nearest 5
        } else if normalized <= 0.4 {
            // 30-60 seconds, 10 second steps
            seconds = 30 + ((normalized - 0.3) / 0.1) * 30
            seconds = round(seconds / 10) * 10  // Round to nearest 10
        } else if normalized <= 0.6 {
            // 60-180 seconds, 30 second steps
            seconds = 60 + ((normalized - 0.4) / 0.2) * 120
            seconds = round(seconds / 30) * 30  // Round to nearest 30
        } else if normalized <= 0.8 {
            // 180-600 seconds, 60 second steps
            seconds = 180 + ((normalized - 0.6) / 0.2) * 420
            seconds = round(seconds / 60) * 60  // Round to nearest 60
        } else {
            // 600-1800 seconds, 300 second steps (5 min)
            seconds = 600 + ((normalized - 0.8) / 0.2) * 1200
            seconds = round(seconds / 300) * 300  // Round to nearest 300
        }
        
        return max(1, min(1800, seconds))
    }
}

// Format duration for display
private func formatDuration(_ seconds: Double) -> String {
    if seconds < 60 {
        return String(format: "%.1f seconds", seconds)
    } else if seconds < 3600 {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        if remainingSeconds == 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    } else {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

#Preview {
    SlideshowSettingsView(settings: ModernSlideshowSettingsManager())
        .frame(width: 500, height: 600)
}