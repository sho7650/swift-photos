import Foundation
import SwiftUI
import Observation

/// Unified performance metrics manager that consolidates all performance tracking
/// Integrates PerformanceMonitor, Repository metrics, and Settings manager performance
@MainActor
@Observable
public final class PerformanceMetricsManager {
    
    // MARK: - Shared Instance
    
    public static let shared = PerformanceMetricsManager()
    
    // MARK: - Published Properties
    
    public private(set) var unifiedStats = UnifiedPerformanceStats()
    public private(set) var isMonitoring = false
    public private(set) var lastUpdate = Date()
    
    // MARK: - Dependencies
    
    public let performanceMonitor = PerformanceMonitor.shared
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 2.0
    
    // MARK: - Configuration
    
    public var enabledCategories: Set<PerformanceCategory> = [
        .system, .repository, .imageLoading, .settings, .ui
    ]
    
    // MARK: - Initialization
    
    private init() {
        ProductionLogger.lifecycle("PerformanceMetricsManager initialized")
    }
    
    deinit {
        // Cannot call @MainActor method from deinit
        // Timer will be cleaned up by ARC
        ProductionLogger.lifecycle("PerformanceMetricsManager deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Start unified performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        performanceMonitor.startMonitoring()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateUnifiedStats()
            }
        }
        
        // Initial update
        Task {
            await updateUnifiedStats()
        }
        
        ProductionLogger.info("PerformanceMetricsManager: Started monitoring")
    }
    
    /// Stop unified performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        performanceMonitor.stopMonitoring()
        updateTimer?.invalidate()
        updateTimer = nil
        
        ProductionLogger.info("PerformanceMetricsManager: Stopped monitoring")
    }
    
    /// Get performance stats for a specific category
    public func getStats(for category: PerformanceCategory) -> CategoryPerformanceStats? {
        switch category {
        case .system:
            return unifiedStats.systemStats
        case .repository:
            return unifiedStats.repositoryStats
        case .imageLoading:
            return unifiedStats.imageLoadingStats
        case .settings:
            return unifiedStats.settingsStats
        case .ui:
            return unifiedStats.uiStats
        }
    }
    
    /// Get comprehensive performance report
    public func getComprehensiveReport() -> ComprehensivePerformanceReport {
        let performanceReport = performanceMonitor.getPerformanceReport()
        
        return ComprehensivePerformanceReport(
            unifiedStats: unifiedStats,
            performanceReport: performanceReport,
            monitoringDuration: isMonitoring ? Date().timeIntervalSince(lastUpdate) : 0,
            enabledCategories: enabledCategories,
            recommendations: generateRecommendations()
        )
    }
    
    /// Reset all performance tracking data
    public func reset() {
        performanceMonitor.reset()
        unifiedStats = UnifiedPerformanceStats()
        lastUpdate = Date()
        
        ProductionLogger.info("PerformanceMetricsManager: Reset all data")
    }
    
    // MARK: - Private Methods
    
    private func updateUnifiedStats() async {
        var newStats = UnifiedPerformanceStats()
        
        // System metrics from PerformanceMonitor
        if enabledCategories.contains(.system) {
            let performanceReport = performanceMonitor.getPerformanceReport()
            newStats.systemStats = CategoryPerformanceStats(
                category: .system,
                operationCount: performanceReport.currentMetrics.totalOperations,
                averageResponseTime: 0, // Will be calculated from operation stats
                errorRate: 0,
                memoryUsageMB: performanceReport.currentMetrics.memoryUsageMB,
                cpuUsagePercentage: performanceReport.currentMetrics.cpuUsagePercentage,
                customMetrics: [
                    "peak_memory_mb": Double(performanceReport.peakMemoryUsage),
                    "memory_warnings": Double(performanceReport.memoryWarningCount),
                    "active_operations": Double(performanceReport.currentMetrics.activeOperations)
                ]
            )
        }
        
        // Repository metrics
        if enabledCategories.contains(.repository) {
            let repositoryMetrics = await ViewModelFactory.getRepositoryMetrics()
            newStats.repositoryStats = aggregateRepositoryStats(repositoryMetrics)
        }
        
        // Image loading metrics
        if enabledCategories.contains(.imageLoading) {
            newStats.imageLoadingStats = await collectImageLoadingStats()
        }
        
        // Settings metrics
        if enabledCategories.contains(.settings) {
            newStats.settingsStats = collectSettingsStats()
        }
        
        // UI metrics
        if enabledCategories.contains(.ui) {
            newStats.uiStats = collectUIStats()
        }
        
        unifiedStats = newStats
        lastUpdate = Date()
    }
    
    private func aggregateRepositoryStats(_ metrics: [String: RepositoryMetrics]) -> CategoryPerformanceStats {
        let totalOperations = metrics.values.map { $0.operationCount }.reduce(0, +)
        let totalErrors = metrics.values.map { $0.errorCount }.reduce(0, +)
        let averageResponseTime = metrics.values.map { $0.averageResponseTime }.reduce(0, +) / Double(max(metrics.count, 1))
        let errorRate = totalOperations > 0 ? Double(totalErrors) / Double(totalOperations) : 0
        
        var customMetrics: [String: Double] = [:]
        for (key, metric) in metrics {
            customMetrics["\(key.lowercased())_operations"] = Double(metric.operationCount)
            customMetrics["\(key.lowercased())_cache_hit_rate"] = metric.cacheHitRate
            customMetrics["\(key.lowercased())_data_mb"] = Double(metric.totalDataTransferred) / (1024 * 1024)
        }
        
        return CategoryPerformanceStats(
            category: .repository,
            operationCount: totalOperations,
            averageResponseTime: averageResponseTime,
            errorRate: errorRate,
            memoryUsageMB: 0, // Repository memory usage tracked separately
            cpuUsagePercentage: 0,
            customMetrics: customMetrics
        )
    }
    
    private func collectImageLoadingStats() async -> CategoryPerformanceStats {
        // Get stats from PerformanceMonitor for image loading operations
        let imageLoadStats = performanceMonitor.getOperationStats("ImageLoad")
        let imageCacheStats = performanceMonitor.getOperationStats("ImageCache")
        
        let totalOperations = (imageLoadStats?.count ?? 0) + (imageCacheStats?.count ?? 0)
        let averageTime = ((imageLoadStats?.averageTime ?? 0) + (imageCacheStats?.averageTime ?? 0)) / 2
        
        return CategoryPerformanceStats(
            category: .imageLoading,
            operationCount: totalOperations,
            averageResponseTime: averageTime,
            errorRate: 0, // Would need error tracking in image loading
            memoryUsageMB: 0, // Image cache memory tracked separately
            cpuUsagePercentage: 0,
            customMetrics: [
                "cache_operations": Double(imageCacheStats?.count ?? 0),
                "load_operations": Double(imageLoadStats?.count ?? 0),
                "max_load_time": imageLoadStats?.maxTime ?? 0,
                "min_load_time": imageLoadStats?.minTime ?? 0
            ]
        )
    }
    
    private func collectSettingsStats() -> CategoryPerformanceStats {
        let settingsStats = performanceMonitor.getOperationStats("SettingsUpdate")
        
        return CategoryPerformanceStats(
            category: .settings,
            operationCount: settingsStats?.count ?? 0,
            averageResponseTime: settingsStats?.averageTime ?? 0,
            errorRate: 0,
            memoryUsageMB: 0,
            cpuUsagePercentage: 0,
            customMetrics: [
                "settings_updates": Double(settingsStats?.count ?? 0),
                "max_update_time": settingsStats?.maxTime ?? 0
            ]
        )
    }
    
    private func collectUIStats() -> CategoryPerformanceStats {
        let uiUpdateStats = performanceMonitor.getOperationStats("UIUpdate")
        let transitionStats = performanceMonitor.getOperationStats("Transition")
        
        let totalOperations = (uiUpdateStats?.count ?? 0) + (transitionStats?.count ?? 0)
        let averageTime = ((uiUpdateStats?.averageTime ?? 0) + (transitionStats?.averageTime ?? 0)) / 2
        
        return CategoryPerformanceStats(
            category: .ui,
            operationCount: totalOperations,
            averageResponseTime: averageTime,
            errorRate: 0,
            memoryUsageMB: 0,
            cpuUsagePercentage: 0,
            customMetrics: [
                "ui_updates": Double(uiUpdateStats?.count ?? 0),
                "transitions": Double(transitionStats?.count ?? 0),
                "max_transition_time": transitionStats?.maxTime ?? 0
            ]
        )
    }
    
    private func generateRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        // Memory recommendations
        if let systemStats = unifiedStats.systemStats {
            if systemStats.memoryUsageMB > 1024 { // > 1GB
                recommendations.append(PerformanceRecommendation(
                    category: .system,
                    severity: .warning,
                    title: "High Memory Usage",
                    description: "Memory usage is \(systemStats.memoryUsageMB)MB. Consider reducing photo cache size.",
                    action: "Reduce performance settings"
                ))
            }
            
            if systemStats.cpuUsagePercentage > 80 {
                recommendations.append(PerformanceRecommendation(
                    category: .system,
                    severity: .critical,
                    title: "High CPU Usage",
                    description: "CPU usage is \(Int(systemStats.cpuUsagePercentage))%. Consider pausing slideshow.",
                    action: "Reduce processing load"
                ))
            }
        }
        
        // Repository recommendations
        if let repoStats = unifiedStats.repositoryStats {
            if repoStats.errorRate > 0.05 { // > 5% error rate
                recommendations.append(PerformanceRecommendation(
                    category: .repository,
                    severity: .warning,
                    title: "High Repository Error Rate",
                    description: "Repository error rate is \(Int(repoStats.errorRate * 100))%.",
                    action: "Check file permissions and disk space"
                ))
            }
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public enum PerformanceCategory: String, CaseIterable, Sendable {
    case system = "System"
    case repository = "Repository"
    case imageLoading = "Image Loading"
    case settings = "Settings"
    case ui = "UI"
    
    var displayName: String { rawValue }
    var icon: String {
        switch self {
        case .system: return "cpu"
        case .repository: return "folder"
        case .imageLoading: return "photo"
        case .settings: return "gearshape"
        case .ui: return "rectangle.on.rectangle"
        }
    }
}

public struct UnifiedPerformanceStats: Sendable {
    public var systemStats: CategoryPerformanceStats?
    public var repositoryStats: CategoryPerformanceStats?
    public var imageLoadingStats: CategoryPerformanceStats?
    public var settingsStats: CategoryPerformanceStats?
    public var uiStats: CategoryPerformanceStats?
    
    public init() {}
    
    public var allCategories: [CategoryPerformanceStats] {
        [systemStats, repositoryStats, imageLoadingStats, settingsStats, uiStats].compactMap { $0 }
    }
    
    public var totalOperations: Int {
        allCategories.map { $0.operationCount }.reduce(0, +)
    }
    
    public var overallAverageResponseTime: Double {
        let stats = allCategories.filter { $0.operationCount > 0 }
        guard !stats.isEmpty else { return 0 }
        return stats.map { $0.averageResponseTime }.reduce(0, +) / Double(stats.count)
    }
}

public struct CategoryPerformanceStats: Sendable {
    public let category: PerformanceCategory
    public let operationCount: Int
    public let averageResponseTime: TimeInterval
    public let errorRate: Double
    public let memoryUsageMB: UInt64
    public let cpuUsagePercentage: Double
    public let customMetrics: [String: Double]
    
    public init(
        category: PerformanceCategory,
        operationCount: Int,
        averageResponseTime: TimeInterval,
        errorRate: Double,
        memoryUsageMB: UInt64 = 0,
        cpuUsagePercentage: Double = 0,
        customMetrics: [String: Double] = [:]
    ) {
        self.category = category
        self.operationCount = operationCount
        self.averageResponseTime = averageResponseTime
        self.errorRate = errorRate
        self.memoryUsageMB = memoryUsageMB
        self.cpuUsagePercentage = cpuUsagePercentage
        self.customMetrics = customMetrics
    }
}

public struct ComprehensivePerformanceReport: Sendable {
    public let unifiedStats: UnifiedPerformanceStats
    public let performanceReport: PerformanceReport
    public let monitoringDuration: TimeInterval
    public let enabledCategories: Set<PerformanceCategory>
    public let recommendations: [PerformanceRecommendation]
    
    public init(
        unifiedStats: UnifiedPerformanceStats,
        performanceReport: PerformanceReport,
        monitoringDuration: TimeInterval,
        enabledCategories: Set<PerformanceCategory>,
        recommendations: [PerformanceRecommendation]
    ) {
        self.unifiedStats = unifiedStats
        self.performanceReport = performanceReport
        self.monitoringDuration = monitoringDuration
        self.enabledCategories = enabledCategories
        self.recommendations = recommendations
    }
}

public struct PerformanceRecommendation: Sendable {
    public enum Severity: String, CaseIterable, Sendable {
        case info = "Info"
        case warning = "Warning"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    public let category: PerformanceCategory
    public let severity: Severity
    public let title: String
    public let description: String
    public let action: String
    
    public init(category: PerformanceCategory, severity: Severity, title: String, description: String, action: String) {
        self.category = category
        self.severity = severity
        self.title = title
        self.description = description
        self.action = action
    }
}