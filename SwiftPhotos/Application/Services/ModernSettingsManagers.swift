import Foundation
import SwiftUI
import Observation
import CoreGraphics

// MARK: - Modern Performance Settings Manager

/// Modern Swift 6 compliant PerformanceSettingsManager using @Observable
@Observable
@MainActor
public final class ModernPerformanceSettingsManager {
    
    // MARK: - Published Properties (No @Published needed with @Observable)
    public var settings: PerformanceSettings = .default {
        didSet {
            saveSettings()
            ProductionLogger.debug("PerformanceSettings updated: \(settings)")
        }
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotosPerformanceSettings"
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        ProductionLogger.lifecycle("PerformanceSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    public func updateSettings(_ newSettings: PerformanceSettings) {
        settings = newSettings
    }
    
    public func recommendedSettings(for collectionSize: Int) -> PerformanceSettings {
        switch collectionSize {
        case 0...100:
            return .default
        case 101...1000:
            return .highPerformance
        case 1001...10000:
            return .unlimited
        case 10001...50000:
            return .massive
        default:
            return .extreme
        }
    }
    
    public func estimatedMemoryUsage(for collectionSize: Int, averageImageSize: CGSize = CGSize(width: 2000, height: 1500)) -> Int {
        let bytesPerPixel = 4 // RGBA
        let bytesPerImage = Int(averageImageSize.width * averageImageSize.height) * bytesPerPixel
        
        // Smart window sizing: use actual window size but cap at collection size
        let effectiveWindowSize = min(settings.memoryWindowSize, collectionSize)
        
        // For massive collections, estimate based on actual memory window, not total collection
        let memoryUsageMB = (effectiveWindowSize * bytesPerImage) / (1024 * 1024)
        
        return memoryUsageMB
    }
    
    public func canHandleCollection(size: Int) -> Bool {
        let estimatedUsage = estimatedMemoryUsage(for: size)
        return estimatedUsage <= settings.maxMemoryUsageMB
    }
    
    public func resetToDefaults() {
        settings = .default
        ProductionLogger.debug("PerformanceSettings reset to defaults")
    }
    
    public func validateSettings() -> Bool {
        // Validation logic for performance settings
        return settings.memoryWindowSize > 0 && 
               settings.maxMemoryUsageMB > 0 && 
               settings.maxConcurrentLoads > 0
    }
    
    public func exportSettings() throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    public func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(PerformanceSettings.self, from: data)
        settings = importedSettings
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(PerformanceSettings.self, from: data) {
            settings = loadedSettings
            ProductionLogger.debug("PerformanceSettings loaded from UserDefaults")
        } else {
            settings = .default
            ProductionLogger.debug("PerformanceSettings using defaults (no saved settings found)")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("PerformanceSettings saved to UserDefaults")
        } else {
            ProductionLogger.error("Failed to save PerformanceSettings to UserDefaults")
        }
    }
}

// MARK: - Modern Slideshow Settings Manager

/// Modern Swift 6 compliant SlideshowSettingsManager using @Observable
@Observable
@MainActor
public final class ModernSlideshowSettingsManager {
    
    // MARK: - Published Properties
    public var settings: SlideshowSettings = .default {
        didSet {
            saveSettings()
            sendNotification()
            ProductionLogger.debug("SlideshowSettings updated: \(settings)")
        }
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotosSlideshowSettings"
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        ProductionLogger.lifecycle("SlideshowSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    public func updateSettings(_ newSettings: SlideshowSettings) {
        settings = newSettings
    }
    
    public func resetToDefaults() {
        settings = .default
        ProductionLogger.debug("SlideshowSettings reset to defaults")
    }
    
    public func validateSettings() -> Bool {
        // Validation logic for slideshow settings
        return settings.slideDuration > 0
    }
    
    public func exportSettings() throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    public func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(SlideshowSettings.self, from: data)
        settings = importedSettings
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(SlideshowSettings.self, from: data) {
            settings = loadedSettings
            ProductionLogger.debug("SlideshowSettings loaded from UserDefaults")
        } else {
            settings = .default
            ProductionLogger.debug("SlideshowSettings using defaults (no saved settings found)")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("SlideshowSettings saved to UserDefaults")
        } else {
            ProductionLogger.error("Failed to save SlideshowSettings to UserDefaults")
        }
    }
    
    private func sendNotification() {
        NotificationCenter.default.post(
            name: .slideshowSettingsChanged,
            object: settings
        )
    }
}

// MARK: - Modern Sort Settings Manager

/// Modern Swift 6 compliant SortSettingsManager using @Observable
@Observable
@MainActor
public final class ModernSortSettingsManager {
    
    // MARK: - Published Properties
    public var settings: SortSettings = .default {
        didSet {
            saveSettings()
            sendNotification()
            ProductionLogger.debug("SortSettings updated: \(settings)")
        }
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotosSortSettings"
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        ProductionLogger.lifecycle("SortSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    public func updateSettings(_ newSettings: SortSettings) {
        settings = newSettings
    }
    
    public func regenerateRandomSeed() {
        let newSettings = SortSettings(
            order: settings.order,
            direction: settings.direction,
            randomSeed: UInt64.random(in: 1...UInt64.max)
        )
        settings = newSettings
        sendNotification()
        ProductionLogger.debug("Random seed regenerated: \(newSettings.randomSeed)")
    }
    
    public func regenerateRandomSeedSilently() {
        let newSettings = SortSettings(
            order: settings.order,
            direction: settings.direction,
            randomSeed: UInt64.random(in: 1...UInt64.max)
        )
        settings = newSettings
        ProductionLogger.debug("Random seed regenerated silently: \(newSettings.randomSeed)")
    }
    
    public func resetToDefaults() {
        settings = .default
        ProductionLogger.debug("SortSettings reset to defaults")
    }
    
    public func validateSettings() -> Bool {
        // Validation logic for sort settings
        return true // SortSettings are always valid
    }
    
    public func exportSettings() throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    public func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(SortSettings.self, from: data)
        settings = importedSettings
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(SortSettings.self, from: data) {
            settings = loadedSettings
            ProductionLogger.debug("SortSettings loaded from UserDefaults")
        } else {
            settings = .default
            ProductionLogger.debug("SortSettings using defaults (no saved settings found)")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("SortSettings saved to UserDefaults")
        } else {
            ProductionLogger.error("Failed to save SortSettings to UserDefaults")
        }
    }
    
    private func sendNotification() {
        NotificationCenter.default.post(
            name: .sortSettingsChanged,
            object: settings
        )
    }
}

// MARK: - Modern Transition Settings Manager

/// Modern Swift 6 compliant TransitionSettingsManager using @Observable
@Observable
@MainActor
public final class ModernTransitionSettingsManager {
    
    // MARK: - Published Properties
    public var settings: TransitionSettings = .default {
        didSet {
            saveSettings()
            sendNotification()
            ProductionLogger.debug("TransitionSettings updated: \(settings)")
        }
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotosTransitionSettings"
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        ProductionLogger.lifecycle("TransitionSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    public func updateSettings(_ newSettings: TransitionSettings) {
        settings = newSettings
    }
    
    public func resetToDefaults() {
        settings = .default
        ProductionLogger.debug("TransitionSettings reset to defaults")
    }
    
    public func validateSettings() -> Bool {
        // Validation logic for transition settings
        return settings.duration > 0 && settings.intensity >= 0 && settings.intensity <= 1
    }
    
    public func exportSettings() throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    public func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(TransitionSettings.self, from: data)
        settings = importedSettings
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(TransitionSettings.self, from: data) {
            settings = loadedSettings
            ProductionLogger.debug("TransitionSettings loaded from UserDefaults")
        } else {
            settings = .default
            ProductionLogger.debug("TransitionSettings using defaults (no saved settings found)")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("TransitionSettings saved to UserDefaults")
        } else {
            ProductionLogger.error("Failed to save TransitionSettings to UserDefaults")
        }
    }
    
    private func sendNotification() {
        NotificationCenter.default.post(
            name: .transitionSettingsChanged,
            object: settings
        )
    }
}

// MARK: - Modern UI Control Settings Manager

/// Modern Swift 6 compliant UIControlSettingsManager using @Observable
@Observable
@MainActor
public final class ModernUIControlSettingsManager {
    
    // MARK: - Published Properties
    public var settings: UIControlSettings = .default {
        didSet {
            saveSettings()
            ProductionLogger.debug("UIControlSettings updated: \(settings)")
        }
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotosUIControlSettings"
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        ProductionLogger.lifecycle("UIControlSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    public func updateSettings(_ newSettings: UIControlSettings) {
        settings = newSettings
    }
    
    public func resetToDefaults() {
        settings = .default
        ProductionLogger.debug("UIControlSettings reset to defaults")
    }
    
    // MARK: - Preset Management
    
    public func applyPreset(_ preset: UIControlSettings.Preset) {
        switch preset {
        case .default:
            settings = .default
        case .minimal:
            settings = .minimal
        case .alwaysVisible:
            settings = .alwaysVisible
        case .subtle:
            settings = .subtle
        }
        ProductionLogger.debug("UIControlSettings preset applied: \(preset)")
    }
    
    public func validateSettings() -> Bool {
        // Validation logic for UI control settings
        return settings.autoHideDelay > 0 && settings.backgroundBlurIntensity >= 0
    }
    
    public func exportSettings() throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    public func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(UIControlSettings.self, from: data)
        settings = importedSettings
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(UIControlSettings.self, from: data) {
            settings = loadedSettings
            ProductionLogger.debug("UIControlSettings loaded from UserDefaults")
        } else {
            settings = .default
            ProductionLogger.debug("UIControlSettings using defaults (no saved settings found)")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("UIControlSettings saved to UserDefaults")
        } else {
            ProductionLogger.error("Failed to save UIControlSettings to UserDefaults")
        }
    }
}

// MARK: - Sendable Conformance

extension ModernPerformanceSettingsManager: @unchecked Sendable {}
extension ModernSlideshowSettingsManager: @unchecked Sendable {}
extension ModernSortSettingsManager: @unchecked Sendable {}
extension ModernTransitionSettingsManager: @unchecked Sendable {}
extension ModernUIControlSettingsManager: @unchecked Sendable {}

// MARK: - Notification Extensions

extension Notification.Name {
    static let slideshowSettingsChanged = Notification.Name("slideshowSettingsChanged")
    static let sortSettingsChanged = Notification.Name("sortSettingsChanged")
    static let transitionSettingsChanged = Notification.Name("transitionSettingsChanged")
    static let slideshowModeChanged = Notification.Name("slideshowModeChanged")
}