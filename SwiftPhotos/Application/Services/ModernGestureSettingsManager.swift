import Foundation
import SwiftUI
import Combine

/// Modern gesture settings manager using Swift 6 @Observable pattern
/// Manages gesture configuration, sensitivity, and user preferences
@MainActor
@Observable
public final class ModernGestureSettingsManager {
    
    // MARK: - Settings Properties
    
    /// Current gesture settings
    public var settings: GestureSettings = .default {
        didSet {
            if settings != oldValue {
                saveSettings()
                objectWillChange.send()
                NotificationCenter.default.post(name: .gestureSettingsChanged, object: settings)
                ProductionLogger.debug("ModernGestureSettingsManager: Settings updated")
            }
        }
    }
    
    // MARK: - ObservableObject Support
    
    public let objectWillChange = PassthroughSubject<Void, Never>()
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "gestureSettings_v2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        ProductionLogger.lifecycle("ModernGestureSettingsManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Apply a predefined preset
    public func applyPreset(_ preset: GestureSettings.Preset) {
        settings = preset.settings
        ProductionLogger.userAction("ModernGestureSettingsManager: Applied preset '\(preset.name)'")
    }
    
    /// Update specific gesture sensitivity
    public func updateGestureSensitivity(_ gestureType: GestureType, sensitivity: Double) {
        var newSensitivities = settings.gestureSensitivities
        newSensitivities[gestureType] = max(0.1, min(3.0, sensitivity))
        
        settings = GestureSettings(
            enabledGestures: settings.enabledGestures,
            gestureSensitivities: newSensitivities,
            gestureThresholds: settings.gestureThresholds,
            enabledZones: settings.enabledZones,
            simultaneousGestureRecognition: settings.simultaneousGestureRecognition,
            feedbackHaptics: settings.feedbackHaptics,
            advancedFeatures: settings.advancedFeatures
        )
    }
    
    /// Toggle gesture enabled state
    public func toggleGesture(_ gestureType: GestureType) {
        var newEnabledGestures = settings.enabledGestures
        
        if newEnabledGestures.contains(gestureType) {
            newEnabledGestures.remove(gestureType)
        } else {
            newEnabledGestures.insert(gestureType)
        }
        
        settings = GestureSettings(
            enabledGestures: newEnabledGestures,
            gestureSensitivities: settings.gestureSensitivities,
            gestureThresholds: settings.gestureThresholds,
            enabledZones: settings.enabledZones,
            simultaneousGestureRecognition: settings.simultaneousGestureRecognition,
            feedbackHaptics: settings.feedbackHaptics,
            advancedFeatures: settings.advancedFeatures
        )
        
        ProductionLogger.userAction("ModernGestureSettingsManager: Toggled \(gestureType.rawValue) gesture")
    }
    
    /// Update gesture threshold
    public func updateGestureThreshold(_ gestureType: GestureType, threshold: Double) {
        var newThresholds = settings.gestureThresholds
        newThresholds[gestureType] = max(1.0, min(200.0, threshold))
        
        settings = GestureSettings(
            enabledGestures: settings.enabledGestures,
            gestureSensitivities: settings.gestureSensitivities,
            gestureThresholds: newThresholds,
            enabledZones: settings.enabledZones,
            simultaneousGestureRecognition: settings.simultaneousGestureRecognition,
            feedbackHaptics: settings.feedbackHaptics,
            advancedFeatures: settings.advancedFeatures
        )
    }
    
    /// Reset to defaults
    public func resetToDefaults() {
        settings = .default
        ProductionLogger.userAction("ModernGestureSettingsManager: Reset to defaults")
    }
    
    /// Export settings as JSON
    public func exportSettings() -> String? {
        do {
            let data = try encoder.encode(settings)
            return String(data: data, encoding: .utf8)
        } catch {
            ProductionLogger.error("ModernGestureSettingsManager: Failed to export settings: \(error)")
            return nil
        }
    }
    
    /// Import settings from JSON
    public func importSettings(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        
        do {
            let importedSettings = try decoder.decode(GestureSettings.self, from: data)
            settings = importedSettings
            ProductionLogger.userAction("ModernGestureSettingsManager: Imported settings from JSON")
            return true
        } catch {
            ProductionLogger.error("ModernGestureSettingsManager: Failed to import settings: \(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            settings = .default
            ProductionLogger.debug("ModernGestureSettingsManager: Using default settings")
            return
        }
        
        do {
            settings = try decoder.decode(GestureSettings.self, from: data)
            ProductionLogger.debug("ModernGestureSettingsManager: Loaded settings from UserDefaults")
        } catch {
            ProductionLogger.error("ModernGestureSettingsManager: Failed to decode settings: \(error)")
            settings = .default
        }
    }
    
    private func saveSettings() {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            ProductionLogger.debug("ModernGestureSettingsManager: Saved settings to UserDefaults")
        } catch {
            ProductionLogger.error("ModernGestureSettingsManager: Failed to encode settings: \(error)")
        }
    }
}

// MARK: - Gesture Settings Model

/// Comprehensive gesture settings configuration
public struct GestureSettings: Codable, Equatable, Sendable {
    
    // MARK: - Core Settings
    
    /// Gestures that are currently enabled
    public let enabledGestures: Set<GestureType>
    
    /// Sensitivity multipliers for each gesture type (0.1 to 3.0)
    public let gestureSensitivities: [GestureType: Double]
    
    /// Detection thresholds for each gesture type
    public let gestureThresholds: [GestureType: Double]
    
    /// Enabled interaction zones
    public let enabledZones: Set<InteractionZone.ZoneType>
    
    /// Whether simultaneous gesture recognition is enabled
    public let simultaneousGestureRecognition: Bool
    
    /// Whether haptic feedback is enabled for gestures
    public let feedbackHaptics: Bool
    
    /// Advanced gesture features
    public let advancedFeatures: AdvancedGestureFeatures
    
    // MARK: - Initialization
    
    public init(
        enabledGestures: Set<GestureType> = Set(GestureType.allCases),
        gestureSensitivities: [GestureType: Double] = [:],
        gestureThresholds: [GestureType: Double] = [:],
        enabledZones: Set<InteractionZone.ZoneType> = Set(InteractionZone.ZoneType.allCases),
        simultaneousGestureRecognition: Bool = true,
        feedbackHaptics: Bool = true,
        advancedFeatures: AdvancedGestureFeatures = .default
    ) {
        self.enabledGestures = enabledGestures
        self.gestureSensitivities = Self.fillDefaultSensitivities(gestureSensitivities)
        self.gestureThresholds = Self.fillDefaultThresholds(gestureThresholds)
        self.enabledZones = enabledZones
        self.simultaneousGestureRecognition = simultaneousGestureRecognition
        self.feedbackHaptics = feedbackHaptics
        self.advancedFeatures = advancedFeatures
    }
    
    // MARK: - Computed Properties
    
    /// Whether pinch-to-zoom is enabled
    public var isPinchZoomEnabled: Bool {
        return enabledGestures.contains(.pinch) || enabledGestures.contains(.magnify)
    }
    
    /// Whether swipe navigation is enabled
    public var isSwipeNavigationEnabled: Bool {
        return enabledGestures.contains(.swipeLeft) || enabledGestures.contains(.swipeRight)
    }
    
    /// Whether pan gestures are enabled
    public var isPanEnabled: Bool {
        return enabledGestures.contains(.pan)
    }
    
    /// Whether tap gestures are enabled
    public var isTapEnabled: Bool {
        return enabledGestures.contains(.tap) || enabledGestures.contains(.doubleTap)
    }
    
    // MARK: - Helper Methods
    
    /// Get sensitivity for a specific gesture type
    public func sensitivity(for gestureType: GestureType) -> Double {
        return gestureSensitivities[gestureType] ?? 1.0
    }
    
    /// Get threshold for a specific gesture type
    public func threshold(for gestureType: GestureType) -> Double {
        return gestureThresholds[gestureType] ?? Self.defaultThreshold(for: gestureType)
    }
    
    // MARK: - Static Methods
    
    private static func fillDefaultSensitivities(_ provided: [GestureType: Double]) -> [GestureType: Double] {
        var result = provided
        
        for gestureType in GestureType.allCases {
            if result[gestureType] == nil {
                result[gestureType] = 1.0
            }
        }
        
        return result
    }
    
    private static func fillDefaultThresholds(_ provided: [GestureType: Double]) -> [GestureType: Double] {
        var result = provided
        
        for gestureType in GestureType.allCases {
            if result[gestureType] == nil {
                result[gestureType] = defaultThreshold(for: gestureType)
            }
        }
        
        return result
    }
    
    private static func defaultThreshold(for gestureType: GestureType) -> Double {
        switch gestureType {
        case .tap: return 2.0
        case .doubleTap: return 5.0
        case .longPress: return 50.0
        case .pan: return 10.0
        case .pinch: return 0.1
        case .rotation: return 5.0
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown: return 50.0
        case .magnify: return 0.1
        case .smartMagnify: return 10.0
        case .hover: return 1.0
        }
    }
    
    // MARK: - Presets
    
    public static let `default` = GestureSettings()
    
    public static let minimal = GestureSettings(
        enabledGestures: [.tap, .doubleTap, .swipeLeft, .swipeRight],
        simultaneousGestureRecognition: false,
        feedbackHaptics: false,
        advancedFeatures: .minimal
    )
    
    public static let touchOptimized = GestureSettings(
        enabledGestures: Set(GestureType.allCases),
        simultaneousGestureRecognition: true,
        feedbackHaptics: true,
        advancedFeatures: .enhanced
    )
    
    public static let performanceOptimized = GestureSettings(
        enabledGestures: [.tap, .doubleTap, .pinch, .pan, .swipeLeft, .swipeRight],
        simultaneousGestureRecognition: false,
        feedbackHaptics: false,
        advancedFeatures: .minimal
    )
}

// MARK: - Advanced Gesture Features

/// Advanced features for gesture handling
public struct AdvancedGestureFeatures: Codable, Equatable, Sendable {
    
    /// Enable momentum and inertia effects
    public let momentumEnabled: Bool
    
    /// Enable smart gesture prediction
    public let predictionEnabled: Bool
    
    /// Enable gesture conflict resolution
    public let conflictResolutionEnabled: Bool
    
    /// Enable gesture analytics collection
    public let analyticsEnabled: Bool
    
    /// Enable dynamic sensitivity adjustment
    public let adaptiveSensitivityEnabled: Bool
    
    /// Enable multi-finger gesture support
    public let multiFingerGesturesEnabled: Bool
    
    /// Enable gesture customization
    public let customGesturesEnabled: Bool
    
    public init(
        momentumEnabled: Bool = true,
        predictionEnabled: Bool = false,
        conflictResolutionEnabled: Bool = true,
        analyticsEnabled: Bool = true,
        adaptiveSensitivityEnabled: Bool = false,
        multiFingerGesturesEnabled: Bool = true,
        customGesturesEnabled: Bool = false
    ) {
        self.momentumEnabled = momentumEnabled
        self.predictionEnabled = predictionEnabled
        self.conflictResolutionEnabled = conflictResolutionEnabled
        self.analyticsEnabled = analyticsEnabled
        self.adaptiveSensitivityEnabled = adaptiveSensitivityEnabled
        self.multiFingerGesturesEnabled = multiFingerGesturesEnabled
        self.customGesturesEnabled = customGesturesEnabled
    }
    
    public static let `default` = AdvancedGestureFeatures()
    
    public static let minimal = AdvancedGestureFeatures(
        momentumEnabled: false,
        predictionEnabled: false,
        conflictResolutionEnabled: true,
        analyticsEnabled: false,
        adaptiveSensitivityEnabled: false,
        multiFingerGesturesEnabled: false,
        customGesturesEnabled: false
    )
    
    public static let enhanced = AdvancedGestureFeatures(
        momentumEnabled: true,
        predictionEnabled: true,
        conflictResolutionEnabled: true,
        analyticsEnabled: true,
        adaptiveSensitivityEnabled: true,
        multiFingerGesturesEnabled: true,
        customGesturesEnabled: true
    )
}

// MARK: - Preset System

extension GestureSettings {
    
    /// Predefined gesture setting presets
    public enum Preset: String, CaseIterable, Identifiable {
        case `default` = "default"
        case minimal = "minimal"
        case touchOptimized = "touchOptimized"
        case performanceOptimized = "performanceOptimized"
        
        public var id: String { rawValue }
        
        public var name: String {
            switch self {
            case .default: return "Default"
            case .minimal: return "Minimal"
            case .touchOptimized: return "Touch Optimized"
            case .performanceOptimized: return "Performance Optimized"
            }
        }
        
        public var description: String {
            switch self {
            case .default: return "Balanced gesture settings for most users"
            case .minimal: return "Essential gestures only for better performance"
            case .touchOptimized: return "All gestures enabled with enhanced touch support"
            case .performanceOptimized: return "Optimized for large photo collections"
            }
        }
        
        public var settings: GestureSettings {
            switch self {
            case .default: return .default
            case .minimal: return .minimal
            case .touchOptimized: return .touchOptimized
            case .performanceOptimized: return .performanceOptimized
            }
        }
    }
}

// MARK: - InteractionZone Extension

extension InteractionZone {
    /// Gesture interaction zone types
    public enum ZoneType: String, CaseIterable, Codable, Sendable {
        case imageArea = "imageArea"
        case controlsArea = "controlsArea"
        case navigationArea = "navigationArea"
        case infoArea = "infoArea"
        case globalArea = "globalArea"
        
        public var name: String {
            switch self {
            case .imageArea: return "Image Area"
            case .controlsArea: return "Controls Area"
            case .navigationArea: return "Navigation Area"
            case .infoArea: return "Info Area"
            case .globalArea: return "Global Area"
            }
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when gesture settings change
    public static let gestureSettingsChanged = Notification.Name("gestureSettingsChanged")
}