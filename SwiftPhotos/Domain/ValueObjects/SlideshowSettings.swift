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
    
    /// Pause auto-play when user manually navigates (prevents conflicts)
    public let pauseOnManualNavigation: Bool
    
    public init(
        slideDuration: Double = 3.0,
        autoStart: Bool = false,
        randomOrder: Bool = false,
        loopSlideshow: Bool = true,
        pauseOnManualNavigation: Bool = true
    ) {
        // Support 1 second to 30 minutes (1800 seconds)
        self.slideDuration = max(1.0, min(1800.0, slideDuration))
        self.autoStart = autoStart
        self.randomOrder = randomOrder
        self.loopSlideshow = loopSlideshow
        self.pauseOnManualNavigation = pauseOnManualNavigation
    }
    
    // Predefined presets
    public static let `default` = SlideshowSettings(
        slideDuration: 3.0,
        autoStart: false,
        randomOrder: false,
        loopSlideshow: true,
        pauseOnManualNavigation: true
    )
    
    public static let quick = SlideshowSettings(
        slideDuration: 1.5,
        autoStart: true,
        randomOrder: false,
        loopSlideshow: true,
        pauseOnManualNavigation: true
    )
    
    public static let slow = SlideshowSettings(
        slideDuration: 5.0,
        autoStart: false,
        randomOrder: false,
        loopSlideshow: true,
        pauseOnManualNavigation: true
    )
    
    public static let random = SlideshowSettings(
        slideDuration: 3.0,
        autoStart: true,
        randomOrder: true,
        loopSlideshow: true,
        pauseOnManualNavigation: true
    )
}

