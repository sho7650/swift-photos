import Foundation
import CoreGraphics

/// Settings for background blur effect
public struct BlurSettings: Codable, Equatable {
    /// Enable/disable background blur
    public let isEnabled: Bool
    
    /// Blur intensity (0.0 = no blur, 1.0 = maximum blur)
    public let intensity: Double
    
    /// Blur style
    public let style: BlurStyle
    
    /// Background opacity (0.0 = transparent, 1.0 = opaque)
    public let backgroundOpacity: Double
    
    public init(
        isEnabled: Bool = true,
        intensity: Double = 0.3,
        style: BlurStyle = .gaussian,
        backgroundOpacity: Double = 0.8
    ) {
        self.isEnabled = isEnabled
        self.intensity = max(0.0, min(1.0, intensity))
        self.style = style
        self.backgroundOpacity = max(0.0, min(1.0, backgroundOpacity))
    }
    
    public enum BlurStyle: String, Codable, CaseIterable {
        case gaussian = "gaussian"
        case motion = "motion"
        case zoom = "zoom"
        
        public var displayName: String {
            switch self {
            case .gaussian:
                return "Gaussian"
            case .motion:
                return "Motion"
            case .zoom:
                return "Zoom"
            }
        }
    }
    
    // Predefined presets
    public static let subtle = BlurSettings(
        isEnabled: true,
        intensity: 0.2,
        style: .gaussian,
        backgroundOpacity: 0.6
    )
    
    public static let medium = BlurSettings(
        isEnabled: true,
        intensity: 0.5,
        style: .gaussian,
        backgroundOpacity: 0.8
    )
    
    public static let strong = BlurSettings(
        isEnabled: true,
        intensity: 0.8,
        style: .gaussian,
        backgroundOpacity: 0.9
    )
    
    public static let disabled = BlurSettings(
        isEnabled: false,
        intensity: 0.0,
        style: .gaussian,
        backgroundOpacity: 1.0
    )
}

/// Settings manager for blur configuration
@MainActor
public class BlurSettingsManager: ObservableObject {
    @Published public var settings: BlurSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "PhotoSlideshowBlurSettings"
    
    public init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(BlurSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = .medium
        }
        print("🎨 BlurSettingsManager: Initialized with settings - enabled: \(settings.isEnabled), intensity: \(settings.intensity), style: \(settings.style.displayName)")
    }
    
    public func updateSettings(_ newSettings: BlurSettings) {
        settings = newSettings
        saveSettings()
    }
    
    public func resetToDefault() {
        settings = .medium
        saveSettings()
    }
    
    public func applyPreset(_ preset: BlurSettings) {
        settings = preset
        saveSettings()
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
}