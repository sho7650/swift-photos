import Foundation

/// Settings for slideshow behavior
public struct SlideshowSettings: Codable, Equatable, Sendable {
    /// Slide duration in seconds
    public let slideDuration: Double
    
    /// Auto-start slideshow when folder is selected
    public let autoStart: Bool
    
    /// Random order of photos
    public let randomOrder: Bool
    
    /// Loop slideshow when reaching the end
    public let loopSlideshow: Bool
    
    public init(
        slideDuration: Double = 3.0,
        autoStart: Bool = false,
        randomOrder: Bool = false,
        loopSlideshow: Bool = true
    ) {
        self.slideDuration = max(1.0, min(30.0, slideDuration))
        self.autoStart = autoStart
        self.randomOrder = randomOrder
        self.loopSlideshow = loopSlideshow
    }
    
    // Predefined presets
    public static let `default` = SlideshowSettings(
        slideDuration: 3.0,
        autoStart: false,
        randomOrder: false,
        loopSlideshow: true
    )
    
    public static let quick = SlideshowSettings(
        slideDuration: 1.5,
        autoStart: true,
        randomOrder: false,
        loopSlideshow: true
    )
    
    public static let slow = SlideshowSettings(
        slideDuration: 5.0,
        autoStart: false,
        randomOrder: false,
        loopSlideshow: true
    )
    
    public static let random = SlideshowSettings(
        slideDuration: 3.0,
        autoStart: true,
        randomOrder: true,
        loopSlideshow: true
    )
}

/// Settings manager for slideshow configuration
@MainActor
@available(*, deprecated, message: "Use ModernSlideshowSettingsManager instead. This class will be removed in a future version. The new ModernSlideshowSettingsManager uses @Observable for better performance and Swift 6 compliance.")
public class SlideshowSettingsManager: ObservableObject {
    @Published public var settings: SlideshowSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "PhotoSlideshowSlideshowSettings"
    
    public init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(SlideshowSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = .default
        }
        ProductionLogger.lifecycle("SlideshowSettingsManager: Initialized with settings - duration: \(settings.slideDuration)s, autoStart: \(settings.autoStart), random: \(settings.randomOrder), loop: \(settings.loopSlideshow)")
    }
    
    public func updateSettings(_ newSettings: SlideshowSettings) {
        let previousRandomOrder = settings.randomOrder
        settings = newSettings
        saveSettings()
        ProductionLogger.debug("SlideshowSettingsManager: Updated settings - duration: \(settings.slideDuration)s, autoStart: \(settings.autoStart), random: \(settings.randomOrder), loop: \(settings.loopSlideshow)")
        
        // Notify about mode change if random order changed
        if previousRandomOrder != newSettings.randomOrder {
            ProductionLogger.debug("SlideshowSettingsManager: Random order changed from \(previousRandomOrder) to \(newSettings.randomOrder)")
            NotificationCenter.default.post(name: .slideshowModeChanged, object: newSettings.randomOrder)
        }
    }
    
    public func resetToDefault() {
        settings = .default
        saveSettings()
    }
    
    public func applyPreset(_ preset: SlideshowSettings) {
        settings = preset
        saveSettings()
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
}