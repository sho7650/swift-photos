import Foundation
import AppKit
import Combine
import os.log

/// Unified interaction detection system that coordinates all input methods
/// Provides centralized event processing with intelligent filtering and rate limiting
@MainActor
public class InteractionDetector: InteractionDetecting, ObservableObject {
    
    // MARK: - Public Properties
    
    public weak var delegate: InteractionDetectorDelegate?
    
    @Published public var isEnabled: Bool = false {
        didSet {
            if isEnabled != oldValue {
                if isEnabled {
                    do {
                        try startDetection()
                    } catch {
                        logger.error("🔍 InteractionDetector: Failed to start detection - \(error.localizedDescription)")
                        isEnabled = false
                    }
                } else {
                    stopDetection()
                }
            }
        }
    }
    
    public var configuration: InteractionConfiguration {
        didSet {
            if configuration != oldValue {
                do {
                    try updateConfiguration(configuration)
                } catch {
                    logger.error("🔍 InteractionDetector: Failed to update configuration - \(error.localizedDescription)")
                }
            }
        }
    }
    
    public var observerCount: Int {
        return observers.count
    }
    
    // MARK: - Private Properties
    
    private var observers: [WeakObserver] = []
    private var recentInteractions: [Interaction] = []
    private let logger = Logger(subsystem: "SwiftPhotos", category: "InteractionDetector")
    
    // Event monitoring
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var keyboardMonitor: Any?
    private var gestureMonitor: Any?
    private var systemEventMonitor: Any?
    
    // Rate limiting and filtering
    private var lastEventTimestamp: TimeInterval = 0
    private var eventQueue: [QueuedEvent] = []
    private var processingTimer: Timer?
    private let eventProcessingInterval: TimeInterval = 0.016 // ~60fps
    
    // Performance optimization
    private var statisticsCollectionEnabled: Bool = true
    private var debugMode: Bool = false
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Initialization
    
    public init(configuration: InteractionConfiguration = InteractionConfiguration()) {
        self.configuration = configuration
        setupEventProcessing()
        logger.info("🔍 InteractionDetector: Initialized with \(configuration.enabledTypes.count) enabled types")
    }
    
    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = gestureMonitor {
            NSEvent.removeMonitor(monitor)
        }
        processingTimer?.invalidate()
        logger.debug("🔍 InteractionDetector: Deinitialized")
    }
    
    // MARK: - Public Methods
    
    public func startDetection() throws {
        guard !isEnabled else { return }
        
        logger.info("🔍 InteractionDetector: Starting detection...")
        
        // Request necessary permissions
        try requestPermissions()
        
        // Start monitoring based on configuration
        try startMouseMonitoring()
        try startKeyboardMonitoring()
        try startGestureMonitoring()
        try startSystemEventMonitoring()
        
        // Start event processing
        startEventProcessing()
        
        isEnabled = true
        logger.info("🔍 InteractionDetector: Detection started successfully")
        delegate?.detectorDidStartDetection(self)
    }
    
    public func stopDetection() {
        guard isEnabled else { return }
        
        logger.info("🔍 InteractionDetector: Stopping detection...")
        
        stopEventProcessing()
        stopAllMonitoring()
        
        isEnabled = false
        logger.info("🔍 InteractionDetector: Detection stopped")
        delegate?.detectorDidStopDetection(self)
    }
    
    public func detectInteraction(type: InteractionType, data: InteractionData) {
        let interaction = Interaction(
            type: type,
            data: data,
            source: .synthesized,
            confidence: 0.8
        )
        
        processInteraction(interaction)
    }
    
    public func addObserver(_ observer: InteractionObserver) {
        // Remove any existing weak reference to the same observer
        observers.removeAll { $0.observer == nil || $0.observer === observer }
        
        observers.append(WeakObserver(observer: observer))
        logger.debug("🔍 InteractionDetector: Added observer (total: \(self.observers.count))")
    }
    
    public func removeObserver(_ observer: InteractionObserver) {
        observers.removeAll { $0.observer == nil || $0.observer === observer }
        logger.debug("🔍 InteractionDetector: Removed observer (total: \(self.observers.count))")
    }
    
    public func removeAllObservers() {
        observers.removeAll()
        logger.debug("🔍 InteractionDetector: Removed all observers")
    }
    
    public func getRecentInteractions(within interval: TimeInterval) -> [Interaction] {
        let cutoffTime = Date().timeIntervalSince1970 - interval
        return recentInteractions.filter { $0.data.timestamp >= cutoffTime }
    }
    
    public func updateConfiguration(_ configuration: InteractionConfiguration) throws {
        let wasEnabled = isEnabled
        
        if wasEnabled {
            stopDetection()
        }
        
        self.configuration = configuration
        
        if wasEnabled {
            try startDetection()
        }
        
        logger.info("🔍 InteractionDetector: Configuration updated")
        delegate?.detectorDidUpdateConfiguration(self, configuration: configuration)
    }
    
    // MARK: - Private Event Monitoring Setup
    
    private func requestPermissions() throws {
        // Check for accessibility permissions
        if configuration.enabledTypes.contains(.mouseMove) || 
           configuration.enabledTypes.contains(.keyPress) {
            let trusted = AXIsProcessTrusted()
            if !trusted {
                throw InteractionError.systemPermissionDenied(permission: "Accessibility permissions required for global event monitoring")
            }
        }
    }
    
    private func startMouseMonitoring() throws {
        guard configuration.enabledTypes.includesMouseInteractions else { return }
        
        // Global mouse monitoring
        if configuration.enabledTypes.contains(.mouseMove) || 
           configuration.enabledTypes.contains(.mouseClick) {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handleMouseEvent(event, isGlobal: true)
                }
            }
        }
        
        // Local mouse monitoring for app-specific events
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseEvent(event, isGlobal: false)
            }
            return event
        }
        
        logger.debug("🔍 InteractionDetector: Mouse monitoring started")
    }
    
    private func startKeyboardMonitoring() throws {
        guard configuration.enabledTypes.contains(.keyPress) else { return }
        
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyboardEvent(event)
            }
        }
        
        logger.debug("🔍 InteractionDetector: Keyboard monitoring started")
    }
    
    private func startGestureMonitoring() throws {
        guard configuration.enableGestures && 
              (configuration.enabledTypes.contains(.gesture) || 
               configuration.enabledTypes.contains(.touch)) else { return }
        
        gestureMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.magnify, .swipe, .rotate, .beginGesture, .endGesture, .smartMagnify]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleGestureEvent(event)
            }
            return event
        }
        
        logger.debug("🔍 InteractionDetector: Gesture monitoring started")
    }
    
    private func startSystemEventMonitoring() throws {
        guard configuration.enabledTypes.contains(.systemEvent) else { return }
        
        // Monitor for window focus changes and other system events
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemEvent(.windowFocus, data: InteractionData())
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemEvent(.windowFocus, data: InteractionData())
            }
        }
        
        logger.debug("🔍 InteractionDetector: System event monitoring started")
    }
    
    // MARK: - Event Handlers
    
    private func handleMouseEvent(_ event: NSEvent, isGlobal: Bool) {
        let eventType: InteractionType
        
        switch event.type {
        case .mouseMoved:
            eventType = .mouseMove
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            eventType = .mouseClick
        case .scrollWheel:
            eventType = .mouseScroll
        default:
            return
        }
        
        guard configuration.enabledTypes.contains(eventType) else { return }
        
        let position = isGlobal ? event.locationInWindow : convertToLocalCoordinates(event.locationInWindow)
        let data = InteractionData(
            position: position,
            velocity: calculateMouseVelocity(position),
            modifierFlags: UInt(event.modifierFlags.rawValue)
        )
        
        let interaction = Interaction(
            type: eventType,
            data: data,
            source: .mouse,
            confidence: isGlobal ? 0.9 : 1.0
        )
        
        queueInteraction(interaction)
    }
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        guard configuration.enabledTypes.contains(.keyPress) else { return }
        
        let data = InteractionData(
            modifierFlags: UInt(event.modifierFlags.rawValue),
            keyCode: event.keyCode
        )
        
        let interaction = Interaction(
            type: .keyPress,
            data: data,
            source: .keyboard,
            confidence: 1.0
        )
        
        queueInteraction(interaction)
    }
    
    private func handleGestureEvent(_ event: NSEvent) {
        guard configuration.enableGestures else { return }
        
        let gestureType: GestureType
        let phase: GesturePhase
        
        switch event.type {
        case .magnify:
            gestureType = .magnify
            phase = event.phase == .began ? .began : 
                   event.phase == .ended ? .ended : .changed
        case .swipe:
            gestureType = determineSwipeDirection(event)
            phase = .ended // Swipes are typically discrete events
        case .rotate:
            gestureType = .rotation
            phase = event.phase == .began ? .began :
                   event.phase == .ended ? .ended : .changed
        case .smartMagnify:
            gestureType = .smartMagnify
            phase = .ended
        default:
            return
        }
        
        let gestureData = GestureData(
            gestureType: gestureType,
            phase: phase,
            scale: event.type == .magnify ? event.magnification : nil,
            rotation: event.type == .rotate ? Double(event.rotation) : nil,
            translation: event.type == .swipe ? CGVector(dx: event.deltaX, dy: event.deltaY) : nil
        )
        
        let data = InteractionData(
            position: convertToLocalCoordinates(event.locationInWindow),
            gestureData: gestureData
        )
        
        let interaction = Interaction(
            type: .gesture,
            data: data,
            source: .trackpad,
            confidence: 0.95
        )
        
        queueInteraction(interaction)
    }
    
    private func handleSystemEvent(_ type: InteractionType, data: InteractionData) {
        guard configuration.enabledTypes.contains(type) else { return }
        
        let interaction = Interaction(
            type: type,
            data: data,
            source: .systemAPI,
            confidence: 0.8
        )
        
        queueInteraction(interaction)
    }
    
    // MARK: - Event Processing
    
    private func setupEventProcessing() {
        // Initialize event processing systems
        eventQueue.reserveCapacity(100)
    }
    
    private func startEventProcessing() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: eventProcessingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processQueuedEvents()
            }
        }
    }
    
    private func stopEventProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
        eventQueue.removeAll()
    }
    
    private func queueInteraction(_ interaction: Interaction) {
        // Rate limiting
        let now = Date().timeIntervalSince1970
        if now - lastEventTimestamp < (1.0 / configuration.maxEventRate) {
            return
        }
        
        // Debouncing
        if now - lastEventTimestamp < configuration.debounceInterval {
            return
        }
        
        let queuedEvent = QueuedEvent(interaction: interaction, queueTime: now)
        eventQueue.append(queuedEvent)
        
        // Prevent queue overflow
        if eventQueue.count > 100 {
            eventQueue.removeFirst(20)
        }
        
        lastEventTimestamp = now
    }
    
    private func processQueuedEvents() {
        guard !eventQueue.isEmpty else { return }
        
        let now = Date().timeIntervalSince1970
        var processedCount = 0
        
        // Process events in order, respecting rate limits
        for queuedEvent in eventQueue {
            if processedCount >= Int(configuration.maxEventRate * eventProcessingInterval) {
                break
            }
            
            // Skip events that are too old
            if now - queuedEvent.queueTime > 1.0 {
                continue
            }
            
            processInteraction(queuedEvent.interaction)
            processedCount += 1
        }
        
        // Remove processed events
        eventQueue.removeFirst(min(processedCount, eventQueue.count))
        
        // Update performance metrics
        if statisticsCollectionEnabled {
            performanceMetrics.recordProcessedEvents(processedCount)
        }
    }
    
    private func processInteraction(_ interaction: Interaction) {
        // Filter by confidence threshold
        guard interaction.confidence >= configuration.minimumConfidence else { return }
        
        // Store in recent interactions
        storeRecentInteraction(interaction)
        
        // Notify observers
        notifyObservers(interaction)
        
        // Notify delegate
        delegate?.detectorDidDetectInteraction(self, interaction: interaction)
        
        if debugMode {
            logger.debug("🔍 InteractionDetector: Processed \(interaction.type.rawValue) interaction (confidence: \(String(format: "%.2f", interaction.confidence)))")
        }
    }
    
    private func storeRecentInteraction(_ interaction: Interaction) {
        recentInteractions.append(interaction)
        
        // Limit history size and age
        let cutoffTime = Date().timeIntervalSince1970 - 30.0 // Keep 30 seconds of history
        recentInteractions = recentInteractions.filter { $0.data.timestamp >= cutoffTime }
        
        if recentInteractions.count > 500 {
            recentInteractions = Array(recentInteractions.suffix(500))
        }
    }
    
    private func notifyObservers(_ interaction: Interaction) {
        // Clean up dead observers
        observers.removeAll { $0.observer == nil }
        
        // Notify active observers
        for weakObserver in observers {
            weakObserver.observer?.interactionOccurred(interaction)
        }
    }
    
    // MARK: - Cleanup
    
    private func stopAllMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        
        if let monitor = gestureMonitor {
            NSEvent.removeMonitor(monitor)
            gestureMonitor = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        
        logger.debug("🔍 InteractionDetector: All monitoring stopped")
    }
    
    // MARK: - Helper Methods
    
    private func convertToLocalCoordinates(_ windowPoint: CGPoint) -> CGPoint {
        // Convert window coordinates to local view coordinates
        // This would be implemented based on specific coordinate system needs
        return windowPoint
    }
    
    private func calculateMouseVelocity(_ position: CGPoint) -> CGVector? {
        // Simple velocity calculation based on recent positions
        guard recentInteractions.count >= 2 else { return nil }
        
        let recentMouseInteractions = recentInteractions
            .filter { $0.type == .mouseMove }
            .suffix(2)
        
        guard recentMouseInteractions.count >= 2,
              let previous = recentMouseInteractions.first,
              let current = recentMouseInteractions.last,
              let previousPos = previous.data.position else { return nil }
        
        let timeDelta = current.data.timestamp - previous.data.timestamp
        guard timeDelta > 0 else { return nil }
        
        let dx = (position.x - previousPos.x) / timeDelta
        let dy = (position.y - previousPos.y) / timeDelta
        
        return CGVector(dx: dx, dy: dy)
    }
    
    private func determineSwipeDirection(_ event: NSEvent) -> GestureType {
        if abs(event.deltaX) > abs(event.deltaY) {
            return event.deltaX > 0 ? .swipeRight : .swipeLeft
        } else {
            return event.deltaY > 0 ? .swipeUp : .swipeDown
        }
    }
}

// MARK: - Supporting Types

private struct QueuedEvent {
    let interaction: Interaction
    let queueTime: TimeInterval
}

private struct WeakObserver {
    weak var observer: InteractionObserver?
}

private struct PerformanceMetrics {
    private var eventCounts: [Double] = []
    private let maxSamples = 100
    
    mutating func recordProcessedEvents(_ count: Int) {
        eventCounts.append(Double(count))
        if eventCounts.count > maxSamples {
            eventCounts.removeFirst()
        }
    }
    
    var averageEventsPerSecond: Double {
        guard !eventCounts.isEmpty else { return 0 }
        return eventCounts.reduce(0, +) / Double(eventCounts.count) / 0.016 // Convert from per-frame to per-second
    }
}