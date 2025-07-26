import SwiftUI

/// Sort settings view for configuring photo ordering in slideshow
/// Provides controls for sort order, direction, and random seed management
struct SortSettingsView: View {
    var settings: ModernSortSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Sort Presets Section
            SortSettingsSection(
                title: L10n.SettingsString.sortPresets(),
                icon: "arrow.up.arrow.down",
                description: L10n.SettingsString.sortPresetsDescription()
            ) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button(L10n.ButtonString.alphabetical()) { settings.updateSettings(.alphabetical) }
                            .buttonStyle(.bordered)
                        Button(L10n.ButtonString.chronological()) { settings.updateSettings(.chronological) }
                            .buttonStyle(.bordered)
                        Button(L10n.ButtonString.newestFirst()) { settings.updateSettings(.newestFirst) }
                            .buttonStyle(.bordered)
                        Button(L10n.ButtonString.largestFirst()) { settings.updateSettings(.largestFirst) }
                            .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Button(L10n.ButtonString.random()) { settings.updateSettings(.randomized) }
                            .buttonStyle(.bordered)
                        
                        if settings.settings.order == .random {
                            Button(L10n.ButtonString.newRandomOrder()) {
                                settings.regenerateRandomSeed()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            
            // Sort Order Section
            SortSettingsSection(
                title: L10n.SettingsString.sortOrder(),
                icon: "list.bullet",
                description: L10n.SettingsString.sortOrderDescription()
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L10n.SettingsString.sortOrder(), selection: Binding(
                        get: { settings.settings.order },
                        set: { newOrder in
                            let newSettings = SortSettings(
                                order: newOrder,
                                direction: settings.settings.direction,
                                randomSeed: newOrder == .random ? UInt64.random(in: 0...UInt64.max) : settings.settings.randomSeed
                            )
                            settings.updateSettings(newSettings)
                        }
                    )) {
                        ForEach(SortSettings.SortOrder.allCases, id: \.self) { order in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.displayName)
                                Text(order.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Sort Direction Section (not applicable for random)
            if settings.settings.order != .random {
                SortSettingsSection(
                    title: L10n.SettingsString.sortDirection(),
                    icon: "arrow.up.down",
                    description: L10n.SettingsString.sortDirectionDescription()
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(L10n.SettingsString.sortDirection(), selection: Binding(
                            get: { settings.settings.direction },
                            set: { newDirection in
                                let newSettings = SortSettings(
                                    order: settings.settings.order,
                                    direction: newDirection,
                                    randomSeed: settings.settings.randomSeed
                                )
                                settings.updateSettings(newSettings)
                            }
                        )) {
                            ForEach(SortSettings.SortDirection.allCases, id: \.self) { direction in
                                HStack {
                                    Text(direction.symbol)
                                    Text(direction.displayName)
                                }
                                .tag(direction)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            
            // Current Settings Summary Section
            SortSettingsSection(
                title: L10n.SettingsString.currentSettings(),
                icon: "info.circle",
                description: L10n.SettingsString.currentSettingsDescription()
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Order:")
                            .foregroundColor(.secondary)
                        Text("\(settings.settings.order.displayName) \(settings.settings.order != .random ? settings.settings.direction.symbol : "")")
                            .fontWeight(.medium)
                    }
                    
                    if settings.settings.order == .random {
                        HStack {
                            Text("Seed:")
                                .foregroundColor(.secondary)
                            Text(String(settings.settings.randomSeed))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Performance Information Section
            SortSettingsSection(
                title: L10n.SettingsString.performanceInformation(),
                icon: "speedometer",
                description: L10n.SettingsString.performanceInformationDescription()
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("💡")
                        Text(L10n.UI.performanceTip)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Sorting files before slideshow improves image caching efficiency. Random sorting with a fixed seed ensures consistent order across sessions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if settings.settings.order == .fileName {
                        Text("• Alphabetical sorting provides fastest cache performance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if settings.settings.order == .creationDate || settings.settings.order == .modificationDate {
                        Text("• Date sorting groups related photos for better caching")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if settings.settings.order == .random {
                        Text("• Random order reduces cache efficiency but provides varied viewing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}

/// Reusable settings section component for sort settings
private struct SortSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let description: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            content()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SortSettingsView(settings: ModernSortSettingsManager())
        .frame(width: 500, height: 600)
}