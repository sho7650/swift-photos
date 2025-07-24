import SwiftUI

/// Sort settings view for configuring photo ordering in slideshow
/// Provides controls for sort order, direction, and random seed management
struct SortSettingsView: View {
    @ObservedObject var settings: SortSettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Sort Presets Section
            SortSettingsSection(
                title: "Sort Presets",
                icon: "arrow.up.arrow.down",
                description: "Quick sorting configurations for common use cases"
            ) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Alphabetical") { settings.applyPreset(.alphabetical) }
                            .buttonStyle(.bordered)
                        Button("Chronological") { settings.applyPreset(.chronological) }
                            .buttonStyle(.bordered)
                        Button("Newest First") { settings.applyPreset(.newestFirst) }
                            .buttonStyle(.bordered)
                        Button("Largest First") { settings.applyPreset(.largestFirst) }
                            .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Button("Random") { settings.applyPreset(.randomized) }
                            .buttonStyle(.bordered)
                        
                        if settings.settings.order == .random {
                            Button("New Random Order") {
                                settings.regenerateRandomSeed()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            
            // Sort Order Section
            SortSettingsSection(
                title: "Sort Order",
                icon: "list.bullet",
                description: "Choose how photos are ordered in the slideshow"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Sort Order", selection: Binding(
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
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            // Sort Direction Section (not applicable for random)
            if settings.settings.order != .random {
                SortSettingsSection(
                    title: "Sort Direction",
                    icon: "arrow.up.down",
                    description: "Choose ascending or descending order"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Sort Direction", selection: Binding(
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
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }
            
            // Current Settings Summary Section
            SortSettingsSection(
                title: "Current Settings",
                icon: "info.circle",
                description: "Summary of your current sort configuration"
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
                title: "Performance Information",
                icon: "speedometer",
                description: "How sorting affects slideshow performance"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("💡")
                        Text("Performance Tip")
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
    SortSettingsView(settings: SortSettingsManager())
        .frame(width: 500, height: 600)
}