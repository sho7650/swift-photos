import Foundation
import Combine
import os.log

/// Unified adaptive timer that selects between AdaptiveTimer and LightweightAdaptiveTimer
/// based on configuration requirements for optimal performance
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
                updateFromActiveTimer()
            }
        }
    }
    
    public private(set) var currentConfiguration: TimerConfiguration
    
    // MARK: - Implementation Selection
    
    public enum ImplementationMode {
        case automatic      // Automatically select best implementation
        case adaptive      // Force use of full adaptive implementation
        case lightweight   // Force use of lightweight implementation
    }
    
    // MARK: - Private Properties
    
    private var activeTimer: AdaptiveTimerProviding
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UnifiedAdaptiveTimer")
    private var isUsingAdaptive: Bool
    
    // MARK: - Initialization
    
    public init(configuration: TimerConfiguration? = nil, mode: ImplementationMode = .automatic) {
        self.currentConfiguration = configuration ?? TimerConfiguration(baseDuration: 5.0)
        
        // Select and create optimal implementation
        let useAdaptive = Self.shouldUseAdaptive(for: self.currentConfiguration, mode: mode)
        self.isUsingAdaptive = useAdaptive
        
        if useAdaptive {
            self.activeTimer = AdaptiveTimer(configuration: self.currentConfiguration)
        } else {
            self.activeTimer = LightweightAdaptiveTimer(configuration: self.currentConfiguration)
        }
        
        // Setup delegation
        self.activeTimer.delegate = TimerDelegateForwarder(parent: self)
        
        logger.info("🔄 UnifiedAdaptiveTimer: Initialized with \(self.implementationName)")
    }
    
    // MARK: - AdaptiveTimerProviding Implementation
    
    public func start(with configuration: TimerConfiguration) throws {
        guard !isRunning else {
            throw TimerError.timerAlreadyRunning
        }
        
        self.currentConfiguration = configuration
        
        // Check if we need to switch implementation
        let shouldUseAdaptive = Self.shouldUseAdaptive(for: configuration, mode: .automatic)
        if shouldUseAdaptive != isUsingAdaptive {
            try switchImplementation(useAdaptive: shouldUseAdaptive)
        }
        
        try activeTimer.start(with: configuration)
        updateFromActiveTimer()
        
        logger.info("🔄 UnifiedAdaptiveTimer: Started with \(self.implementationName)")
    }
    
    public func pause() {
        guard isRunning && !isPaused else { return }
        
        activeTimer.pause()
        updateFromActiveTimer()
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Paused")
        delegate?.timerWasPaused(self)
    }
    
    public func resume() {
        guard isRunning && isPaused else { return }
        
        activeTimer.resume()
        updateFromActiveTimer()
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Resumed")
        delegate?.timerWasResumed(self)
    }
    
    public func stop() {
        guard isRunning else { return }
        
        activeTimer.stop()
        updateFromActiveTimer()
        
        logger.info("🔄 UnifiedAdaptiveTimer: Stopped")
        delegate?.timerWasStopped(self)
    }
    
    public func extend(by duration: TimeInterval) {
        guard isRunning else { return }
        
        activeTimer.extend(by: duration)
        updateFromActiveTimer()
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Extended by \(duration)s")
    }
    
    public func adaptTiming(based context: TimingContext) {
        guard adaptationEnabled && isRunning else { return }
        
        activeTimer.adaptTiming(based: context)
        updateFromActiveTimer()
    }
    
    public func reset() {
        activeTimer.reset()
        updateFromActiveTimer()
        
        logger.debug("🔄 UnifiedAdaptiveTimer: Reset")
    }
    
    public func getAdaptationHistory(limit: Int = 50) -> [TimingAdaptation] {
        return activeTimer.getAdaptationHistory(limit: limit)
    }
    
    public func updateConfiguration(_ configuration: TimerConfiguration) throws {
        self.currentConfiguration = configuration
        
        // Check if we need to switch implementation
        let shouldUseAdaptive = Self.shouldUseAdaptive(for: configuration, mode: .automatic)
        if shouldUseAdaptive != isUsingAdaptive {
            let wasRunning = isRunning
            let wasPaused = isPaused
            
            if wasRunning {
                stop()
            }
            
            try switchImplementation(useAdaptive: shouldUseAdaptive)
            
            if wasRunning {
                try start(with: configuration)
                if wasPaused {
                    pause()
                }
            }
        }
        
        logger.info("🔄 UnifiedAdaptiveTimer: Configuration updated")
    }
    
    // MARK: - Implementation Management
    
    private static func shouldUseAdaptive(
        for configuration: TimerConfiguration,
        mode: ImplementationMode
    ) -> Bool {
        switch mode {
        case .adaptive:
            return true
        case .lightweight:
            return false
        case .automatic:
            // Use adaptive for complex features, lightweight for performance
            let hasComplexFeatures = configuration.learningEnabled
            let needsHighPerformance = configuration.coalescingEnabled || configuration.backgroundOptimization
            let isShortDuration = configuration.baseDuration < 1.0
            
            if hasComplexFeatures {
                return true
            } else if needsHighPerformance || isShortDuration {
                return false
            } else {
                return true
            }
        }
    }
    
    private func switchImplementation(useAdaptive: Bool) throws {
        // Create new implementation
        let newTimer: AdaptiveTimerProviding
        if useAdaptive {
            newTimer = AdaptiveTimer(configuration: currentConfiguration)
        } else {
            newTimer = LightweightAdaptiveTimer(configuration: currentConfiguration)
        }
        
        // Setup delegation
        newTimer.delegate = TimerDelegateForwarder(parent: self)
        
        // Switch
        self.activeTimer = newTimer
        self.isUsingAdaptive = useAdaptive
        
        updateFromActiveTimer()
        logger.info("🔄 UnifiedAdaptiveTimer: Switched to \(self.implementationName)")
    }
    
    fileprivate func updateFromActiveTimer() {
        isRunning = activeTimer.isRunning
        isPaused = activeTimer.isPaused
        remainingTime = activeTimer.remainingTime
        elapsedTime = activeTimer.elapsedTime
        totalDuration = activeTimer.totalDuration
    }
    
    private var implementationName: String {
        return isUsingAdaptive ? "Adaptive" : "Lightweight"
    }
}

// MARK: - Delegation Forwarder

private class TimerDelegateForwarder: AdaptiveTimerDelegate {
    weak var parent: UnifiedAdaptiveTimer?
    
    init(parent: UnifiedAdaptiveTimer) {
        self.parent = parent
    }
    
    func timerDidFire(_ timer: AdaptiveTimerProviding) {
        guard let parent = parent else { return }
        parent.updateFromActiveTimer()
        parent.delegate?.timerDidFire(parent)
    }
    
    func timerDidAdapt(_ timer: AdaptiveTimerProviding, newDuration: TimeInterval, reason: AdaptationReason) {
        guard let parent = parent else { return }
        parent.updateFromActiveTimer()
        parent.delegate?.timerDidAdapt(parent, newDuration: newDuration, reason: reason)
    }
    
    func timerWasPaused(_ timer: AdaptiveTimerProviding) {
        guard let parent = parent else { return }
        parent.updateFromActiveTimer()
        // Don't forward - we handle this ourselves
    }
    
    func timerWasResumed(_ timer: AdaptiveTimerProviding) {
        guard let parent = parent else { return }
        parent.updateFromActiveTimer()
        // Don't forward - we handle this ourselves
    }
    
    func timerWasStopped(_ timer: AdaptiveTimerProviding) {
        guard let parent = parent else { return }
        parent.updateFromActiveTimer()
        // Don't forward - we handle this ourselves
    }
    
    func timerDidEncounterError(_ timer: AdaptiveTimerProviding, error: TimerError) {
        guard let parent = parent else { return }
        parent.updateFromActiveTimer()
        parent.delegate?.timerDidEncounterError(parent, error: error)
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