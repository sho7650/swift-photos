import Foundation
import Combine
import AppKit
import os.log

/// High-performance timer pool that manages multiple timers efficiently
/// Reduces overhead by sharing a single high-frequency timer for all timing needs
@MainActor
public final class OptimizedTimerPool: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = OptimizedTimerPool()
    
    // MARK: - Properties
    
    private var masterTimer: Timer?
    private var timerEntries: [UUID: TimerEntry] = [:]
    private let masterTickInterval: TimeInterval = 0.016 // ~60fps precision
    private let logger = Logger(subsystem: "SwiftPhotos", category: "OptimizedTimerPool")
    
    // Performance tracking
    private var lastCleanupTime: Date = Date()
    private let cleanupInterval: TimeInterval = 10.0 // Clean up every 10 seconds
    private var totalTimersCreated = 0
    private var totalTimersCompleted = 0
    
    // Background optimization
    private var isInBackground = false
    private var backgroundTickInterval: TimeInterval = 0.5 // Reduced frequency in background
    
    // MARK: - Initialization
    
    private init() {
        logger.info("🏊‍♂️ OptimizedTimerPool: Initialized")
        setupBackgroundMonitoring()
    }
    
    deinit {
        // Note: Cannot call @MainActor method from deinit
        // Timer cleanup will be handled automatically when the object is deallocated
        masterTimer?.invalidate()
        logger.info("🏊‍♂️ OptimizedTimerPool: Deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Schedule a timer with high efficiency
    public func scheduleTimer(
        duration: TimeInterval,
        tolerance: TimeInterval = 0.1,
        repeats: Bool = false,
        userInfo: [String: Any]? = nil,
        completion: @escaping () -> Void
    ) -> UUID {
        let timerId = UUID()
        let entry = TimerEntry(
            id: timerId,
            targetTime: Date().addingTimeInterval(duration),
            duration: duration,
            tolerance: tolerance,
            repeats: repeats,
            userInfo: userInfo,
            completion: completion
        )
        
        timerEntries[timerId] = entry
        totalTimersCreated += 1
        
        // Start master timer if needed
        if masterTimer == nil {
            startMasterTimer()
        }
        
        logger.debug("🏊‍♂️ OptimizedTimerPool: Scheduled timer \(timerId.uuidString.prefix(8)) for \(duration)s")
        return timerId
    }
    
    /// Cancel a scheduled timer
    public func cancelTimer(_ timerId: UUID) {
        guard timerEntries[timerId] != nil else { return }
        
        timerEntries.removeValue(forKey: timerId)
        logger.debug("🏊‍♂️ OptimizedTimerPool: Cancelled timer \(timerId.uuidString.prefix(8))")
        
        // Stop master timer if no more entries
        if timerEntries.isEmpty {
            stopMasterTimer()
        }
    }
    
    /// Extend a timer's duration
    public func extendTimer(_ timerId: UUID, by additionalDuration: TimeInterval) {
        guard var entry = timerEntries[timerId] else { return }
        
        entry.targetTime = entry.targetTime.addingTimeInterval(additionalDuration)
        entry.duration += additionalDuration
        timerEntries[timerId] = entry
        
        logger.debug("🏊‍♂️ OptimizedTimerPool: Extended timer \(timerId.uuidString.prefix(8)) by \(additionalDuration)s")
    }
    
    /// Get current timer information
    public func getTimerInfo(_ timerId: UUID) -> TimerInfo? {
        guard let entry = timerEntries[timerId] else { return nil }
        
        let now = Date()
        let remainingTime = max(0, entry.targetTime.timeIntervalSince(now))
        let elapsedTime = now.timeIntervalSince(entry.targetTime.addingTimeInterval(-entry.duration))
        
        return TimerInfo(
            id: timerId,
            duration: entry.duration,
            remainingTime: remainingTime,
            elapsedTime: max(0, elapsedTime),
            isActive: remainingTime > 0
        )
    }
    
    /// Get pool statistics
    public func getPoolStatistics() -> PoolStatistics {
        return PoolStatistics(
            activeTimers: timerEntries.count,
            totalTimersCreated: totalTimersCreated,
            totalTimersCompleted: totalTimersCompleted,
            masterTimerRunning: masterTimer != nil,
            isInBackground: isInBackground,
            currentTickInterval: isInBackground ? backgroundTickInterval : masterTickInterval
        )
    }
    
    // MARK: - Private Methods
    
    private func startMasterTimer() {
        stopMasterTimer()
        
        let interval = isInBackground ? backgroundTickInterval : masterTickInterval
        
        masterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processTick()
            }
        }
        
        // Optimize timer for better performance
        if let timer = masterTimer {
            timer.tolerance = interval * 0.1 // 10% tolerance for better coalescing
        }
        
        logger.info("🏊‍♂️ OptimizedTimerPool: Master timer started with \(String(format: "%.3f", interval))s interval")
    }
    
    private func stopMasterTimer() {
        masterTimer?.invalidate()
        masterTimer = nil
        logger.debug("🏊‍♂️ OptimizedTimerPool: Master timer stopped")
    }
    
    private func processTick() {
        let now = Date()
        var completedTimers: [UUID] = []
        var timersToRepeat: [TimerEntry] = []
        
        // Process all timer entries
        for (timerId, entry) in timerEntries {
            let timeUntilTarget = entry.targetTime.timeIntervalSince(now)
            
            // Check if timer should fire (within tolerance)
            if timeUntilTarget <= entry.tolerance {
                completedTimers.append(timerId)
                
                // Execute completion
                entry.completion()
                totalTimersCompleted += 1
                
                // Handle repeating timers
                if entry.repeats {
                    var newEntry = entry
                    newEntry.targetTime = now.addingTimeInterval(entry.duration)
                    timersToRepeat.append(newEntry)
                }
                
                logger.debug("🏊‍♂️ OptimizedTimerPool: Timer \(timerId.uuidString.prefix(8)) fired")
            }
        }
        
        // Remove completed timers
        for timerId in completedTimers {
            timerEntries.removeValue(forKey: timerId)
        }
        
        // Re-add repeating timers
        for entry in timersToRepeat {
            timerEntries[entry.id] = entry
        }
        
        // Perform periodic cleanup
        if now.timeIntervalSince(lastCleanupTime) > cleanupInterval {
            performCleanup(at: now)
        }
        
        // Stop master timer if no more entries
        if timerEntries.isEmpty {
            stopMasterTimer()
        }
    }
    
    private func performCleanup(at now: Date) {
        let initialCount = timerEntries.count
        
        // Remove any stale entries (shouldn't happen, but defensive programming)
        timerEntries = timerEntries.filter { _, entry in
            entry.targetTime.timeIntervalSince(now) > -60.0 // Remove entries older than 1 minute
        }
        
        let removedCount = initialCount - timerEntries.count
        if removedCount > 0 {
            logger.warning("🏊‍♂️ OptimizedTimerPool: Cleaned up \(removedCount) stale timer entries")
        }
        
        lastCleanupTime = now
        
        // Log performance statistics periodically
        let stats = getPoolStatistics()
        logger.info("🏊‍♂️ OptimizedTimerPool: Stats - Active: \(stats.activeTimers), Created: \(stats.totalTimersCreated), Completed: \(stats.totalTimersCompleted)")
    }
    
    private func setupBackgroundMonitoring() {
        // Monitor app state changes for background optimization
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBecameActive()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppResignedActive()
            }
        }
    }
    
    private func handleAppBecameActive() {
        guard isInBackground else { return }
        
        isInBackground = false
        logger.info("🏊‍♂️ OptimizedTimerPool: App became active - switching to foreground mode")
        
        // Restart master timer with higher frequency if needed
        if !timerEntries.isEmpty {
            startMasterTimer()
        }
    }
    
    private func handleAppResignedActive() {
        guard !isInBackground else { return }
        
        isInBackground = true
        logger.info("🏊‍♂️ OptimizedTimerPool: App resigned active - switching to background mode")
        
        // Restart master timer with lower frequency if needed
        if !timerEntries.isEmpty {
            startMasterTimer()
        }
    }
}

// MARK: - Supporting Types

/// Entry in the timer pool
private struct TimerEntry {
    let id: UUID
    var targetTime: Date
    var duration: TimeInterval
    let tolerance: TimeInterval
    let repeats: Bool
    let userInfo: [String: Any]?
    let completion: () -> Void
}

/// Information about a timer
public struct TimerInfo {
    public let id: UUID
    public let duration: TimeInterval
    public let remainingTime: TimeInterval
    public let elapsedTime: TimeInterval
    public let isActive: Bool
    
    /// Progress from 0.0 to 1.0
    public var progress: Double {
        guard duration > 0 else { return 1.0 }
        return min(1.0, max(0.0, elapsedTime / duration))
    }
}

/// Statistics about the timer pool
public struct PoolStatistics {
    public let activeTimers: Int
    public let totalTimersCreated: Int
    public let totalTimersCompleted: Int
    public let masterTimerRunning: Bool
    public let isInBackground: Bool
    public let currentTickInterval: TimeInterval
    
    /// Efficiency ratio (completed vs created)
    public var efficiency: Double {
        guard totalTimersCreated > 0 else { return 0.0 }
        return Double(totalTimersCompleted) / Double(totalTimersCreated)
    }
}

// MARK: - Convenience Extensions

extension OptimizedTimerPool {
    
    /// Schedule a one-shot timer with a simple closure
    @discardableResult
    public func after(_ delay: TimeInterval, execute: @escaping () -> Void) -> UUID {
        return scheduleTimer(duration: delay, completion: execute)
    }
    
    /// Schedule a repeating timer
    @discardableResult
    public func every(_ interval: TimeInterval, execute: @escaping () -> Void) -> UUID {
        return scheduleTimer(duration: interval, repeats: true, completion: execute)
    }
    
    /// Schedule a timer with high precision (lower tolerance)
    @discardableResult
    public func preciseTimer(duration: TimeInterval, execute: @escaping () -> Void) -> UUID {
        return scheduleTimer(duration: duration, tolerance: 0.01, completion: execute)
    }
    
    /// Schedule a timer with relaxed precision (higher tolerance for better performance)
    @discardableResult
    public func relaxedTimer(duration: TimeInterval, execute: @escaping () -> Void) -> UUID {
        return scheduleTimer(duration: duration, tolerance: duration * 0.2, completion: execute)
    }
}