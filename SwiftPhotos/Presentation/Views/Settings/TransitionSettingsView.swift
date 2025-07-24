import SwiftUI

/// Transition settings view for configuring smooth transition effects between photos
/// Provides controls for effect type, duration, easing, and intensity
struct TransitionSettingsView: View {
    @ObservedObject var settings: TransitionSettingsManager
    
    private func createTransitionSettings(
        effectType: TransitionSettings.TransitionEffectType? = nil,
        duration: Double? = nil,
        easing: TransitionSettings.EasingFunction? = nil,
        intensity: Double? = nil,
        isEnabled: Bool? = nil
    ) -> TransitionSettings {
        return TransitionSettings(
            effectType: effectType ?? settings.settings.effectType,
            duration: duration ?? settings.settings.duration,
            easing: easing ?? settings.settings.easing,
            intensity: intensity ?? settings.settings.intensity,
            isEnabled: isEnabled ?? settings.settings.isEnabled
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Enable/Disable Section
            TransitionSettingsSection(
                title: "Transition Effects",
                icon: "arrow.triangle.2.circlepath",
                description: "Configure smooth transition effects between photos during slideshow"
            ) {
                Toggle("Enable Transition Effects", isOn: Binding(
                    get: { settings.settings.isEnabled },
                    set: { isEnabled in
                        settings.updateSettings(createTransitionSettings(isEnabled: isEnabled))
                    }
                ))
                .toggleStyle(SwitchToggleStyle())
            }
            
            if settings.settings.isEnabled {
                // Presets Section
                TransitionSettingsSection(
                    title: "Effect Presets",
                    icon: "square.grid.2x2",
                    description: "Quick configurations for different transition styles"
                ) {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button("Simple Fade") { 
                                settings.applyPreset(.simpleFade) 
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Elegant Slide") { 
                                settings.applyPreset(.elegantSlide) 
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Dynamic Zoom") { 
                                settings.applyPreset(.dynamicZoom) 
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Smooth Crossfade") { 
                                settings.applyPreset(.smoothCrossfade) 
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Cinematic Push") { 
                                settings.applyPreset(.cinematicPush) 
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Effect Type Section
                TransitionSettingsSection(
                    title: "Effect Type",
                    icon: "wand.and.stars",
                    description: "Choose the type of transition effect"
                ) {
                    Picker("Effect Type", selection: Binding(
                        get: { settings.settings.effectType },
                        set: { effectType in
                            settings.updateSettings(createTransitionSettings(effectType: effectType))
                        }
                    )) {
                        ForEach(TransitionSettings.TransitionEffectType.allCases, id: \.self) { effectType in
                            HStack {
                                Image(systemName: effectType.icon)
                                Text(effectType.displayName)
                            }
                            .tag(effectType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Timing Settings Section
                TransitionSettingsSection(
                    title: "Timing Settings",
                    icon: "timer",
                    description: "Control transition duration and animation curve"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Duration Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Duration")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(String(format: "%.1f seconds", settings.settings.duration))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { settings.settings.duration },
                                    set: { duration in
                                        settings.updateSettings(createTransitionSettings(duration: duration))
                                    }
                                ),
                                in: 0.1...3.0
                            )
                        }
                        
                        // Easing Function Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Animation Easing")
                                .fontWeight(.medium)
                            
                            Picker("Easing", selection: Binding(
                                get: { settings.settings.easing },
                                set: { easing in
                                    settings.updateSettings(createTransitionSettings(easing: easing))
                                }
                            )) {
                                ForEach(TransitionSettings.EasingFunction.allCases, id: \.self) { easing in
                                    Text(easing.displayName)
                                        .tag(easing)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
                
                // Effect Intensity Section
                TransitionSettingsSection(
                    title: "Effect Intensity",
                    icon: "dial.high",
                    description: "Adjust the strength of the transition effect"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Effect Intensity")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.0f%%", settings.settings.intensity * 100))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.intensity },
                                set: { intensity in
                                    settings.updateSettings(createTransitionSettings(intensity: intensity))
                                }
                            ),
                            in: 0.0...1.0
                        )
                    }
                }
                
                // Current Settings Summary Section
                TransitionSettingsSection(
                    title: "Current Settings",
                    icon: "info.circle",
                    description: "Summary of your current transition configuration"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: settings.settings.effectType.icon)
                                .foregroundColor(.blue)
                            Text("Effect: \(settings.settings.effectType.displayName)")
                        }
                        .font(.caption)
                        
                        Text("Duration: \(String(format: "%.1f", settings.settings.duration)) seconds")
                            .font(.caption)
                        
                        Text("Easing: \(settings.settings.easing.displayName)")
                            .font(.caption)
                        
                        Text("Intensity: \(String(format: "%.0f", settings.settings.intensity * 100))%")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Performance Information Section
                TransitionSettingsSection(
                    title: "Performance Information",
                    icon: "speedometer",
                    description: "How transition settings affect performance"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("💡")
                            Text("Performance Tip")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        Text("Smooth transitions enhance user experience. Lower intensity and shorter duration improve performance on slower systems.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if settings.settings.effectType == .fade || settings.settings.effectType == .crossfade {
                            Text("• Fade effects are most performance-friendly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if settings.settings.effectType == .zoomIn || settings.settings.effectType == .zoomOut {
                            Text("• Zoom effects may impact performance on large images")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if settings.settings.effectType == .pushLeft || settings.settings.effectType == .pushRight {
                            Text("• Push effects provide smooth directional transitions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}

/// Reusable settings section component for transition settings
private struct TransitionSettingsSection<Content: View>: View {
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
    TransitionSettingsView(settings: TransitionSettingsManager())
        .frame(width: 500, height: 600)
}