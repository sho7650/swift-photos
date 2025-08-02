import Foundation
import SwiftUI

/// Domain value object representing a settings category in the sidebar navigation
/// Follows DDD principles with immutable design and business logic encapsulation
public struct SettingsCategory: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let systemIcon: String
    public let displayOrder: Int
    public let isEnabled: Bool
    public let sections: [SettingsSection]
    public let searchKeywords: [String]
    public let description: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        systemIcon: String,
        displayOrder: Int,
        isEnabled: Bool = true,
        sections: [SettingsSection] = [],
        searchKeywords: [String] = [],
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.systemIcon = systemIcon
        self.displayOrder = displayOrder
        self.isEnabled = isEnabled
        self.sections = sections
        self.searchKeywords = searchKeywords
        self.description = description
    }
    
    // MARK: - Business Logic
    
    /// Check if this category matches a search query
    public func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        
        // Check category name
        if name.lowercased().contains(query) { return true }
        
        // Check description
        if description.lowercased().contains(query) { return true }
        
        // Check search keywords
        if searchKeywords.contains(where: { $0.lowercased().contains(query) }) { return true }
        
        // Check sections
        return sections.contains { $0.matches(searchQuery: query) }
    }
    
    /// Get all settings items across all sections
    public var allSettingsItems: [SettingsItem] {
        return sections.flatMap { $0.items }
    }
    
    /// Count of enabled sections
    public var enabledSectionsCount: Int {
        return sections.filter { $0.isEnabled }.count
    }
    
    /// Check if category has any visible content
    public var hasVisibleContent: Bool {
        return isEnabled && enabledSectionsCount > 0
    }
    
    // MARK: - Display Properties
    
    /// Icon with fallback
    public var safeSystemIcon: String {
        return systemIcon.isEmpty ? "gear" : systemIcon
    }
    
    /// Display name with fallback
    public var displayName: String {
        return name.isEmpty ? "Settings" : name
    }
    
    /// Shortened description for UI display
    public var shortDescription: String {
        return description.count > 100 ? String(description.prefix(97)) + "..." : description
    }
}

// MARK: - Predefined Categories

extension SettingsCategory {
    /// Performance optimization settings
    public static let performance = SettingsCategory(
        name: "Performance",
        systemIcon: "speedometer",
        displayOrder: 1,
        searchKeywords: ["speed", "memory", "cache", "optimization", "performance", "concurrent", "window"],
        description: "Optimize slideshow performance for different collection sizes and system capabilities"
    )
    
    /// Slideshow behavior and timing settings
    public static let slideshow = SettingsCategory(
        name: "Slideshow",
        systemIcon: "play.circle",
        displayOrder: 2,
        searchKeywords: ["play", "auto", "timing", "duration", "loop", "interval", "automatic"],
        description: "Configure automatic slideshow behavior, timing, and playback options"
    )
    
    /// File sorting and organization settings
    public static let sorting = SettingsCategory(
        name: "Sorting",
        systemIcon: "arrow.up.arrow.down",
        displayOrder: 3,
        searchKeywords: ["sort", "order", "alphabetical", "chronological", "random", "arrange", "organize"],
        description: "Control how photos are ordered and organized in the slideshow"
    )
    
    /// Transition effects and animations
    public static let transitions = SettingsCategory(
        name: "Transitions", 
        systemIcon: "rectangle.stack.person.crop",
        displayOrder: 4,
        searchKeywords: ["animation", "effect", "fade", "slide", "zoom", "transition", "smooth"],
        description: "Configure smooth transition effects and animations between photos"
    )
    
    /// User interface and controls
    public static let interface = SettingsCategory(
        name: "Interface",
        systemIcon: "macwindow",
        displayOrder: 5,
        searchKeywords: ["ui", "controls", "overlay", "visibility", "mouse", "keyboard", "interaction"],
        description: "Customize user interface controls, visibility, and interaction behavior"
    )
    
    /// File menu and recent files
    public static let fileManagement = SettingsCategory(
        name: "File Management",
        systemIcon: "folder",
        displayOrder: 6,
        searchKeywords: ["file", "folder", "recent", "menu", "open", "import", "export"],
        description: "Manage file access, recent folders, and import/export options"
    )
    
    /// Keyboard shortcuts and accessibility
    public static let keyboard = SettingsCategory(
        name: "Keyboard",
        systemIcon: "keyboard",
        displayOrder: 7,
        searchKeywords: ["shortcut", "key", "keyboard", "accessibility", "navigation", "hotkey"],
        description: "View and customize keyboard shortcuts for slideshow control"
    )
    
    /// Language and localization settings
    public static let language = SettingsCategory(
        name: "Language",
        systemIcon: "globe",
        displayOrder: 8,
        searchKeywords: ["language", "localization", "region", "format", "locale", "translation", "international"],
        description: "Configure application language, regional formatting, and localization preferences"
    )
    
    /// Advanced settings and debugging
    public static let advanced = SettingsCategory(
        name: "Advanced",
        systemIcon: "gearshape.2",
        displayOrder: 9,
        searchKeywords: ["debug", "advanced", "technical", "logging", "developer", "experimental"],
        description: "Advanced configuration options and debugging features"
    )
    
    /// All default categories in display order
    public static let defaultCategories: [SettingsCategory] = [
        .performance,
        .slideshow, 
        .sorting,
        .transitions,
        .interface,
        .fileManagement,
        .keyboard,
        .language,
        .advanced
    ].sorted { $0.displayOrder < $1.displayOrder }
}

// MARK: - Category Navigation

/// Navigation state for settings categories
public struct SettingsCategoryNavigation: Codable, Equatable {
    public let selectedCategoryId: UUID?
    public let expandedCategoryIds: Set<UUID>
    public let searchQuery: String
    public let showSearchResults: Bool
    
    public init(
        selectedCategoryId: UUID? = nil,
        expandedCategoryIds: Set<UUID> = [],
        searchQuery: String = "",
        showSearchResults: Bool = false
    ) {
        self.selectedCategoryId = selectedCategoryId
        self.expandedCategoryIds = expandedCategoryIds
        self.searchQuery = searchQuery
        self.showSearchResults = showSearchResults
    }
    
    /// Check if a category is expanded
    public func isExpanded(_ categoryId: UUID) -> Bool {
        return expandedCategoryIds.contains(categoryId)
    }
    
    /// Check if a category is selected
    public func isSelected(_ categoryId: UUID) -> Bool {
        return selectedCategoryId == categoryId
    }
    
    /// Get navigation with category selection
    public func selecting(_ categoryId: UUID) -> SettingsCategoryNavigation {
        return SettingsCategoryNavigation(
            selectedCategoryId: categoryId,
            expandedCategoryIds: expandedCategoryIds,
            searchQuery: searchQuery,
            showSearchResults: showSearchResults
        )
    }
    
    /// Get navigation with category expansion toggle
    public func toggling(_ categoryId: UUID) -> SettingsCategoryNavigation {
        var newExpanded = expandedCategoryIds
        if expandedCategoryIds.contains(categoryId) {
            newExpanded.remove(categoryId)
        } else {
            newExpanded.insert(categoryId)
        }
        
        return SettingsCategoryNavigation(
            selectedCategoryId: selectedCategoryId,
            expandedCategoryIds: newExpanded,
            searchQuery: searchQuery,
            showSearchResults: showSearchResults
        )
    }
    
    /// Get navigation with search query
    public func searching(_ query: String) -> SettingsCategoryNavigation {
        return SettingsCategoryNavigation(
            selectedCategoryId: selectedCategoryId,
            expandedCategoryIds: expandedCategoryIds,
            searchQuery: query,
            showSearchResults: !query.isEmpty
        )
    }
}