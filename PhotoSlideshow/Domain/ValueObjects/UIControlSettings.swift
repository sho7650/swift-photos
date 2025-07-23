import Foundation

// Notification for UI control settings changes
extension Notification.Name {
    static let uiControlSettingsChanged = Notification.Name("uiControlSettingsChanged")
}

/// Settings for UI control behavior and appearance
public struct UIControlSettings: Codable, Equatable {
    /// Auto-hide delay in seconds when no interaction
    public let autoHideDelay: Double
    
    /// Auto-hide delay when slideshow is playing (typically shorter)
    public let playingAutoHideDelay: Double
    
    /// Auto-hide delay when slideshow is paused (typically longer)
    public let pausedAutoHideDelay: Double
    
    /// Fade animation duration in seconds
    public let fadeAnimationDuration: Double
    
    /// Background blur intensity (0.0 to 1.0)
    public let backgroundBlurIntensity: Double
    
    /// Background opacity when controls are visible (0.0 to 1.0)
    public let backgroundOpacity: Double
    
    /// Whether to show detailed info by default
    public let showDetailedInfoByDefault: Bool
    
    /// Whether to hide controls completely when slideshow is playing
    public let hideOnPlay: Bool
    
    /// Minimum time controls stay visible after interaction (seconds)
    public let minimumVisibilityDuration: Double
    
    /// Whether to show controls on mouse movement
    public let showOnMouseMovement: Bool
    
    /// Mouse movement sensitivity (pixels to trigger show)
    public let mouseSensitivity: Double
    
    /// Controls position offset from bottom (in pixels)
    public let bottomOffset: Double
    
    public init(
        autoHideDelay: Double = 5.0,
        playingAutoHideDelay: Double = 2.0,
        pausedAutoHideDelay: Double = 10.0,
        fadeAnimationDuration: Double = 0.3,
        backgroundBlurIntensity: Double = 0.8,
        backgroundOpacity: Double = 0.15,
        showDetailedInfoByDefault: Bool = false,
        hideOnPlay: Bool = true,
        minimumVisibilityDuration: Double = 1.0,
        showOnMouseMovement: Bool = true,
        mouseSensitivity: Double = 10.0,
        bottomOffset: Double = 50.0
    ) {
        self.autoHideDelay = max(1.0, min(30.0, autoHideDelay))
        self.playingAutoHideDelay = max(0.5, min(10.0, playingAutoHideDelay))
        self.pausedAutoHideDelay = max(1.0, min(60.0, pausedAutoHideDelay))
        self.fadeAnimationDuration = max(0.1, min(2.0, fadeAnimationDuration))
        self.backgroundBlurIntensity = max(0.0, min(1.0, backgroundBlurIntensity))
        self.backgroundOpacity = max(0.0, min(1.0, backgroundOpacity))
        self.showDetailedInfoByDefault = showDetailedInfoByDefault
        self.hideOnPlay = hideOnPlay
        self.minimumVisibilityDuration = max(0.1, min(5.0, minimumVisibilityDuration))
        self.showOnMouseMovement = showOnMouseMovement
        self.mouseSensitivity = max(1.0, min(100.0, mouseSensitivity))
        self.bottomOffset = max(20.0, min(200.0, bottomOffset))
    }
    
    // Predefined presets
    public static let `default` = UIControlSettings()
    
    public static let minimal = UIControlSettings(
        autoHideDelay: 3.0,
        playingAutoHideDelay: 1.0,
        pausedAutoHideDelay: 5.0,
        fadeAnimationDuration: 0.2,
        backgroundBlurIntensity: 0.6,
        backgroundOpacity: 0.1,
        showDetailedInfoByDefault: false,
        hideOnPlay: true,
        minimumVisibilityDuration: 0.5,
        showOnMouseMovement: true,
        mouseSensitivity: 15.0,
        bottomOffset: 30.0
    )
    
    public static let alwaysVisible = UIControlSettings(
        autoHideDelay: 999.0,
        playingAutoHideDelay: 999.0,
        pausedAutoHideDelay: 999.0,
        fadeAnimationDuration: 0.3,
        backgroundBlurIntensity: 0.9,
        backgroundOpacity: 0.2,
        showDetailedInfoByDefault: true,
        hideOnPlay: false,
        minimumVisibilityDuration: 1.0,
        showOnMouseMovement: true,
        mouseSensitivity: 5.0,
        bottomOffset: 60.0
    )
    
    public static let subtle = UIControlSettings(
        autoHideDelay: 7.0,
        playingAutoHideDelay: 3.0,
        pausedAutoHideDelay: 15.0,
        fadeAnimationDuration: 0.5,
        backgroundBlurIntensity: 0.5,
        backgroundOpacity: 0.05,
        showDetailedInfoByDefault: false,
        hideOnPlay: true,
        minimumVisibilityDuration: 1.5,
        showOnMouseMovement: true,
        mouseSensitivity: 20.0,
        bottomOffset: 40.0
    )
}

/// Settings manager for UI control configuration
@MainActor
public class UIControlSettingsManager: ObservableObject {
    @Published public var settings: UIControlSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "PhotoSlideshowUIControlSettings"
    
    public init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(UIControlSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = .default
        }
        print("🎮 UIControlSettingsManager: Initialized with settings - autoHide: \(settings.autoHideDelay)s, blur: \(settings.backgroundBlurIntensity), opacity: \(settings.backgroundOpacity)")
    }
    
    public func updateSettings(_ newSettings: UIControlSettings) {
        settings = newSettings
        saveSettings()
        print("🎮 UIControlSettingsManager: Updated settings - autoHide: \(settings.autoHideDelay)s, blur: \(settings.backgroundBlurIntensity), opacity: \(settings.backgroundOpacity)")
        
        // Notify observers about settings change
        NotificationCenter.default.post(name: .uiControlSettingsChanged, object: settings)
    }
    
    public func resetToDefault() {
        updateSettings(.default)
    }
    
    public func applyPreset(_ preset: UIControlSettings) {
        updateSettings(preset)
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
}