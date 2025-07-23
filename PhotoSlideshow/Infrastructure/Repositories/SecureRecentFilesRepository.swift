import Foundation
import AppKit

/// Thread-safe repository for managing recent files with secure bookmark storage
/// Implements the RecentFilesService domain contract with UserDefaults persistence
public actor SecureRecentFilesRepository: RecentFilesAnalyticsService {
    private let userDefaults: UserDefaults
    private let recentFilesKey = "PhotoSlideshowRecentFiles"
    private let configurationKey = "PhotoSlideshowMenuConfiguration"
    
    private var recentFiles: [RecentFileItem] = []
    private var configuration: MenuConfiguration = .default
    
    // Cache for frequently accessed data
    private var lastLoadTime: Date?
    private let cacheValidityInterval: TimeInterval = 60 // 1 minute
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load initial data
        Task {
            await loadRecentFilesFromStorage()
            await loadConfigurationFromStorage()
        }
        
        print("🔐 SecureRecentFilesRepository: Initialized with secure storage")
    }
    
    // MARK: - Core RecentFilesService Implementation
    
    public func addRecentFile(_ url: URL, securityBookmark: Data) async throws {
        print("🔐 Adding recent file: \(url.path)")
        
        // Validation
        guard url.isFileURL else {
            throw RecentFilesServiceError.invalidURL(url)
        }
        
        guard !securityBookmark.isEmpty else {
            throw RecentFilesServiceError.invalidSecurityBookmark(url)
        }
        
        // Check if file already exists
        if let existingIndex = recentFiles.firstIndex(where: { $0.url == url }) {
            // Update existing file with new access date
            let existingFile = recentFiles[existingIndex]
            let updatedFile = existingFile.withUpdatedAccessDate()
            recentFiles[existingIndex] = updatedFile
            print("🔐 Updated existing recent file access date")
        } else {
            // Add new file
            do {
                let newFile = try RecentFileItem.fromFolder(url: url, securityBookmark: securityBookmark)
                recentFiles.insert(newFile, at: 0) // Add to beginning for most recent first
                print("🔐 Added new recent file")
            } catch {
                print("❌ Failed to create recent file item: \(error)")
                throw RecentFilesServiceError.storageError("Failed to create recent file item: \(error.localizedDescription)")
            }
        }
        
        // Enforce maximum limit
        await enforceMaximumRecentFiles()
        
        // Sort by most recent first
        recentFiles.sort { $0.lastAccessDate > $1.lastAccessDate }
        
        // Persist to storage
        try await saveRecentFilesToStorage()
        
        print("🔐 Recent file added successfully, total count: \(recentFiles.count)")
    }
    
    public func getRecentFiles() async -> [RecentFileItem] {
        await loadRecentFilesIfNeeded()
        return Array(recentFiles.prefix(configuration.effectiveMaxRecentFiles))
    }
    
    public func clearRecentFiles() async throws {
        print("🔐 Clearing all recent files")
        recentFiles.removeAll()
        try await saveRecentFilesToStorage()
        print("🔐 All recent files cleared")
    }
    
    public func removeRecentFile(id: UUID) async throws {
        print("🔐 Removing recent file with ID: \(id)")
        
        guard let index = recentFiles.firstIndex(where: { $0.id == id }) else {
            throw RecentFilesServiceError.fileNotFound(URL(fileURLWithPath: "unknown"))
        }
        
        let removedFile = recentFiles.remove(at: index)
        try await saveRecentFilesToStorage()
        
        print("🔐 Removed recent file: \(removedFile.displayName)")
    }
    
    public func removeRecentFile(url: URL) async throws {
        print("🔐 Removing recent file with URL: \(url.path)")
        
        guard let index = recentFiles.firstIndex(where: { $0.url == url }) else {
            throw RecentFilesServiceError.fileNotFound(url)
        }
        
        let removedFile = recentFiles.remove(at: index)
        try await saveRecentFilesToStorage()
        
        print("🔐 Removed recent file: \(removedFile.displayName)")
    }
    
    public func updateConfiguration(_ configuration: MenuConfiguration) async throws {
        print("🔐 Updating menu configuration")
        self.configuration = configuration
        try await saveConfigurationToStorage()
        
        // Enforce new limits
        await enforceMaximumRecentFiles()
        
        print("🔐 Menu configuration updated")
    }
    
    public func getConfiguration() async -> MenuConfiguration {
        await loadConfigurationIfNeeded()
        return configuration
    }
    
    public func cleanupInvalidFiles() async -> Int {
        print("🔐 Starting cleanup of invalid recent files")
        
        var cleanedCount = 0
        var validFiles: [RecentFileItem] = []
        
        for file in recentFiles {
            if await isFileValid(file) {
                validFiles.append(file)
            } else {
                cleanedCount += 1
                print("🔐 Removing invalid file: \(file.displayPath)")
            }
        }
        
        if cleanedCount > 0 {
            recentFiles = validFiles
            do {
                try await saveRecentFilesToStorage()
                print("🔐 Cleanup completed, removed \(cleanedCount) invalid files")
            } catch {
                print("❌ Failed to save after cleanup: \(error)")
            }
        }
        
        return cleanedCount
    }
    
    public func containsRecentFile(url: URL) async -> Bool {
        await loadRecentFilesIfNeeded()
        return recentFiles.contains { $0.url == url }
    }
    
    public func searchRecentFiles(query: String) async -> [RecentFileItem] {
        await loadRecentFilesIfNeeded()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return recentFiles
        }
        
        let lowercaseQuery = query.lowercased()
        return recentFiles.filter { file in
            file.displayName.lowercased().contains(lowercaseQuery) ||
            file.displayPath.lowercased().contains(lowercaseQuery)
        }
    }
    
    public func updatePhotoCount(for url: URL, photoCount: Int) async throws {
        guard let index = recentFiles.firstIndex(where: { $0.url == url }) else {
            throw RecentFilesServiceError.fileNotFound(url)
        }
        
        do {
            let updatedFile = try recentFiles[index].withUpdatedPhotoCount(photoCount)
            recentFiles[index] = updatedFile
            try await saveRecentFilesToStorage()
            print("🔐 Updated photo count for \(url.lastPathComponent): \(photoCount)")
        } catch {
            throw RecentFilesServiceError.storageError("Failed to update photo count: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Analytics Implementation
    
    public func getStatistics() async -> RecentFilesStatistics {
        await loadRecentFilesIfNeeded()
        
        let validFiles = await getValidFiles()
        let invalidCount = recentFiles.count - validFiles.count
        
        let photoCountSum = recentFiles.compactMap { $0.photoCount }.reduce(0, +)
        let filesWithPhotoCount = recentFiles.compactMap { $0.photoCount }.count
        let averagePhotoCount = filesWithPhotoCount > 0 ? Double(photoCountSum) / Double(filesWithPhotoCount) : 0.0
        
        let totalBookmarkSize = recentFiles.map { Int64($0.securityBookmark.count) }.reduce(0, +)
        
        return RecentFilesStatistics(
            totalCount: recentFiles.count,
            validCount: validFiles.count,
            invalidCount: invalidCount,
            mostRecentFile: recentFiles.first,
            oldestFile: recentFiles.last,
            averagePhotoCount: averagePhotoCount,
            totalBookmarkSize: totalBookmarkSize
        )
    }
    
    public func getRecentFilesGroupedByDirectory() async -> [String: [RecentFileItem]] {
        await loadRecentFilesIfNeeded()
        
        var groups: [String: [RecentFileItem]] = [:]
        
        for file in recentFiles {
            let parentPath = file.url.deletingLastPathComponent().path
            if groups[parentPath] == nil {
                groups[parentPath] = []
            }
            groups[parentPath]?.append(file)
        }
        
        return groups
    }
    
    public func getRecentFilesWithin(timeInterval: TimeInterval) async -> [RecentFileItem] {
        await loadRecentFilesIfNeeded()
        
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        return recentFiles.filter { $0.lastAccessDate > cutoffDate }
    }
    
    public func exportRecentFiles() async throws -> Data {
        await loadRecentFilesIfNeeded()
        
        do {
            let exportData = try JSONEncoder().encode(recentFiles)
            print("🔐 Exported \(recentFiles.count) recent files")
            return exportData
        } catch {
            throw RecentFilesServiceError.storageError("Failed to export recent files: \(error.localizedDescription)")
        }
    }
    
    public func importRecentFiles(from data: Data, merge: Bool) async throws {
        do {
            let importedFiles = try JSONDecoder().decode([RecentFileItem].self, from: data)
            
            if merge {
                // Merge with existing files, avoiding duplicates
                var urlSet = Set(recentFiles.map { $0.url })
                let newFiles = importedFiles.filter { !urlSet.contains($0.url) }
                recentFiles.append(contentsOf: newFiles)
            } else {
                // Replace existing files
                recentFiles = importedFiles
            }
            
            // Sort and enforce limits
            recentFiles.sort { $0.lastAccessDate > $1.lastAccessDate }
            await enforceMaximumRecentFiles()
            
            try await saveRecentFilesToStorage()
            print("🔐 Imported \(importedFiles.count) recent files, merge: \(merge)")
        } catch {
            throw RecentFilesServiceError.storageError("Failed to import recent files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func loadRecentFilesFromStorage() async {
        if let data = userDefaults.data(forKey: recentFilesKey) {
            do {
                recentFiles = try JSONDecoder().decode([RecentFileItem].self, from: data)
                lastLoadTime = Date()
                print("🔐 Loaded \(recentFiles.count) recent files from storage")
            } catch {
                print("❌ Failed to decode recent files: \(error)")
                recentFiles = []
            }
        }
    }
    
    private func saveRecentFilesToStorage() async throws {
        do {
            let data = try JSONEncoder().encode(recentFiles)
            userDefaults.set(data, forKey: recentFilesKey)
            print("🔐 Saved \(recentFiles.count) recent files to storage")
        } catch {
            print("❌ Failed to encode recent files: \(error)")
            throw RecentFilesServiceError.storageError("Failed to save recent files: \(error.localizedDescription)")
        }
    }
    
    private func loadConfigurationFromStorage() async {
        if let data = userDefaults.data(forKey: configurationKey) {
            do {
                configuration = try JSONDecoder().decode(MenuConfiguration.self, from: data)
                print("🔐 Loaded menu configuration from storage")
            } catch {
                print("❌ Failed to decode menu configuration: \(error)")
                configuration = .default
            }
        }
    }
    
    private func saveConfigurationToStorage() async throws {
        do {
            let data = try JSONEncoder().encode(configuration)
            userDefaults.set(data, forKey: configurationKey)
            print("🔐 Saved menu configuration to storage")
        } catch {
            print("❌ Failed to encode menu configuration: \(error)")
            throw RecentFilesServiceError.configurationError("Failed to save configuration: \(error.localizedDescription)")
        }
    }
    
    private func loadRecentFilesIfNeeded() async {
        if lastLoadTime == nil || 
           Date().timeIntervalSince(lastLoadTime!) > cacheValidityInterval {
            await loadRecentFilesFromStorage()
        }
    }
    
    private func loadConfigurationIfNeeded() async {
        // Configuration changes less frequently, so we don't need caching
        await loadConfigurationFromStorage()
    }
    
    private func enforceMaximumRecentFiles() async {
        let maxFiles = configuration.effectiveMaxRecentFiles
        if recentFiles.count > maxFiles {
            let excessCount = recentFiles.count - maxFiles
            recentFiles.removeLast(excessCount)
            print("🔐 Enforced maximum recent files limit, removed \(excessCount) oldest files")
        }
    }
    
    private func isFileValid(_ file: RecentFileItem) async -> Bool {
        // Check if file exists and security bookmark is still valid
        let fileManager = FileManager.default
        
        // Basic existence check
        guard fileManager.fileExists(atPath: file.url.path) else {
            return false
        }
        
        // Try to access the file using security bookmark
        var bookmarkDataIsStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: file.securityBookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &bookmarkDataIsStale
            )
            
            if bookmarkDataIsStale {
                print("🔐 Security bookmark is stale for: \(file.displayName)")
                return false
            }
            
            // Try to access the resolved URL
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                return false
            }
            
            defer {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
            
            // Verify we can read the directory
            do {
                let _ = try fileManager.contentsOfDirectory(at: resolvedURL, includingPropertiesForKeys: nil)
                return true
            } catch {
                print("🔐 Cannot access directory: \(error)")
                return false
            }
            
        } catch {
            print("🔐 Invalid security bookmark: \(error)")
            return false
        }
    }
    
    private func getValidFiles() async -> [RecentFileItem] {
        var validFiles: [RecentFileItem] = []
        
        for file in recentFiles {
            if await isFileValid(file) {
                validFiles.append(file)
            }
        }
        
        return validFiles
    }
}