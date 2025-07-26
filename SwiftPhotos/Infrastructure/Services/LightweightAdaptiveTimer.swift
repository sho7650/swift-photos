import Foundation
import Combine
import os.log

/// Lightweight adaptive timer that uses OptimizedTimerPool for better performance
/// Maintains full compatibility with the AdaptiveTimerProviding protocol while reducing overhead
@MainActor
public class LightweightAdaptiveTimer: AdaptiveTimerProviding, ObservableObject {
    
    // MARK: - Public Properties
    
    public weak var delegate: AdaptiveTimerDelegate?
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var remainingTime: TimeInterval = 0
    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public private(set) var totalDuration: TimeInterval = 0
    
    public var adaptationEnabled: Bool = true {
        didSet {
            if adaptationEnabled != oldValue {
                logger.info("⚡ LightweightAdaptiveTimer: Adaptation \(self.adaptationEnabled ? "enabled" : "disabled")")
            }
        }
    }
    
    public private(set) var currentConfiguration: TimerConfiguration
    
    // MARK: - Private Properties
    
    private var poolTimerId: UUID?
    private var updateTimerId: UUID?
    private var startTime: Date?
    private var pauseTime: Date?
    private var pausedDuration: TimeInterval = 0
    
    private let timerPool = OptimizedTimerPool.shared
    private let logger = Logger(subsystem: "SwiftPhotos", category: "LightweightAdaptiveTimer")
    
    // Simplified adaptation tracking (reduced memory usage)
    private var recentAdaptations: [SimplifiedAdaptation] = []
    private let maxAdaptationHistory = 20 // Reduced from 200
    
    // Context caching for performance
    private var cachedContext: TimingContext?
    private var contextCacheTime: Date?
    private let contextCacheInterval: TimeInterval = 1.0 // Cache context for 1 second
    
    // MARK: - Initialization
    
    public init(configuration: TimerConfiguration? = nil) {
        self.currentConfiguration = configuration ?? TimerConfiguration(baseDuration: 5.0)
        logger.debug("⚡ LightweightAdaptiveTimer: Initialized with base duration \(self.currentConfiguration.baseDuration)s")
    }
    
    deinit {
        // Cancel pool timers during cleanup (cannot call @MainActor method from deinit)
        if let poolTimerId = poolTimerId {
            Task { @MainActor in
                OptimizedTimerPool.shared.cancelTimer(poolTimerId)
            }
        }
        if let updateTimerId = updateTimerId {
            Task { @MainActor in
                OptimizedTimerPool.shared.cancelTimer(updateTimerId)
            }
        }
        logger.debug("⚡ LightweightAdaptiveTimer: Deinitialized")
    }
    
    // MARK: - AdaptiveTimerProviding Implementation
    
    public func start(with configuration: TimerConfiguration) throws {
        guard !isRunning else {
            throw TimerError.timerAlreadyRunning
        }
        
        self.currentConfiguration = configuration
        self.totalDuration = configuration.baseDuration
        self.remainingTime = configuration.baseDuration
        self.elapsedTime = 0
        self.isPaused = false
        self.pausedDuration = 0
        
        try startPoolTimer()
        
        logger.info("⚡ LightweightAdaptiveTimer: Started with duration \(configuration.baseDuration)s")
    }
    
    public func pause() {
        guard isRunning && !isPaused else { return }
        
        pauseTime = Date()
        isPaused = true
        stopAllPoolTimers()
        
        logger.debug("⚡ LightweightAdaptiveTimer: Paused at \(self.elapsedTime)s")
        delegate?.timerWasPaused(self)
    }
    
    public func resume() {
        guard isRunning && isPaused else { return }
        
        if let pauseTime = pauseTime {
            pausedDuration += Date().timeIntervalSince(pauseTime)
        }
        
        isPaused = false
        pauseTime = nil
        
        do {
            try startPoolTimer()
            logger.debug("⚡ LightweightAdaptiveTimer: Resumed at \(self.elapsedTime)s")
            delegate?.timerWasResumed(self)
        } catch {
            logger.error("⚡ LightweightAdaptiveTimer: Failed to resume - \(error.localizedDescription)")
            delegate?.timerDidEncounterError(self, error: error as? TimerError ?? .systemResourceUnavailable)
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        
        stopAllPoolTimers()
        isRunning = false
        isPaused = false
        startTime = nil
        pauseTime = nil
        pausedDuration = 0
        
        logger.info("⚡ LightweightAdaptiveTimer: Stopped")
        delegate?.timerWasStopped(self)
    }
    
    public func extend(by duration: TimeInterval) {
        guard isRunning else { return }
        
        let oldDuration = totalDuration
        totalDuration += duration
        remainingTime += duration
        
        // Extend the pool timer if it exists
        if let poolTimerId = poolTimerId {
            timerPool.extendTimer(poolTimerId, by: duration)
        }
        
        logger.debug("⚡ LightweightAdaptiveTimer: Extended by \(duration)s (total: \(self.totalDuration)s)")
        
        // Record simplified adaptation
        let adaptation = SimplifiedAdaptation(
            previousDuration: oldDuration,
            newDuration: totalDuration,
            reason: .manual,
            timestamp: Date().timeIntervalSince1970
        )
        recordSimplifiedAdaptation(adaptation)
    }
    
    public func adaptTiming(based context: TimingContext) {
        guard adaptationEnabled && isRunning else { return }
        
        let adaptationFactor = calculateLightweightAdaptationFactor(context: context)
        let newDuration = calculateAdaptedDuration(factor: adaptationFactor)
        
        guard abs(newDuration - totalDuration) > 0.1 else { return } // Minimum 100ms change
        
        let oldDuration = totalDuration
        totalDuration = newDuration
        
        // Adjust remaining time proportionally
        let progress = elapsedTime / oldDuration
        remainingTime = newDuration * (1.0 - progress)
        
        // Update pool timer
        if let poolTimerId = poolTimerId, let info = timerPool.getTimerInfo(poolTimerId) {
            let extensionNeeded = newDuration - info.elapsedTime
            timerPool.cancelTimer(poolTimerId)
            
            // Start new timer with adjusted duration
            self.poolTimerId = timerPool.relaxedTimer(duration: extensionNeeded) { [weak self] in
                Task { @MainActor in
                    self?.timerDidFire()
                }
            }
        }
        
        let reason = determineAdaptationReason(context: context, factor: adaptationFactor)
        
        // Record simplified adaptation
        let adaptation = SimplifiedAdaptation(
            previousDuration: oldDuration,
            newDuration: newDuration,
            reason: reason,
            timestamp: Date().timeIntervalSince1970
        )
        recordSimplifiedAdaptation(adaptation)
        
        logger.info("⚡ LightweightAdaptiveTimer: Adapted duration from \(String(format: "%.1f", oldDuration))s to \(String(format: "%.1f", newDuration))s (\(reason.rawValue))")
        delegate?.timerDidAdapt(self, newDuration: newDuration, reason: reason)
    }
    
    public func reset() {
        stop()
        totalDuration = currentConfiguration.baseDuration
        remainingTime = currentConfiguration.baseDuration
        elapsedTime = 0
        
        logger.debug("⚡ LightweightAdaptiveTimer: Reset to base duration \(self.currentConfiguration.baseDuration)s")
    }
    
    public func getAdaptationHistory(limit: Int = 50) -> [TimingAdaptation] {
        // Convert simplified adaptations to full format
        let requestedLimit = min(limit, recentAdaptations.count)
        return Array(recentAdaptations.suffix(requestedLimit)).map { adaptation in
            TimingAdaptation(
                timestamp: adaptation.timestamp,
                previousDuration: adaptation.previousDuration,
                newDuration: adaptation.newDuration,
                reason: adaptation.reason,
                context: getCachedContext(),
                confidence: 0.8 // Default confidence for lightweight version
            )
        }
    }
    
    public func updateConfiguration(_ configuration: TimerConfiguration) throws {
        let wasRunning = isRunning
        
        if wasRunning {
            stop()
        }
        
        self.currentConfiguration = configuration
        
        if wasRunning {
            try start(with: configuration)
        }
        
        logger.info("⚡ LightweightAdaptiveTimer: Configuration updated")
    }
    
    // MARK: - Private Methods
    
    private func startPoolTimer() throws {
        stopAllPoolTimers()
        
        startTime = Date()
        isRunning = true
        
        // Schedule main timer using appropriate method based on configuration
        let tolerance = currentConfiguration.coalescingEnabled ? totalDuration * 0.1 : 0.05
        
        poolTimerId = timerPool.scheduleTimer(
            duration: totalDuration,
            tolerance: tolerance,
            repeats: false
        ) { [weak self] in
            Task { @MainActor in
                self?.timerDidFire()
            }
        }
        
        // Schedule update timer for UI updates (less frequent than the master timer)
        let updateInterval: TimeInterval = currentConfiguration.backgroundOptimization ? 0.5 : 0.1
        updateTimerId = timerPool.every(updateInterval) { [weak self] in
            Task { @MainActor in
                self?.updateTimeValues()
            }
        }
        
        logger.debug("⚡ LightweightAdaptiveTimer: Pool timers started")
    }
    
    private func stopAllPoolTimers() {
        if let poolTimerId = poolTimerId {
            timerPool.cancelTimer(poolTimerId)
            self.poolTimerId = nil
        }
        
        if let updateTimerId = updateTimerId {
            timerPool.cancelTimer(updateTimerId)
            self.updateTimerId = nil
        }
    }
    
    private func updateTimeValues() {
        guard let startTime = startTime, isRunning && !isPaused else { return }
        
        let now = Date()
        elapsedTime = now.timeIntervalSince(startTime) - pausedDuration
        remainingTime = max(0, totalDuration - elapsedTime)
    }
    
    private func timerDidFire() {
        logger.info("⚡ LightweightAdaptiveTimer: Timer fired after \(String(format: "%.1f", self.elapsedTime))s")
        
        // Final time update
        updateTimeValues()
        
        stop()
        delegate?.timerDidFire(self)
    }
    
    // MARK: - Lightweight Adaptation Algorithm
    
    private func calculateLightweightAdaptationFactor(context: TimingContext) -> Double {
        var factor = 1.0
        
        // Apply core adaptations with optimized calculations
        factor *= context.userActivity.adaptationFactor
        factor *= context.appState.adaptationFactor
        factor *= context.systemLoad.adaptationFactor
        
        // Simple interaction-based adjustment
        factor *= calculateInteractionFactor(interactionCount: context.interactionCount)
        
        // Apply custom factors efficiently
        for (_, customFactor) in context.customFactors {
            factor *= customFactor
        }
        
        // Apply sensitivity with reduced computation
        let sensitivityAdjustedFactor = 1.0 + (factor - 1.0) * currentConfiguration.adaptationSensitivity
        
        return max(0.2, min(5.0, sensitivityAdjustedFactor)) // Reduced range for stability
    }
    
    private func calculateAdaptedDuration(factor: Double) -> TimeInterval {
        let baseDuration = currentConfiguration.baseDuration
        let adaptedDuration = baseDuration * factor
        
        return max(
            currentConfiguration.minimumDuration,
            min(currentConfiguration.maximumDuration, adaptedDuration)
        )
    }
    
    private func calculateInteractionFactor(interactionCount: Int) -> Double {
        // Simplified interaction calculation
        switch interactionCount {
        case 0: return 1.2
        case 1...2: return 1.0
        case 3...5: return 0.8
        default: return 0.7
        }
    }
    
    private func determineAdaptationReason(context: TimingContext, factor: Double) -> AdaptationReason {
        if context.appState != .foreground {
            return .appState
        }
        
        if context.systemLoad != .normal {
            return .systemLoad
        }
        
        if let batteryLevel = context.batteryLevel, batteryLevel < 0.2 {
            return .batteryOptimization
        }
        
        return .userBehavior
    }
    
    // MARK: - Simplified History Management
    
    private func recordSimplifiedAdaptation(_ adaptation: SimplifiedAdaptation) {
        recentAdaptations.append(adaptation)
        
        // Maintain size limit efficiently
        if recentAdaptations.count > maxAdaptationHistory {
            recentAdaptations.removeFirst(recentAdaptations.count - maxAdaptationHistory)
        }
    }
    
    // MARK: - Context Caching
    
    private func getCachedContext() -> TimingContext {
        let now = Date()
        
        // Return cached context if still valid
        if let cachedContext = cachedContext,
           let cacheTime = contextCacheTime,
           now.timeIntervalSince(cacheTime) < contextCacheInterval {
            return cachedContext
        }
        
        // Create new context
        let context = TimingContext(
            userActivity: .moderate,
            appState: .foreground,
            systemLoad: .normal,
            batteryLevel: nil,
            customFactors: [:]
        )
        
        self.cachedContext = context
        self.contextCacheTime = now
        
        return context
    }
}

// MARK: - Supporting Types

/// Simplified adaptation record for reduced memory usage
private struct SimplifiedAdaptation {
    let previousDuration: TimeInterval
    let newDuration: TimeInterval
    let reason: AdaptationReason
    let timestamp: TimeInterval
}

// MARK: - Factory Methods

extension LightweightAdaptiveTimer {
    
    /// Create a lightweight timer optimized for UI controls
    public static func forUIControls(baseDuration: TimeInterval) -> LightweightAdaptiveTimer {
        let config = TimerConfiguration(
            baseDuration: baseDuration,
            minimumDuration: baseDuration * 0.3,
            maximumDuration: baseDuration * 2.0,
            adaptationSensitivity: 1.0,
            learningEnabled: false, // Disabled for better performance
            coalescingEnabled: true,
            backgroundOptimization: true
        )
        
        let timer = LightweightAdaptiveTimer(configuration: config)
        timer.adaptationEnabled = true
        return timer
    }
    
    /// Create a high-performance timer with minimal adaptation
    public static func highPerformance(baseDuration: TimeInterval) -> LightweightAdaptiveTimer {
        let config = TimerConfiguration(
            baseDuration: baseDuration,
            minimumDuration: baseDuration * 0.8,
            maximumDuration: baseDuration * 1.2,
            adaptationSensitivity: 0.3,
            learningEnabled: false,
            coalescingEnabled: true,
            backgroundOptimization: true
        )
        
        let timer = LightweightAdaptiveTimer(configuration: config)
        timer.adaptationEnabled = false // Disable adaptation for maximum performance
        return timer
    }
    
    /// Create a battery-optimized timer
    public static func batteryOptimized(baseDuration: TimeInterval) -> LightweightAdaptiveTimer {
        let config = TimerConfiguration(
            baseDuration: baseDuration,
            minimumDuration: baseDuration * 0.5,
            maximumDuration: baseDuration * 3.0,
            adaptationSensitivity: 1.5,
            learningEnabled: false,
            coalescingEnabled: true,
            backgroundOptimization: true
        )
        
        let timer = LightweightAdaptiveTimer(configuration: config)
        timer.adaptationEnabled = true
        return timer
    }
}