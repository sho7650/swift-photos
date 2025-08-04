import Foundation
import SwiftUI
import Observation

// MARK: - Unified Settings Management Protocol

/// Protocol for all settings types to enable unified management
public protocol ManagedSettings: Codable, Sendable, Equatable {
    static var `default`: Self { get }
    var settingsKey: String { get }
    var requiresNotification: Bool { get }
    var notificationName: Notification.Name? { get }
}

// MARK: - Unified Settings Manager

/// Unified settings manager that provides a generic, reusable settings management system
/// Eliminates code duplication across multiple setting types
@Observable
@MainActor
public final class UnifiedSettingsManager<T: ManagedSettings> {
    
    // MARK: - Properties
    
    public var settings: T {
        didSet {
            saveSettings()
            sendNotificationIfNeeded()
            logSettingsChange()
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let logger: ProductionLogger.Type
    
    // MARK: - Initialization
    
    public init(
        userDefaults: UserDefaults = .standard,
        logger: ProductionLogger.Type = ProductionLogger.self
    ) {
        self.userDefaults = userDefaults
        self.logger = logger
        
        // Initialize with loaded settings or default
        if let data = userDefaults.data(forKey: T.default.settingsKey),
           let loadedSettings = try? JSONDecoder().decode(T.self, from: data) {
            self.settings = loadedSettings
            logger.debug("\(T.self) loaded from UserDefaults")
        } else {
            self.settings = T.default
            logger.debug("\(T.self) using defaults (no saved settings found)")
        }
        logger.lifecycle("UnifiedSettingsManager<\(T.self)> initialized")
    }
    
    // MARK: - Public Methods
    
    /// Update settings with new values
    public func updateSettings(_ newSettings: T) {
        settings = newSettings
    }
    
    /// Reset settings to default values
    public func resetToDefaults() {
        settings = T.default
        logger.debug("\(T.self) reset to defaults")
    }
    
    /// Validate and fix settings if needed
    public func validateSettings() -> Bool {
        // Subclasses can override for specific validation
        return true
    }
    
    /// Get current settings as Data for export
    public func exportSettings() throws -> Data {
        let data = try JSONEncoder().encode(settings)
        logger.debug("\(T.self) exported - size: \(data.count) bytes")
        return data
    }
    
    /// Import settings from Data
    public func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(T.self, from: data)
        settings = importedSettings
        logger.debug("\(T.self) imported successfully")
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settings.settingsKey)
            logger.debug("\(T.self) saved to UserDefaults")
        } catch {
            logger.error("Failed to save \(T.self) to UserDefaults: \(error)")
        }
    }
    
    private func sendNotificationIfNeeded() {
        guard settings.requiresNotification,
              let notificationName = settings.notificationName else { return }
        
        NotificationCenter.default.post(
            name: notificationName,
            object: settings
        )
    }
    
    private func logSettingsChange() {
        logger.debug("\(T.self) updated: \(settings)")
    }
}

// MARK: - Specialized Settings Managers

/// Performance settings manager using unified system (composition pattern)
public final class UnifiedPerformanceSettingsManager: PerformanceSettingsManagerProtocol {
    
    // Use composition instead of inheritance to avoid final class issue
    private let unifiedSettings: UnifiedSettingsManager<PerformanceSettings>
    
    public var settings: PerformanceSettings {
        get { unifiedSettings.settings }
        set { unifiedSettings.settings = newValue }
    }
    
    public init() {
        self.unifiedSettings = UnifiedSettingsManager<PerformanceSettings>()
    }
    
    public func updateSettings(_ newSettings: PerformanceSettings) {
        unifiedSettings.updateSettings(newSettings)
    }
    
    public func resetToDefaults() {
        unifiedSettings.resetToDefaults()
    }
    
    /// Get recommended settings for collection size
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
    
    /// Estimate memory usage for collection
    public func estimatedMemoryUsage(for collectionSize: Int, averageImageSize: CGSize = CGSize(width: 2000, height: 1500)) -> Int {
        let bytesPerPixel = 4 // RGBA
        let bytesPerImage = Int(averageImageSize.width * averageImageSize.height) * bytesPerPixel
        let effectiveWindowSize = min(settings.memoryWindowSize, collectionSize)
        let memoryUsageMB = (effectiveWindowSize * bytesPerImage) / (1024 * 1024)
        return memoryUsageMB
    }
    
    /// Check if settings can handle collection size
    public func canHandleCollection(size: Int) -> Bool {
        let estimatedUsage = estimatedMemoryUsage(for: size)
        return estimatedUsage <= settings.maxMemoryUsageMB
    }
    
    /// Validate settings consistency
    public func validateSettings() -> Bool {
        return unifiedSettings.validateSettings()
    }
    
    /// Export settings as Data
    public func exportSettings() throws -> Data {
        return try unifiedSettings.exportSettings()
    }
    
    /// Import settings from Data
    public func importSettings(from data: Data) throws {
        try unifiedSettings.importSettings(from: data)
    }
}

/// Sort settings manager with random seed management (ModernSortSettingsManager compatible)
public final class UnifiedSortSettingsManager: SortSettingsManagerProtocol {
    
    // Use composition instead of inheritance to avoid final class issue
    private let modernSortSettings: ModernSortSettingsManager
    
    public var settings: SortSettings {
        get { modernSortSettings.settings }
        set { modernSortSettings.settings = newValue }
    }
    
    /// Expose the underlying ModernSortSettingsManager for Settings Window synchronization
    public var underlyingManager: ModernSortSettingsManager {
        return modernSortSettings
    }
    
    public init() {
        self.modernSortSettings = ModernSortSettingsManager()
    }
    
    public func updateSettings(_ newSettings: SortSettings) {
        modernSortSettings.updateSettings(newSettings)
    }
    
    public func resetToDefaults() {
        modernSortSettings.resetToDefaults()
    }
    
    /// Regenerate random seed and notify
    public func regenerateRandomSeed() {
        modernSortSettings.regenerateRandomSeed()
    }
    
    /// Regenerate random seed without notification
    public func regenerateRandomSeedSilently() {
        modernSortSettings.regenerateRandomSeedSilently()
    }
    
    /// Validate settings consistency
    public func validateSettings() -> Bool {
        return modernSortSettings.validateSettings()
    }
    
    /// Export settings as Data
    public func exportSettings() throws -> Data {
        return try modernSortSettings.exportSettings()
    }
    
    /// Import settings from Data
    public func importSettings(from data: Data) throws {
        try modernSortSettings.importSettings(from: data)
    }
}

/// UI Control settings manager with preset support
public final class UnifiedUIControlSettingsManager: UIControlSettingsManagerProtocol {
    
    // Use composition instead of inheritance to avoid final class issue
    private let unifiedSettings: UnifiedSettingsManager<UIControlSettings>
    
    public var settings: UIControlSettings {
        get { unifiedSettings.settings }
        set { unifiedSettings.settings = newValue }
    }
    
    public init() {
        self.unifiedSettings = UnifiedSettingsManager<UIControlSettings>()
    }
    
    public func updateSettings(_ newSettings: UIControlSettings) {
        unifiedSettings.updateSettings(newSettings)
    }
    
    public func resetToDefaults() {
        unifiedSettings.resetToDefaults()
    }
    
    /// Apply preset configuration
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
    
    /// Validate settings consistency
    public func validateSettings() -> Bool {
        return unifiedSettings.validateSettings()
    }
    
    /// Export settings as Data
    public func exportSettings() throws -> Data {
        return try unifiedSettings.exportSettings()
    }
    
    /// Import settings from Data
    public func importSettings(from data: Data) throws {
        try unifiedSettings.importSettings(from: data)
    }
}

// MARK: - Settings Protocol Extensions

extension PerformanceSettings: ManagedSettings {
    public var settingsKey: String { "SwiftPhotosPerformanceSettings" }
    public var requiresNotification: Bool { false }
    public var notificationName: Notification.Name? { nil }
}

extension SlideshowSettings: ManagedSettings {
    public var settingsKey: String { "SwiftPhotosSlideshowSettings" }
    public var requiresNotification: Bool { true }
    public var notificationName: Notification.Name? { .slideshowSettingsChanged }
}

extension SortSettings: ManagedSettings {
    public var settingsKey: String { "SwiftPhotosSortSettings" }
    public var requiresNotification: Bool { true }
    public var notificationName: Notification.Name? { .sortSettingsChanged }
}

extension TransitionSettings: ManagedSettings {
    public var settingsKey: String { "SwiftPhotosTransitionSettings" }
    public var requiresNotification: Bool { true }
    public var notificationName: Notification.Name? { .transitionSettingsChanged }
}

extension UIControlSettings: ManagedSettings {
    public var settingsKey: String { "SwiftPhotosUIControlSettings" }
    public var requiresNotification: Bool { false }
    public var notificationName: Notification.Name? { nil }
}

// MARK: - Sendable Conformance

extension UnifiedSettingsManager: @unchecked Sendable {}
extension UnifiedPerformanceSettingsManager: @unchecked Sendable {}
extension UnifiedSortSettingsManager: @unchecked Sendable {}
extension UnifiedUIControlSettingsManager: @unchecked Sendable {}

// MARK: - Notification Extensions
// Note: Notification names are already defined in ModernSettingsManagers.swift