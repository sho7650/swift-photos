import Foundation

/// Configuration settings for the application's menu bar behavior
/// Follows Domain-Driven Design principles with immutability and validation
public struct MenuConfiguration: Codable, Equatable {
    /// Maximum number of recent files to maintain
    public let maxRecentFiles: Int
    
    /// Whether the File menu should be enabled
    public let enableFileMenu: Bool
    
    /// Whether recent files functionality should be enabled
    public let enableRecentFiles: Bool
    
    /// Whether to show full paths in recent files menu
    public let showFullPaths: Bool
    
    /// Whether to automatically clean up invalid recent files
    public let autoCleanupInvalidFiles: Bool
    
    /// Time interval (in seconds) after which unused recent files are removed
    public let recentFileExpirationInterval: TimeInterval
    
    /// Whether to group recent files by parent directory
    public let groupRecentFilesByDirectory: Bool
    
    public init(
        maxRecentFiles: Int = 10,
        enableFileMenu: Bool = true,
        enableRecentFiles: Bool = true,
        showFullPaths: Bool = false,
        autoCleanupInvalidFiles: Bool = true,
        recentFileExpirationInterval: TimeInterval = 30 * 24 * 60 * 60, // 30 days
        groupRecentFilesByDirectory: Bool = false
    ) throws {
        // Validation: Maximum recent files must be reasonable
        guard maxRecentFiles >= 0 && maxRecentFiles <= 50 else {
            throw MenuConfigurationError.invalidMaxRecentFiles(maxRecentFiles)
        }
        
        // Validation: Expiration interval must be positive
        guard recentFileExpirationInterval > 0 else {
            throw MenuConfigurationError.invalidExpirationInterval(recentFileExpirationInterval)
        }
        
        // Validation: If recent files are enabled, file menu must also be enabled
        if enableRecentFiles && !enableFileMenu {
            throw MenuConfigurationError.recentFilesRequireFileMenu
        }
        
        self.maxRecentFiles = maxRecentFiles
        self.enableFileMenu = enableFileMenu
        self.enableRecentFiles = enableRecentFiles
        self.showFullPaths = showFullPaths
        self.autoCleanupInvalidFiles = autoCleanupInvalidFiles
        self.recentFileExpirationInterval = recentFileExpirationInterval
        self.groupRecentFilesByDirectory = groupRecentFilesByDirectory
    }
    
    /// Create a new MenuConfiguration with updated max recent files
    /// Following immutability principles - returns new instance instead of modifying
    public func withMaxRecentFiles(_ count: Int) throws -> MenuConfiguration {
        return try MenuConfiguration(
            maxRecentFiles: count,
            enableFileMenu: self.enableFileMenu,
            enableRecentFiles: self.enableRecentFiles,
            showFullPaths: self.showFullPaths,
            autoCleanupInvalidFiles: self.autoCleanupInvalidFiles,
            recentFileExpirationInterval: self.recentFileExpirationInterval,
            groupRecentFilesByDirectory: self.groupRecentFilesByDirectory
        )
    }
    
    /// Create a new MenuConfiguration with recent files enabled/disabled
    /// Following immutability principles - returns new instance instead of modifying
    public func withRecentFilesEnabled(_ enabled: Bool) throws -> MenuConfiguration {
        return try MenuConfiguration(
            maxRecentFiles: self.maxRecentFiles,
            enableFileMenu: self.enableFileMenu,
            enableRecentFiles: enabled,
            showFullPaths: self.showFullPaths,
            autoCleanupInvalidFiles: self.autoCleanupInvalidFiles,
            recentFileExpirationInterval: self.recentFileExpirationInterval,
            groupRecentFilesByDirectory: self.groupRecentFilesByDirectory
        )
    }
    
    /// Returns true if recent files should be shown in the menu
    public var shouldShowRecentFiles: Bool {
        return enableFileMenu && enableRecentFiles && maxRecentFiles > 0
    }
    
    /// Returns the effective maximum number of recent files to display
    public var effectiveMaxRecentFiles: Int {
        return shouldShowRecentFiles ? maxRecentFiles : 0
    }
    
    /// Returns true if the given recent file count would trigger cleanup
    public func shouldCleanupRecentFiles(currentCount: Int) -> Bool {
        return autoCleanupInvalidFiles && currentCount > maxRecentFiles
    }
}

/// Errors that can occur when creating or manipulating MenuConfiguration
public enum MenuConfigurationError: LocalizedError, Equatable {
    case invalidMaxRecentFiles(Int)
    case invalidExpirationInterval(TimeInterval)
    case recentFilesRequireFileMenu
    
    public var errorDescription: String? {
        switch self {
        case .invalidMaxRecentFiles(let count):
            return "Maximum recent files must be between 0 and 50, got: \(count)"
        case .invalidExpirationInterval(let interval):
            return "Expiration interval must be positive, got: \(interval)"
        case .recentFilesRequireFileMenu:
            return "Recent files cannot be enabled when file menu is disabled"
        }
    }
}

// MARK: - Predefined Configurations

extension MenuConfiguration {
    /// Default configuration suitable for most users
    public static let `default` = try! MenuConfiguration()
    
    /// Minimal configuration with reduced functionality
    public static let minimal = try! MenuConfiguration(
        maxRecentFiles: 5,
        enableFileMenu: true,
        enableRecentFiles: true,
        showFullPaths: false,
        autoCleanupInvalidFiles: true,
        recentFileExpirationInterval: 7 * 24 * 60 * 60, // 7 days
        groupRecentFilesByDirectory: false
    )
    
    /// Power user configuration with enhanced features
    public static let powerUser = try! MenuConfiguration(
        maxRecentFiles: 20,
        enableFileMenu: true,
        enableRecentFiles: true,
        showFullPaths: true,
        autoCleanupInvalidFiles: true,
        recentFileExpirationInterval: 90 * 24 * 60 * 60, // 90 days
        groupRecentFilesByDirectory: true
    )
    
    /// Disabled configuration for users who don't want menu functionality
    public static let disabled = try! MenuConfiguration(
        maxRecentFiles: 0,
        enableFileMenu: false,
        enableRecentFiles: false,
        showFullPaths: false,
        autoCleanupInvalidFiles: false,
        recentFileExpirationInterval: 1, // Minimal positive value
        groupRecentFilesByDirectory: false
    )
    
    /// Testing configuration for development and testing
    public static let testing = try! MenuConfiguration(
        maxRecentFiles: 3,
        enableFileMenu: true,
        enableRecentFiles: true,
        showFullPaths: true,
        autoCleanupInvalidFiles: false,
        recentFileExpirationInterval: 60, // 1 minute for testing
        groupRecentFilesByDirectory: false
    )
}