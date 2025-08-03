import Foundation
import AppKit

// MARK: - Loading Strategy Protocol

/// Strategy pattern protocol for different image loading approaches
protocol ImageLoadingStrategy: Sendable {
    /// Load a single image with the strategy-specific approach
    func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage
    
    /// Load multiple images with strategy-specific optimization
    func loadImages(photos: [Photo], context: LoadingContext) async -> [UUID: SendableImage]
    
    /// Update performance settings for the strategy
    func updateSettings(_ settings: PerformanceSettings) async
    
    /// Get strategy-specific statistics
    func getStatistics() async -> LoadingStatistics
    
    /// Cancel ongoing operations for the strategy
    func cancelOperations(for photoIds: Set<UUID>) async
    
    /// Cleanup resources
    func cleanup() async
}

// MARK: - Loading Context

/// Context information for image loading operations
public struct LoadingContext: Sendable {
    let collectionSize: Int
    let currentIndex: Int
    let priority: LoadingPriority
    let memoryPressure: MemoryPressureLevel
    let navigationDirection: NavigationDirection?
    let isEmergency: Bool
    
    public init(
        collectionSize: Int,
        currentIndex: Int = 0,
        priority: LoadingPriority = .normal,
        memoryPressure: MemoryPressureLevel = .normal,
        navigationDirection: NavigationDirection? = nil,
        isEmergency: Bool = false
    ) {
        self.collectionSize = collectionSize
        self.currentIndex = currentIndex
        self.priority = priority
        self.memoryPressure = memoryPressure
        self.navigationDirection = navigationDirection
        self.isEmergency = isEmergency
    }
}

// MARK: - Supporting Types

public enum LoadingPriority: Int, Sendable, CaseIterable {
    case background = 0
    case normal = 1
    case high = 2
    case emergency = 3
    
    public var taskPriority: TaskPriority {
        switch self {
        case .background: return .low
        case .normal: return .medium
        case .high: return .high
        case .emergency: return .userInitiated
        }
    }
}

public enum MemoryPressureLevel: Sendable {
    case low
    case normal
    case high
    case critical
}

public enum NavigationDirection: Sendable {
    case forward
    case backward
    case unknown
}

// MARK: - Loading Statistics

public struct LoadingStatistics: Sendable {
    public let totalLoads: Int
    public let successfulLoads: Int
    public let failedLoads: Int
    public let averageLoadTime: TimeInterval
    public let memoryUsageMB: Int
    public let cacheHitRate: Double
    public let activeTaskCount: Int
    
    public var successRate: Double {
        guard totalLoads > 0 else { return 0.0 }
        return Double(successfulLoads) / Double(totalLoads)
    }
}

// MARK: - Strategy Selection Protocol

/// Protocol for determining which loading strategy to use
protocol LoadingStrategySelector: Sendable {
    func selectStrategy(for context: LoadingContext) async -> ImageLoadingStrategy
}

// MARK: - Default Strategy Selector

actor DefaultLoadingStrategySelector: LoadingStrategySelector {
    private let basicStrategy: ImageLoadingStrategy
    private let virtualStrategy: ImageLoadingStrategy
    private let emergencyStrategy: ImageLoadingStrategy
    private let preloadStrategy: ImageLoadingStrategy
    
    init(
        basicStrategy: ImageLoadingStrategy,
        virtualStrategy: ImageLoadingStrategy,
        emergencyStrategy: ImageLoadingStrategy,
        preloadStrategy: ImageLoadingStrategy
    ) {
        self.basicStrategy = basicStrategy
        self.virtualStrategy = virtualStrategy
        self.emergencyStrategy = emergencyStrategy
        self.preloadStrategy = preloadStrategy
    }
    
    func selectStrategy(for context: LoadingContext) async -> ImageLoadingStrategy {
        // Emergency loading takes highest priority
        if context.isEmergency || context.priority == .emergency {
            return emergencyStrategy
        }
        
        // For very large collections, use virtual loading
        if context.collectionSize > 1000 {
            return virtualStrategy
        }
        
        // For background/preload operations
        if context.priority == .background {
            return preloadStrategy
        }
        
        // Default to basic strategy for small to medium collections
        return basicStrategy
    }
}

// MARK: - Unified Loading Result

struct UnifiedLoadingResult: Sendable {
    let image: SendableImage?
    let error: Error?
    let loadTime: TimeInterval
    let strategy: String
    let fromCache: Bool
    
    var isSuccess: Bool {
        return image != nil && error == nil
    }
}

// MARK: - Load Operation

struct LoadOperation: Sendable {
    let id: UUID
    let photo: Photo
    let context: LoadingContext
    let startTime: Date
    let strategy: String
    
    init(photo: Photo, context: LoadingContext, strategy: String) {
        self.id = UUID()
        self.photo = photo
        self.context = context
        self.startTime = Date()
        self.strategy = strategy
    }
}