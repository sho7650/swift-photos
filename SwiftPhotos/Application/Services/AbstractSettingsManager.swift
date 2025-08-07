import Foundation
import SwiftUI
import Observation

/// Abstract base class implementing Template Method pattern for settings management
/// Reduces code duplication across all Modern*SettingsManager classes
@MainActor
@Observable  
public class AbstractSettingsManager<SettingsType: Codable & Equatable & DefaultConfigurable> {
    
    // MARK: - Abstract Properties
    
    /// Settings instance - must be implemented by subclasses
    public var settings: SettingsType {
        get { internalSettings }
        set {
            let oldValue = internalSettings
            internalSettings = newValue
            if oldValue != newValue {
                onSettingsChanged(oldValue: oldValue, newValue: newValue)
            }
        }
    }
    
    // MARK: - Private Properties
    
    fileprivate var internalSettings: SettingsType
    private let userDefaults = UserDefaults.standard
    private let settingsKey: String
    private let managerName: String
    
    // MARK: - Template Method Implementation
    
    public init(settingsKey: String, managerName: String) {
        self.settingsKey = settingsKey
        self.managerName = managerName
        self.internalSettings = SettingsType.default
        
        loadSettings()
        ProductionLogger.lifecycle("\(managerName) initialized using AbstractSettingsManager")
    }
    
    // MARK: - Template Methods (Common Implementation)
    
    /// Update settings (Template Method)
    public final func updateSettings(_ newSettings: SettingsType) {
        settings = newSettings
    }
    
    /// Reset to defaults (Template Method)
    public final func resetToDefaults() {
        settings = SettingsType.default
        ProductionLogger.debug("\(managerName): Reset to defaults")
    }
    
    /// Export settings as JSON data (Template Method)
    public final func exportSettings() throws -> Data {
        return try JSONEncoder().encode(settings)
    }
    
    /// Import settings from JSON data (Template Method)
    public final func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(SettingsType.self, from: data)
        settings = importedSettings
        ProductionLogger.debug("\(managerName): Settings imported from data")
    }
    
    /// Export settings as JSON string (Template Method)
    public final func exportSettingsAsString() -> String? {
        do {
            let data = try exportSettings()
            return String(data: data, encoding: .utf8)
        } catch {
            ProductionLogger.error("\(managerName): Failed to export settings as string: \(error)")
            return nil
        }
    }
    
    /// Import settings from JSON string (Template Method)
    public final func importSettings(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            ProductionLogger.error("\(managerName): Invalid JSON string format")
            return false
        }
        
        do {
            try importSettings(from: data)
            return true
        } catch {
            ProductionLogger.error("\(managerName): Failed to import settings from string: \(error)")
            return false
        }
    }
    
    // MARK: - Hook Methods (Override in Subclasses)
    
    /// Hook method called when settings change - override in subclasses for custom behavior
    open func onSettingsChanged(oldValue: SettingsType, newValue: SettingsType) {
        saveSettings()
        sendNotificationIfNeeded()
        logSettingsChange(oldValue: oldValue, newValue: newValue)
    }
    
    /// Hook method for custom validation - override in subclasses
    open func validateSettings() -> Bool {
        return true // Default implementation - always valid
    }
    
    /// Hook method for notification posting - override in subclasses if needed
    open func getNotificationName() -> Notification.Name? {
        return nil // Default: no notification
    }
    
    /// Hook method for custom behavior during settings load - override in subclasses
    open func onSettingsLoaded() {
        // Default: no additional behavior
    }
    
    /// Hook method for custom behavior during settings save - override in subclasses  
    open func onSettingsSaved() {
        // Default: no additional behavior
    }
    
    // MARK: - Private Template Implementation
    
    private final func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(SettingsType.self, from: data) {
            internalSettings = loadedSettings
            onSettingsLoaded()
            ProductionLogger.debug("\(managerName): Settings loaded from UserDefaults")
        } else {
            internalSettings = SettingsType.default
            ProductionLogger.debug("\(managerName): Using default settings (no saved settings found)")
        }
    }
    
    fileprivate final func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            onSettingsSaved()
            ProductionLogger.debug("\(managerName): Settings saved to UserDefaults")
        } else {
            ProductionLogger.error("\(managerName): Failed to save settings to UserDefaults")
        }
    }
    
    private final func sendNotificationIfNeeded() {
        if let notificationName = getNotificationName() {
            NotificationCenter.default.post(
                name: notificationName,
                object: settings
            )
            ProductionLogger.debug("\(managerName): Notification sent: \(notificationName)")
        }
    }
    
    private final func logSettingsChange(oldValue: SettingsType, newValue: SettingsType) {
        ProductionLogger.debug("\(managerName): Settings updated")
        
        // Only log detailed changes in debug builds
        #if DEBUG
        if oldValue != newValue {
            ProductionLogger.debug("\(managerName): Settings changed from \(oldValue) to \(newValue)")
        }
        #endif
    }
}

// MARK: - Supporting Protocols

/// Protocol for types that can provide default configuration
public protocol DefaultConfigurable {
    static var `default`: Self { get }
}

// MARK: - Concrete Settings Manager Implementations

/// Performance Settings Manager using Template Method pattern
@MainActor
@Observable
public final class ModernPerformanceSettingsManager: AbstractSettingsManager<PerformanceSettings> {
    
    public init() {
        super.init(
            settingsKey: "SwiftPhotosPerformanceSettings",
            managerName: "PerformanceSettingsManager"
        )
    }
    
    // MARK: - Specialized Methods
    
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
        let effectiveWindowSize = min(settings.memoryWindowSize, collectionSize)
        let memoryUsageMB = (effectiveWindowSize * bytesPerImage) / (1024 * 1024)
        return memoryUsageMB
    }
    
    public func canHandleCollection(size: Int) -> Bool {
        let estimatedUsage = estimatedMemoryUsage(for: size)
        return estimatedUsage <= settings.maxMemoryUsageMB
    }
    
    // MARK: - Template Method Overrides
    
    public override func validateSettings() -> Bool {
        return settings.memoryWindowSize > 0 && 
               settings.maxMemoryUsageMB > 0 && 
               settings.maxConcurrentLoads > 0
    }
}

/// Slideshow Settings Manager using Template Method pattern
@MainActor
@Observable
public final class ModernSlideshowSettingsManager: AbstractSettingsManager<SlideshowSettings> {
    
    public init() {
        super.init(
            settingsKey: "SwiftPhotosSlideshowSettings",
            managerName: "SlideshowSettingsManager"
        )
    }
    
    // MARK: - Template Method Overrides
    
    public override func validateSettings() -> Bool {
        return settings.slideDuration > 0
    }
    
    public override func getNotificationName() -> Notification.Name? {
        return .slideshowSettingsChanged
    }
}

/// Sort Settings Manager using Template Method pattern  
@MainActor
@Observable
public final class ModernSortSettingsManager: AbstractSettingsManager<SortSettings> {
    
    public init() {
        super.init(
            settingsKey: "SwiftPhotosSortSettings",
            managerName: "SortSettingsManager"
        )
    }
    
    // MARK: - Specialized Methods
    
    public func regenerateRandomSeed() {
        let newSettings = SortSettings(
            order: settings.order,
            direction: settings.direction,
            randomSeed: UInt64.random(in: 1...UInt64.max)
        )
        updateSettings(newSettings)
    }
    
    public func regenerateRandomSeedSilently() {
        let newSettings = SortSettings(
            order: settings.order,
            direction: settings.direction,
            randomSeed: UInt64.random(in: 1...UInt64.max)
        )
        // Update settings directly without triggering notifications
        internalSettings = newSettings
        saveSettings()
        ProductionLogger.debug("SortSettingsManager: Random seed regenerated silently")
    }
    
    // MARK: - Template Method Overrides
    
    public override func onSettingsChanged(oldValue: SortSettings, newValue: SortSettings) {
        let currentDirection = oldValue.direction
        let newDirection = newValue.direction
        
        ProductionLogger.debug("ModernSortSettingsManager: Direction change: \(currentDirection.displayName) → \(newDirection.displayName)")
        
        // Call parent implementation for standard behavior
        super.onSettingsChanged(oldValue: oldValue, newValue: newValue)
        
        ProductionLogger.debug("ModernSortSettingsManager: Final direction: \(settings.direction.displayName)")
    }
    
    public override func getNotificationName() -> Notification.Name? {
        return .sortSettingsChanged
    }
}

/// Transition Settings Manager using Template Method pattern
@MainActor
@Observable  
public final class ModernTransitionSettingsManager: AbstractSettingsManager<TransitionSettings> {
    
    public init() {
        super.init(
            settingsKey: "SwiftPhotosTransitionSettings", 
            managerName: "TransitionSettingsManager"
        )
    }
    
    // MARK: - Template Method Overrides
    
    public override func getNotificationName() -> Notification.Name? {
        return .transitionSettingsChanged
    }
}

/// UI Control Settings Manager using Template Method pattern
@MainActor
@Observable
public final class ModernUIControlSettingsManager: AbstractSettingsManager<UIControlSettings> {
    
    public init() {
        super.init(
            settingsKey: "SwiftPhotosUIControlSettings",
            managerName: "UIControlSettingsManager"
        )
    }
    
    // MARK: - Specialized Methods
    
    public func applyPreset(_ preset: UIControlSettings.Preset) {
        switch preset {
        case .default:
            updateSettings(.default)
        case .minimal:
            updateSettings(.minimal)
        case .alwaysVisible:
            updateSettings(.alwaysVisible)
        case .subtle:
            updateSettings(.subtle)
        }
        ProductionLogger.debug("UIControlSettingsManager: Applied preset \(preset)")
    }
    
    // MARK: - Template Method Overrides
    
    public override func validateSettings() -> Bool {
        return settings.autoHideDelay > 0
    }
}

// MARK: - Extensions for DefaultConfigurable Protocol

extension PerformanceSettings: DefaultConfigurable {}
extension SlideshowSettings: DefaultConfigurable {}
extension SortSettings: DefaultConfigurable {}
extension TransitionSettings: DefaultConfigurable {}
extension UIControlSettings: DefaultConfigurable {}

// MARK: - Notification Names Extension

extension Notification.Name {
    public static let slideshowSettingsChanged = Notification.Name("slideshowSettingsChanged")
    public static let sortSettingsChanged = Notification.Name("sortSettingsChanged")
    public static let transitionSettingsChanged = Notification.Name("transitionSettingsChanged")
}