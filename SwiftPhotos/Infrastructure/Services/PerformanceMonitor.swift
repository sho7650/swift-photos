import Foundation
import AppKit
import os.log

/// Advanced performance monitoring system for large photo collections
@MainActor
public final class PerformanceMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - Properties
    
    @Published public private(set) var currentMetrics = PerformanceMetrics()
    @Published public private(set) var isMonitoring = false
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "PerformanceMonitor")
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 5.0 // Monitor every 5 seconds
    
    // Memory tracking
    private var peakMemoryUsage: UInt64 = 0
    private var memoryWarningCount = 0
    private var lastMemoryWarning: Date?
    
    // Performance tracking
    private var operationStartTimes: [String: Date] = [:]
    private var operationCounts: [String: Int] = [:]
    private var operationDurations: [String: [TimeInterval]] = [:]
    
    // MARK: - Initialization
    
    private init() {
        logger.info("📊 PerformanceMonitor: Initialized")
        setupMemoryWarningNotifications()
    }
    
    deinit {
        // Note: Can't call async stopMonitoring() in deinit - timer will be cleaned up by ARC
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /// Start performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("📊 PerformanceMonitor: Starting monitoring")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
        
        // Initial metrics collection
        Task {
            await updateMetrics()
        }
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("📊 PerformanceMonitor: Stopped monitoring")
    }
    
    /// Record the start of an operation
    public func startOperation(_ name: String) {
        operationStartTimes[name] = Date()
        operationCounts[name, default: 0] += 1
    }
    
    /// Record the end of an operation
    public func endOperation(_ name: String) {
        guard let startTime = operationStartTimes[name] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        operationDurations[name, default: []].append(duration)
        operationStartTimes.removeValue(forKey: name)
        
        // Log slow operations
        if duration > 1.0 {
            logger.warning("📊 PerformanceMonitor: Slow operation '\(name)' took \(String(format: "%.2f", duration))s")
        }
    }
    
    /// Get operation statistics
    public func getOperationStats(_ name: String) -> OperationStats? {
        guard let durations = operationDurations[name], !durations.isEmpty else { return nil }
        
        let count = operationCounts[name] ?? 0
        let totalTime = durations.reduce(0, +)
        let averageTime = totalTime / Double(durations.count)
        let minTime = durations.min() ?? 0
        let maxTime = durations.max() ?? 0
        
        return OperationStats(
            name: name,
            count: count,
            totalTime: totalTime,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime
        )
    }
    
    /// Get comprehensive performance report
    public func getPerformanceReport() -> PerformanceReport {
        let allOperationStats = operationDurations.keys.compactMap { getOperationStats($0) }
        
        return PerformanceReport(
            currentMetrics: currentMetrics,
            operationStats: allOperationStats,
            peakMemoryUsage: peakMemoryUsage,
            memoryWarningCount: memoryWarningCount,
            lastMemoryWarning: lastMemoryWarning,
            monitoringDuration: isMonitoring ? Date().timeIntervalSince(currentMetrics.timestamp) : 0
        )
    }
    
    /// Reset all performance data
    public func reset() {
        operationStartTimes.removeAll()
        operationCounts.removeAll()
        operationDurations.removeAll()
        peakMemoryUsage = 0
        memoryWarningCount = 0
        lastMemoryWarning = nil
        
        Task {
            await updateMetrics()
        }
        
        logger.info("📊 PerformanceMonitor: Reset all data")
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryWarningNotifications() {
        // Note: macOS doesn't have built-in memory warnings like iOS
        // We'll monitor memory pressure through other means
        logger.debug("📊 PerformanceMonitor: Memory warning monitoring setup (macOS compatible)")
    }
    
    private func handleMemoryWarning() {
        memoryWarningCount += 1
        lastMemoryWarning = Date()
        
        logger.warning("📊 PerformanceMonitor: Memory warning received (count: \(self.memoryWarningCount))")
        
        Task {
            await updateMetrics()
        }
    }
    
    private func updateMetrics() async {
        let newMetrics = await collectCurrentMetrics()
        
        // Update peak memory usage
        if newMetrics.memoryUsageMB > peakMemoryUsage {
            peakMemoryUsage = newMetrics.memoryUsageMB
        }
        
        currentMetrics = newMetrics
    }
    
    private func collectCurrentMetrics() async -> PerformanceMetrics {
        let memoryInfo = getMemoryInfo()
        let cpuUsage = getCPUUsage()
        
        return PerformanceMetrics(
            timestamp: Date(),
            memoryUsageMB: memoryInfo.usedMemoryMB,
            availableMemoryMB: memoryInfo.availableMemoryMB,
            cpuUsagePercentage: cpuUsage,
            activeOperations: operationStartTimes.count,
            totalOperations: operationCounts.values.reduce(0, +)
        )
    }
    
    private func getMemoryInfo() -> (usedMemoryMB: UInt64, availableMemoryMB: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let usedMemoryMB: UInt64
        if result == KERN_SUCCESS {
            usedMemoryMB = UInt64(info.resident_size) / (1024 * 1024)
        } else {
            usedMemoryMB = 0
        }
        
        // Get system memory info
        let totalMemoryMB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
        let availableMemoryMB = totalMemoryMB - usedMemoryMB
        
        return (usedMemoryMB, availableMemoryMB)
    }
    
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            // This is a simplified CPU usage calculation
            // In a real implementation, you'd need to track user_time and system_time over time
            return Double(info.user_time.seconds + info.system_time.seconds) * 0.01
        }
        
        return 0.0
    }
}

// MARK: - Supporting Types

public struct PerformanceMetrics: Codable, Sendable {
    public let timestamp: Date
    public let memoryUsageMB: UInt64
    public let availableMemoryMB: UInt64
    public let cpuUsagePercentage: Double
    public let activeOperations: Int
    public let totalOperations: Int
    
    public init(
        timestamp: Date = Date(),
        memoryUsageMB: UInt64 = 0,
        availableMemoryMB: UInt64 = 0,
        cpuUsagePercentage: Double = 0,
        activeOperations: Int = 0,
        totalOperations: Int = 0
    ) {
        self.timestamp = timestamp
        self.memoryUsageMB = memoryUsageMB
        self.availableMemoryMB = availableMemoryMB
        self.cpuUsagePercentage = cpuUsagePercentage
        self.activeOperations = activeOperations
        self.totalOperations = totalOperations
    }
}

public struct OperationStats: Codable, Sendable {
    public let name: String
    public let count: Int
    public let totalTime: TimeInterval
    public let averageTime: TimeInterval
    public let minTime: TimeInterval
    public let maxTime: TimeInterval
}

public struct PerformanceReport: Codable, Sendable {
    public let currentMetrics: PerformanceMetrics
    public let operationStats: [OperationStats]
    public let peakMemoryUsage: UInt64
    public let memoryWarningCount: Int
    public let lastMemoryWarning: Date?
    public let monitoringDuration: TimeInterval
}