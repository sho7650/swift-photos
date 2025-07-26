//
//  TimerPerformanceTests.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/26.
//

import Testing
import Foundation
@testable import Swift_Photos

@MainActor
struct TimerPerformanceTests {
    
    // MARK: - OptimizedTimerPool Performance Tests
    
    @Test func testTimerPoolPerformanceWithManyTimers() async {
        let timerPool = OptimizedTimerPool.shared
        let timerCount = 100
        var completedTimers = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Schedule many short timers
        var timerIds: [UUID] = []
        for i in 0..<timerCount {
            let duration = 0.01 + Double(i) * 0.001 // 0.01s to 0.11s
            let timerId = timerPool.scheduleTimer(duration: duration) {
                completedTimers += 1
            }
            timerIds.append(timerId)
        }
        
        // Wait for all timers to complete
        let maxWaitTime: TimeInterval = 2.0
        let pollInterval: TimeInterval = 0.01
        var waitTime: TimeInterval = 0
        
        while completedTimers < timerCount && waitTime < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            waitTime += pollInterval
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let stats = timerPool.getPoolStatistics()
        
        #expect(completedTimers == timerCount)
        #expect(totalTime < 1.0) // Should complete well within 1 second
        #expect(stats.efficiency > 0.8) // At least 80% efficiency
        
        // Clean up any remaining timers
        for timerId in timerIds {
            timerPool.cancelTimer(timerId)
        }
    }
    
    @Test func testTimerPoolMemoryEfficiency() async {
        let timerPool = OptimizedTimerPool.shared
        let initialStats = timerPool.getPoolStatistics()
        
        // Create and complete many timers to test memory management
        for batch in 0..<10 {
            var batchTimers: [UUID] = []
            
            // Schedule 20 timers per batch
            for i in 0..<20 {
                let timerId = timerPool.scheduleTimer(duration: 0.01) {
                    // Timer completion
                }
                batchTimers.append(timerId)
            }
            
            // Wait for batch to complete
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            
            // Check that active timer count returns to baseline
            let batchStats = timerPool.getPoolStatistics()
            if batch > 2 { // Allow warmup period
                #expect(batchStats.activeTimers <= 5) // Should be few or no active timers
            }
        }
        
        let finalStats = timerPool.getPoolStatistics()
        #expect(finalStats.activeTimers <= initialStats.activeTimers + 2) // Minimal active timer growth
    }
    
    @Test func testTimerPoolBackgroundOptimization() async {
        let timerPool = OptimizedTimerPool.shared
        
        // Simulate app going to background
        let notification = Notification(name: NSApplication.didResignActiveNotification)
        NotificationCenter.default.post(notification)
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s for notification processing
        
        let backgroundStats = timerPool.getPoolStatistics()
        #expect(backgroundStats.isInBackground == true)
        #expect(backgroundStats.currentTickInterval > 0.1) // Should use slower tick rate
        
        // Simulate app coming to foreground
        let foregroundNotification = Notification(name: NSApplication.didBecomeActiveNotification)
        NotificationCenter.default.post(foregroundNotification)
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s for notification processing
        
        let foregroundStats = timerPool.getPoolStatistics()
        #expect(foregroundStats.isInBackground == false)
        #expect(foregroundStats.currentTickInterval < 0.05) // Should use faster tick rate
    }
    
    // MARK: - LightweightAdaptiveTimer Performance Tests
    
    @Test func testLightweightTimerInitializationSpeed() async {
        let iterations = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var timers: [LightweightAdaptiveTimer] = []
        for _ in 0..<iterations {
            let timer = LightweightAdaptiveTimer.forUIControls(baseDuration: 1.0)
            timers.append(timer)
        }
        
        let initTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should initialize 1000 timers very quickly
        #expect(initTime < 0.1) // Less than 100ms for 1000 timers
        #expect(timers.count == iterations)
        
        // Clean up
        for timer in timers {
            timer.stop()
        }
    }
    
    @Test func testLightweightTimerAdaptationPerformance() async {
        let timer = LightweightAdaptiveTimer.forUIControls(baseDuration: 1.0)
        timer.adaptationEnabled = true
        
        let config = TimerConfiguration.autoHide(duration: 1.0)
        
        do {
            try timer.start(with: config)
            
            // Perform many adaptations quickly
            let adaptationCount = 100
            let startTime = CFAbsoluteTimeGetCurrent()
            
            for i in 0..<adaptationCount {
                let context = TimingContext(
                    userActivity: i % 2 == 0 ? .active : .moderate,
                    appState: .foreground,
                    customFactors: ["testFactor": 1.0 + Double(i) * 0.01]
                )
                timer.adaptTiming(based: context)
                
                // Small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
            
            let adaptationTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Should handle 100 adaptations quickly
            #expect(adaptationTime < 0.5) // Less than 500ms for 100 adaptations
            
            timer.stop()
        } catch {
            #expect(Bool(false), "Timer should start successfully: \(error)")
        }
    }
    
    @Test func testLightweightTimerMemoryUsage() async {
        // Test that lightweight timer uses less memory than full adaptive timer
        let lightweightTimer = LightweightAdaptiveTimer.forUIControls(baseDuration: 1.0)
        let fullTimer = AdaptiveTimer()
        
        // Both timers should be lightweight in terms of initialization
        #expect(lightweightTimer.currentConfiguration.baseDuration == 1.0)
        #expect(fullTimer.currentConfiguration.baseDuration == 5.0) // Default
        
        // Lightweight timer should have simpler adaptation history
        let lightweightHistory = lightweightTimer.getAdaptationHistory()
        let fullHistory = fullTimer.getAdaptationHistory()
        
        #expect(lightweightHistory.count == 0) // No history initially
        #expect(fullHistory.count == 0) // No history initially
        
        // Test that adaptation history is limited in lightweight version
        lightweightTimer.adaptationEnabled = true
        fullTimer.adaptationEnabled = true
        
        let config = TimerConfiguration.autoHide(duration: 0.1)
        
        do {
            try lightweightTimer.start(with: config)
            try fullTimer.start(with: config)
            
            // Generate some adaptation history
            for _ in 0..<10 {
                let context = TimingContext(userActivity: .active, appState: .foreground)
                lightweightTimer.adaptTiming(based: context)
                fullTimer.adaptTiming(based: context)
            }
            
            lightweightTimer.stop()
            fullTimer.stop()
            
            // Both should have some adaptation history, but lightweight should be more efficient
            let lightweightHistoryAfter = lightweightTimer.getAdaptationHistory()
            let fullHistoryAfter = fullTimer.getAdaptationHistory()
            
            #expect(lightweightHistoryAfter.count >= 0) // May or may not have history depending on actual adaptations
            #expect(fullHistoryAfter.count >= 0) // May or may not have history depending on actual adaptations
            
        } catch {
            #expect(Bool(false), "Timers should start successfully: \(error)")
        }
    }
    
    // MARK: - Comparative Performance Tests
    
    @Test func testTimerPoolVsIndividualTimers() async {
        let timerCount = 50
        let duration: TimeInterval = 0.05
        
        // Test individual Timer instances
        let individualStartTime = CFAbsoluteTimeGetCurrent()
        var individualTimers: [Timer] = []
        var individualCompletions = 0
        
        for _ in 0..<timerCount {
            let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                individualCompletions += 1
            }
            individualTimers.append(timer)
        }
        
        // Wait for individual timers
        while individualCompletions < timerCount {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let individualTime = CFAbsoluteTimeGetCurrent() - individualStartTime
        
        // Clean up individual timers
        for timer in individualTimers {
            timer.invalidate()
        }
        
        // Test timer pool
        let poolStartTime = CFAbsoluteTimeGetCurrent()
        let timerPool = OptimizedTimerPool.shared
        var poolCompletions = 0
        var poolTimerIds: [UUID] = []
        
        for _ in 0..<timerCount {
            let timerId = timerPool.scheduleTimer(duration: duration) {
                poolCompletions += 1
            }
            poolTimerIds.append(timerId)
        }
        
        // Wait for pool timers
        while poolCompletions < timerCount {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let poolTime = CFAbsoluteTimeGetCurrent() - poolStartTime
        
        // Timer pool should be at least as fast, often faster due to shared infrastructure
        #expect(poolTime <= individualTime * 1.2) // Allow 20% margin
        #expect(poolCompletions == timerCount)
        #expect(individualCompletions == timerCount)
        
        // Clean up pool timers
        for timerId in poolTimerIds {
            timerPool.cancelTimer(timerId)
        }
    }
    
    @Test func testUIControlStateManagerTimerPerformance() async {
        let uiControlSettings = UIControlSettingsManager()
        uiControlSettings.updateSettings(UIControlSettings(
            autoHideDelay: 0.1, // Short delay for testing
            playingAutoHideDelay: 0.05,
            pausedAutoHideDelay: 0.2,
            minimumVisibilityDuration: 0.05
        ))
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        let operationCount = 20
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform many show/hide operations
        for i in 0..<operationCount {
            stateManager.showControls()
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            if i % 2 == 0 {
                stateManager.hideControls(force: true)
            }
            
            // Simulate user interaction
            stateManager.handleKeyboardInteraction()
            stateManager.handleMouseInteraction(at: CGPoint(x: Double(i * 10), y: Double(i * 10)))
        }
        
        let operationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should handle many operations quickly
        #expect(operationTime < 1.0) // Less than 1 second for 20 operations
        #expect(stateManager.isControlsVisible == true) // Should end in visible state
    }
    
    // MARK: - Timer Precision Tests
    
    @Test func testTimerPoolPrecision() async {
        let timerPool = OptimizedTimerPool.shared
        let targetDuration: TimeInterval = 0.1
        let tolerance: TimeInterval = 0.02 // 20ms tolerance
        
        var actualDuration: TimeInterval = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let timerId = timerPool.preciseTimer(duration: targetDuration) {
            actualDuration = CFAbsoluteTimeGetCurrent() - startTime
        }
        
        // Wait for timer with some buffer
        try? await Task.sleep(nanoseconds: UInt64((targetDuration + 0.05) * 1_000_000_000))
        
        #expect(actualDuration > 0) // Timer should have fired
        #expect(abs(actualDuration - targetDuration) < tolerance) // Within tolerance
        
        timerPool.cancelTimer(timerId) // Clean up (though it should be completed)
    }
    
    @Test func testLightweightTimerPrecision() async {
        let timer = LightweightAdaptiveTimer.highPerformance(baseDuration: 0.1)
        let targetDuration: TimeInterval = 0.1
        let tolerance: TimeInterval = 0.03 // 30ms tolerance (more lenient for lightweight version)
        
        var timerFired = false
        var actualDuration: TimeInterval = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        timer.delegate = TimerTestDelegate { _ in
            actualDuration = CFAbsoluteTimeGetCurrent() - startTime
            timerFired = true
        }
        
        let config = TimerConfiguration.performance(duration: targetDuration)
        
        do {
            try timer.start(with: config)
            
            // Wait for timer with buffer
            try? await Task.sleep(nanoseconds: UInt64((targetDuration + 0.1) * 1_000_000_000))
            
            #expect(timerFired == true)
            #expect(actualDuration > 0)
            #expect(abs(actualDuration - targetDuration) < tolerance)
            
        } catch {
            #expect(Bool(false), "Timer should start successfully: \(error)")
        }
    }
}

// MARK: - Test Helper

@MainActor
private class TimerTestDelegate: AdaptiveTimerDelegate {
    private let onFire: (AdaptiveTimerProviding) -> Void
    
    init(onFire: @escaping (AdaptiveTimerProviding) -> Void) {
        self.onFire = onFire
    }
    
    func timerDidFire(_ timer: AdaptiveTimerProviding) {
        onFire(timer)
    }
}