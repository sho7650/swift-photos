import Foundation
import SwiftUI

/// Domain value object representing a section within a settings category
/// Groups related settings items with clear organizational structure
public struct SettingsSection: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let displayOrder: Int
    public let isEnabled: Bool
    public let items: [SettingsItem]
    public let description: String
    public let icon: String?
    public let searchKeywords: [String]
    
    public init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int,
        isEnabled: Bool = true,
        items: [SettingsItem] = [],
        description: String = "",
        icon: String? = nil,
        searchKeywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.isEnabled = isEnabled
        self.items = items
        self.description = description
        self.icon = icon
        self.searchKeywords = searchKeywords
    }
    
    // MARK: - Business Logic
    
    /// Check if this section matches a search query
    public func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        
        // Check section name
        if name.lowercased().contains(query) { return true }
        
        // Check description
        if description.lowercased().contains(query) { return true }
        
        // Check search keywords
        if searchKeywords.contains(where: { $0.lowercased().contains(query) }) { return true }
        
        // Check items
        return items.contains { $0.matches(searchQuery: query) }
    }
    
    /// Get enabled items only
    public var enabledItems: [SettingsItem] {
        return items.filter { $0.isEnabled }
    }
    
    /// Count of enabled items
    public var enabledItemsCount: Int {
        return enabledItems.count
    }
    
    /// Check if section has any visible content
    public var hasVisibleContent: Bool {
        return isEnabled && enabledItemsCount > 0
    }
    
    /// Get items matching a search query
    public func itemsMatching(searchQuery: String) -> [SettingsItem] {
        return items.filter { $0.matches(searchQuery: searchQuery) }
    }
    
    // MARK: - Display Properties
    
    /// Display name with fallback
    public var displayName: String {
        return name.isEmpty ? "Settings" : name
    }
    
    /// Short description for UI display
    public var shortDescription: String {
        return description.count > 80 ? String(description.prefix(77)) + "..." : description
    }
    
    /// Section icon with fallback
    public var displayIcon: String {
        return icon ?? "slider.horizontal.3"
    }
}

/// Individual settings item within a section
public struct SettingsItem: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let type: SettingsItemType
    public let isEnabled: Bool
    public let searchKeywords: [String]
    public let helpText: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        type: SettingsItemType,
        isEnabled: Bool = true,
        searchKeywords: [String] = [],
        helpText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.isEnabled = isEnabled
        self.searchKeywords = searchKeywords
        self.helpText = helpText
    }
    
    // MARK: - Business Logic
    
    /// Check if this item matches a search query
    public func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        
        // Check item name
        if name.lowercased().contains(query) { return true }
        
        // Check description
        if description.lowercased().contains(query) { return true }
        
        // Check help text
        if let helpText = helpText, helpText.lowercased().contains(query) { return true }
        
        // Check search keywords
        return searchKeywords.contains(where: { $0.lowercased().contains(query) })
    }
    
    // MARK: - Display Properties
    
    /// Display name with fallback
    public var displayName: String {
        return name.isEmpty ? "Setting" : name
    }
    
    /// Short description for UI display
    public var shortDescription: String {
        return description.count > 60 ? String(description.prefix(57)) + "..." : description
    }
}

/// Types of settings items that can be displayed
public enum SettingsItemType: String, Codable, CaseIterable, Sendable {
    case toggle = "toggle"
    case slider = "slider"
    case picker = "picker"
    case text = "text"
    case button = "button"
    case preset = "preset"
    case section = "section"
    case info = "info"
    
    /// Icon for the settings item type
    public var icon: String {
        switch self {
        case .toggle:
            return "switch.2"
        case .slider:
            return "slider.horizontal.3"
        case .picker:
            return "list.bullet"
        case .text:
            return "textformat"
        case .button:
            return "button.horizontal"
        case .preset:
            return "square.grid.2x2"
        case .section:
            return "folder"
        case .info:
            return "info.circle"
        }
    }
    
    /// Display name for the type
    public var displayName: String {
        switch self {
        case .toggle:
            return "Toggle"
        case .slider:
            return "Slider"
        case .picker:
            return "Picker"
        case .text:
            return "Text Field"
        case .button:
            return "Button"
        case .preset:
            return "Presets"
        case .section:
            return "Section"
        case .info:
            return "Information"
        }
    }
}

// MARK: - Predefined Sections

extension SettingsSection {
    
    // MARK: - Performance Sections
    
    public static let performancePresets = SettingsSection(
        name: "Performance Presets",
        displayOrder: 1,
        description: "Quick presets optimized for different collection sizes",
        icon: "speedometer",
        searchKeywords: ["preset", "quick", "collection", "size", "optimization"]
    )
    
    public static let memoryManagement = SettingsSection(
        name: "Memory Management",
        displayOrder: 2,
        description: "Control memory usage and caching behavior",
        icon: "memorychip",
        searchKeywords: ["memory", "cache", "window", "usage", "management"]
    )
    
    public static let concurrencySettings = SettingsSection(
        name: "Concurrency",
        displayOrder: 3,
        description: "Configure concurrent loading and processing",
        icon: "cpu",
        searchKeywords: ["concurrent", "parallel", "loading", "threads"]
    )
    
    // MARK: - Slideshow Sections
    
    public static let slideshowTiming = SettingsSection(
        name: "Timing",
        displayOrder: 1,
        description: "Configure slideshow duration and intervals",
        icon: "timer",
        searchKeywords: ["timing", "duration", "interval", "speed"]
    )
    
    public static let slideshowBehavior = SettingsSection(
        name: "Behavior",
        displayOrder: 2,
        description: "Control automatic playback and looping",
        icon: "play.circle",
        searchKeywords: ["behavior", "auto", "loop", "playback"]
    )
    
    public static let slideshowPresets = SettingsSection(
        name: "Slideshow Presets",
        displayOrder: 3,
        description: "Quick preset configurations for common scenarios",
        icon: "square.grid.2x2",
        searchKeywords: ["preset", "quick", "default", "fast", "slow"]
    )
    
    // MARK: - Sorting Sections
    
    public static let sortingMethods = SettingsSection(
        name: "Sort Methods",
        displayOrder: 1,
        description: "Choose how photos are ordered",
        icon: "arrow.up.arrow.down",
        searchKeywords: ["method", "order", "alphabetical", "chronological", "size"]
    )
    
    public static let randomization = SettingsSection(
        name: "Randomization",
        displayOrder: 2,
        description: "Configure random sorting behavior",
        icon: "shuffle",
        searchKeywords: ["random", "shuffle", "seed", "chaos"]
    )
    
    public static let sortingPresets = SettingsSection(
        name: "Sorting Presets",
        displayOrder: 3,
        description: "Quick sorting configurations",
        icon: "square.grid.2x2",
        searchKeywords: ["preset", "quick", "alphabetical", "chronological"]
    )
    
    // MARK: - Transition Sections
    
    public static let transitionEffects = SettingsSection(
        name: "Effects",
        displayOrder: 1,
        description: "Choose transition animation effects",
        icon: "rectangle.stack.person.crop",
        searchKeywords: ["effect", "animation", "fade", "slide", "zoom"]
    )
    
    public static let transitionTiming = SettingsSection(
        name: "Timing & Easing",
        displayOrder: 2,
        description: "Control animation duration and easing",
        icon: "timer",
        searchKeywords: ["timing", "duration", "easing", "smooth", "speed"]
    )
    
    public static let transitionPresets = SettingsSection(
        name: "Transition Presets",
        displayOrder: 3,
        description: "Predefined transition configurations",
        icon: "square.grid.2x2",
        searchKeywords: ["preset", "simple", "elegant", "dynamic", "cinematic"]
    )
    
    // MARK: - Interface Sections
    
    public static let controlsVisibility = SettingsSection(
        name: "Controls Visibility",
        displayOrder: 1,
        description: "Configure when and how controls are shown",
        icon: "eye",
        searchKeywords: ["visibility", "controls", "hide", "show", "auto"]
    )
    
    public static let overlaySettings = SettingsSection(
        name: "Overlay Settings",
        displayOrder: 2,
        description: "Customize overlay appearance and behavior",
        icon: "layers",
        searchKeywords: ["overlay", "blur", "opacity", "appearance"]
    )
    
    public static let interactionSettings = SettingsSection(
        name: "Interaction",
        displayOrder: 3,
        description: "Configure mouse and gesture behavior",
        icon: "hand.point.up",
        searchKeywords: ["interaction", "mouse", "gesture", "touch", "hover"]
    )
    
    // MARK: - File Management Sections
    
    public static let recentFilesSettings = SettingsSection(
        name: "Recent Files",
        displayOrder: 1,
        description: "Configure recent folders behavior",
        icon: "clock",
        searchKeywords: ["recent", "history", "files", "folders", "cleanup"]
    )
    
    public static let fileAccess = SettingsSection(
        name: "File Access",
        displayOrder: 2,
        description: "Security and permissions settings",
        icon: "lock",
        searchKeywords: ["security", "permissions", "access", "sandbox"]
    )
    
    public static let importExport = SettingsSection(
        name: "Import & Export",
        displayOrder: 3,
        description: "Data import and export options",
        icon: "square.and.arrow.up",
        searchKeywords: ["import", "export", "data", "backup", "restore"]
    )
    
    // MARK: - Keyboard Sections
    
    public static let navigationShortcuts = SettingsSection(
        name: "Navigation",
        displayOrder: 1,
        description: "Shortcuts for slideshow navigation",
        icon: "arrow.left.arrow.right",
        searchKeywords: ["navigation", "arrow", "space", "play", "pause"]
    )
    
    public static let interfaceShortcuts = SettingsSection(
        name: "Interface",
        displayOrder: 2,
        description: "Shortcuts for interface control",
        icon: "command",
        searchKeywords: ["interface", "settings", "info", "controls", "hide"]
    )
    
    public static let systemShortcuts = SettingsSection(
        name: "System",
        displayOrder: 3,
        description: "System-level keyboard shortcuts",
        icon: "keyboard",
        searchKeywords: ["system", "open", "folder", "quit", "close"]
    )
    
    // MARK: - Language Sections
    
    public static let languageSelection = SettingsSection(
        name: "Language Selection",
        displayOrder: 1,
        description: "Choose application language and region",
        icon: "globe",
        searchKeywords: ["language", "region", "locale", "interface", "translation"]
    )
    
    public static let regionalFormatting = SettingsSection(
        name: "Regional Formatting",
        displayOrder: 2,
        description: "Configure date, number, and time formats",
        icon: "textformat.123",
        searchKeywords: ["format", "date", "number", "time", "regional", "measurement"]
    )
    
    public static let localizationPreferences = SettingsSection(
        name: "Localization Preferences",
        displayOrder: 3,
        description: "Advanced localization and accessibility options",
        icon: "gear.badge",
        searchKeywords: ["localization", "accessibility", "preferences", "advanced", "sorting"]
    )
    
    // MARK: - Advanced Sections
    
    public static let debuggingOptions = SettingsSection(
        name: "Debugging",
        displayOrder: 1,
        description: "Debug logging and diagnostic options",
        icon: "ant",
        searchKeywords: ["debug", "logging", "diagnostic", "verbose"]
    )
    
    public static let experimentalFeatures = SettingsSection(
        name: "Experimental",
        displayOrder: 2,
        description: "Experimental and beta features",
        icon: "flask",
        searchKeywords: ["experimental", "beta", "advanced", "test"]
    )
    
    public static let technicalInfo = SettingsSection(
        name: "Technical Information",
        displayOrder: 3,
        description: "System and application information",
        icon: "info.circle",
        searchKeywords: ["technical", "system", "version", "info"]
    )
}