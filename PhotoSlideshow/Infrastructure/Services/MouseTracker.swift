import Foundation
import AppKit
import CoreGraphics
import Combine
import os.log

/// Enhanced mouse tracking system with velocity calculation, zone detection, and sensitivity curves
/// Provides accurate mouse movement analysis for sophisticated interaction detection
@MainActor
public class MouseTracker: MouseTracking, ObservableObject {
    
    // MARK: - Public Properties
    
    @Published public var configuration: MouseTrackingConfiguration {
        didSet {
            if configuration != oldValue {
                updateTrackingConfiguration()
            }
        }
    }
    
    @Published public private(set) var currentPosition: CGPoint = .zero
    @Published public private(set) var velocity: CGVector = .zero
    @Published public private(set) var acceleration: Double = 0.0
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var trackingZones: [MouseTrackingZone] = []
    
    public weak var delegate: MouseTrackingDelegate?
    
    // MARK: - Private Properties
    
    private var eventMonitor: Any?
    private var trackingTimer: Timer?
    private let logger = Logger(subsystem: "PhotoSlideshow", category: "MouseTracker")
    
    // Velocity and acceleration calculation
    private var positionHistory: [PositionSample] = []
    private var velocityHistory: [VelocityDataPoint] = []
    private let maxHistorySize: Int = 60 // 1 second at 60fps
    
    // Performance optimization
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval
    private var coalescingBuffer: [MouseEvent] = []
    
    // Zone detection
    private var activeZone: MouseTrackingZone?
    private var zoneTransitionThreshold: Double = 5.0 // pixels
    
    // MARK: - Initialization
    
    public init(configuration: MouseTrackingConfiguration = MouseTrackingConfiguration()) {
        self.configuration = configuration
        self.updateInterval = 1.0 / configuration.samplingRate
        logger.info("🖱️ MouseTracker: Initialized with sampling rate \(configuration.samplingRate)Hz")
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        trackingTimer?.invalidate()
        logger.debug("🖱️ MouseTracker: Deinitialized")
    }
    
    // MARK: - Public Methods
    
    public func startTracking() throws {
        guard !isTracking else {
            logger.warning("🖱️ MouseTracker: Already tracking")
            return
        }
        
        logger.info("🖱️ MouseTracker: Starting mouse tracking...")
        
        // Start event monitoring
        try startEventMonitoring()
        
        // Start periodic updates if enabled
        if configuration.enableVelocityTracking {
            startPeriodicUpdates()
        }
        
        isTracking = true
        currentPosition = NSEvent.mouseLocation
        
        logger.info("🖱️ MouseTracker: Mouse tracking started successfully")
        delegate?.mouseTrackingDidStart(self)
    }
    
    public func stopTracking() {
        guard isTracking else { return }
        
        logger.info("🖱️ MouseTracker: Stopping mouse tracking...")
        
        stopEventMonitoring()
        stopPeriodicUpdates()
        clearHistory()
        
        isTracking = false
        velocity = .zero
        acceleration = 0.0
        activeZone = nil
        
        logger.info("🖱️ MouseTracker: Mouse tracking stopped")
        delegate?.mouseTrackingDidStop(self)
    }
    
    public func addTrackingZone(_ zone: MouseTrackingZone) {
        trackingZones.append(zone)
        trackingZones.sort { $0.priority > $1.priority }
        
        logger.debug("🖱️ MouseTracker: Added tracking zone '\(zone.name)' (total: \(self.trackingZones.count))")
        delegate?.mouseTracker(self, didAddZone: zone)
    }
    
    public func removeTrackingZone(id: UUID) {
        let originalCount = trackingZones.count
        trackingZones.removeAll { $0.id == id }
        
        if trackingZones.count < originalCount {
            logger.debug("🖱️ MouseTracker: Removed tracking zone \(id) (remaining: \(self.trackingZones.count))")
            delegate?.mouseTracker(self, didRemoveZoneWithId: id)
        }
        
        // Clear active zone if it was removed
        if activeZone?.id == id {
            activeZone = nil
        }
    }
    
    public func clearTrackingZones() {
        let count = trackingZones.count
        trackingZones.removeAll()
        activeZone = nil
        
        logger.debug("🖱️ MouseTracker: Cleared all \(count) tracking zones")
        delegate?.mouseTrackerDidClearAllZones(self)
    }
    
    public func isPointInTrackingZone(_ point: CGPoint) -> MouseTrackingZone? {
        return trackingZones.first { zone in
            zone.contains(point)
        }
    }
    
    public func getVelocityHistory(duration: TimeInterval) -> [VelocityDataPoint] {
        let cutoffTime = Date().timeIntervalSince1970 - duration
        return velocityHistory.filter { $0.timestamp >= cutoffTime }
    }
    
    public func getCurrentSensitivity() -> Double {
        return activeZone?.sensitivity ?? configuration.sensitivity
    }
    
    public func getEffectiveVelocity() -> CGVector {
        let sensitivity = getCurrentSensitivity()
        return CGVector(dx: velocity.dx * sensitivity, dy: velocity.dy * sensitivity)
    }
    
    // MARK: - Private Event Monitoring
    
    private func startEventMonitoring() throws {
        // Global mouse monitoring for all mouse events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseEvent(event)
            }
        }
        
        if eventMonitor == nil {
            throw MouseTrackingError.monitoringFailed("Failed to create mouse event monitor")
        }
        
        logger.debug("🖱️ MouseTracker: Event monitoring started")
    }
    
    private func stopEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            logger.debug("🖱️ MouseTracker: Event monitoring stopped")
        }
    }
    
    private func startPeriodicUpdates() {
        trackingTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicUpdate()
            }
        }
    }
    
    private func stopPeriodicUpdates() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }
    
    // MARK: - Event Handling
    
    private func handleMouseEvent(_ event: NSEvent) {
        let now = Date().timeIntervalSince1970
        
        // Rate limiting based on configuration
        if now - lastUpdateTime < (1.0 / configuration.samplingRate) {
            // Buffer the event for later processing
            if coalescingBuffer.count < 10 {
                coalescingBuffer.append(MouseEvent(event: event, timestamp: now))
            }
            return
        }
        
        let newPosition = event.locationInWindow != .zero ? event.locationInWindow : NSEvent.mouseLocation
        processMousePosition(newPosition, timestamp: now)
        
        lastUpdateTime = now
        
        // Process any buffered events
        processCoalescingBuffer()
    }
    
    private func processMousePosition(_ position: CGPoint, timestamp: TimeInterval) {
        let previousPosition = currentPosition
        currentPosition = position
        
        // Update position history
        updatePositionHistory(position, timestamp: timestamp)
        
        // Calculate velocity and acceleration
        if configuration.enableVelocityTracking {
            updateVelocityAndAcceleration(from: previousPosition, to: position, timestamp: timestamp)
        }
        
        // Check zone transitions
        if configuration.enableZoneDetection {
            checkZoneTransitions(position)
        }
        
        // Notify delegate
        delegate?.mouseTracker(self, didUpdatePosition: position, velocity: velocity)
    }
    
    private func updatePositionHistory(_ position: CGPoint, timestamp: TimeInterval) {
        let sample = PositionSample(position: position, timestamp: timestamp)
        positionHistory.append(sample)
        
        // Maintain history size
        if positionHistory.count > maxHistorySize {
            positionHistory.removeFirst()
        }
    }
    
    private func updateVelocityAndAcceleration(from previousPosition: CGPoint, to currentPosition: CGPoint, timestamp: TimeInterval) {
        guard positionHistory.count >= 2 else { return }
        
        let timeDelta = timestamp - positionHistory[positionHistory.count - 2].timestamp
        guard timeDelta > 0 else { return }
        
        // Calculate raw velocity
        let dx = (currentPosition.x - previousPosition.x) / timeDelta
        let dy = (currentPosition.y - previousPosition.y) / timeDelta
        let rawVelocity = CGVector(dx: dx, dy: dy)
        
        // Apply smoothing
        let smoothing = configuration.velocitySmoothing
        velocity = CGVector(
            dx: velocity.dx * smoothing + rawVelocity.dx * (1.0 - smoothing),
            dy: velocity.dy * smoothing + rawVelocity.dy * (1.0 - smoothing)
        )
        
        // Calculate acceleration
        if let lastVelocityPoint = velocityHistory.last {
            let velocityDelta = sqrt(pow(velocity.dx - lastVelocityPoint.velocity.dx, 2) + 
                                   pow(velocity.dy - lastVelocityPoint.velocity.dy, 2))
            let timeDelta = timestamp - lastVelocityPoint.timestamp
            acceleration = timeDelta > 0 ? velocityDelta / timeDelta : 0.0
        }
        
        // Store velocity history
        let velocityPoint = VelocityDataPoint(
            timestamp: timestamp,
            position: currentPosition,
            velocity: velocity,
            acceleration: acceleration
        )
        velocityHistory.append(velocityPoint)
        
        // Maintain velocity history size
        let maxVelocityHistory = Int(configuration.historyDuration * configuration.samplingRate)
        if velocityHistory.count > maxVelocityHistory {
            velocityHistory.removeFirst()
        }
    }
    
    private func checkZoneTransitions(_ position: CGPoint) {
        let newZone = isPointInTrackingZone(position)
        
        if newZone?.id != activeZone?.id {
            // Zone transition detected
            if let currentZone = activeZone {
                delegate?.mouseTracker(self, didExitZone: currentZone)
                logger.debug("🖱️ MouseTracker: Exited zone '\(currentZone.name)'")
            }
            
            if let newZone = newZone {
                delegate?.mouseTracker(self, didEnterZone: newZone)
                logger.debug("🖱️ MouseTracker: Entered zone '\(newZone.name)'")
            }
            
            activeZone = newZone
        }
    }
    
    private func processCoalescingBuffer() {
        guard !coalescingBuffer.isEmpty else { return }
        
        // Process the most recent event from the buffer
        if let mostRecentEvent = coalescingBuffer.last {
            let position = mostRecentEvent.event.locationInWindow != .zero ? 
                          mostRecentEvent.event.locationInWindow : NSEvent.mouseLocation
            processMousePosition(position, timestamp: mostRecentEvent.timestamp)
        }
        
        coalescingBuffer.removeAll()
    }
    
    private func performPeriodicUpdate() {
        // This method can be used for periodic cleanup or calibration
        let now = Date().timeIntervalSince1970
        
        // Clean up old history
        let cutoffTime = now - configuration.historyDuration
        positionHistory.removeAll { $0.timestamp < cutoffTime }
        velocityHistory.removeAll { $0.timestamp < cutoffTime }
        
        // Check for significant velocity changes that might indicate gesture start/end
        if velocity.magnitude > configuration.accelerationThreshold {
            delegate?.mouseTracker(self, didDetectHighVelocity: velocity)
        }
    }
    
    private func updateTrackingConfiguration() {
        logger.info("🖱️ MouseTracker: Configuration updated")
        
        // Update timing if needed
        if isTracking {
            stopPeriodicUpdates()
            if configuration.enableVelocityTracking {
                startPeriodicUpdates()
            }
        }
        
        delegate?.mouseTracker(self, didUpdateConfiguration: configuration)
    }
    
    private func clearHistory() {
        positionHistory.removeAll()
        velocityHistory.removeAll()
        coalescingBuffer.removeAll()
    }
}

// MARK: - Supporting Types

/// Mouse event wrapper for coalescing
private struct MouseEvent {
    let event: NSEvent
    let timestamp: TimeInterval
}

/// Position sample for history tracking
private struct PositionSample {
    let position: CGPoint
    let timestamp: TimeInterval
}

/// Errors that can occur during mouse tracking
public enum MouseTrackingError: LocalizedError {
    case monitoringFailed(String)
    case configurationInvalid(String)
    case systemPermissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .monitoringFailed(let reason):
            return "Mouse monitoring failed: \(reason)"
        case .configurationInvalid(let parameter):
            return "Invalid mouse tracking configuration: \(parameter)"
        case .systemPermissionDenied:
            return "System permission denied for mouse tracking"
        }
    }
}

/// Delegate protocol for mouse tracking events
@MainActor
public protocol MouseTrackingDelegate: AnyObject {
    /// Called when mouse tracking starts
    func mouseTrackingDidStart(_ tracker: MouseTracker)
    
    /// Called when mouse tracking stops
    func mouseTrackingDidStop(_ tracker: MouseTracker)
    
    /// Called when mouse position or velocity updates
    func mouseTracker(_ tracker: MouseTracker, didUpdatePosition position: CGPoint, velocity: CGVector)
    
    /// Called when mouse enters a tracking zone
    func mouseTracker(_ tracker: MouseTracker, didEnterZone zone: MouseTrackingZone)
    
    /// Called when mouse exits a tracking zone
    func mouseTracker(_ tracker: MouseTracker, didExitZone zone: MouseTrackingZone)
    
    /// Called when a new tracking zone is added
    func mouseTracker(_ tracker: MouseTracker, didAddZone zone: MouseTrackingZone)
    
    /// Called when a tracking zone is removed
    func mouseTracker(_ tracker: MouseTracker, didRemoveZoneWithId id: UUID)
    
    /// Called when all tracking zones are cleared
    func mouseTrackerDidClearAllZones(_ tracker: MouseTracker)
    
    /// Called when configuration is updated
    func mouseTracker(_ tracker: MouseTracker, didUpdateConfiguration configuration: MouseTrackingConfiguration)
    
    /// Called when high velocity is detected
    func mouseTracker(_ tracker: MouseTracker, didDetectHighVelocity velocity: CGVector)
}

// MARK: - Extensions

extension CGVector {
    /// Calculate the magnitude of the vector
    var magnitude: Double {
        return sqrt(dx * dx + dy * dy)
    }
}

/// Default implementations for optional delegate methods
extension MouseTrackingDelegate {
    func mouseTrackingDidStart(_ tracker: MouseTracker) {}
    func mouseTrackingDidStop(_ tracker: MouseTracker) {}
    func mouseTracker(_ tracker: MouseTracker, didEnterZone zone: MouseTrackingZone) {}
    func mouseTracker(_ tracker: MouseTracker, didExitZone zone: MouseTrackingZone) {}
    func mouseTracker(_ tracker: MouseTracker, didAddZone zone: MouseTrackingZone) {}
    func mouseTracker(_ tracker: MouseTracker, didRemoveZoneWithId id: UUID) {}
    func mouseTrackerDidClearAllZones(_ tracker: MouseTracker) {}
    func mouseTracker(_ tracker: MouseTracker, didUpdateConfiguration configuration: MouseTrackingConfiguration) {}
    func mouseTracker(_ tracker: MouseTracker, didDetectHighVelocity velocity: CGVector) {}
}