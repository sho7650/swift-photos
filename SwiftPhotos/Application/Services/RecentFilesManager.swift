import Foundation
import SwiftUI
import Combine

/// Notification names for recent files events
extension Notification.Name {
    static let recentFilesChanged = Notification.Name("recentFilesChanged")
    static let recentFileAdded = Notification.Name("recentFileAdded")
    static let recentFileRemoved = Notification.Name("recentFileRemoved")
    static let menuConfigurationChanged = Notification.Name("menuConfigurationChanged")
}

/// Application service for managing recent files and menu configuration
/// Provides SwiftUI-reactive interface to the domain layer
@MainActor
public class RecentFilesManager: ObservableObject {
    @Published public var recentFiles: [RecentFileItem] = []
    @Published public var configuration: MenuConfiguration = .default
    @Published public var statistics: RecentFilesStatistics?
    @Published public var isLoading: Bool = false
    
    private let repository: SecureRecentFilesRepository
    private var cancellables = Set<AnyCancellable>()
    
    // Automatic cleanup configuration
    private let autoCleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private var cleanupTimer: Timer?
    
    public init(repository: SecureRecentFilesRepository? = nil) {
        self.repository = repository ?? SecureRecentFilesRepository()
        
        ProductionLogger.lifecycle("RecentFilesManager: Initializing...")
        
        // Load initial data
        Task {
            await loadInitialData()
            await setupPeriodicCleanup()
        }
        
        ProductionLogger.lifecycle("RecentFilesManager: Initialized")
    }
    
    // MARK: - Public Interface
    
    /// Add a folder to recent files
    /// This is the primary method called when user selects a folder
    public func addRecentFile(url: URL, securityBookmark: Data) async {
        ProductionLogger.userAction("RecentFilesManager: Adding recent file: \(url.lastPathComponent)")
        isLoading = true
        
        do {
            try await repository.addRecentFile(url, securityBookmark: securityBookmark)
            await refreshRecentFiles()
            
            // Notify observers
            NotificationCenter.default.post(
                name: .recentFileAdded,
                object: url,
                userInfo: ["displayName": url.lastPathComponent]
            )
            
            ProductionLogger.debug("RecentFilesManager: Successfully added recent file")
        } catch {
            ProductionLogger.error("RecentFilesManager: Failed to add recent file: \(error)")
            // Could emit an error event here for UI to handle
        }
        
        isLoading = false
    }
    
    /// Remove a specific recent file
    public func removeRecentFile(id: UUID) async {
        ProductionLogger.userAction("RecentFilesManager: Removing recent file with ID: \(id)")
        isLoading = true
        
        do {
            try await repository.removeRecentFile(id: id)
            await refreshRecentFiles()
            
            // Notify observers
            NotificationCenter.default.post(
                name: .recentFileRemoved,
                object: id
            )
            
            ProductionLogger.debug("RecentFilesManager: Successfully removed recent file")
        } catch {
            ProductionLogger.error("RecentFilesManager: Failed to remove recent file: \(error)")
        }
        
        isLoading = false
    }
    
    /// Remove a specific recent file by URL
    public func removeRecentFile(url: URL) async {
        ProductionLogger.userAction("RecentFilesManager: Removing recent file: \(url.lastPathComponent)")
        isLoading = true
        
        do {
            try await repository.removeRecentFile(url: url)
            await refreshRecentFiles()
            
            // Notify observers
            NotificationCenter.default.post(
                name: .recentFileRemoved,
                object: url
            )
            
            ProductionLogger.debug("RecentFilesManager: Successfully removed recent file")
        } catch {
            ProductionLogger.error("RecentFilesManager: Failed to remove recent file: \(error)")
        }
        
        isLoading = false
    }
    
    /// Clear all recent files
    public func clearAllRecentFiles() async {
        ProductionLogger.userAction("RecentFilesManager: Clearing all recent files")
        isLoading = true
        
        do {
            try await repository.clearRecentFiles()
            await refreshRecentFiles()
            
            // Notify observers
            NotificationCenter.default.post(name: .recentFilesChanged, object: nil)
            
            ProductionLogger.debug("RecentFilesManager: Successfully cleared all recent files")
        } catch {
            ProductionLogger.error("RecentFilesManager: Failed to clear recent files: \(error)")
        }
        
        isLoading = false
    }
    
    /// Update menu configuration
    public func updateConfiguration(_ newConfiguration: MenuConfiguration) async {
        ProductionLogger.debug("RecentFilesManager: Updating configuration")
        
        do {
            try await repository.updateConfiguration(newConfiguration)
            self.configuration = newConfiguration
            await refreshRecentFiles() // May change visible files based on new limits
            
            // Notify observers
            NotificationCenter.default.post(
                name: .menuConfigurationChanged,
                object: newConfiguration
            )
            
            ProductionLogger.debug("RecentFilesManager: Successfully updated configuration")
        } catch {
            ProductionLogger.error("RecentFilesManager: Failed to update configuration: \(error)")
        }
    }
    
    /// Manually trigger cleanup of invalid files
    public func performCleanup() async -> Int {
        ProductionLogger.userAction("RecentFilesManager: Performing manual cleanup")
        isLoading = true
        
        let cleanedCount = await repository.cleanupInvalidFiles()
        
        if cleanedCount > 0 {
            await refreshRecentFiles()
            await refreshStatistics()
            
            // Notify observers
            NotificationCenter.default.post(
                name: .recentFilesChanged,
                object: nil,
                userInfo: ["cleanedCount": cleanedCount]
            )
        }
        
        isLoading = false
        ProductionLogger.debug("RecentFilesManager: Cleanup completed, removed \(cleanedCount) files")
        return cleanedCount
    }
    
    /// Search recent files
    public func searchRecentFiles(query: String) async -> [RecentFileItem] {
        return await repository.searchRecentFiles(query: query)
    }
    
    /// Check if a URL is in recent files
    public func containsRecentFile(url: URL) async -> Bool {
        return await repository.containsRecentFile(url: url)
    }
    
    /// Update photo count for a recent file
    public func updatePhotoCount(for url: URL, count: Int) async {
        do {
            try await repository.updatePhotoCount(for: url, photoCount: count)
            await refreshRecentFiles()
            ProductionLogger.debug("RecentFilesManager: Updated photo count for \(url.lastPathComponent): \(count)")
        } catch {
            ProductionLogger.error("RecentFilesManager: Failed to update photo count: \(error)")
        }
    }
    
    // MARK: - Configuration Presets
    
    /// Apply a predefined configuration preset
    public func applyConfigurationPreset(_ preset: MenuConfiguration) async {
        await updateConfiguration(preset)
    }
    
    /// Reset configuration to default
    public func resetConfiguration() async {
        await updateConfiguration(.default)
    }
    
    // MARK: - Analytics and Statistics
    
    /// Refresh statistics data
    public func refreshStatistics() async {
        let stats = await repository.getStatistics()
        self.statistics = stats
        ProductionLogger.debug("RecentFilesManager: Refreshed statistics - \(stats.totalCount) total files")
    }
    
    /// Get recent files grouped by directory
    public func getRecentFilesGroupedByDirectory() async -> [String: [RecentFileItem]] {
        return await repository.getRecentFilesGroupedByDirectory()
    }
    
    /// Get files accessed within time period
    public func getRecentFilesWithin(timeInterval: TimeInterval) async -> [RecentFileItem] {
        return await repository.getRecentFilesWithin(timeInterval: timeInterval)
    }
    
    // MARK: - Export/Import
    
    /// Export recent files data
    public func exportRecentFiles() async throws -> Data {
        return try await repository.exportRecentFiles()
    }
    
    /// Import recent files data
    public func importRecentFiles(from data: Data, merge: Bool = true) async throws {
        try await repository.importRecentFiles(from: data, merge: merge)
        await refreshRecentFiles()
        await refreshStatistics()
        
        // Notify observers
        NotificationCenter.default.post(name: .recentFilesChanged, object: nil)
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() async {
        ProductionLogger.lifecycle("RecentFilesManager: Loading initial data")
        
        // Load configuration
        self.configuration = await repository.getConfiguration()
        
        // Load recent files
        await refreshRecentFiles()
        
        // Load statistics
        await refreshStatistics()
        
        ProductionLogger.lifecycle("RecentFilesManager: Initial data loaded")
    }
    
    private func refreshRecentFiles() async {
        let files = await repository.getRecentFiles()
        self.recentFiles = files
        
        // Notify observers of change
        NotificationCenter.default.post(name: .recentFilesChanged, object: nil)
    }
    
    private func setupPeriodicCleanup() async {
        guard configuration.autoCleanupInvalidFiles else {
            ProductionLogger.debug("RecentFilesManager: Auto cleanup is disabled")
            return
        }
        
        ProductionLogger.lifecycle("RecentFilesManager: Setting up periodic cleanup every \(autoCleanupInterval/3600) hours")
        
        // Cancel existing timer
        cleanupTimer?.invalidate()
        
        // Setup new timer
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: autoCleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let cleanedCount = await self.performCleanup()
                if cleanedCount > 0 {
                    ProductionLogger.debug("RecentFilesManager: Periodic cleanup removed \(cleanedCount) invalid files")
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Get display-ready recent files (respects configuration limits)
    public var displayRecentFiles: [RecentFileItem] {
        let maxFiles = configuration.effectiveMaxRecentFiles
        return Array(recentFiles.prefix(maxFiles))
    }
    
    /// Check if recent files should be shown in menu
    public var shouldShowRecentFiles: Bool {
        return configuration.shouldShowRecentFiles && !recentFiles.isEmpty
    }
    
    /// Get formatted recent files for menu display
    public var menuRecentFiles: [RecentFileItem] {
        guard shouldShowRecentFiles else { return [] }
        return displayRecentFiles
    }
    
    deinit {
        cleanupTimer?.invalidate()
        cancellables.removeAll()
        ProductionLogger.lifecycle("RecentFilesManager: Deinitialized")
    }
}