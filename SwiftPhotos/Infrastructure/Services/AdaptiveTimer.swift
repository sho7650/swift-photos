import Foundation
import Combine
import os.log

/// Smart timer implementation with context-aware adaptation capabilities
/// Replaces basic Timer usage with intelligent timing that adapts to user behavior and system state
@MainActor
public class AdaptiveTimer: AdaptiveTimerProviding, ObservableObject {
    
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
                logger.info("🕒 AdaptiveTimer: Adaptation \(self.adaptationEnabled ? "enabled" : "disabled")")
            }
        }
    }
    
    public private(set) var currentConfiguration: TimerConfiguration
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var startTime: Date?
    private var pauseTime: Date?
    private var adaptationHistory: [TimingAdaptation] = []
    private var tickInterval: TimeInterval = 0.1 // 100ms precision
    private let logger = Logger(subsystem: "SwiftPhotos", category: "AdaptiveTimer")
    
    // Learning algorithm properties
    private var userBehaviorPatterns: [UserBehaviorPattern] = []
    private var adaptationLearningRate: Double = 0.1
    private var confidenceThreshold: Double = 0.7
    
    // Performance optimization
    private var coalescingBuffer: [CoalescedTimerEvent] = []
    private var backgroundOptimizationActive: Bool = false
    
    // MARK: - Initialization
    
    public init(configuration: TimerConfiguration? = nil) {
        self.currentConfiguration = configuration ?? TimerConfiguration(baseDuration: 5.0)
        logger.debug("🕒 AdaptiveTimer: Initialized with base duration \(self.currentConfiguration.baseDuration)s")
    }
    
    deinit {
        // Note: Manual cleanup may cause concurrency issues
        // Timer is cleaned up automatically
        logger.debug("🕒 AdaptiveTimer: Deinitialized")
    }
    
    // MARK: - Public Methods
    
    public func start(with configuration: TimerConfiguration) throws {
        guard !isRunning else {
            throw TimerError.timerAlreadyRunning
        }
        
        self.currentConfiguration = configuration
        self.totalDuration = configuration.baseDuration
        self.remainingTime = configuration.baseDuration
        self.elapsedTime = 0
        self.isPaused = false
        
        try startInternalTimer()
        
        logger.info("🕒 AdaptiveTimer: Started with duration \(configuration.baseDuration)s")
        // Note: timerDidStartDetection is intended for InteractionDetecting compatibility
    }
    
    public func pause() {
        guard isRunning && !isPaused else { return }
        
        pauseTime = Date()
        isPaused = true
        stopInternalTimer()
        
        logger.debug("🕒 AdaptiveTimer: Paused at \(self.elapsedTime)s")
        delegate?.timerWasPaused(self)
    }
    
    public func resume() {
        guard isRunning && isPaused else { return }
        
        if let pauseTime = pauseTime {
            // Adjust start time to account for pause duration
            let pauseDuration = Date().timeIntervalSince(pauseTime)
            startTime = startTime?.addingTimeInterval(pauseDuration)
        }
        
        isPaused = false
        pauseTime = nil
        
        do {
            try startInternalTimer()
            logger.debug("🕒 AdaptiveTimer: Resumed at \(self.elapsedTime)s")
            delegate?.timerWasResumed(self)
        } catch {
            logger.error("🕒 AdaptiveTimer: Failed to resume - \(error.localizedDescription)")
            delegate?.timerDidEncounterError(self, error: error as? TimerError ?? .systemResourceUnavailable)
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        
        stopInternalTimer()
        isRunning = false
        isPaused = false
        startTime = nil
        pauseTime = nil
        
        logger.info("🕒 AdaptiveTimer: Stopped")
        delegate?.timerWasStopped(self)
    }
    
    public func extend(by duration: TimeInterval) {
        guard isRunning else { return }
        
        let oldDuration = totalDuration
        totalDuration += duration
        remainingTime += duration
        
        logger.debug("🕒 AdaptiveTimer: Extended by \(duration)s (total: \(self.totalDuration)s)")
        
        // Record adaptation
        let adaptation = TimingAdaptation(
            previousDuration: oldDuration,
            newDuration: totalDuration,
            reason: .manual,
            context: getCurrentContext(),
            confidence: 1.0
        )
        recordAdaptation(adaptation)
    }
    
    public func adaptTiming(based context: TimingContext) {
        guard adaptationEnabled && isRunning else { return }
        
        let adaptationFactor = calculateAdaptationFactor(context: context)
        let newDuration = calculateAdaptedDuration(factor: adaptationFactor, context: context)
        
        guard abs(newDuration - totalDuration) > 0.1 else { return } // Minimum 100ms change
        
        let oldDuration = totalDuration
        totalDuration = newDuration
        
        // Adjust remaining time proportionally
        let progress = elapsedTime / oldDuration
        remainingTime = newDuration * (1.0 - progress)
        
        // Determine adaptation reason
        let reason = determineAdaptationReason(context: context, factor: adaptationFactor)
        
        // Record adaptation
        let adaptation = TimingAdaptation(
            previousDuration: oldDuration,
            newDuration: newDuration,
            reason: reason,
            context: context,
            confidence: calculateAdaptationConfidence(context: context)
        )
        recordAdaptation(adaptation)
        
        logger.info("🕒 AdaptiveTimer: Adapted duration from \(String(format: "%.1f", oldDuration))s to \(String(format: "%.1f", newDuration))s (\(reason.rawValue))")
        delegate?.timerDidAdapt(self, newDuration: newDuration, reason: reason)
        
        // Learn from this adaptation if enabled
        if currentConfiguration.learningEnabled {
            learnFromAdaptation(adaptation)
        }
    }
    
    public func reset() {
        stop()
        totalDuration = currentConfiguration.baseDuration
        remainingTime = currentConfiguration.baseDuration
        elapsedTime = 0
        
        logger.debug("🕒 AdaptiveTimer: Reset to base duration \(self.currentConfiguration.baseDuration)s")
    }
    
    public func getAdaptationHistory(limit: Int = 50) -> [TimingAdaptation] {
        return Array(adaptationHistory.suffix(limit))
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
        
        logger.info("🕒 AdaptiveTimer: Configuration updated")
    }
    
    // MARK: - Private Methods
    
    private func startInternalTimer() throws {
        stopInternalTimer()
        
        startTime = Date()
        isRunning = true
        
        // Use CADisplayLink for better precision if available, fallback to Timer
        if currentConfiguration.coalescingEnabled {
            timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.timerTick()
                }
            }
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.timerTick()
                }
            }
        }
        
        // Optimize for background performance if enabled
        if currentConfiguration.backgroundOptimization {
            optimizeForBackground()
        }
    }
    
    private func stopInternalTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerTick() {
        guard let startTime = startTime else { return }
        
        let now = Date()
        elapsedTime = now.timeIntervalSince(startTime)
        remainingTime = max(0, totalDuration - elapsedTime)
        
        // Check if timer should fire
        if remainingTime <= 0 {
            timerDidFire()
        }
        
        // Handle coalescing if enabled
        if currentConfiguration.coalescingEnabled {
            handleCoalescing()
        }
    }
    
    private func timerDidFire() {
        logger.info("🕒 AdaptiveTimer: Timer fired after \(String(format: "%.1f", self.elapsedTime))s")
        
        stop()
        delegate?.timerDidFire(self)
        
        // Learn from this firing if patterns are enabled
        if currentConfiguration.learningEnabled {
            recordUserBehaviorPattern()
        }
    }
    
    // MARK: - Adaptation Algorithm
    
    private func calculateAdaptationFactor(context: TimingContext) -> Double {
        var factor = 1.0
        
        // Apply user activity adaptation
        factor *= context.userActivity.adaptationFactor
        
        // Apply app state adaptation
        factor *= context.appState.adaptationFactor
        
        // Apply system load adaptation
        factor *= context.systemLoad.adaptationFactor
        
        // Apply battery optimization if available
        if let batteryLevel = context.batteryLevel, batteryLevel < 0.2 {
            factor *= 1.3 // Longer delays when battery is low
        }
        
        // Apply recent interaction patterns
        factor *= calculateInteractionBasedFactor(interactionCount: context.interactionCount)
        
        // Apply custom factors
        for (_, customFactor) in context.customFactors {
            factor *= customFactor
        }
        
        // Apply learning if enabled
        if currentConfiguration.learningEnabled {
            factor *= calculateLearnedFactor(context: context)
        }
        
        // Apply sensitivity
        let sensitivityAdjustedFactor = 1.0 + (factor - 1.0) * currentConfiguration.adaptationSensitivity
        
        return max(0.1, min(10.0, sensitivityAdjustedFactor))
    }
    
    private func calculateAdaptedDuration(factor: Double, context: TimingContext) -> TimeInterval {
        let baseDuration = currentConfiguration.baseDuration
        let adaptedDuration = baseDuration * factor
        
        // Constrain to configuration limits
        return max(
            currentConfiguration.minimumDuration,
            min(currentConfiguration.maximumDuration, adaptedDuration)
        )
    }
    
    private func calculateInteractionBasedFactor(interactionCount: Int) -> Double {
        switch interactionCount {
        case 0: return 1.2      // No recent interactions - longer delay
        case 1...3: return 1.0  // Normal interaction level
        case 4...10: return 0.8 // High interaction - shorter delay
        default: return 0.6     // Very high interaction - much shorter delay
        }
    }
    
    private func calculateLearnedFactor(context: TimingContext) -> Double {
        // Simple pattern matching against historical adaptations
        let similarAdaptations = adaptationHistory.filter { adaptation in
            isSimilarContext(adaptation.context, context)
        }
        
        guard !similarAdaptations.isEmpty else { return 1.0 }
        
        // Calculate weighted average of previous adaptations
        let weightedSum = similarAdaptations.reduce(0.0) { sum, adaptation in
            let weight = adaptation.confidence * calculateContextSimilarity(adaptation.context, context)
            return sum + (adaptation.newDuration / adaptation.previousDuration) * weight
        }
        
        let totalWeight = similarAdaptations.reduce(0.0) { sum, adaptation in
            sum + adaptation.confidence * calculateContextSimilarity(adaptation.context, context)
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 1.0
    }
    
    private func determineAdaptationReason(context: TimingContext, factor: Double) -> AdaptationReason {
        if currentConfiguration.learningEnabled && abs(factor - 1.0) > 0.3 {
            return .learningAlgorithm
        }
        
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
    
    private func calculateAdaptationConfidence(context: TimingContext) -> Double {
        var confidence = 0.8 // Base confidence
        
        // Increase confidence based on number of recent interactions
        confidence += min(0.2, Double(context.interactionCount) * 0.02)
        
        // Adjust based on system state reliability
        switch context.systemLoad {
        case .low, .normal: confidence += 0.1
        case .high: confidence -= 0.1
        case .critical: confidence -= 0.2
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    // MARK: - Learning Algorithm
    
    private func learnFromAdaptation(_ adaptation: TimingAdaptation) {
        guard adaptation.confidence > confidenceThreshold else { return }
        
        // Simple reinforcement learning approach
        let pattern = UserBehaviorPattern(
            contextSignature: createContextSignature(adaptation.context),
            adaptationFactor: adaptation.newDuration / adaptation.previousDuration,
            confidence: adaptation.confidence,
            timestamp: adaptation.timestamp
        )
        
        // Update existing pattern or add new one
        if let existingIndex = userBehaviorPatterns.firstIndex(where: { $0.contextSignature == pattern.contextSignature }) {
            let existing = userBehaviorPatterns[existingIndex]
            let newConfidence = existing.confidence + (pattern.confidence - existing.confidence) * adaptationLearningRate
            let newFactor = existing.adaptationFactor + (pattern.adaptationFactor - existing.adaptationFactor) * adaptationLearningRate
            
            userBehaviorPatterns[existingIndex] = UserBehaviorPattern(
                contextSignature: pattern.contextSignature,
                adaptationFactor: newFactor,
                confidence: newConfidence,
                timestamp: pattern.timestamp
            )
        } else {
            userBehaviorPatterns.append(pattern)
        }
        
        // Limit history size
        if userBehaviorPatterns.count > 100 {
            userBehaviorPatterns = userBehaviorPatterns.sorted { $0.confidence > $1.confidence }.prefix(100).map { $0 }
        }
        
        logger.debug("🕒 AdaptiveTimer: Learned from adaptation (patterns: \(self.userBehaviorPatterns.count))")
    }
    
    private func recordUserBehaviorPattern() {
        let context = getCurrentContext()
        _ = UserBehaviorPattern(
            contextSignature: createContextSignature(context),
            adaptationFactor: 1.0, // No adaptation, just recording the base behavior
            confidence: 0.5,
            timestamp: Date().timeIntervalSince1970
        )
        
        // This would be used to establish baseline patterns
        // Implementation could be expanded based on specific needs
    }
    
    // MARK: - Performance Optimization
    
    private func optimizeForBackground() {
        guard !backgroundOptimizationActive else { return }
        
        // Reduce timer precision when in background
        tickInterval = 0.5 // 500ms for background
        backgroundOptimizationActive = true
        
        logger.debug("🕒 AdaptiveTimer: Background optimization activated")
    }
    
    private func handleCoalescing() {
        // Simple coalescing implementation
        // Could be enhanced with more sophisticated algorithms
        
        let now = Date().timeIntervalSince1970
        coalescingBuffer.removeAll { now - $0.timestamp > 1.0 }
        
        let event = CoalescedTimerEvent(timestamp: now, remainingTime: remainingTime)
        coalescingBuffer.append(event)
        
        // Coalesce if we have multiple rapid events
        if coalescingBuffer.count > 5 {
            coalescingBuffer = Array(coalescingBuffer.suffix(1))
        }
    }
    
    // MARK: - Helper Methods
    
    private func recordAdaptation(_ adaptation: TimingAdaptation) {
        adaptationHistory.append(adaptation)
        
        // Limit history size
        if adaptationHistory.count > 200 {
            adaptationHistory = Array(adaptationHistory.suffix(200))
        }
    }
    
    private func getCurrentContext() -> TimingContext {
        // This would be populated with real context information
        // For now, return a basic context
        return TimingContext(
            userActivity: .moderate,
            appState: .foreground,
            systemLoad: .normal,
            batteryLevel: nil,
            customFactors: [:]
        )
    }
    
    private func isSimilarContext(_ context1: TimingContext, _ context2: TimingContext) -> Bool {
        return context1.userActivity == context2.userActivity &&
               context1.appState == context2.appState &&
               context1.systemLoad == context2.systemLoad
    }
    
    private func calculateContextSimilarity(_ context1: TimingContext, _ context2: TimingContext) -> Double {
        var similarity = 0.0
        
        if context1.userActivity == context2.userActivity { similarity += 0.3 }
        if context1.appState == context2.appState { similarity += 0.3 }
        if context1.systemLoad == context2.systemLoad { similarity += 0.2 }
        
        // Battery level similarity
        if let battery1 = context1.batteryLevel, let battery2 = context2.batteryLevel {
            let batteryDiff = abs(battery1 - battery2)
            similarity += 0.2 * (1.0 - batteryDiff)
        }
        
        return min(1.0, similarity)
    }
    
    private func createContextSignature(_ context: TimingContext) -> String {
        return "\(context.userActivity.rawValue):\(context.appState.rawValue):\(context.systemLoad.rawValue)"
    }
}

// MARK: - Supporting Types

private struct UserBehaviorPattern {
    let contextSignature: String
    let adaptationFactor: Double
    let confidence: Double
    let timestamp: TimeInterval
}

private struct CoalescedTimerEvent {
    let timestamp: TimeInterval
    let remainingTime: TimeInterval
}

// MARK: - Extensions

extension AdaptiveTimerDelegate {
    /// Default implementations for optional methods
    func timerDidAdapt(_ timer: AdaptiveTimerProviding, newDuration: TimeInterval, reason: AdaptationReason) {}
    func timerWasPaused(_ timer: AdaptiveTimerProviding) {}
    func timerWasResumed(_ timer: AdaptiveTimerProviding) {}
    func timerWasStopped(_ timer: AdaptiveTimerProviding) {}
    func timerDidEncounterError(_ timer: AdaptiveTimerProviding, error: TimerError) {}
}