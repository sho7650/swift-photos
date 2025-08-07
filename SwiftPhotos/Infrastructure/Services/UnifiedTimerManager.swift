//
//  UnifiedTimerManager.swift
//  Swift Photos
//
//  Unified timer manager that implements TimerManagementProtocol
//  Consolidates OptimizedTimerPool functionality with clean interface
//

import Foundation

/// Unified timer manager that implements the TimerManagementProtocol
/// Wraps OptimizedTimerPool to provide a clean Application layer interface
@MainActor
public final class UnifiedTimerManager: TimerManagementProtocol {
    
    // MARK: - Properties
    
    private let timerPool: OptimizedTimerPool
    private var timerMetadata: [UUID: TimerMetadata] = [:]
    
    // MARK: - Initialization
    
    public init(timerPool: OptimizedTimerPool = OptimizedTimerPool.shared) {
        self.timerPool = timerPool
        ProductionLogger.lifecycle("UnifiedTimerManager initialized with OptimizedTimerPool")
    }
    
    // MARK: - TimerManagementProtocol Implementation
    
    public func scheduleTimer(
        duration: TimeInterval,
        tolerance: TimeInterval = 0.1,
        userInfo: [String: String]? = nil,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID {
        let timerId = timerPool.scheduleTimer(
            duration: duration,
            tolerance: tolerance,
            repeats: false,
            userInfo: userInfo,
            completion: { [weak self] in
                Task { @MainActor in
                    await self?.handleTimerCompleted(timerId)
                }
                completion()
            }
        )
        
        // Store metadata for enhanced info
        timerMetadata[timerId] = TimerMetadata(
            id: timerId,
            duration: duration,
            tolerance: tolerance,
            isRepeating: false,
            userInfo: userInfo,
            startTime: Date()
        )
        
        ProductionLogger.debug("UnifiedTimerManager: Scheduled one-shot timer \(timerId.uuidString.prefix(8)) for \(duration)s")
        return timerId
    }
    
    public func scheduleRepeatingTimer(
        interval: TimeInterval,
        tolerance: TimeInterval = 0.1,
        userInfo: [String: String]? = nil,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID {
        let timerId = timerPool.scheduleTimer(
            duration: interval,
            tolerance: tolerance,
            repeats: true,
            userInfo: userInfo,
            completion: completion
        )
        
        // Store metadata for enhanced info
        timerMetadata[timerId] = TimerMetadata(
            id: timerId,
            duration: interval,
            tolerance: tolerance,
            isRepeating: true,
            userInfo: userInfo,
            startTime: Date()
        )
        
        ProductionLogger.debug("UnifiedTimerManager: Scheduled repeating timer \(timerId.uuidString.prefix(8)) with \(interval)s interval")
        return timerId
    }
    
    public func cancelTimer(_ timerId: UUID) async {
        timerPool.cancelTimer(timerId)
        timerMetadata.removeValue(forKey: timerId)
        ProductionLogger.debug("UnifiedTimerManager: Cancelled timer \(timerId.uuidString.prefix(8))")
    }
    
    public func extendTimer(_ timerId: UUID, by additionalDuration: TimeInterval) async {
        timerPool.extendTimer(timerId, by: additionalDuration)
        
        // Update metadata
        if var metadata = timerMetadata[timerId] {
            metadata.duration += additionalDuration
            timerMetadata[timerId] = metadata
        }
        
        ProductionLogger.debug("UnifiedTimerManager: Extended timer \(timerId.uuidString.prefix(8)) by \(additionalDuration)s")
    }
    
    public func getTimerInfo(_ timerId: UUID) async -> UnifiedTimerInfo? {
        guard let poolInfo = timerPool.getTimerInfo(timerId),
              let metadata = timerMetadata[timerId] else {
            return nil
        }
        
        return UnifiedTimerInfo(
            id: timerId,
            duration: poolInfo.duration,
            remainingTime: poolInfo.remainingTime,
            elapsedTime: poolInfo.elapsedTime,
            isActive: poolInfo.isActive,
            isRepeating: metadata.isRepeating,
            userInfo: metadata.userInfo
        )
    }
    
    public func getPoolStatistics() async -> TimerPoolStatistics {
        let poolStats = timerPool.getPoolStatistics()
        
        return TimerPoolStatistics(
            activeTimers: poolStats.activeTimers,
            totalTimersCreated: poolStats.totalTimersCreated,
            totalTimersCompleted: poolStats.totalTimersCompleted,
            isRunning: poolStats.masterTimerRunning,
            currentTickInterval: poolStats.currentTickInterval,
            isInBackground: poolStats.isInBackground
        )
    }
    
    public func cancelAllTimers() async {
        let activeTimerIds = Array(timerMetadata.keys)
        
        for timerId in activeTimerIds {
            timerPool.cancelTimer(timerId)
        }
        
        timerMetadata.removeAll()
        ProductionLogger.info("UnifiedTimerManager: Cancelled all \(activeTimerIds.count) active timers")
    }
    
    // MARK: - Private Methods
    
    private func handleTimerCompleted(_ timerId: UUID) async {
        // Clean up metadata for one-shot timers
        if let metadata = timerMetadata[timerId], !metadata.isRepeating {
            timerMetadata.removeValue(forKey: timerId)
        }
    }
}

// MARK: - Supporting Types

/// Internal metadata for enhanced timer tracking
private struct TimerMetadata {
    let id: UUID
    var duration: TimeInterval
    let tolerance: TimeInterval
    let isRepeating: Bool
    let userInfo: [String: String]?
    let startTime: Date
}

// MARK: - Factory Implementation

/// Factory for creating UnifiedTimerManager instances
public struct UnifiedTimerManagerFactory: TimerManagementFactory {
    
    public init() {}
    
    @MainActor
    public func createTimerManager() -> TimerManagementProtocol {
        return UnifiedTimerManager()
    }
}

// MARK: - Convenience Extensions

extension UnifiedTimerManager {
    
    /// Create a unified timer manager optimized for UI controls
    public static func forUIControls() -> UnifiedTimerManager {
        let manager = UnifiedTimerManager()
        ProductionLogger.debug("UnifiedTimerManager: Created UI controls optimized instance")
        return manager
    }
    
    /// Create a unified timer manager optimized for background tasks
    public static func forBackgroundTasks() -> UnifiedTimerManager {
        let manager = UnifiedTimerManager()
        ProductionLogger.debug("UnifiedTimerManager: Created background tasks optimized instance")
        return manager
    }
    
    /// Create a unified timer manager with high precision requirements
    public static func highPrecision() -> UnifiedTimerManager {
        let manager = UnifiedTimerManager()
        ProductionLogger.debug("UnifiedTimerManager: Created high precision instance")
        return manager
    }
}