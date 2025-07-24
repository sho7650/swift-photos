import Foundation
import SwiftUI

/// Domain service for managing settings categories and their organization
/// Provides business logic for category management, search, and navigation
@MainActor
public class SettingsCategoryService: ObservableObject {
    
    // MARK: - Category Management
    
    /// Get all available settings categories
    public func getAllCategories() -> [SettingsCategory] {
        return buildCategoriesWithSections()
    }
    
    /// Get categories matching a search query
    public func searchCategories(query: String) -> [SettingsCategory] {
        let categories = getAllCategories()
        guard !query.isEmpty else { return categories }
        
        return categories.compactMap { category in
            if category.matches(searchQuery: query) {
                // Return category with filtered sections if needed
                let matchingSections = category.sections.filter { $0.matches(searchQuery: query) }
                if matchingSections.count != category.sections.count {
                    return SettingsCategory(
                        id: category.id,
                        name: category.name,
                        systemIcon: category.systemIcon,
                        displayOrder: category.displayOrder,
                        isEnabled: category.isEnabled,
                        sections: matchingSections,
                        searchKeywords: category.searchKeywords,
                        description: category.description
                    )
                }
                return category
            }
            return nil
        }
    }
    
    /// Get a specific category by ID
    public func getCategory(id: UUID) -> SettingsCategory? {
        return getAllCategories().first { $0.id == id }
    }
    
    /// Get categories sorted by display order
    public func getCategoriesSorted() -> [SettingsCategory] {
        return getAllCategories().sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// Get enabled categories only
    public func getEnabledCategories() -> [SettingsCategory] {
        return getAllCategories().filter { $0.isEnabled && $0.hasVisibleContent }
    }
    
    // MARK: - Section Management
    
    /// Get sections for a specific category
    public func getSections(for categoryId: UUID) -> [SettingsSection] {
        return getCategory(id: categoryId)?.sections ?? []
    }
    
    /// Get a specific section by ID within a category
    public func getSection(id: UUID, in categoryId: UUID) -> SettingsSection? {
        return getSections(for: categoryId).first { $0.id == id }
    }
    
    /// Search sections across all categories
    public func searchSections(query: String) -> [(category: SettingsCategory, sections: [SettingsSection])] {
        let categories = getAllCategories()
        guard !query.isEmpty else {
            return categories.map { (category: $0, sections: $0.sections) }
        }
        
        return categories.compactMap { category in
            let matchingSections = category.sections.filter { $0.matches(searchQuery: query) }
            return matchingSections.isEmpty ? nil : (category: category, sections: matchingSections)
        }
    }
    
    // MARK: - Settings Items Management
    
    /// Get all settings items across all categories
    public func getAllSettingsItems() -> [SettingsItem] {
        return getAllCategories().flatMap { $0.allSettingsItems }
    }
    
    /// Search settings items across all categories
    public func searchSettingsItems(query: String) -> [(category: SettingsCategory, section: SettingsSection, items: [SettingsItem])] {
        let categories = getAllCategories()
        guard !query.isEmpty else {
            return categories.flatMap { category in
                category.sections.map { section in
                    (category: category, section: section, items: section.items)
                }
            }
        }
        
        var results: [(category: SettingsCategory, section: SettingsSection, items: [SettingsItem])] = []
        
        for category in categories {
            for section in category.sections {
                let matchingItems = section.items.filter { $0.matches(searchQuery: query) }
                if !matchingItems.isEmpty {
                    results.append((category: category, section: section, items: matchingItems))
                }
            }
        }
        
        return results
    }
    
    // MARK: - Navigation Helpers
    
    /// Get navigation breadcrumb for a category
    public func getBreadcrumb(for categoryId: UUID) -> [String] {
        guard let category = getCategory(id: categoryId) else { return [] }
        return ["Settings", category.name]
    }
    
    /// Get navigation breadcrumb for a section within a category
    public func getBreadcrumb(for sectionId: UUID, in categoryId: UUID) -> [String] {
        guard let category = getCategory(id: categoryId),
              let section = getSection(id: sectionId, in: categoryId) else { return [] }
        return ["Settings", category.name, section.name]
    }
    
    /// Get suggested categories based on current selection
    public func getSuggestedCategories(currentCategoryId: UUID?) -> [SettingsCategory] {
        let categories = getEnabledCategories()
        
        // If no current selection, return first few categories
        guard let currentId = currentCategoryId,
              let currentCategory = getCategory(id: currentId) else {
            return Array(categories.prefix(3))
        }
        
        // Return categories with similar keywords or adjacent display order
        let currentOrder = currentCategory.displayOrder
        return categories.filter { category in
            // Adjacent categories
            if abs(category.displayOrder - currentOrder) <= 1 && category.id != currentId {
                return true
            }
            
            // Categories with overlapping keywords
            let commonKeywords = Set(category.searchKeywords).intersection(Set(currentCategory.searchKeywords))
            return commonKeywords.count >= 2
        }
    }
    
    // MARK: - Statistics and Analytics
    
    /// Get statistics about settings organization
    public func getStatistics() -> SettingsCategoryStatistics {
        let categories = getAllCategories()
        let enabledCategories = categories.filter { $0.isEnabled }
        let allSections = categories.flatMap { $0.sections }
        let enabledSections = allSections.filter { $0.isEnabled }
        let allItems = allSections.flatMap { $0.items }
        let enabledItems = allItems.filter { $0.isEnabled }
        
        return SettingsCategoryStatistics(
            totalCategories: categories.count,
            enabledCategories: enabledCategories.count,
            totalSections: allSections.count,
            enabledSections: enabledSections.count,
            totalItems: allItems.count,
            enabledItems: enabledItems.count,
            averageSectionsPerCategory: enabledCategories.isEmpty ? 0 : Double(enabledSections.count) / Double(enabledCategories.count),
            averageItemsPerSection: enabledSections.isEmpty ? 0 : Double(enabledItems.count) / Double(enabledSections.count)
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func buildCategoriesWithSections() -> [SettingsCategory] {
        var categories = SettingsCategory.defaultCategories
        
        // Build categories with their sections
        categories = categories.map { category in
            let sections = buildSectionsForCategory(category)
            return SettingsCategory(
                id: category.id,
                name: category.name,
                systemIcon: category.systemIcon,
                displayOrder: category.displayOrder,
                isEnabled: category.isEnabled,
                sections: sections,
                searchKeywords: category.searchKeywords,
                description: category.description
            )
        }
        
        return categories.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    private func buildSectionsForCategory(_ category: SettingsCategory) -> [SettingsSection] {
        switch category.name {
        case "Performance":
            return [
                .performancePresets,
                .memoryManagement,
                .concurrencySettings
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "Slideshow":
            return [
                .slideshowTiming,
                .slideshowBehavior,
                .slideshowPresets
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "Sorting":
            return [
                .sortingMethods,
                .randomization,
                .sortingPresets
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "Transitions":
            return [
                .transitionEffects,
                .transitionTiming,
                .transitionPresets
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "Interface":
            return [
                .controlsVisibility,
                .overlaySettings,
                .interactionSettings
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "File Management":
            return [
                .recentFilesSettings,
                .fileAccess,
                .importExport
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "Keyboard":
            return [
                .navigationShortcuts,
                .interfaceShortcuts,
                .systemShortcuts
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        case "Advanced":
            return [
                .debuggingOptions,
                .experimentalFeatures,
                .technicalInfo
            ].sorted { $0.displayOrder < $1.displayOrder }
            
        default:
            return []
        }
    }
}

/// Statistics about settings category organization
public struct SettingsCategoryStatistics: Codable, Equatable {
    public let totalCategories: Int
    public let enabledCategories: Int
    public let totalSections: Int
    public let enabledSections: Int
    public let totalItems: Int
    public let enabledItems: Int
    public let averageSectionsPerCategory: Double
    public let averageItemsPerSection: Double
    
    public init(
        totalCategories: Int,
        enabledCategories: Int,
        totalSections: Int,
        enabledSections: Int,
        totalItems: Int,
        enabledItems: Int,
        averageSectionsPerCategory: Double,
        averageItemsPerSection: Double
    ) {
        self.totalCategories = totalCategories
        self.enabledCategories = enabledCategories
        self.totalSections = totalSections
        self.enabledSections = enabledSections
        self.totalItems = totalItems
        self.enabledItems = enabledItems
        self.averageSectionsPerCategory = averageSectionsPerCategory
        self.averageItemsPerSection = averageItemsPerSection
    }
    
    /// Human-readable summary of statistics
    public var summary: String {
        return """
        Settings Organization:
        • \(enabledCategories) categories (\(totalCategories) total)
        • \(enabledSections) sections (\(totalSections) total)
        • \(enabledItems) settings (\(totalItems) total)
        • \(String(format: "%.1f", averageSectionsPerCategory)) sections per category
        • \(String(format: "%.1f", averageItemsPerSection)) settings per section
        """
    }
}