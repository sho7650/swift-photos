import SwiftUI
import AppKit

/// SwiftUI Commands integration for Swift Photos menu bar
/// Provides declarative menu bar configuration with recent files support
public struct SwiftPhotosMenuBar: Commands {
    @ObservedObject private var recentFilesManager: RecentFilesManager
    @State private var isSelectingFolder = false
    
    // Callback for when a folder is selected
    let onFolderSelected: (URL) -> Void
    
    public init(
        recentFilesManager: RecentFilesManager,
        onFolderSelected: @escaping (URL) -> Void
    ) {
        self.recentFilesManager = recentFilesManager
        self.onFolderSelected = onFolderSelected
    }
    
    public var body: some Commands {
        // Replace default File menu
        CommandGroup(replacing: .newItem) {
            // Open Folder command
            Button("Open Folder...") {
                openFolderAction()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(isSelectingFolder)
            
            Divider()
            
            // Recent Files submenu
            Menu("Open Recent") {
                if recentFilesManager.shouldShowRecentFiles {
                    ForEach(recentFilesManager.menuRecentFiles) { recentFile in
                        Button(action: {
                            openRecentFile(recentFile)
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(getDisplayName(for: recentFile))
                                if let photoCount = recentFile.photoCount {
                                    Text("\(photoCount) photos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .help(recentFile.displayPath)
                    }
                    
                    if !recentFilesManager.recentFiles.isEmpty {
                        Divider()
                        
                        Button("Clear Menu") {
                            clearRecentFiles()
                        }
                    }
                } else {
                    Text("No Recent Folders")
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!recentFilesManager.configuration.shouldShowRecentFiles)
            
            Divider()
        }
        
        // Add Settings menu item to existing menus
        CommandGroup(after: .appSettings) {
            Button("Recent Files Settings...") {
                openRecentFilesSettings()
            }
            .keyboardShortcut(",", modifiers: [.command, .option])
        }
        
        // Add View menu items
        CommandGroup(after: .windowArrangement) {
            Menu("Recent Files") {
                Button("Show Statistics") {
                    showRecentFilesStatistics()
                }
                
                Button("Clean Up Invalid Files") {
                    performCleanup()
                }
                
                Divider()
                
                Button("Export Recent Files...") {
                    exportRecentFiles()
                }
                
                Button("Import Recent Files...") {
                    importRecentFiles()
                }
            }
        }
        
        // Add Window menu items for window level control and fullscreen
        CommandGroup(before: .windowArrangement) {
            Button("Toggle Fullscreen") {
                toggleFullscreen()
            }
            .keyboardShortcut("f", modifiers: [])
            
            Divider()
            
            Menu("Window Level") {
                Button("Normal") {
                    changeWindowLevel(.normal)
                }
                .keyboardShortcut("0", modifiers: [.command, .control])
                
                Button("Always on Top") {
                    changeWindowLevel(.alwaysOnTop)
                }
                .keyboardShortcut("1", modifiers: [.command, .control])
                
                Button("Always at Bottom") {
                    changeWindowLevel(.alwaysAtBottom)
                }
                .keyboardShortcut("2", modifiers: [.command, .control])
            }
            
            Divider()
        }
    }
    
    // MARK: - Action Methods
    
    private func openFolderAction() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Open Folder action triggered")
        isSelectingFolder = true
        
        Task { @MainActor in
            defer { isSelectingFolder = false }
            
            do {
                let secureFileAccess = SecureFileAccess()
                guard let folderURL = try secureFileAccess.selectFolder() else {
                    ProductionLogger.debug("PhotoSlideshowMenuBar: Folder selection cancelled")
                    return
                }
                
                ProductionLogger.userAction("PhotoSlideshowMenuBar: Selected folder: \(folderURL.path)")
                
                // Start security scoped access
                let accessStarted = folderURL.startAccessingSecurityScopedResource()
                defer {
                    if accessStarted {
                        folderURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                ProductionLogger.debug("PhotoSlideshowMenuBar: Security access \(accessStarted ? "started" : "not needed") for selected folder")
                
                // Create security bookmark
                let bookmarkData = try folderURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                // Add to recent files
                await recentFilesManager.addRecentFile(url: folderURL, securityBookmark: bookmarkData)
                
                // Notify callback with the URL (callback will handle security access)
                onFolderSelected(folderURL)
                
            } catch {
                ProductionLogger.error("PhotoSlideshowMenuBar: Failed to open folder: \(error)")
                showErrorAlert("Failed to open folder: \(error.localizedDescription)")
            }
        }
    }
    
    private func openRecentFile(_ recentFile: RecentFileItem) {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Opening recent file: \(recentFile.displayName)")
        
        Task { @MainActor in
            do {
                // Resolve security bookmark
                var bookmarkDataIsStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: recentFile.securityBookmark,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &bookmarkDataIsStale
                )
                
                // Check if we can access the file
                guard resolvedURL.startAccessingSecurityScopedResource() else {
                    throw RecentFilesServiceError.permissionDenied(recentFile.url)
                }
                
                defer {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
                
                // Update access date in recent files
                let newBookmarkData: Data
                if bookmarkDataIsStale {
                    // Create fresh bookmark
                    newBookmarkData = try resolvedURL.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } else {
                    newBookmarkData = recentFile.securityBookmark
                }
                
                // Update recent files with new access date
                await recentFilesManager.addRecentFile(url: resolvedURL, securityBookmark: newBookmarkData)
                
                // Notify callback
                onFolderSelected(resolvedURL)
                
            } catch {
                ProductionLogger.error("PhotoSlideshowMenuBar: Failed to open recent file: \(error)")
                
                // Remove invalid file from recent files
                await recentFilesManager.removeRecentFile(id: recentFile.id)
                
                showErrorAlert("Could not open '\(recentFile.displayName)'. The folder may have been moved or deleted.")
            }
        }
    }
    
    private func clearRecentFiles() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Clear recent files action triggered")
        
        Task { @MainActor in
            await recentFilesManager.clearAllRecentFiles()
            ProductionLogger.debug("PhotoSlideshowMenuBar: Recent files cleared")
        }
    }
    
    private func openRecentFilesSettings() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Opening recent files settings")
        // This would open a settings window focused on recent files configuration
        // For now, we'll just log the action
    }
    
    private func showRecentFilesStatistics() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Showing recent files statistics")
        
        Task { @MainActor in
            await recentFilesManager.refreshStatistics()
            
            if let stats = recentFilesManager.statistics {
                let message = """
                Recent Files Statistics:
                
                Total Files: \(stats.totalCount)
                Valid Files: \(stats.validCount)
                Invalid Files: \(stats.invalidCount)
                Average Photos per Folder: \(String(format: "%.1f", stats.averagePhotoCount))
                Storage Used: \(ByteCountFormatter.string(fromByteCount: stats.totalBookmarkSize, countStyle: .file))
                """
                
                showInfoAlert("Recent Files Statistics", message: message)
            }
        }
    }
    
    private func performCleanup() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Performing cleanup")
        
        Task { @MainActor in
            let cleanedCount = await recentFilesManager.performCleanup()
            
            let message = cleanedCount > 0 
                ? "Removed \(cleanedCount) invalid files from recent files."
                : "No invalid files found."
            
            showInfoAlert("Cleanup Complete", message: message)
        }
    }
    
    private func exportRecentFiles() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Exporting recent files")
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Recent Files"
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "PhotoSlideshow-RecentFiles.json"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            Task { @MainActor in
                do {
                    let data = try await recentFilesManager.exportRecentFiles()
                    try data.write(to: url)
                    showInfoAlert("Export Complete", message: "Recent files exported successfully.")
                } catch {
                    showErrorAlert("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func changeWindowLevel(_ level: WindowLevel) {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Changing window level to \(level.displayName)")
        NotificationCenter.default.post(
            name: .init("SwiftPhotosWindowLevelChanged"),
            object: level
        )
    }
    
    private func toggleFullscreen() {
        ProductionLogger.userAction("SwiftPhotosMenuBar: Toggling fullscreen from menu")
        
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.mainWindow else {
                ProductionLogger.error("SwiftPhotosMenuBar: No main window found for fullscreen toggle")
                return
            }
            
            if window.styleMask.contains(.fullScreen) {
                ProductionLogger.debug("SwiftPhotosMenuBar: Exiting fullscreen")
                window.toggleFullScreen(nil)
            } else {
                ProductionLogger.debug("SwiftPhotosMenuBar: Entering fullscreen")
                window.toggleFullScreen(nil)
            }
        }
    }
    
    private func importRecentFiles() {
        ProductionLogger.userAction("PhotoSlideshowMenuBar: Importing recent files")
        
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Recent Files"
        openPanel.allowedContentTypes = [.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            
            Task { @MainActor in
                do {
                    let data = try Data(contentsOf: url)
                    try await recentFilesManager.importRecentFiles(from: data, merge: true)
                    showInfoAlert("Import Complete", message: "Recent files imported successfully.")
                } catch {
                    showErrorAlert("Import failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDisplayName(for recentFile: RecentFileItem) -> String {
        return recentFilesManager.configuration.showFullPaths 
            ? recentFile.displayPath 
            : recentFile.displayName
    }
    
    private func showErrorAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Swift Photos"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func showInfoAlert(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - SwiftUI Integration Extensions

extension SwiftPhotosMenuBar {
    /// Create a SwiftPhotosMenuBar with automatic integration
    /// This is the recommended way to integrate the menu bar with your SwiftUI app
    public static func integrated(
        recentFilesManager: RecentFilesManager,
        onFolderSelected: @escaping (URL) -> Void
    ) -> SwiftPhotosMenuBar {
        return SwiftPhotosMenuBar(
            recentFilesManager: recentFilesManager,
            onFolderSelected: onFolderSelected
        )
    }
}

// MARK: - Menu Item View Models

/// View model for recent file menu items with rich display information
public struct RecentFileMenuItem: Identifiable {
    public let id: UUID
    public let displayName: String
    public let fullPath: String
    public let photoCount: Int?
    public let lastAccessed: Date
    public let recentFile: RecentFileItem
    
    public init(recentFile: RecentFileItem, showFullPaths: Bool) {
        self.id = recentFile.id
        self.displayName = showFullPaths ? recentFile.displayPath : recentFile.displayName
        self.fullPath = recentFile.displayPath
        self.photoCount = recentFile.photoCount
        self.lastAccessed = recentFile.lastAccessDate
        self.recentFile = recentFile
    }
}