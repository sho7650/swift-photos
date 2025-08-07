import Foundation

// MARK: - Settings Manager Protocols

/// Protocol for Sort Settings Manager to enable unified interface
@MainActor
public protocol SortSettingsManagerProtocol: AnyObject {
    var settings: SortSettings { get set }
    
    func updateSettings(_ newSettings: SortSettings)
    func resetToDefaults()
    func regenerateRandomSeed()
    func regenerateRandomSeedSilently()
    func validateSettings() -> Bool
    func exportSettings() throws -> Data
    func importSettings(from data: Data) throws
}

/// Protocol for Performance Settings Manager to enable unified interface
@MainActor
public protocol PerformanceSettingsManagerProtocol: AnyObject {
    var settings: PerformanceSettings { get set }
    
    func updateSettings(_ newSettings: PerformanceSettings)
    func resetToDefaults()
    func recommendedSettings(for collectionSize: Int) -> PerformanceSettings
    func estimatedMemoryUsage(for collectionSize: Int, averageImageSize: CGSize) -> Int
    func canHandleCollection(size: Int) -> Bool
    func validateSettings() -> Bool
    func exportSettings() throws -> Data
    func importSettings(from data: Data) throws
}

/// Protocol for Slideshow Settings Manager to enable unified interface
@MainActor
public protocol SlideshowSettingsManagerProtocol: AnyObject {
    var settings: SlideshowSettings { get set }
    
    func updateSettings(_ newSettings: SlideshowSettings)
    func resetToDefaults()
}

/// Protocol for Transition Settings Manager to enable unified interface
@MainActor
public protocol TransitionSettingsManagerProtocol: AnyObject {
    var settings: TransitionSettings { get set }
    
    func updateSettings(_ newSettings: TransitionSettings)
    func resetToDefaults()
}

/// Protocol for UI Control Settings Manager to enable unified interface
@MainActor
public protocol UIControlSettingsManagerProtocol: AnyObject {
    var settings: UIControlSettings { get set }
    
    func updateSettings(_ newSettings: UIControlSettings)
    func resetToDefaults()
    func applyPreset(_ preset: UIControlSettings.Preset)
    func validateSettings() -> Bool
    func exportSettings() throws -> Data
    func importSettings(from data: Data) throws
}

// MARK: - Protocol Conformances for Modern Settings Managers

extension ModernSortSettingsManager: SortSettingsManagerProtocol {
    // Already implements all required methods
}

extension ModernPerformanceSettingsManager: PerformanceSettingsManagerProtocol {
    // Already implements all required methods
}

extension ModernSlideshowSettingsManager: SlideshowSettingsManagerProtocol {
    // Already implements all required methods
}

extension ModernTransitionSettingsManager: TransitionSettingsManagerProtocol {
    // Already implements all required methods
}

extension ModernUIControlSettingsManager: UIControlSettingsManagerProtocol {
    // Already implements all required methods
}