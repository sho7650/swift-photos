import SwiftUI
import AppKit

/// Modern Music.app-style settings window with sidebar navigation
/// Follows macOS design patterns with native sidebar and content area layout
public struct SidebarSettingsWindow: View {
    var performanceSettings: ModernPerformanceSettingsManager
    var slideshowSettings: ModernSlideshowSettingsManager
    var sortSettings: ModernSortSettingsManager
    var transitionSettings: ModernTransitionSettingsManager
    var uiControlSettings: ModernUIControlSettingsManager
    @EnvironmentObject var recentFilesManager: RecentFilesManager
    
    @StateObject private var settingsCategoryService = SettingsCategoryService()
    @State private var navigation = SettingsCategoryNavigation()
    @State private var searchText = ""
    @State private var showingResetConfirmation = false
    @State private var selectedCategory: SettingsCategory?
    
    private let sidebarWidth: CGFloat = 240
    private let minimumWindowWidth: CGFloat = 720
    private let minimumWindowHeight: CGFloat = 520
    
    public init(
        performanceSettings: ModernPerformanceSettingsManager,
        slideshowSettings: ModernSlideshowSettingsManager,
        sortSettings: ModernSortSettingsManager,
        transitionSettings: ModernTransitionSettingsManager,
        uiControlSettings: ModernUIControlSettingsManager
    ) {
        self.performanceSettings = performanceSettings
        self.slideshowSettings = slideshowSettings
        self.sortSettings = sortSettings
        self.transitionSettings = transitionSettings
        self.uiControlSettings = uiControlSettings
    }
    
    public var body: some View {
        NavigationSplitView(sidebar: {
            sidebarContent
        }, detail: {
            detailContent
        })
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: minimumWindowWidth,
            minHeight: minimumWindowHeight
        )
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            setupInitialSelection()
        }
        .alert("Reset All Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    // MARK: - Sidebar Content
    
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // Categories list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCategories) { category in
                        CategoryRowView(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            onSelect: {
                                selectCategory(category)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            // Bottom section with app info and reset
            bottomSidebarSection
        }
        .frame(width: sidebarWidth)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search settings...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit {
                    updateNavigationForSearch()
                }
                .onChange(of: searchText) {
                    updateNavigationForSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private var bottomSidebarSection: some View {
        VStack(spacing: 8) {
            Divider()
            
            // App version info
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swift Photos")
                        .font(.system(size: 12, weight: .medium))
                    Text("Version 1.0")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Reset button
            Button("Reset All Settings") {
                showingResetConfirmation = true
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Detail Content
    
    private var detailContent: some View {
        Group {
            if let category = selectedCategory {
                CategoryDetailView(
                    category: category,
                    performanceSettings: performanceSettings,
                    slideshowSettings: slideshowSettings,
                    sortSettings: sortSettings,
                    transitionSettings: transitionSettings,
                    uiControlSettings: uiControlSettings,
                    recentFilesManager: recentFilesManager,
                    searchQuery: searchText
                )
            } else {
                welcomeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Swift Photos Settings")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Select a category from the sidebar to configure your slideshow experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Text("Quick Actions")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    QuickActionButton(
                        title: "Performance",
                        icon: "speedometer",
                        description: "Optimize for your collection size"
                    ) {
                        selectCategoryByName("Performance")
                    }
                    
                    QuickActionButton(
                        title: "Slideshow",
                        icon: "play.circle",
                        description: "Configure timing and behavior"
                    ) {
                        selectCategoryByName("Slideshow")
                    }
                    
                    QuickActionButton(
                        title: "Transitions",
                        icon: "rectangle.stack.person.crop",
                        description: "Set up beautiful animations"
                    ) {
                        selectCategoryByName("Transitions")
                    }
                }
            }
        }
        .frame(maxWidth: 400)
        .padding(40)
    }
    
    // MARK: - Computed Properties
    
    private var filteredCategories: [SettingsCategory] {
        if searchText.isEmpty {
            return settingsCategoryService.getEnabledCategories()
        } else {
            return settingsCategoryService.searchCategories(query: searchText)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialSelection() {
        // Select first category by default
        if selectedCategory == nil {
            selectedCategory = settingsCategoryService.getEnabledCategories().first
        }
    }
    
    private func selectCategory(_ category: SettingsCategory) {
        selectedCategory = category
        navigation = navigation.selecting(category.id)
    }
    
    private func selectCategoryByName(_ name: String) {
        if let category = settingsCategoryService.getEnabledCategories().first(where: { $0.name == name }) {
            selectCategory(category)
        }
    }
    
    private func updateNavigationForSearch() {
        navigation = navigation.searching(searchText)
    }
    
    private func resetAllSettings() {
        performanceSettings.resetToDefaults()
        slideshowSettings.resetToDefaults()
        sortSettings.resetToDefaults()
        transitionSettings.resetToDefaults()
        uiControlSettings.resetToDefaults()
        
        // Reset recent files configuration if available
        Task {
            await recentFilesManager.resetConfiguration()
        }
    }
}

// MARK: - Category Row View

private struct CategoryRowView: View {
    let category: SettingsCategory
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: category.safeSystemIcon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    if !category.shortDescription.isEmpty {
                        Text(category.shortDescription)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if category.enabledSectionsCount > 0 {
                    Text("\(category.enabledSectionsCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 100, height: 80)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Detail View

private struct CategoryDetailView: View {
    let category: SettingsCategory
    let performanceSettings: ModernPerformanceSettingsManager
    let slideshowSettings: ModernSlideshowSettingsManager
    let sortSettings: ModernSortSettingsManager
    let transitionSettings: ModernTransitionSettingsManager
    let uiControlSettings: ModernUIControlSettingsManager
    let recentFilesManager: RecentFilesManager
    let searchQuery: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Category header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: category.safeSystemIcon)
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        
                        Text(category.displayName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    if !category.description.isEmpty {
                        Text(category.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                // Category-specific content
                Group {
                    switch category.name {
                    case "Performance":
                        PerformanceSettingsView(settings: performanceSettings)
                    case "Slideshow":
                        SlideshowSettingsView(settings: slideshowSettings)
                    case "Sorting":
                        SortSettingsView(settings: sortSettings)
                    case "Transitions":
                        TransitionSettingsView(settings: transitionSettings)
                    case "Interface":
                        InterfaceSettingsView(settings: uiControlSettings)
                    case "File Management":
                        FileManagementSettingsView(recentFilesManager: recentFilesManager)
                    case "Keyboard":
                        KeyboardShortcutsView()
                    case "Advanced":
                        AdvancedSettingsView()
                    default:
                        Text("Settings for \(category.name) will be implemented here.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    SidebarSettingsWindow(
        performanceSettings: ModernPerformanceSettingsManager(),
        slideshowSettings: ModernSlideshowSettingsManager(),
        sortSettings: ModernSortSettingsManager(),
        transitionSettings: ModernTransitionSettingsManager(),
        uiControlSettings: ModernUIControlSettingsManager()
    )
    .environmentObject(RecentFilesManager())
}