import Foundation
import Combine
import os.log

/// Unified adaptive timer that provides timer functionality with configurable behavior
/// Consolidates features from previous AdaptiveTimer and LightweightAdaptiveTimer implementations
@MainActor
public final class UnifiedAdaptiveTimer: AdaptiveTimerProviding, ObservableObject {
    
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
                logger.info("🔄 UnifiedAdaptiveTimer: Adaptation \(self.adaptationEnabled ? "enabled" : "disabled")")
            }
        }
    }
    
    public private(set) var currentConfiguration: TimerConfiguration
    
    // MARK: - Implementation Selection
    
    public enum ImplementationMode {
        case automatic      // Automatically select best implementation features
        case adaptive      // Use full adaptive features
        case lightweight   // Use lightweight implementation
    }
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var startTime: Date?
    private var pauseTime: Date?
    private var cumulativeElapsedTime: TimeInterval = 0
    private var adaptationHistory: [TimingAdaptation] = []
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UnifiedAdaptiveTimer")
    private let mode: ImplementationMode
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    public init(configuration: TimerConfiguration? = nil, mode: ImplementationMode = .automatic) {
        self.currentConfiguration = configuration ?? TimerConfiguration(baseDuration: 5.0)
        self.mode = mode
        
        logger.info("🔄 UnifiedAdaptiveTimer: Initialized in \(self.implementationDescription) mode")
    }
    
    // MARK: - AdaptiveTimerProviding Implementation
    
    public func start(with configuration: TimerConfiguration) throws {
        guard !isRunning else {
            throw TimerError.timerAlreadyRunning
        }
        
        self.currentConfiguration = configuration
        self.totalDuration = configuration.baseDuration
        self.remainingTime = totalDuration
        self.elapsedTime = 0
        self.cumulativeElapsedTime = 0
        self.startTime = Date()
        self.pauseTime = nil
        self.isRunning = true
        self.isPaused = false
        
        // Start main timer
        startMainTimer()
        
        // Start update timer for UI updates (if not in lightweight mode)
        if mode != .lightweight {
            startUpdateTimer()
        }
        
        logger.info("🔄 UnifiedAdaptiveTimer: Started with duration \(configuration.baseDuration)s")
    }
    
    public func pause() {
        guard isRunning && !isPaused else { return }
        
        pauseTime = Date()
        isPaused = true
        timer?.invalidate()
        updateTimer?.invalidate()
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Paused")
        delegate?.timerWasPaused(self)
    }
    
    public func resume() {
        guard isRunning && isPaused else { return }
        
        // Add paused time to cumulative elapsed time
        if let pauseTime = pauseTime, let startTime = startTime {
            cumulativeElapsedTime = Date().timeIntervalSince(startTime)
        }
        
        // Restart timers with remaining time
        startMainTimer()
        if mode != .lightweight {
            startUpdateTimer()
        }
        
        pauseTime = nil
        isPaused = false
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Resumed")
        delegate?.timerWasResumed(self)
    }
    
    public func stop() {
        guard isRunning else { return }
        
        timer?.invalidate()
        updateTimer?.invalidate()
        timer = nil
        updateTimer = nil
        
        isRunning = false
        isPaused = false
        remainingTime = 0
        elapsedTime = totalDuration
        startTime = nil
        pauseTime = nil
        cumulativeElapsedTime = 0
        
        logger.info("🔄 UnifiedAdaptiveTimer: Stopped")
        delegate?.timerWasStopped(self)
    }
    
    public func extend(by duration: TimeInterval) {
        guard isRunning else { return }
        
        totalDuration += duration
        remainingTime += duration
        
        // Restart timer with new duration
        timer?.invalidate()
        startMainTimer()
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Extended by \(duration)s")
    }
    
    public func adaptTiming(based context: TimingContext) {
        guard adaptationEnabled && isRunning && mode != .lightweight else { return }
        
        let adaptationFactor = calculateAdaptationFactor(context: context)
        let newDuration = max(
            currentConfiguration.minimumDuration,
            min(currentConfiguration.maximumDuration, totalDuration * adaptationFactor)
        )
        
        if abs(newDuration - totalDuration) > 0.1 { // Only adapt if change is significant
            let oldDuration = totalDuration
            totalDuration = newDuration
            remainingTime = max(0, remainingTime * adaptationFactor)
            
            // Record adaptation
            let adaptation = TimingAdaptation(
                timestamp: Date().timeIntervalSince1970,
                previousDuration: oldDuration,
                newDuration: newDuration,
                reason: getAdaptationReason(context: context),
                context: context,
                confidence: 1.0
            )
            adaptationHistory.append(adaptation)
            
            // Keep history manageable
            if adaptationHistory.count > 100 {
                adaptationHistory.removeFirst(50)
            }
            
            // Restart timer with new duration
            timer?.invalidate()
            startMainTimer()
            
            delegate?.timerDidAdapt(self, newDuration: newDuration, reason: adaptation.reason)
        }
    }
    
    public func reset() {
        timer?.invalidate()
        updateTimer?.invalidate()
        timer = nil
        updateTimer = nil
        
        isRunning = false
        isPaused = false
        remainingTime = currentConfiguration.baseDuration
        elapsedTime = 0
        totalDuration = currentConfiguration.baseDuration
        startTime = nil
        pauseTime = nil
        cumulativeElapsedTime = 0
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Reset")
    }
    
    public func getAdaptationHistory(limit: Int = 50) -> [TimingAdaptation] {
        return Array(adaptationHistory.suffix(limit))
    }
    
    public func updateConfiguration(_ configuration: TimerConfiguration) throws {
        let wasRunning = isRunning
        let wasPaused = isPaused
        let savedRemainingTime = remainingTime
        
        if wasRunning {
            stop()
        }
        
        self.currentConfiguration = configuration
        
        if wasRunning {
            try start(with: configuration)
            
            // Adjust remaining time proportionally
            if savedRemainingTime > 0 {
                remainingTime = min(configuration.baseDuration, savedRemainingTime)
                totalDuration = configuration.baseDuration
            }
            
            if wasPaused {
                pause()
            }
        }
        
        logger.info("🔄 UnifiedAdaptiveTimer: Configuration updated")
    }
    
    // MARK: - Private Timer Implementation
    
    private func startMainTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerFired()
            }
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        
        // Update every 0.1 seconds for smooth UI updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }
    
    private func handleTimerFired() {
        guard isRunning && !isPaused else { return }
        
        timer?.invalidate()
        updateTimer?.invalidate()
        timer = nil
        updateTimer = nil
        
        isRunning = false
        isPaused = false
        remainingTime = 0
        elapsedTime = totalDuration
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Timer fired")
        delegate?.timerDidFire(self)
    }
    
    private func updateElapsedTime() {
        guard isRunning && !isPaused, let startTime = startTime else { return }
        
        let totalElapsed = Date().timeIntervalSince(startTime) + cumulativeElapsedTime
        elapsedTime = min(totalElapsed, totalDuration)
        remainingTime = max(0, totalDuration - elapsedTime)
    }
    
    // MARK: - Adaptation Logic
    
    private func calculateAdaptationFactor(context: TimingContext) -> Double {
        // Base adaptation on various context factors
        var factor = 1.0
        
        // User activity level adjustments
        switch context.userActivity {
        case .idle:
            factor *= 1.5 // Longer intervals when idle
        case .light:
            factor *= 1.2 // Slightly longer when light activity
        case .moderate:
            factor *= 1.0 // No change for moderate activity
        case .active:
            factor *= 0.9 // Slightly shorter when active
        case .intensive:
            factor *= 0.8 // Shorter intervals when highly intensive
        }
        
        // App state adjustments
        switch context.appState {
        case .foreground, .fullscreen, .slideshow:
            factor *= 1.0 // No change when foreground/fullscreen/slideshow
        case .background:
            factor *= 2.0 // Much longer in background
        case .minimized, .inactive:
            factor *= 1.5 // Longer when minimized or inactive
        }
        
        // System load adjustments
        switch context.systemLoad {
        case .low:
            factor *= 1.0 // No change for low load
        case .normal:
            factor *= 1.0 // No change for normal load
        case .high:
            factor *= 1.5 // Longer intervals under high load
        case .critical:
            factor *= 2.0 // Much longer under critical load
        }
        
        // Battery level adjustments
        if let batteryLevel = context.batteryLevel, batteryLevel < 0.2 {
            factor *= 2.0 // Much longer when battery is low
        }
        
        return max(0.5, min(3.0, factor)) // Clamp between 0.5x and 3.0x
    }
    
    private func getAdaptationReason(context: TimingContext) -> AdaptationReason {
        // Determine primary reason for adaptation
        if context.appState == .background {
            return .appState
        } else if context.systemLoad == .high || context.systemLoad == .critical {
            return .systemLoad
        } else if let batteryLevel = context.batteryLevel, batteryLevel < 0.2 {
            return .batteryOptimization
        } else if context.userActivity == .intensive || context.userActivity == .active {
            return .userBehavior
        } else {
            return .manual
        }
    }
    
    private var implementationDescription: String {
        switch mode {
        case .automatic:
            return "automatic"
        case .adaptive:
            return "adaptive"
        case .lightweight:
            return "lightweight"
        }
    }
    
    deinit {
        timer?.invalidate()
        updateTimer?.invalidate()
    }
}

// MARK: - Factory Methods

extension UnifiedAdaptiveTimer {
    
    /// Create a unified timer optimized for UI controls
    public static func forUIControls(baseDuration: TimeInterval) -> UnifiedAdaptiveTimer {
        let config = TimerConfiguration.autoHide(duration: baseDuration)
        let timer = UnifiedAdaptiveTimer(configuration: config, mode: .automatic)
        timer.adaptationEnabled = true
        return timer
    }
    
    /// Create a high-performance timer with minimal overhead
    public static func highPerformance(baseDuration: TimeInterval) -> UnifiedAdaptiveTimer {
        let config = TimerConfiguration.performance(duration: baseDuration)
        let timer = UnifiedAdaptiveTimer(configuration: config, mode: .lightweight)
        timer.adaptationEnabled = false
        return timer
    }
    
    /// Create a battery-optimized timer
    public static func batteryOptimized(baseDuration: TimeInterval) -> UnifiedAdaptiveTimer {
        let config = TimerConfiguration(
            baseDuration: baseDuration,
            minimumDuration: baseDuration * 0.5,
            maximumDuration: baseDuration * 3.0,
            adaptationSensitivity: 1.5,
            learningEnabled: false,
            coalescingEnabled: true,
            backgroundOptimization: true
        )
        let timer = UnifiedAdaptiveTimer(configuration: config, mode: .lightweight)
        timer.adaptationEnabled = true
        return timer
    }
    
    /// Create a full-featured adaptive timer with learning
    public static func fullAdaptive(baseDuration: TimeInterval) -> UnifiedAdaptiveTimer {
        let config = TimerConfiguration(
            baseDuration: baseDuration,
            adaptationSensitivity: 1.2,
            learningEnabled: true,
            coalescingEnabled: true,
            backgroundOptimization: true
        )
        let timer = UnifiedAdaptiveTimer(configuration: config, mode: .adaptive)
        timer.adaptationEnabled = true
        return timer
    }
}