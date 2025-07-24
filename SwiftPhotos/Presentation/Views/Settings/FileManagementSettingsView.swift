import SwiftUI

/// File management settings view for recent files and file access configuration
/// Integrates with the RecentFilesManager and provides comprehensive file management options
struct FileManagementSettingsView: View {
    @ObservedObject var recentFilesManager: RecentFilesManager
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Recent Files Configuration Section
            FileSettingsSection(
                title: "Recent Folders",
                icon: "clock",
                description: "Configure how recent folders are managed and displayed"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Enable recent files
                    Toggle("Show recent folders in File menu", isOn: Binding(
                        get: { recentFilesManager.configuration.enableRecentFiles },
                        set: { newValue in
                            do {
                                let newConfig = try MenuConfiguration(
                                    maxRecentFiles: recentFilesManager.configuration.maxRecentFiles,
                                    enableFileMenu: recentFilesManager.configuration.enableFileMenu,
                                    enableRecentFiles: newValue,
                                    showFullPaths: recentFilesManager.configuration.showFullPaths,
                                    autoCleanupInvalidFiles: recentFilesManager.configuration.autoCleanupInvalidFiles,
                                    recentFileExpirationInterval: recentFilesManager.configuration.recentFileExpirationInterval,
                                    groupRecentFilesByDirectory: recentFilesManager.configuration.groupRecentFilesByDirectory
                                )
                                Task { await recentFilesManager.updateConfiguration(newConfig) }
                            } catch {
                                print("Failed to update configuration: \(error)")
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    
                    if recentFilesManager.configuration.enableRecentFiles {
                        // Maximum recent files
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Maximum Recent Folders")
                                Spacer()
                                Text("\(recentFilesManager.configuration.maxRecentFiles)")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(recentFilesManager.configuration.maxRecentFiles) },
                                    set: { newValue in
                                        do {
                                            let newConfig = try MenuConfiguration(
                                                maxRecentFiles: Int(newValue),
                                                enableFileMenu: recentFilesManager.configuration.enableFileMenu,
                                                enableRecentFiles: recentFilesManager.configuration.enableRecentFiles,
                                                showFullPaths: recentFilesManager.configuration.showFullPaths,
                                                autoCleanupInvalidFiles: recentFilesManager.configuration.autoCleanupInvalidFiles,
                                                recentFileExpirationInterval: recentFilesManager.configuration.recentFileExpirationInterval,
                                                groupRecentFilesByDirectory: recentFilesManager.configuration.groupRecentFilesByDirectory
                                            )
                                            Task { await recentFilesManager.updateConfiguration(newConfig) }
                                        } catch {
                                            print("Failed to update configuration: \(error)")
                                        }
                                    }
                                ),
                                in: 5...50,
                                step: 1
                            )
                        }
                        
                        // Show full paths
                        Toggle("Show full paths in menu", isOn: Binding(
                            get: { recentFilesManager.configuration.showFullPaths },
                            set: { newValue in
                                do {
                                    let newConfig = try MenuConfiguration(
                                        maxRecentFiles: recentFilesManager.configuration.maxRecentFiles,
                                        enableFileMenu: recentFilesManager.configuration.enableFileMenu,
                                        enableRecentFiles: recentFilesManager.configuration.enableRecentFiles,
                                        showFullPaths: newValue,
                                        autoCleanupInvalidFiles: recentFilesManager.configuration.autoCleanupInvalidFiles,
                                        recentFileExpirationInterval: recentFilesManager.configuration.recentFileExpirationInterval,
                                        groupRecentFilesByDirectory: recentFilesManager.configuration.groupRecentFilesByDirectory
                                    )
                                    Task { await recentFilesManager.updateConfiguration(newConfig) }
                                } catch {
                                    print("Failed to update configuration: \(error)")
                                }
                            }
                        ))
                        
                        // Auto cleanup
                        Toggle("Automatically remove invalid folders", isOn: Binding(
                            get: { recentFilesManager.configuration.autoCleanupInvalidFiles },
                            set: { newValue in
                                do {
                                    let newConfig = try MenuConfiguration(
                                        maxRecentFiles: recentFilesManager.configuration.maxRecentFiles,
                                        enableFileMenu: recentFilesManager.configuration.enableFileMenu,
                                        enableRecentFiles: recentFilesManager.configuration.enableRecentFiles,
                                        showFullPaths: recentFilesManager.configuration.showFullPaths,
                                        autoCleanupInvalidFiles: newValue,
                                        recentFileExpirationInterval: recentFilesManager.configuration.recentFileExpirationInterval,
                                        groupRecentFilesByDirectory: recentFilesManager.configuration.groupRecentFilesByDirectory
                                    )
                                    Task { await recentFilesManager.updateConfiguration(newConfig) }
                                } catch {
                                    print("Failed to update configuration: \(error)")
                                }
                            }
                        ))
                    }
                }
            }
            
            // Recent Files Statistics Section
            if let statistics = recentFilesManager.statistics {
                FileSettingsSection(
                    title: "Statistics",
                    icon: "chart.bar",
                    description: "Current status of your recent folders"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        StatisticRow(label: "Total Folders", value: "\(statistics.totalCount)")
                        StatisticRow(label: "Valid Folders", value: "\(statistics.validCount)")
                        if statistics.invalidCount > 0 {
                            StatisticRow(label: "Invalid Folders", value: "\(statistics.invalidCount)", isWarning: true)
                        }
                        StatisticRow(label: "Average Photos", value: String(format: "%.0f", statistics.averagePhotoCount))
                        StatisticRow(label: "Storage Used", value: ByteCountFormatter.string(fromByteCount: statistics.totalBookmarkSize, countStyle: .file))
                    }
                }
            }
            
            // Recent Files Management Section
            FileSettingsSection(
                title: "Management",
                icon: "gear",
                description: "Manage your recent folders data"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Action buttons
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button("Clean Up Invalid Folders") {
                                Task {
                                    let cleaned = await recentFilesManager.performCleanup()
                                    print("Cleaned up \(cleaned) invalid folders")
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Refresh Statistics") {
                                Task {
                                    await recentFilesManager.refreshStatistics()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Export Recent Folders...") {
                                exportRecentFiles()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Import Recent Folders...") {
                                importRecentFiles()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Clear All Recent Folders") {
                            showingClearConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    
                    // Current folders list (first few)
                    if !recentFilesManager.recentFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Folders")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(Array(recentFilesManager.recentFiles.prefix(5))) { recentFile in
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recentFile.displayName)
                                            .font(.caption)
                                            .lineLimit(1)
                                        
                                        Text(recentFile.lastAccessDate, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if let photoCount = recentFile.photoCount {
                                        Text("\(photoCount)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                            }
                            
                            if recentFilesManager.recentFiles.count > 5 {
                                Text("... and \(recentFilesManager.recentFiles.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // File Access Security Section
            FileSettingsSection(
                title: "Security & Access",
                icon: "lock.shield",
                description: "File system access and security settings"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.green)
                        Text("App Sandbox Protection Enabled")
                            .font(.subheadline)
                    }
                    
                    Text("PhotoSlideshow uses security-scoped bookmarks to maintain safe access to your photos while respecting macOS security requirements.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("External volumes and network drives are supported with automatic permission management.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Configuration Presets Section
            FileSettingsSection(
                title: "Presets",
                icon: "square.grid.2x2",
                description: "Quick configuration presets for common scenarios"
            ) {
                HStack(spacing: 12) {
                    Button("Conservative") {
                        Task {
                            await recentFilesManager.applyConfigurationPreset(.conservative)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Balanced") {
                        Task {
                            await recentFilesManager.applyConfigurationPreset(.default)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Extensive") {
                        Task {
                            await recentFilesManager.applyConfigurationPreset(.extensive)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .alert("Clear All Recent Folders", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task {
                    await recentFilesManager.clearAllRecentFiles()
                }
            }
        } message: {
            Text("This will remove all recent folders from the File menu. This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportRecentFiles() {
        Task {
            do {
                let data = try await recentFilesManager.exportRecentFiles()
                
                let savePanel = NSSavePanel()
                savePanel.title = "Export Recent Folders"
                savePanel.allowedContentTypes = [.json]
                savePanel.nameFieldStringValue = "PhotoSlideshow-RecentFolders.json"
                
                if savePanel.runModal() == .OK, let url = savePanel.url {
                    try data.write(to: url)
                }
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
    
    private func importRecentFiles() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Recent Folders"
        openPanel.allowedContentTypes = [.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            Task {
                do {
                    let data = try Data(contentsOf: url)
                    try await recentFilesManager.importRecentFiles(from: data, merge: true)
                } catch {
                    print("Import failed: \(error)")
                }
            }
        }
    }
}

/// Reusable settings section component for file management settings
private struct FileSettingsSection<Content: View>: View {
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

/// Helper view for displaying statistics
private struct StatisticRow: View {
    let label: String
    let value: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(isWarning ? .orange : .primary)
        }
        .font(.caption)
    }
}

// MARK: - MenuConfiguration Extensions

extension MenuConfiguration {
    static var conservative: MenuConfiguration {
        try! MenuConfiguration(
            maxRecentFiles: 5,
            enableFileMenu: true,
            enableRecentFiles: true,
            showFullPaths: false,
            autoCleanupInvalidFiles: true,
            recentFileExpirationInterval: 7 * 24 * 60 * 60, // 1 week
            groupRecentFilesByDirectory: false
        )
    }
    
    static var extensive: MenuConfiguration {
        try! MenuConfiguration(
            maxRecentFiles: 25,
            enableFileMenu: true,
            enableRecentFiles: true,
            showFullPaths: true,
            autoCleanupInvalidFiles: false,
            recentFileExpirationInterval: 90 * 24 * 60 * 60, // 3 months
            groupRecentFilesByDirectory: true
        )
    }
}

#Preview {
    FileManagementSettingsView(recentFilesManager: RecentFilesManager())
        .frame(width: 500, height: 600)
}