import Foundation
import AppKit

@MainActor
public class SecureFileAccess {
    private var securityScopedBookmarks: [URL: Data] = [:]
    
    public init() {}
    
    public func selectFolder() throws -> URL? {
        print("📁 Opening folder selection dialog...")
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Image Folder"
        openPanel.message = "Choose a folder containing images for the slideshow"
        
        print("📁 Running modal dialog...")
        let result = openPanel.runModal()
        print("📁 Dialog result: \(result.rawValue)")
        
        if result == .OK, let url = openPanel.url {
            print("📁 Selected folder: \(url.path)")
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                self.securityScopedBookmarks[url] = bookmarkData
                print("📁 Successfully created security-scoped bookmark")
                return url
            } catch {
                print("❌ Failed to create security-scoped bookmark: \(error)")
                throw SlideshowError.securityError("Failed to create security-scoped bookmark: \(error.localizedDescription)")
            }
        } else {
            print("📁 Folder selection cancelled")
            return nil
        }
    }
    
    public func enumerateImages(in folderURL: URL) throws -> [URL] {
        print("📁 Starting to enumerate images in folder: \(folderURL.path)")
        print("📁 Is file URL: \(folderURL.isFileURL)")
        print("📁 Path components: \(folderURL.pathComponents)")
        
        // For user-selected folders via NSOpenPanel, we already have access
        // No need for additional security-scoped resource handling
        
        let fileManager = FileManager.default
        
        // Check if folder exists and is readable
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) else {
            print("❌ Folder does not exist at path: \(folderURL.path)")
            throw SlideshowError.fileNotFound(folderURL)
        }
        
        guard isDirectory.boolValue else {
            print("❌ Path is not a directory: \(folderURL.path)")
            throw SlideshowError.securityError("Selected path is not a directory")
        }
        
        guard fileManager.isReadableFile(atPath: folderURL.path) else {
            print("❌ No read permission for folder: \(folderURL.path)")
            throw SlideshowError.securityError("No read permission for selected folder")
        }
        
        print("📁 Folder exists and is readable, creating enumerator...")
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            print("❌ Failed to create file enumerator for: \(folderURL.path)")
            throw SlideshowError.fileNotFound(folderURL)
        }
        
        print("📁 Created file enumerator successfully")
        var imageURLs: [URL] = []
        var processedCount = 0
        
        for case let url as URL in enumerator {
            processedCount += 1
            if processedCount % 100 == 0 {
                print("📁 Processing file #\(processedCount)...")
            }
            
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                
                if isImageFile(url) {
                    imageURLs.append(url)
                    if imageURLs.count <= 10 {
                        print("📁 Found image file: \(url.lastPathComponent)")
                    }
                }
            } catch {
                print("⚠️ Failed to get resource values for: \(url.lastPathComponent) - \(error)")
                continue
            }
        }
        
        let sortedURLs = imageURLs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        print("📁 Found \(sortedURLs.count) image files total, processed \(processedCount) files")
        
        // No limits - support unlimited collections with virtual loading
        print("📁 Found \(sortedURLs.count) image files - no artificial limits applied")
        
        return sortedURLs
    }
    
    public func validateFileAccess(for url: URL) throws {
        print("📁 Validating file access for: \(url.path)")
        
        var isStale = false
        
        if let bookmarkData = securityScopedBookmarks[url] {
            print("📁 Found bookmark data for URL")
            do {
                let bookmarkURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    print("❌ Security-scoped bookmark is stale")
                    securityScopedBookmarks.removeValue(forKey: url)
                    throw SlideshowError.securityError("Security-scoped bookmark is stale")
                }
                
                if bookmarkURL != url {
                    print("❌ Bookmark URL mismatch: \(bookmarkURL) != \(url)")
                    throw SlideshowError.securityError("Bookmark URL mismatch")
                }
                
                print("📁 Bookmark validation successful")
            } catch {
                print("❌ Failed to resolve bookmark: \(error)")
                throw SlideshowError.securityError("Failed to resolve bookmark: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ No bookmark data found for URL - this is OK for selected folders")
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ File not found at path: \(url.path)")
            throw SlideshowError.fileNotFound(url)
        }
        
        print("📁 File access validation completed successfully")
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
    
    deinit {
        for url in securityScopedBookmarks.keys {
            url.stopAccessingSecurityScopedResource()
        }
    }
}