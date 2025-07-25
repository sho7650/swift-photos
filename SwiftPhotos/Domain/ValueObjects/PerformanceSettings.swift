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

/// Settings manager for performance configuration
@MainActor
public class PerformanceSettingsManager: ObservableObject {
    @Published public var settings: PerformanceSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "SwiftPhotosPerformanceSettings"
    
    public init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(PerformanceSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = .default
        }
    }
    
    public func updateSettings(_ newSettings: PerformanceSettings) {
        settings = newSettings
        saveSettings()
    }
    
    public func resetToDefault() {
        settings = .default
        saveSettings()
    }
    
    public func applyPreset(_ preset: PerformanceSettings) {
        settings = preset
        saveSettings()
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    /// Get estimated memory usage for given number of images with smart window sizing
    public func estimatedMemoryUsage(for imageCount: Int, averageImageSize: CGSize = CGSize(width: 2000, height: 1500)) -> Int {
        let bytesPerPixel = 4 // RGBA
        let bytesPerImage = Int(averageImageSize.width * averageImageSize.height) * bytesPerPixel
        
        // Smart window sizing: use actual window size but cap at collection size
        let effectiveWindowSize = min(settings.memoryWindowSize, imageCount)
        
        // For massive collections, estimate based on actual memory window, not total collection
        let memoryUsageMB = (effectiveWindowSize * bytesPerImage) / (1024 * 1024)
        
        return memoryUsageMB
    }
    
    /// Check if current settings can handle the collection size
    public func canHandleCollection(size: Int) -> Bool {
        let estimatedUsage = estimatedMemoryUsage(for: size)
        return estimatedUsage <= settings.maxMemoryUsageMB
    }
    
    /// Get recommended settings for collection size with dynamic scaling for massive collections
    public func recommendedSettings(for collectionSize: Int) -> PerformanceSettings {
        switch collectionSize {
        case 0...100:
            return .default
        case 101...1000:
            return .highPerformance
        case 1001...10000:
            return .unlimited
        case 10001...50000:
            return .massive
        case 50001...100000:
            return .extreme
        default:
            // Dynamic scaling for truly massive collections (100k+)
            // Scale window size logarithmically to prevent memory explosion
            let logScale = log10(Double(collectionSize))
            let dynamicWindowSize = min(10000, max(1000, Int(1000 * logScale)))
            let dynamicPreloadDistance = min(500, max(100, Int(100 * logScale)))
            
            return PerformanceSettings(
                memoryWindowSize: dynamicWindowSize,
                maxMemoryUsageMB: 32000, // 32GB max for massive collections
                maxConcurrentLoads: 50,
                largeCollectionThreshold: 10000,
                aggressiveMemoryManagement: true,
                preloadDistance: dynamicPreloadDistance
            )
        }
    }
}