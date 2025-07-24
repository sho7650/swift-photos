import Foundation

/// Value object representing a recently accessed folder in the slideshow application
/// Follows Domain-Driven Design principles with immutability and validation
public struct RecentFileItem: Codable, Equatable, Identifiable, Hashable {
    /// Unique identifier for the recent file item
    public let id: UUID
    
    /// The URL of the folder that was accessed
    public let url: URL
    
    /// Human-readable display name for the folder
    public let displayName: String
    
    /// When this folder was last accessed
    public let lastAccessDate: Date
    
    /// Security bookmark data for sandboxed file access
    public let securityBookmark: Data
    
    /// File size estimation for the folder (optional)
    public let estimatedSize: Int64?
    
    /// Number of photos detected in the folder (optional)
    public let photoCount: Int?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        displayName: String? = nil,
        lastAccessDate: Date = Date(),
        securityBookmark: Data,
        estimatedSize: Int64? = nil,
        photoCount: Int? = nil
    ) throws {
        // Validation: URL must be a valid file URL
        guard url.isFileURL else {
            throw RecentFileItemError.invalidURL(url)
        }
        
        // Validation: Display name cannot be empty
        let resolvedDisplayName = displayName ?? url.lastPathComponent
        guard !resolvedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecentFileItemError.emptyDisplayName
        }
        
        // Validation: Security bookmark must not be empty
        guard !securityBookmark.isEmpty else {
            throw RecentFileItemError.emptySecurityBookmark
        }
        
        // Validation: Photo count cannot be negative
        if let count = photoCount, count < 0 {
            throw RecentFileItemError.negativePhotoCount(count)
        }
        
        // Validation: Estimated size cannot be negative
        if let size = estimatedSize, size < 0 {
            throw RecentFileItemError.negativeEstimatedSize(size)
        }
        
        self.id = id
        self.url = url
        self.displayName = resolvedDisplayName
        self.lastAccessDate = lastAccessDate
        self.securityBookmark = securityBookmark
        self.estimatedSize = estimatedSize
        self.photoCount = photoCount
    }
    
    /// Create a new RecentFileItem with updated access date
    /// Following immutability principles - returns new instance instead of modifying
    public func withUpdatedAccessDate(_ date: Date = Date()) -> RecentFileItem {
        return try! RecentFileItem(
            id: self.id,
            url: self.url,
            displayName: self.displayName,
            lastAccessDate: date,
            securityBookmark: self.securityBookmark,
            estimatedSize: self.estimatedSize,
            photoCount: self.photoCount
        )
    }
    
    /// Create a new RecentFileItem with updated photo count
    /// Following immutability principles - returns new instance instead of modifying
    public func withUpdatedPhotoCount(_ count: Int) throws -> RecentFileItem {
        return try RecentFileItem(
            id: self.id,
            url: self.url,
            displayName: self.displayName,
            lastAccessDate: self.lastAccessDate,
            securityBookmark: self.securityBookmark,
            estimatedSize: self.estimatedSize,
            photoCount: count
        )
    }
    
    /// Returns a user-friendly path for display purposes
    public var displayPath: String {
        return url.path
    }
    
    /// Returns true if this recent file item is older than the specified time interval
    public func isOlderThan(_ timeInterval: TimeInterval) -> Bool {
        return Date().timeIntervalSince(lastAccessDate) > timeInterval
    }
    
    /// Hash implementation for Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Errors that can occur when creating or manipulating RecentFileItem
public enum RecentFileItemError: LocalizedError, Equatable {
    case invalidURL(URL)
    case emptyDisplayName
    case emptySecurityBookmark
    case negativePhotoCount(Int)
    case negativeEstimatedSize(Int64)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid file URL: \(url.absoluteString)"
        case .emptyDisplayName:
            return "Display name cannot be empty"
        case .emptySecurityBookmark:
            return "Security bookmark data cannot be empty"
        case .negativePhotoCount(let count):
            return "Photo count cannot be negative: \(count)"
        case .negativeEstimatedSize(let size):
            return "Estimated size cannot be negative: \(size)"
        }
    }
}

// MARK: - Predefined Factory Methods

extension RecentFileItem {
    /// Create a RecentFileItem from a folder URL with security bookmark
    /// This is the primary factory method for creating recent file items
    public static func fromFolder(
        url: URL,
        securityBookmark: Data,
        photoCount: Int? = nil
    ) throws -> RecentFileItem {
        return try RecentFileItem(
            url: url,
            securityBookmark: securityBookmark,
            photoCount: photoCount
        )
    }
    
    /// Create a RecentFileItem for testing purposes with minimal data
    public static func forTesting(
        url: URL = URL(fileURLWithPath: "/tmp/test"),
        displayName: String = "Test Folder"
    ) throws -> RecentFileItem {
        let dummyBookmark = Data("test-bookmark".utf8)
        return try RecentFileItem(
            url: url,
            displayName: displayName,
            securityBookmark: dummyBookmark
        )
    }
}