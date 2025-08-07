//
//  TimerManagementProtocol.swift
//  Swift Photos
//
//  Clean Architecture Interface for Timer Management
//  Application layer defines the contract, Infrastructure implements it
//

import Foundation

// MARK: - Timer Management Protocol

/// Protocol for unified timer management services
/// Defines the contract that Infrastructure implementations must fulfill
/// Consolidates scattered Timer usage into a clean interface
public protocol TimerManagementProtocol: AnyObject, Sendable {
    
    // MARK: - Timer Scheduling
    
    /// Schedule a one-shot timer
    /// - Parameters:
    ///   - duration: Timer duration in seconds
    ///   - tolerance: Acceptable timing tolerance for optimization
    ///   - userInfo: Optional user information
    ///   - completion: Closure to execute when timer fires
    /// - Returns: Timer identifier for cancellation
    func scheduleTimer(
        duration: TimeInterval,
        tolerance: TimeInterval,
        userInfo: [String: String]?,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID
    
    /// Schedule a repeating timer
    /// - Parameters:
    ///   - interval: Repeat interval in seconds
    ///   - tolerance: Acceptable timing tolerance for optimization
    ///   - userInfo: Optional user information
    ///   - completion: Closure to execute on each timer fire
    /// - Returns: Timer identifier for cancellation
    func scheduleRepeatingTimer(
        interval: TimeInterval,
        tolerance: TimeInterval,
        userInfo: [String: String]?,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID
    
    // MARK: - Timer Control
    
    /// Cancel a scheduled timer
    /// - Parameter timerId: Timer identifier to cancel
    func cancelTimer(_ timerId: UUID) async
    
    /// Extend a timer's duration
    /// - Parameters:
    ///   - timerId: Timer identifier to extend
    ///   - additionalDuration: Additional time to add
    func extendTimer(_ timerId: UUID, by additionalDuration: TimeInterval) async
    
    /// Get information about a timer
    /// - Parameter timerId: Timer identifier
    /// - Returns: Timer information or nil if not found
    func getTimerInfo(_ timerId: UUID) async -> UnifiedTimerInfo?
    
    // MARK: - Pool Management
    
    /// Get timer pool statistics
    /// - Returns: Current statistics about the timer pool
    func getPoolStatistics() async -> TimerPoolStatistics
    
    /// Cancel all active timers
    func cancelAllTimers() async
}

// MARK: - Supporting Types

/// Information about a timer
public struct UnifiedTimerInfo: Sendable {
    public let id: UUID
    public let duration: TimeInterval
    public let remainingTime: TimeInterval
    public let elapsedTime: TimeInterval
    public let isActive: Bool
    public let isRepeating: Bool
    public let userInfo: [String: String]? // Simplified to be Sendable-compliant
    
    /// Progress from 0.0 to 1.0
    public var progress: Double {
        guard duration > 0 else { return 1.0 }
        return min(1.0, max(0.0, elapsedTime / duration))
    }
    
    public init(
        id: UUID,
        duration: TimeInterval,
        remainingTime: TimeInterval,
        elapsedTime: TimeInterval,
        isActive: Bool,
        isRepeating: Bool = false,
        userInfo: [String: String]? = nil
    ) {
        self.id = id
        self.duration = duration
        self.remainingTime = remainingTime
        self.elapsedTime = elapsedTime
        self.isActive = isActive
        self.isRepeating = isRepeating
        self.userInfo = userInfo
    }
}

/// Statistics about the timer pool
public struct TimerPoolStatistics: Sendable {
    public let activeTimers: Int
    public let totalTimersCreated: Int
    public let totalTimersCompleted: Int
    public let isRunning: Bool
    public let currentTickInterval: TimeInterval
    public let isInBackground: Bool
    
    /// Efficiency ratio (completed vs created)
    public var efficiency: Double {
        guard totalTimersCreated > 0 else { return 0.0 }
        return Double(totalTimersCompleted) / Double(totalTimersCreated)
    }
    
    public init(
        activeTimers: Int,
        totalTimersCreated: Int,
        totalTimersCompleted: Int,
        isRunning: Bool,
        currentTickInterval: TimeInterval,
        isInBackground: Bool = false
    ) {
        self.activeTimers = activeTimers
        self.totalTimersCreated = totalTimersCreated
        self.totalTimersCompleted = totalTimersCompleted
        self.isRunning = isRunning
        self.currentTickInterval = currentTickInterval
        self.isInBackground = isInBackground
    }
}

// MARK: - Timer Factory Protocol

/// Factory for creating timer management instances
/// Allows Application layer to create Infrastructure services without direct dependencies
public protocol TimerManagementFactory: Sendable {
    
    /// Create a timer management instance
    @MainActor func createTimerManager() -> TimerManagementProtocol
}

// MARK: - Convenience Extensions

extension TimerManagementProtocol {
    
    /// Schedule a simple timer with default tolerance
    public func scheduleTimer(
        duration: TimeInterval,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID {
        return await scheduleTimer(
            duration: duration,
            tolerance: duration * 0.1, // 10% tolerance
            userInfo: nil,
            completion: completion
        )
    }
    
    /// Schedule a simple repeating timer with default tolerance
    public func scheduleRepeatingTimer(
        interval: TimeInterval,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID {
        return await scheduleRepeatingTimer(
            interval: interval,
            tolerance: interval * 0.1, // 10% tolerance
            userInfo: nil,
            completion: completion
        )
    }
    
    /// Schedule a high-precision timer with low tolerance
    public func schedulePreciseTimer(
        duration: TimeInterval,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID {
        return await scheduleTimer(
            duration: duration,
            tolerance: 0.01, // Very low tolerance
            userInfo: nil,
            completion: completion
        )
    }
    
    /// Schedule a relaxed timer with high tolerance for better performance
    public func scheduleRelaxedTimer(
        duration: TimeInterval,
        completion: @escaping @Sendable () -> Void
    ) async -> UUID {
        return await scheduleTimer(
            duration: duration,
            tolerance: duration * 0.2, // 20% tolerance
            userInfo: nil,
            completion: completion
        )
    }
}