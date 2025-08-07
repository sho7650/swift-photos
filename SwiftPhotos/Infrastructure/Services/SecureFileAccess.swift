import Foundation
import AppKit

@MainActor
public class SecureFileAccess {
    private var securityScopedBookmarks: [URL: Data] = [:]
    private var activeScopedAccess: [URL: Bool] = [:]
    
    public init() {}
    
    public func selectFolder() throws -> URL? {
        ProductionLogger.userAction("Opening folder selection dialog...")
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Image Folder"
        openPanel.message = "Choose a folder containing images for the slideshow"
        
        // Ensure we're on the main thread for proper dialog presentation
        guard Thread.isMainThread else {
            ProductionLogger.warning("selectFolder() called off main thread, dispatching to main")
            return try DispatchQueue.main.sync {
                return try selectFolder()
            }
        }
        
        ProductionLogger.debug("Running modal dialog...")
        let result = openPanel.runModal()
        ProductionLogger.debug("Dialog result: \(result.rawValue)")
        
        if result == .OK, let url = openPanel.url {
            ProductionLogger.userAction("Selected folder: \(url.path)")
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                self.securityScopedBookmarks[url] = bookmarkData
                ProductionLogger.debug("Successfully created security-scoped bookmark")
                return url
            } catch {
                ProductionLogger.error("Failed to create security-scoped bookmark: \(error)")
                throw SlideshowError.securityError("Failed to create security-scoped bookmark: \(error.localizedDescription)")
            }
        } else {
            ProductionLogger.debug("Folder selection cancelled")
            return nil
        }
    }
    
    public func enumerateImages(in folderURL: URL) throws -> [URL] {
        ProductionLogger.debug("Starting to enumerate images in folder: \(folderURL.path)")
        ProductionLogger.debug("Is file URL: \(folderURL.isFileURL)")
        ProductionLogger.debug("Path components: \(folderURL.pathComponents)")
        
        // For user-selected folders via NSOpenPanel, we already have access
        // No need for additional security-scoped resource handling
        
        let fileManager = FileManager.default
        
        // Check if folder exists and is readable
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) else {
            ProductionLogger.error("Folder does not exist at path: \(folderURL.path)")
            throw SlideshowError.fileNotFound(folderURL)
        }
        
        guard isDirectory.boolValue else {
            ProductionLogger.error("Path is not a directory: \(folderURL.path)")
            throw SlideshowError.securityError("Selected path is not a directory")
        }
        
        guard fileManager.isReadableFile(atPath: folderURL.path) else {
            ProductionLogger.error("No read permission for folder: \(folderURL.path)")
            throw SlideshowError.securityError("No read permission for selected folder")
        }
        
        ProductionLogger.debug("Folder exists and is readable, creating enumerator...")
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            ProductionLogger.error("Failed to create file enumerator for: \(folderURL.path)")
            throw SlideshowError.fileNotFound(folderURL)
        }
        
        ProductionLogger.debug("Created file enumerator successfully")
        var imageURLs: [URL] = []
        var processedCount = 0
        
        for case let url as URL in enumerator {
            processedCount += 1
            if processedCount % 100 == 0 {
                ProductionLogger.debug("Processing file #\(processedCount)...")
            }
            
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                
                if isImageFile(url) {
                    imageURLs.append(url)
                    if imageURLs.count <= 10 {
                        ProductionLogger.debug("Found image file: \(url.lastPathComponent)")
                    }
                }
            } catch {
                ProductionLogger.warning("Failed to get resource values for: \(url.lastPathComponent) - \(error)")
                continue
            }
        }
        
        let sortedURLs = imageURLs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        ProductionLogger.debug("Found \(sortedURLs.count) image files total, processed \(processedCount) files")
        
        // No limits - support unlimited collections with virtual loading
        ProductionLogger.debug("Found \(sortedURLs.count) image files - no artificial limits applied")
        
        return sortedURLs
    }
    
    public func validateFileAccess(for url: URL) throws {
        ProductionLogger.debug("Validating file access for: \(url.path)")
        
        var isStale = false
        
        if let bookmarkData = securityScopedBookmarks[url] {
            ProductionLogger.debug("Found bookmark data for URL")
            do {
                let bookmarkURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    ProductionLogger.warning("Security-scoped bookmark is stale")
                    securityScopedBookmarks.removeValue(forKey: url)
                    throw SlideshowError.securityError("Security-scoped bookmark is stale")
                }
                
                if bookmarkURL != url {
                    ProductionLogger.error("Bookmark URL mismatch: \(bookmarkURL) != \(url)")
                    throw SlideshowError.securityError("Bookmark URL mismatch")
                }
                
                ProductionLogger.debug("Bookmark validation successful")
            } catch {
                ProductionLogger.error("Failed to resolve bookmark: \(error)")
                throw SlideshowError.securityError("Failed to resolve bookmark: \(error.localizedDescription)")
            }
        } else {
            ProductionLogger.debug("No bookmark data found for URL - this is OK for selected folders")
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            ProductionLogger.error("File not found at path: \(url.path)")
            throw SlideshowError.fileNotFound(url)
        }
        
        ProductionLogger.debug("File access validation completed successfully")
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        do {
            _ = try ImageURL(url)
            return true
        } catch {
            return false
        }
    }
    
    public func releaseSecurityScopedResource(for url: URL) {
        securityScopedBookmarks.removeValue(forKey: url)
        url.stopAccessingSecurityScopedResource()
    }
    
    /// Add a security bookmark for a URL that was obtained from external sources (like recent files)
    public func addSecurityBookmark(for url: URL, bookmarkData: Data) {
        ProductionLogger.debug("Adding external security bookmark for: \(url.path)")
        securityScopedBookmarks[url] = bookmarkData
    }
    
    /// Create slideshow with proper security handling for external URLs
    public func prepareForAccess(url: URL, bookmarkData: Data? = nil) throws {
        ProductionLogger.debug("Preparing access for URL: \(url.path)")
        
        if let bookmark = bookmarkData {
            // Store the bookmark for later validation
            securityScopedBookmarks[url] = bookmark
            ProductionLogger.debug("Stored external security bookmark")
        }
        
        // Try to start security scoped access if needed and not already active
        if activeScopedAccess[url] != true {
            let accessStarted = url.startAccessingSecurityScopedResource()
            if accessStarted {
                activeScopedAccess[url] = true
                ProductionLogger.debug("Security scoped access started and will be maintained")
            } else {
                ProductionLogger.debug("Security scoped access not required")
            }
        } else {
            ProductionLogger.debug("Security scoped access already active")
        }
        
        // Validate that we can actually access the folder
        try validateFileAccess(for: url)
    }
    
    /// Check if a URL or its parent folder has active security scoped access
    public func hasActiveAccess(for url: URL) -> Bool {
        // Check if the exact URL has active access
        if activeScopedAccess[url] == true {
            return true
        }
        
        // Check if any parent directory has active access (for files within secured folders)
        var currentURL = url.deletingLastPathComponent()
        while currentURL.path != "/" {
            if activeScopedAccess[currentURL] == true {
                ProductionLogger.debug("Found active security access for parent folder: \(currentURL.path)")
                return true
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return false
    }
    
    /// Release security scoped access for a specific URL
    public func releaseAccess(for url: URL) {
        if activeScopedAccess[url] == true {
            url.stopAccessingSecurityScopedResource()
            activeScopedAccess.removeValue(forKey: url)
            ProductionLogger.debug("Released security scoped access for: \(url.path)")
        }
    }
    
    deinit {
        // Release all active security scoped access
        for url in activeScopedAccess.keys {
            url.stopAccessingSecurityScopedResource()
        }
        activeScopedAccess.removeAll()
        securityScopedBookmarks.removeAll()
    }
}