import Cocoa
import SwiftUI
import Combine

/// Coordinator for native macOS menu bar integration
/// Manages File menu with Open and Open Recent functionality
@MainActor
public class MenuBarCoordinator: NSObject, ObservableObject {
    private let recentFilesManager: RecentFilesManager
    private let secureFileAccess: SecureFileAccess
    private var cancellables = Set<AnyCancellable>()
    
    // Menu references
    private weak var fileMenu: NSMenu?
    private weak var openRecentMenu: NSMenu?
    private weak var clearRecentMenuItem: NSMenuItem?
    
    // Action handlers
    public var onOpenFolder: ((URL) -> Void)?
    public var onSelectFolder: (() -> Void)?
    
    public init(recentFilesManager: RecentFilesManager, secureFileAccess: SecureFileAccess) {
        self.recentFilesManager = recentFilesManager
        self.secureFileAccess = secureFileAccess
        
        super.init()
        
        print("🍔 MenuBarCoordinator: Initializing menu bar coordinator")
        
        // Setup menu bar
        setupMenuBar()
        
        // Listen for recent files changes
        setupNotificationObservers()
        
        print("🍔 MenuBarCoordinator: Menu bar coordinator initialized")
    }
    
    // MARK: - Menu Setup
    
    private func setupMenuBar() {
        guard let mainMenu = NSApplication.shared.mainMenu else {
            print("❌ MenuBarCoordinator: No main menu found")
            return
        }
        
        // Find or create File menu
        if let existingFileMenu = findFileMenu(in: mainMenu) {
            fileMenu = existingFileMenu
            print("🍔 MenuBarCoordinator: Found existing File menu")
        } else {
            fileMenu = createFileMenu()
            if let fileMenu = fileMenu {
                // Insert File menu as second item (after app menu)
                let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
                fileMenuItem.submenu = fileMenu
                mainMenu.insertItem(fileMenuItem, at: 1)
                print("🍔 MenuBarCoordinator: Created new File menu")
            }
        }
        
        // Setup File menu items
        setupFileMenuItems()
        
        // Update recent files menu
        updateRecentFilesMenu()
    }
    
    private func findFileMenu(in mainMenu: NSMenu) -> NSMenu? {
        for item in mainMenu.items {
            if item.title == "File" || item.title.lowercased().contains("file") {
                return item.submenu
            }
        }
        return nil
    }
    
    private func createFileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.autoenablesItems = false
        return menu
    }
    
    private func setupFileMenuItems() {
        guard let fileMenu = fileMenu else { return }
        
        // Clear existing items (be careful not to remove system items)
        removeCustomMenuItems()
        
        // Add Open Folder item
        let openItem = NSMenuItem(
            title: "Open Folder...",
            action: #selector(openFolderAction),
            keyEquivalent: "o"
        )
        openItem.target = self
        openItem.keyEquivalentModifierMask = [.command]
        fileMenu.insertItem(openItem, at: 0)
        
        // Add separator
        fileMenu.insertItem(NSMenuItem.separator(), at: 1)
        
        // Add Open Recent submenu
        let openRecentItem = NSMenuItem(
            title: "Open Recent",
            action: nil,
            keyEquivalent: ""
        )
        
        let openRecentSubmenu = NSMenu(title: "Open Recent")
        openRecentSubmenu.autoenablesItems = false
        openRecentItem.submenu = openRecentSubmenu
        
        fileMenu.insertItem(openRecentItem, at: 2)
        self.openRecentMenu = openRecentSubmenu
        
        // Add Clear Menu item to Open Recent
        let clearMenuItem = NSMenuItem(
            title: "Clear Menu",
            action: #selector(clearRecentFilesAction),
            keyEquivalent: ""
        )
        clearMenuItem.target = self
        openRecentSubmenu.addItem(clearMenuItem)
        self.clearRecentMenuItem = clearMenuItem
        
        // Add another separator after Open Recent
        fileMenu.insertItem(NSMenuItem.separator(), at: 3)
        
        print("🍔 MenuBarCoordinator: File menu items setup completed")
    }
    
    private func removeCustomMenuItems() {
        guard let fileMenu = fileMenu else { return }
        
        // Remove items that we added (be careful with system items)
        var itemsToRemove: [NSMenuItem] = []
        
        for item in fileMenu.items {
            if item.title == "Open Folder..." ||
               item.title == "Open Recent" ||
               (item.isSeparatorItem && fileMenu.items.firstIndex(of: item) ?? 0 < 4) {
                itemsToRemove.append(item)
            }
        }
        
        for item in itemsToRemove {
            fileMenu.removeItem(item)
        }
    }
    
    // MARK: - Recent Files Menu Management
    
    private func updateRecentFilesMenu() {
        guard let openRecentMenu = openRecentMenu else { return }
        
        // Clear existing recent file items (keep Clear Menu item)
        let itemsToRemove = openRecentMenu.items.filter { $0 != clearRecentMenuItem }
        for item in itemsToRemove {
            openRecentMenu.removeItem(item)
        }
        
        // Add recent files
        let recentFiles = recentFilesManager.menuRecentFiles
        
        if recentFiles.isEmpty {
            // Add "No Recent Folders" placeholder
            let noItemsItem = NSMenuItem(title: "No Recent Folders", action: nil, keyEquivalent: "")
            noItemsItem.isEnabled = false
            openRecentMenu.insertItem(noItemsItem, at: 0)
            
            // Disable Clear Menu
            clearRecentMenuItem?.isEnabled = false
        } else {
            // Add recent files
            for (index, recentFile) in recentFiles.enumerated() {
                let menuItem = createRecentFileMenuItem(for: recentFile, at: index)
                openRecentMenu.insertItem(menuItem, at: index)
            }
            
            // Add separator before Clear Menu if there are items
            if !recentFiles.isEmpty {
                openRecentMenu.insertItem(NSMenuItem.separator(), at: recentFiles.count)
            }
            
            // Enable Clear Menu
            clearRecentMenuItem?.isEnabled = true
        }
        
        print("🍔 MenuBarCoordinator: Updated recent files menu with \(recentFiles.count) items")
    }
    
    private func createRecentFileMenuItem(for recentFile: RecentFileItem, at index: Int) -> NSMenuItem {
        let configuration = recentFilesManager.configuration
        
        // Determine display name
        let displayName = configuration.showFullPaths ? recentFile.displayPath : recentFile.displayName
        
        // Create menu item
        let menuItem = NSMenuItem(
            title: displayName,
            action: #selector(openRecentFileAction(_:)),
            keyEquivalent: index < 9 ? "\(index + 1)" : ""
        )
        
        menuItem.target = self
        menuItem.representedObject = recentFile
        
        // Add keyboard shortcut for first 9 items
        if index < 9 {
            menuItem.keyEquivalentModifierMask = [.command]
        }
        
        // Add photo count to tooltip if available
        if let photoCount = recentFile.photoCount {
            menuItem.toolTip = "\(recentFile.displayPath) (\(photoCount) photos)"
        } else {
            menuItem.toolTip = recentFile.displayPath
        }
        
        return menuItem
    }
    
    // MARK: - Menu Actions
    
    @objc private func openFolderAction() {
        print("🍔 MenuBarCoordinator: Open Folder action triggered")
        
        Task { @MainActor in
            do {
                guard let folderURL = try secureFileAccess.selectFolder() else {
                    print("🍔 MenuBarCoordinator: Folder selection cancelled")
                    return
                }
                
                print("🍔 MenuBarCoordinator: Selected folder: \(folderURL.path)")
                
                // Create security bookmark
                let bookmarkData = try folderURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                // Add to recent files
                await recentFilesManager.addRecentFile(url: folderURL, securityBookmark: bookmarkData)
                
                // Notify handler
                onOpenFolder?(folderURL)
                
            } catch {
                print("❌ MenuBarCoordinator: Failed to open folder: \(error)")
                // Could show error dialog here
                showErrorAlert("Failed to open folder: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func openRecentFileAction(_ sender: NSMenuItem) {
        guard let recentFile = sender.representedObject as? RecentFileItem else {
            print("❌ MenuBarCoordinator: Invalid recent file menu item")
            return
        }
        
        print("🍔 MenuBarCoordinator: Opening recent file: \(recentFile.displayName)")
        
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
                
                // Notify handler
                onOpenFolder?(resolvedURL)
                
            } catch {
                print("❌ MenuBarCoordinator: Failed to open recent file: \(error)")
                
                // Remove invalid file from recent files
                await recentFilesManager.removeRecentFile(id: recentFile.id)
                
                showErrorAlert("Could not open '\(recentFile.displayName)'. The folder may have been moved or deleted.")
            }
        }
    }
    
    @objc private func clearRecentFilesAction() {
        print("🍔 MenuBarCoordinator: Clear recent files action triggered")
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Clear Recent Folders"
        alert.informativeText = "Are you sure you want to clear all recent folders?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            Task { @MainActor in
                await recentFilesManager.clearAllRecentFiles()
                print("🍔 MenuBarCoordinator: Recent files cleared")
            }
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for recent files changes
        NotificationCenter.default.publisher(for: .recentFilesChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRecentFilesMenu()
            }
            .store(in: &cancellables)
        
        // Listen for menu configuration changes
        NotificationCenter.default.publisher(for: .menuConfigurationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRecentFilesMenu()
            }
            .store(in: &cancellables)
        
        print("🍔 MenuBarCoordinator: Notification observers setup")
    }
    
    // MARK: - Utility Methods
    
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Swift Photos"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Manually refresh the menu (useful for testing or force updates)
    public func refreshMenu() {
        updateRecentFilesMenu()
    }
    
    /// Enable or disable the File menu
    public func setFileMenuEnabled(_ enabled: Bool) {
        fileMenu?.items.forEach { $0.isEnabled = enabled }
    }
    
    deinit {
        cancellables.removeAll()
        print("🍔 MenuBarCoordinator: Menu bar coordinator deinitialized")
    }
}