import Foundation

/// Domain service contract for managing recently accessed folders
/// Provides abstraction for recent files operations with security considerations
public protocol RecentFilesService {
    /// Add a new folder to the recent files list
    /// If the folder already exists, updates its access date
    /// - Parameter url: The folder URL to add
    /// - Parameter securityBookmark: Security bookmark data for sandboxed access
    /// - Throws: RecentFilesServiceError if the operation fails
    func addRecentFile(_ url: URL, securityBookmark: Data) async throws
    
    /// Retrieve all recent files, sorted by most recently accessed first
    /// - Returns: Array of recent file items
    func getRecentFiles() async -> [RecentFileItem]
    
    /// Remove all recent files from storage
    func clearRecentFiles() async throws
    
    /// Remove a specific recent file by its ID
    /// - Parameter id: The unique identifier of the recent file to remove
    func removeRecentFile(id: UUID) async throws
    
    /// Remove a specific recent file by its URL
    /// - Parameter url: The URL of the recent file to remove
    func removeRecentFile(url: URL) async throws
    
    /// Update the configuration for recent files management
    /// - Parameter configuration: The new menu configuration to apply
    func updateConfiguration(_ configuration: MenuConfiguration) async throws
    
    /// Get the current configuration
    /// - Returns: Current menu configuration
    func getConfiguration() async -> MenuConfiguration
    
    /// Validate and cleanup invalid recent files
    /// Removes files that no longer exist or have invalid security bookmarks
    /// - Returns: Number of files that were cleaned up
    @discardableResult
    func cleanupInvalidFiles() async -> Int
    
    /// Check if a specific URL exists in recent files
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL exists in recent files
    func containsRecentFile(url: URL) async -> Bool
    
    /// Get recent files that match a search query
    /// - Parameter query: Search string to match against folder names
    /// - Returns: Array of matching recent file items
    func searchRecentFiles(query: String) async -> [RecentFileItem]
    
    /// Update photo count for a specific recent file
    /// - Parameters:
    ///   - url: The URL of the recent file to update
    ///   - photoCount: The new photo count
    func updatePhotoCount(for url: URL, photoCount: Int) async throws
}

/// Errors that can occur in recent files service operations
public enum RecentFilesServiceError: LocalizedError, Equatable {
    case fileNotFound(URL)
    case invalidSecurityBookmark(URL)
    case storageError(String)
    case configurationError(String)
    case permissionDenied(URL)
    case invalidURL(URL)
    case operationCancelled
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .invalidSecurityBookmark(let url):
            return "Invalid security bookmark for: \(url.path)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .permissionDenied(let url):
            return "Permission denied for: \(url.path)"
        case .invalidURL(let url):
            return "Invalid URL: \(url.absoluteString)"
        case .operationCancelled:
            return "Operation was cancelled"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please select a folder that exists on your system"
        case .invalidSecurityBookmark:
            return "Please reselect the folder to refresh security permissions"
        case .storageError:
            return "Please check available disk space and permissions"
        case .configurationError:
            return "Please check recent files settings"
        case .permissionDenied:
            return "Please grant file access permissions to the application"
        case .invalidURL:
            return "Please select a valid folder location"
        case .operationCancelled:
            return "The operation was cancelled by the user"
        }
    }
}

// MARK: - Additional Domain Contracts

/// Statistics about recent files usage
public struct RecentFilesStatistics: Equatable {
    /// Total number of recent files stored
    public let totalCount: Int
    
    /// Number of recent files that are still valid/accessible
    public let validCount: Int
    
    /// Number of recent files that need cleanup
    public let invalidCount: Int
    
    /// Most recently accessed file
    public let mostRecentFile: RecentFileItem?
    
    /// Oldest recent file
    public let oldestFile: RecentFileItem?
    
    /// Average number of photos per recent folder
    public let averagePhotoCount: Double
    
    /// Total storage space used by recent files bookmarks
    public let totalBookmarkSize: Int64
    
    public init(
        totalCount: Int,
        validCount: Int,
        invalidCount: Int,
        mostRecentFile: RecentFileItem?,
        oldestFile: RecentFileItem?,
        averagePhotoCount: Double,
        totalBookmarkSize: Int64
    ) {
        self.totalCount = totalCount
        self.validCount = validCount
        self.invalidCount = invalidCount
        self.mostRecentFile = mostRecentFile
        self.oldestFile = oldestFile
        self.averagePhotoCount = averagePhotoCount
        self.totalBookmarkSize = totalBookmarkSize
    }
}

/// Extended recent files service with analytics capabilities
public protocol RecentFilesAnalyticsService: RecentFilesService {
    /// Get detailed statistics about recent files usage
    /// - Returns: Statistics about recent files
    func getStatistics() async -> RecentFilesStatistics
    
    /// Get recent files grouped by parent directory
    /// - Returns: Dictionary with parent directory paths as keys
    func getRecentFilesGroupedByDirectory() async -> [String: [RecentFileItem]]
    
    /// Get recent files accessed within a specific time period
    /// - Parameter timeInterval: Time interval to look back (in seconds)
    /// - Returns: Array of recent files accessed within the time period
    func getRecentFilesWithin(timeInterval: TimeInterval) async -> [RecentFileItem]
    
    /// Export recent files data for backup purposes
    /// - Returns: Data representation of recent files
    func exportRecentFiles() async throws -> Data
    
    /// Import recent files data from backup
    /// - Parameter data: Data to import
    /// - Parameter merge: Whether to merge with existing data or replace
    func importRecentFiles(from data: Data, merge: Bool) async throws
}