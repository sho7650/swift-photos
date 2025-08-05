import SwiftUI

/// Transition settings view for configuring smooth transition effects between photos
/// Provides controls for effect type, duration, easing, and intensity
struct TransitionSettingsView: View {
    var settings: ModernTransitionSettingsManager
    
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
            SettingsComponentFactory.createSection(
                title: String(localized: "transitions.effects"),
                icon: "arrow.triangle.2.circlepath",
                description: "Configure smooth transition effects between photos during slideshow"
            ) {
                Toggle("Enable Transition Effects", isOn: Binding(
                    get: { settings.settings.isEnabled },
                    set: { isEnabled in
                        settings.updateSettings(createTransitionSettings(isEnabled: isEnabled))
                    }
                ))
                .toggleStyle(.switch)
            }
            
            if settings.settings.isEnabled {
                // Presets Section
                SettingsComponentFactory.createSection(
                    title: String(localized: "transitions.presets"),
                    icon: "square.grid.2x2",
                    description: "Quick configurations for different transition styles"
                ) {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button(L10n.Transitions.simpleFade) { 
                                settings.updateSettings(.simpleFade) 
                            }
                            .buttonStyle(.bordered)
                            
                            Button(L10n.Transitions.elegantSlide) { 
                                settings.updateSettings(.elegantSlide) 
                            }
                            .buttonStyle(.bordered)
                            
                            Button(L10n.Transitions.dynamicZoom) { 
                                settings.updateSettings(.dynamicZoom) 
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 12) {
                            Button(L10n.Transitions.smoothCrossfade) { 
                                settings.updateSettings(.smoothCrossfade) 
                            }
                            .buttonStyle(.bordered)
                            
                            Button(L10n.Transitions.cinematicPush) { 
                                settings.updateSettings(.cinematicPush) 
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Effect Type Section
                SettingsComponentFactory.createSection(
                    title: String(localized: "transitions.effect_type"),
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
                    .pickerStyle(.menu)
                }
                
                // Timing Settings Section
                SettingsComponentFactory.createSection(
                    title: String(localized: "transitions.timing_settings"),
                    icon: "timer",
                    description: "Control transition duration and animation curve"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Duration Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L10n.Transitions.duration)
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
                            Text(L10n.Transitions.animationEasing)
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
                            .pickerStyle(.segmented)
                        }
                    }
                }
                
                // Effect Intensity Section
                SettingsComponentFactory.createSection(
                    title: String(localized: "transitions.effect_intensity"),
                    icon: "dial.high",
                    description: "Adjust the strength of the transition effect"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L10n.Transitions.effectIntensity)
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
                SettingsComponentFactory.createSection(
                    title: String(localized: "transitions.current_settings"),
                    icon: "info.circle",
                    description: "Summary of your current transition configuration"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: settings.settings.effectType.icon)
                                .foregroundColor(.blue)
                            Text(String(localized: "transitions.effect_label").replacingOccurrences(of: "%@", with: settings.settings.effectType.displayName))
                        }
                        .font(.caption)
                        
                        Text(String(localized: "transitions.duration_label").replacingOccurrences(of: "%@", with: String(format: "%.1f", settings.settings.duration)))
                            .font(.caption)
                        
                        Text(String(localized: "transitions.easing_label").replacingOccurrences(of: "%@", with: settings.settings.easing.displayName))
                            .font(.caption)
                        
                        Text(String(localized: "transitions.intensity_label").replacingOccurrences(of: "%@", with: String(format: "%.0f", settings.settings.intensity * 100)))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Performance Information Section
                SettingsComponentFactory.createSection(
                    title: String(localized: "transitions.performance_information"),
                    icon: "speedometer",
                    description: "How transition settings affect performance"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("💡")
                            Text(L10n.Transitions.performanceTip)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        Text(L10n.Transitions.performanceTipDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if settings.settings.effectType == .fade || settings.settings.effectType == .crossfade {
                            Text(L10n.Transitions.fadeEffectTip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if settings.settings.effectType == .zoomIn || settings.settings.effectType == .zoomOut {
                            Text(L10n.Transitions.zoomEffectTip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if settings.settings.effectType == .pushLeft || settings.settings.effectType == .pushRight {
                            Text(L10n.Transitions.pushEffectTip)
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



#Preview {
    TransitionSettingsView(settings: ModernTransitionSettingsManager())
        .frame(width: 500, height: 600)
}