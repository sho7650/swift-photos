import Foundation

/// File sorting configuration for slideshow photo organization
public struct SortSettings: Codable, Equatable, Sendable {
    /// Sort criteria
    public let order: SortOrder
    
    /// Sort direction
    public let direction: SortDirection
    
    /// Random seed for consistent random ordering (when order is .random)
    public let randomSeed: UInt64
    
    public init(
        order: SortOrder = .fileName,
        direction: SortDirection = .ascending,
        randomSeed: UInt64? = nil
    ) {
        self.order = order
        self.direction = direction
        // Generate consistent seed for random ordering if not provided
        self.randomSeed = randomSeed ?? UInt64.random(in: 0...UInt64.max)
    }
    
    /// Sort order options
    public enum SortOrder: String, CaseIterable, Codable, Sendable {
        case fileName = "fileName"
        case creationDate = "creationDate"
        case modificationDate = "modificationDate"
        case fileSize = "fileSize"
        case random = "random"
        
        public var displayName: String {
            switch self {
            case .fileName:
                return "File Name"
            case .creationDate:
                return "Creation Date"
            case .modificationDate:
                return "Modification Date"
            case .fileSize:
                return "File Size"
            case .random:
                return "Random"
            }
        }
        
        public var description: String {
            switch self {
            case .fileName:
                return "Sort by file name alphabetically"
            case .creationDate:
                return "Sort by when the photo was taken"
            case .modificationDate:
                return "Sort by when the file was last modified"
            case .fileSize:
                return "Sort by file size"
            case .random:
                return "Random order with consistent seed"
            }
        }
    }
    
    /// Sort direction options
    public enum SortDirection: String, CaseIterable, Codable, Sendable {
        case ascending = "ascending"
        case descending = "descending"
        
        public var displayName: String {
            switch self {
            case .ascending:
                return "Ascending"
            case .descending:
                return "Descending"
            }
        }
        
        public var symbol: String {
            switch self {
            case .ascending:
                return "↑"
            case .descending:
                return "↓"
            }
        }
    }
    
    // Predefined presets
    public static let `default` = SortSettings(
        order: .fileName,
        direction: .ascending
    )
    
    public static let alphabetical = SortSettings(
        order: .fileName,
        direction: .ascending
    )
    
    public static let chronological = SortSettings(
        order: .creationDate,
        direction: .ascending
    )
    
    public static let newestFirst = SortSettings(
        order: .creationDate,
        direction: .descending
    )
    
    public static let largestFirst = SortSettings(
        order: .fileSize,
        direction: .descending
    )
    
    public static let randomized = SortSettings(
        order: .random,
        direction: .ascending
    )
}

