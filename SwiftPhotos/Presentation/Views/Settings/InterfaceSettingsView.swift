import SwiftUI

/// Interface settings view for UI controls and interaction behavior
/// Integrates with the sidebar-based settings window design
struct InterfaceSettingsView: View {
    var settings: ModernUIControlSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Auto-hide Settings Section
            SettingsSectionView(
                title: L10n.SettingsString.autoHide(),
                icon: "eye.slash",
                description: L10n.SettingsString.autoHideDescription()
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // General auto-hide delay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("General Auto-hide Delay")
                            Spacer()
                            Text(String(format: "%.1f seconds", settings.settings.autoHideDelay))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.autoHideDelay },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: newValue,
                                        playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                        pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                        fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                        backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                        backgroundOpacity: settings.settings.backgroundOpacity,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: settings.settings.bottomOffset
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 1.0...15.0
                        )
                    }
                    
                    // Playing auto-hide delay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("During Slideshow")
                            Spacer()
                            Text(String(format: "%.1f seconds", settings.settings.playingAutoHideDelay))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.playingAutoHideDelay },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: settings.settings.autoHideDelay,
                                        playingAutoHideDelay: newValue,
                                        pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                        fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                        backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                        backgroundOpacity: settings.settings.backgroundOpacity,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: settings.settings.bottomOffset
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 0.5...10.0
                        )
                    }
                    
                    // Paused auto-hide delay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("When Paused")
                            Spacer()
                            Text(String(format: "%.1f seconds", settings.settings.pausedAutoHideDelay))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.pausedAutoHideDelay },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: settings.settings.autoHideDelay,
                                        playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                        pausedAutoHideDelay: newValue,
                                        fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                        backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                        backgroundOpacity: settings.settings.backgroundOpacity,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: settings.settings.bottomOffset
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 2.0...30.0
                        )
                    }
                    
                    // Hide on play toggle
                    Toggle(L10n.ToggleString.hideControlsCompletely(), isOn: Binding(
                        get: { settings.settings.hideOnPlay },
                        set: { newValue in
                            let newSettings = UIControlSettings(
                                autoHideDelay: settings.settings.autoHideDelay,
                                playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                backgroundOpacity: settings.settings.backgroundOpacity,
                                showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                hideOnPlay: newValue,
                                minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                showOnMouseMovement: settings.settings.showOnMouseMovement,
                                mouseSensitivity: settings.settings.mouseSensitivity,
                                bottomOffset: settings.settings.bottomOffset
                            )
                            settings.updateSettings(newSettings)
                        }
                    ))
                    .toggleStyle(.switch)
                }
            }
            
            // Mouse Interaction Section
            SettingsSectionView(
                title: L10n.SettingsString.mouseInteraction(),
                icon: "cursorarrow",
                description: L10n.SettingsString.mouseInteractionDescription()
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(L10n.ToggleString.showControlsOnMouseMovement(), isOn: Binding(
                        get: { settings.settings.showOnMouseMovement },
                        set: { newValue in
                            let newSettings = UIControlSettings(
                                autoHideDelay: settings.settings.autoHideDelay,
                                playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                backgroundOpacity: settings.settings.backgroundOpacity,
                                showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                hideOnPlay: settings.settings.hideOnPlay,
                                minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                showOnMouseMovement: newValue,
                                mouseSensitivity: settings.settings.mouseSensitivity,
                                bottomOffset: settings.settings.bottomOffset
                            )
                            settings.updateSettings(newSettings)
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    if settings.settings.showOnMouseMovement {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Mouse Sensitivity")
                                Spacer()
                                Text(String(format: "%.0f pixels", settings.settings.mouseSensitivity))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { settings.settings.mouseSensitivity },
                                    set: { newValue in
                                        let newSettings = UIControlSettings(
                                            autoHideDelay: settings.settings.autoHideDelay,
                                            playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                            pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                            fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                            backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                            backgroundOpacity: settings.settings.backgroundOpacity,
                                            showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                            hideOnPlay: settings.settings.hideOnPlay,
                                            minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                            showOnMouseMovement: settings.settings.showOnMouseMovement,
                                            mouseSensitivity: newValue,
                                            bottomOffset: settings.settings.bottomOffset
                                        )
                                        settings.updateSettings(newSettings)
                                    }
                                ),
                                in: 1.0...50.0
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Minimum Visibility Duration")
                                Spacer()
                                Text(String(format: "%.1f seconds", settings.settings.minimumVisibilityDuration))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { settings.settings.minimumVisibilityDuration },
                                    set: { newValue in
                                        let newSettings = UIControlSettings(
                                            autoHideDelay: settings.settings.autoHideDelay,
                                            playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                            pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                            fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                            backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                            backgroundOpacity: settings.settings.backgroundOpacity,
                                            showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                            hideOnPlay: settings.settings.hideOnPlay,
                                            minimumVisibilityDuration: newValue,
                                            showOnMouseMovement: settings.settings.showOnMouseMovement,
                                            mouseSensitivity: settings.settings.mouseSensitivity,
                                            bottomOffset: settings.settings.bottomOffset
                                        )
                                        settings.updateSettings(newSettings)
                                    }
                                ),
                                in: 0.1...5.0
                            )
                        }
                    }
                }
            }
            
            // Appearance Section
            SettingsSectionView(
                title: L10n.SettingsString.appearance(),
                icon: "paintbrush",
                description: L10n.SettingsString.appearanceDescription()
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Background blur intensity
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Background Blur Intensity")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.settings.backgroundBlurIntensity * 100))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.backgroundBlurIntensity },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: settings.settings.autoHideDelay,
                                        playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                        pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                        fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                        backgroundBlurIntensity: newValue,
                                        backgroundOpacity: settings.settings.backgroundOpacity,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: settings.settings.bottomOffset
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 0.0...1.0
                        )
                    }
                    
                    // Background opacity
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Background Opacity")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.settings.backgroundOpacity * 100))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.backgroundOpacity },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: settings.settings.autoHideDelay,
                                        playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                        pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                        fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                        backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                        backgroundOpacity: newValue,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: settings.settings.bottomOffset
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 0.1...1.0
                        )
                    }
                    
                    // Fade animation duration
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Fade Animation Duration")
                            Spacer()
                            Text(String(format: "%.1f seconds", settings.settings.fadeAnimationDuration))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.fadeAnimationDuration },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: settings.settings.autoHideDelay,
                                        playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                        pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                        fadeAnimationDuration: newValue,
                                        backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                        backgroundOpacity: settings.settings.backgroundOpacity,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: settings.settings.bottomOffset
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 0.1...2.0
                        )
                    }
                    
                    // Bottom offset
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Controls Position from Bottom")
                            Spacer()
                            Text(String(format: "%.0f pixels", settings.settings.bottomOffset))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.settings.bottomOffset },
                                set: { newValue in
                                    let newSettings = UIControlSettings(
                                        autoHideDelay: settings.settings.autoHideDelay,
                                        playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                        pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                        fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                        backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                        backgroundOpacity: settings.settings.backgroundOpacity,
                                        showDetailedInfoByDefault: settings.settings.showDetailedInfoByDefault,
                                        hideOnPlay: settings.settings.hideOnPlay,
                                        minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                        showOnMouseMovement: settings.settings.showOnMouseMovement,
                                        mouseSensitivity: settings.settings.mouseSensitivity,
                                        bottomOffset: newValue
                                    )
                                    settings.updateSettings(newSettings)
                                }
                            ),
                            in: 0.0...200.0
                        )
                    }
                }
            }
            
            // Information Display Section
            SettingsSectionView(
                title: L10n.SettingsString.informationDisplay(),
                icon: "info.circle",
                description: L10n.SettingsString.informationDisplayDescription()
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(L10n.ToggleString.showDetailedPhotoInformation(), isOn: Binding(
                        get: { settings.settings.showDetailedInfoByDefault },
                        set: { newValue in
                            let newSettings = UIControlSettings(
                                autoHideDelay: settings.settings.autoHideDelay,
                                playingAutoHideDelay: settings.settings.playingAutoHideDelay,
                                pausedAutoHideDelay: settings.settings.pausedAutoHideDelay,
                                fadeAnimationDuration: settings.settings.fadeAnimationDuration,
                                backgroundBlurIntensity: settings.settings.backgroundBlurIntensity,
                                backgroundOpacity: settings.settings.backgroundOpacity,
                                showDetailedInfoByDefault: newValue,
                                hideOnPlay: settings.settings.hideOnPlay,
                                minimumVisibilityDuration: settings.settings.minimumVisibilityDuration,
                                showOnMouseMovement: settings.settings.showOnMouseMovement,
                                mouseSensitivity: settings.settings.mouseSensitivity,
                                bottomOffset: settings.settings.bottomOffset
                            )
                            settings.updateSettings(newSettings)
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    if settings.settings.showDetailedInfoByDefault {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Press 'I' to toggle detailed information during slideshow")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Shows: filename, dimensions, file size, creation date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Presets Section
            SettingsSectionView(
                title: L10n.SettingsString.presets(),
                icon: "square.grid.2x2",
                description: L10n.SettingsString.presetsDescription()
            ) {
                HStack(spacing: 12) {
                    Button(L10n.ButtonString.defaultPreset()) {
                        settings.updateSettings(.default)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(L10n.ButtonString.minimal()) {
                        settings.updateSettings(.minimal)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(L10n.ButtonString.alwaysVisible()) {
                        settings.updateSettings(.alwaysVisible)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(L10n.ButtonString.subtle()) {
                        settings.updateSettings(.subtle)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}

/// Reusable settings section component with unique name to avoid conflicts
private struct SettingsSectionView<Content: View>: View {
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
    InterfaceSettingsView(settings: ModernUIControlSettingsManager())
        .frame(width: 500, height: 600)
}