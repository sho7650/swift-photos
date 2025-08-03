import Foundation
import CoreGraphics

/// Performance settings for image loading and caching
public struct PerformanceSettings: Codable, Equatable, Sendable {
    /// Number of images to keep in memory window around current image
    public let memoryWindowSize: Int
    
    /// Maximum memory usage in MB
    public let maxMemoryUsageMB: Int
    
    /// Maximum concurrent image loads
    public let maxConcurrentLoads: Int
    
    /// Threshold for switching to virtual loading mode
    public let largeCollectionThreshold: Int
    
    /// Enable aggressive memory management
    public let aggressiveMemoryManagement: Bool
    
    /// Preload distance (how far ahead/behind to preload)
    public let preloadDistance: Int
    
    public init(
        memoryWindowSize: Int = 50,
        maxMemoryUsageMB: Int = 2000, // 2GB default
        maxConcurrentLoads: Int = 5,
        largeCollectionThreshold: Int = 100,
        aggressiveMemoryManagement: Bool = true,
        preloadDistance: Int = 10
    ) {
        // Validate and constrain values - NO UPPER LIMITS for truly unlimited support
        self.memoryWindowSize = max(10, memoryWindowSize) // No upper limit - can be 10,000+
        self.maxMemoryUsageMB = max(500, maxMemoryUsageMB) // No upper limit - can use all available RAM
        self.maxConcurrentLoads = max(1, min(50, maxConcurrentLoads)) // 1-50 range (prevent thread exhaustion)
        self.largeCollectionThreshold = max(50, largeCollectionThreshold) // No upper limit
        self.aggressiveMemoryManagement = aggressiveMemoryManagement
        self.preloadDistance = max(5, preloadDistance) // No upper limit - can preload thousands
    }
    
    public static let `default` = PerformanceSettings()
    
    public static let highPerformance = PerformanceSettings(
        memoryWindowSize: 200,
        maxMemoryUsageMB: 4000,
        maxConcurrentLoads: 10,
        largeCollectionThreshold: 500,
        aggressiveMemoryManagement: false,
        preloadDistance: 25
    )
    
    public static let memoryConstrained = PerformanceSettings(
        memoryWindowSize: 20,
        maxMemoryUsageMB: 1000,
        maxConcurrentLoads: 3,
        largeCollectionThreshold: 50,
        aggressiveMemoryManagement: true,
        preloadDistance: 5
    )
    
    public static let unlimited = PerformanceSettings(
        memoryWindowSize: 1000,
        maxMemoryUsageMB: 8000,
        maxConcurrentLoads: 15,
        largeCollectionThreshold: 1000,
        aggressiveMemoryManagement: false,
        preloadDistance: 50
    )
    
    public static let massive = PerformanceSettings(
        memoryWindowSize: 2000,
        maxMemoryUsageMB: 16000, // 16GB
        maxConcurrentLoads: 25,
        largeCollectionThreshold: 5000,
        aggressiveMemoryManagement: true,
        preloadDistance: 100
    )
    
    public static let extreme = PerformanceSettings(
        memoryWindowSize: 5000,
        maxMemoryUsageMB: 32000, // 32GB
        maxConcurrentLoads: 40,
        largeCollectionThreshold: 10000,
        aggressiveMemoryManagement: true,
        preloadDistance: 200
    )
}

