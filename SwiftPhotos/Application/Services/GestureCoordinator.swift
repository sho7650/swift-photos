import Foundation
import SwiftUI
import Combine
import os.log

/// Coordinates gesture handling between interaction components
/// Provides high-level gesture management with intelligent conflict resolution
@MainActor
public class GestureCoordinator: ObservableObject {
    
    // MARK: - Public Properties
    
    @Published public var isEnabled: Bool = true
    @Published public var activeZones: [InteractionZone] = []
    @Published public var gestureConfiguration: GestureConfiguration
    
    public weak var delegate: GestureCoordinatorDelegate?
    
    // MARK: - Private Properties
    
    private var interactionDetector: InteractionDetecting?
    private var mouseTracker: MouseTracking?
    private let logger = Logger(subsystem: "SwiftPhotos", category: "GestureCoordinator")
    
    // Gesture state management
    private var activeGestures: [UUID: ActiveGesture] = [:]
    private var gestureConflictResolver: GestureConflictResolver
    private var gestureHistory: [CompletedGesture] = []
    
    // Performance optimization
    private var gestureProcessingQueue = DispatchQueue(label: "gesture.processing", qos: .userInteractive)
    private var lastGestureProcessedTime: TimeInterval = 0
    private let gestureProcessingThrottle: TimeInterval = 0.016 // ~60fps
    
    // MARK: - Initialization
    
    public init(
        gestureConfiguration: GestureConfiguration = GestureConfiguration(),
        interactionDetector: InteractionDetecting? = nil,
        mouseTracker: MouseTracking? = nil
    ) {
        self.gestureConfiguration = gestureConfiguration
        self.interactionDetector = interactionDetector
        self.mouseTracker = mouseTracker
        self.gestureConflictResolver = GestureConflictResolver(configuration: gestureConfiguration)
        
        logger.info("🎯 GestureCoordinator: Initialized with \(gestureConfiguration.enabledGestures.count) enabled gestures")
        
        setupGestureIntegration()
    }
    
    // MARK: - Public Methods
    
    /// Add a gesture zone for interaction detection
    public func addGestureZone(_ zone: InteractionZone) {
        activeZones.append(zone)
        activeZones.sort { $0.priority > $1.priority }
        
        logger.debug("🎯 GestureCoordinator: Added zone '\(zone.name)' (total: \(self.activeZones.count))")
        delegate?.gestureCoordinator(self, didAddZone: zone)
    }
    
    /// Remove a gesture zone
    public func removeGestureZone(id: UUID) {
        let originalCount = activeZones.count
        activeZones.removeAll { $0.id == id }
        
        if activeZones.count < originalCount {
            logger.debug("🎯 GestureCoordinator: Removed zone \(id) (remaining: \(self.activeZones.count))")
            delegate?.gestureCoordinator(self, didRemoveZoneWithId: id)
        }
        
        // Cancel any active gestures in this zone
        cancelActiveGesturesInZone(id: id)
    }
    
    /// Update gesture configuration
    public func updateConfiguration(_ configuration: GestureConfiguration) {
        gestureConfiguration = configuration
        gestureConflictResolver.updateConfiguration(configuration)
        
        logger.info("🎯 GestureCoordinator: Configuration updated")
        delegate?.gestureCoordinator(self, didUpdateConfiguration: configuration)
    }
    
    /// Manually trigger a gesture (for testing or external integration)
    public func triggerGesture(_ gestureType: GestureType, at location: CGPoint, in zone: InteractionZone?) {
        let gestureData = GestureData(
            gestureType: gestureType,
            phase: .ended
        )
        
        processGesture(gestureData, at: location, in: zone, sensitivity: zone?.sensitivity ?? 1.0)
    }
    
    /// Enable or disable specific gesture types
    public func setGestureEnabled(_ gestureType: GestureType, enabled: Bool) {
        var enabledGestures = gestureConfiguration.enabledGestures
        
        if enabled {
            enabledGestures.insert(gestureType)
        } else {
            enabledGestures.remove(gestureType)
            
            // Cancel any active gestures of this type
            cancelActiveGestures(ofType: gestureType)
        }
        
        let newConfiguration = GestureConfiguration(
            enabledGestures: enabledGestures,
            minimumTouchCount: gestureConfiguration.minimumTouchCount,
            maximumTouchCount: gestureConfiguration.maximumTouchCount,
            recognitionDelay: gestureConfiguration.recognitionDelay,
            simultaneousRecognition: gestureConfiguration.simultaneousRecognition,
            pressureSupport: gestureConfiguration.pressureSupport
        )
        
        updateConfiguration(newConfiguration)
    }
    
    /// Get gesture statistics
    public func getGestureStatistics() -> GestureStatistics {
        let completedGestures = gestureHistory.suffix(100) // Last 100 gestures
        
        return GestureStatistics(
            totalGesturesProcessed: gestureHistory.count,
            activeGestureCount: activeGestures.count,
            averageGestureProcessingTime: calculateAverageProcessingTime(from: completedGestures),
            gestureSuccessRate: calculateSuccessRate(from: completedGestures),
            mostUsedGesture: findMostUsedGesture(from: completedGestures)
        )
    }
    
    // MARK: - Public Gesture Processing Methods
    
    /// Process a gesture detected by any interaction component
    public func processDetectedGesture(_ gesture: GestureData, in zone: InteractionZone?, at location: CGPoint, sensitivity: Double) {
        processGesture(gesture, at: location, in: zone, sensitivity: sensitivity)
    }
    
    /// Update an active gesture
    public func updateDetectedGesture(_ gesture: GestureData, in zone: InteractionZone?, at location: CGPoint) {
        updateActiveGesture(gesture, at: location, in: zone)
    }
    
    /// Notify that gesture detection has started
    public func notifyGestureDetectionStarted() {
        logger.info("🎯 GestureCoordinator: Gesture detection started")
        delegate?.gestureCoordinatorDidStartGestureDetection(self)
    }
    
    /// Notify that gesture detection has stopped
    public func notifyGestureDetectionStopped() {
        logger.info("🎯 GestureCoordinator: Gesture detection stopped")
        cancelAllActiveGestures()
        delegate?.gestureCoordinatorDidStopGestureDetection(self)
    }
    
    // MARK: - Private Methods
    
    private func setupGestureIntegration() {
        // Integrate with InteractionDetector if available
        if let detector = interactionDetector {
            // Add observer for gesture events from other sources
            logger.debug("🎯 GestureCoordinator: Integrated with InteractionDetector")
        }
        
        // Integrate with MouseTracker if available
        if let tracker = mouseTracker {
            // Setup mouse gesture detection
            logger.debug("🎯 GestureCoordinator: Integrated with MouseTracker")
        }
    }
    
    private func processGesture(_ gesture: GestureData, at location: CGPoint, in zone: InteractionZone?, sensitivity: Double = 1.0) {
        guard isEnabled && gestureConfiguration.enabledGestures.contains(gesture.gestureType) else {
            return
        }
        
        let now = Date().timeIntervalSince1970
        
        // Throttle gesture processing for performance
        guard now - lastGestureProcessedTime >= gestureProcessingThrottle else {
            return
        }
        lastGestureProcessedTime = now
        
        gestureProcessingQueue.async { [weak self] in
            Task { @MainActor in
                self?.performGestureProcessing(gesture, at: location, in: zone, sensitivity: sensitivity)
            }
        }
    }
    
    private func performGestureProcessing(_ gesture: GestureData, at location: CGPoint, in zone: InteractionZone?, sensitivity: Double) {
        let gestureId = UUID()
        let startTime = Date().timeIntervalSince1970
        
        // Create active gesture
        let activeGesture = ActiveGesture(
            id: gestureId,
            data: gesture,
            location: location,
            zone: zone,
            sensitivity: sensitivity,
            startTime: startTime
        )
        
        // Check for gesture conflicts
        let conflictResolution = gestureConflictResolver.resolveConflicts(
            newGesture: activeGesture,
            activeGestures: Array(activeGestures.values)
        )
        
        switch conflictResolution.action {
        case .allow:
            processAllowedGesture(activeGesture)
        case .cancel(let gestureIds):
            cancelSpecificGestures(gestureIds)
            processAllowedGesture(activeGesture)
        case .`defer`:
            deferGesture(activeGesture)
        case .reject:
            rejectGesture(activeGesture, reason: conflictResolution.reason)
        }
    }
    
    private func processAllowedGesture(_ gesture: ActiveGesture) {
        activeGestures[gesture.id] = gesture
        
        logger.debug("🎯 GestureCoordinator: Processing \(gesture.data.gestureType.rawValue) gesture in zone '\(gesture.zone?.name ?? "none")'")
        
        // Notify delegate
        delegate?.gestureCoordinator(self, didProcessGesture: gesture.data, at: gesture.location, in: gesture.zone)
        
        // If gesture is complete (ended phase), finish it
        if gesture.data.phase == .ended || gesture.data.phase == .cancelled || gesture.data.phase == .failed {
            completeGesture(gesture)
        }
    }
    
    private func updateActiveGesture(_ gesture: GestureData, at location: CGPoint, in zone: InteractionZone?) {
        // Find active gesture to update (simplified - would need better matching logic)
        if let activeGesture = activeGestures.values.first(where: { $0.data.gestureType == gesture.gestureType }) {
            let updatedGesture = ActiveGesture(
                id: activeGesture.id,
                data: gesture,
                location: location,
                zone: zone,
                sensitivity: activeGesture.sensitivity,
                startTime: activeGesture.startTime
            )
            
            activeGestures[activeGesture.id] = updatedGesture
            
            delegate?.gestureCoordinator(self, didUpdateGesture: gesture, at: location, in: zone)
            
            // Complete gesture if it ended
            if gesture.phase == .ended || gesture.phase == .cancelled || gesture.phase == .failed {
                completeGesture(updatedGesture)
            }
        }
    }
    
    private func completeGesture(_ gesture: ActiveGesture) {
        activeGestures.removeValue(forKey: gesture.id)
        
        let completedGesture = CompletedGesture(
            gesture: gesture,
            endTime: Date().timeIntervalSince1970,
            wasSuccessful: gesture.data.phase == .ended
        )
        
        gestureHistory.append(completedGesture)
        
        // Limit history size
        if gestureHistory.count > 500 {
            gestureHistory = Array(gestureHistory.suffix(500))
        }
        
        logger.debug("🎯 GestureCoordinator: Completed \(gesture.data.gestureType.rawValue) gesture")
        delegate?.gestureCoordinator(self, didCompleteGesture: completedGesture.gesture.data, at: completedGesture.gesture.location, in: completedGesture.gesture.zone)
    }
    
    private func cancelActiveGesturesInZone(id: UUID) {
        let gesturesToCancel = activeGestures.values.filter { $0.zone?.id == id }
        
        for gesture in gesturesToCancel {
            activeGestures.removeValue(forKey: gesture.id)
            logger.debug("🎯 GestureCoordinator: Cancelled gesture \(gesture.data.gestureType.rawValue) in zone \(id)")
        }
    }
    
    private func cancelActiveGestures(ofType gestureType: GestureType) {
        let gesturesToCancel = activeGestures.values.filter { $0.data.gestureType == gestureType }
        
        for gesture in gesturesToCancel {
            activeGestures.removeValue(forKey: gesture.id)
            logger.debug("🎯 GestureCoordinator: Cancelled \(gestureType.rawValue) gesture")
        }
    }
    
    private func cancelSpecificGestures(_ gestureIds: [UUID]) {
        for id in gestureIds {
            if let gesture = activeGestures.removeValue(forKey: id) {
                logger.debug("🎯 GestureCoordinator: Cancelled conflicting gesture \(gesture.data.gestureType.rawValue)")
            }
        }
    }
    
    private func deferGesture(_ gesture: ActiveGesture) {
        // For now, just reject deferred gestures
        // Could implement a queue system for more sophisticated handling
        rejectGesture(gesture, reason: "Gesture deferred due to conflicts")
    }
    
    private func rejectGesture(_ gesture: ActiveGesture, reason: String) {
        logger.debug("🎯 GestureCoordinator: Rejected \(gesture.data.gestureType.rawValue) gesture: \(reason)")
        delegate?.gestureCoordinator(self, didRejectGesture: gesture.data, at: gesture.location, reason: reason)
    }
    
    private func cancelAllActiveGestures() {
        let count = activeGestures.count
        activeGestures.removeAll()
        
        if count > 0 {
            logger.debug("🎯 GestureCoordinator: Cancelled all \(count) active gestures")
        }
    }
    
    // MARK: - Statistics Helpers
    
    private func calculateAverageProcessingTime(from gestures: ArraySlice<CompletedGesture>) -> TimeInterval {
        guard !gestures.isEmpty else { return 0 }
        
        let totalTime = gestures.reduce(0.0) { sum, gesture in
            sum + (gesture.endTime - gesture.gesture.startTime)
        }
        
        return totalTime / Double(gestures.count)
    }
    
    private func calculateSuccessRate(from gestures: ArraySlice<CompletedGesture>) -> Double {
        guard !gestures.isEmpty else { return 0 }
        
        let successfulGestures = gestures.filter { $0.wasSuccessful }.count
        return Double(successfulGestures) / Double(gestures.count)
    }
    
    private func findMostUsedGesture(from gestures: ArraySlice<CompletedGesture>) -> GestureType? {
        let gestureCounts = gestures.reduce(into: [GestureType: Int]()) { counts, gesture in
            counts[gesture.gesture.data.gestureType, default: 0] += 1
        }
        
        return gestureCounts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Supporting Types

/// Active gesture being processed
public struct ActiveGesture {
    public let id: UUID
    public let data: GestureData
    public let location: CGPoint
    public let zone: InteractionZone?
    public let sensitivity: Double
    public let startTime: TimeInterval
}

/// Completed gesture for history tracking
public struct CompletedGesture {
    public let gesture: ActiveGesture
    public let endTime: TimeInterval
    public let wasSuccessful: Bool
}

/// Gesture processing statistics
public struct GestureStatistics {
    public let totalGesturesProcessed: Int
    public let activeGestureCount: Int
    public let averageGestureProcessingTime: TimeInterval
    public let gestureSuccessRate: Double
    public let mostUsedGesture: GestureType?
}

/// Gesture conflict resolution system
public class GestureConflictResolver {
    private var configuration: GestureConfiguration
    
    public init(configuration: GestureConfiguration) {
        self.configuration = configuration
    }
    
    public func updateConfiguration(_ configuration: GestureConfiguration) {
        self.configuration = configuration
    }
    
    public func resolveConflicts(newGesture: ActiveGesture, activeGestures: [ActiveGesture]) -> ConflictResolution {
        // If simultaneous recognition is disabled, check for conflicts
        if !configuration.simultaneousRecognition && !activeGestures.isEmpty {
            // Simple conflict resolution: cancel older gestures for newer ones
            let conflictingGestures = activeGestures.map { $0.id }
            return ConflictResolution(action: .cancel(conflictingGestures), reason: "Simultaneous recognition disabled")
        }
        
        // Check for specific gesture type conflicts
        let conflictingGestureIds = activeGestures.compactMap { activeGesture -> UUID? in
            if hasConflict(between: newGesture.data.gestureType, and: activeGesture.data.gestureType) {
                return activeGesture.id
            }
            return nil
        }
        
        if !conflictingGestureIds.isEmpty {
            return ConflictResolution(action: .cancel(conflictingGestureIds), reason: "Gesture type conflict")
        }
        
        return ConflictResolution(action: .allow, reason: "No conflicts")
    }
    
    private func hasConflict(between gesture1: GestureType, and gesture2: GestureType) -> Bool {
        // Define which gestures conflict with each other
        switch (gesture1, gesture2) {
        case (.tap, .doubleTap), (.doubleTap, .tap):
            return true
        case (.pan, .swipeLeft), (.pan, .swipeRight), (.pan, .swipeUp), (.pan, .swipeDown):
            return true
        case (.pinch, .magnify), (.magnify, .pinch):
            return true
        default:
            return false
        }
    }
}

/// Result of gesture conflict resolution
public struct ConflictResolution {
    public let action: ConflictAction
    public let reason: String
}

/// Actions that can be taken for conflicting gestures
public enum ConflictAction {
    case allow
    case cancel([UUID])
    case `defer`
    case reject
}

/// Delegate protocol for gesture coordination events
@MainActor
public protocol GestureCoordinatorDelegate: AnyObject {
    /// Called when a gesture is processed
    func gestureCoordinator(_ coordinator: GestureCoordinator, didProcessGesture gesture: GestureData, at location: CGPoint, in zone: InteractionZone?)
    
    /// Called when a gesture is updated
    func gestureCoordinator(_ coordinator: GestureCoordinator, didUpdateGesture gesture: GestureData, at location: CGPoint, in zone: InteractionZone?)
    
    /// Called when a gesture is completed
    func gestureCoordinator(_ coordinator: GestureCoordinator, didCompleteGesture gesture: GestureData, at location: CGPoint, in zone: InteractionZone?)
    
    /// Called when a gesture is rejected
    func gestureCoordinator(_ coordinator: GestureCoordinator, didRejectGesture gesture: GestureData, at location: CGPoint, reason: String)
    
    /// Called when a zone is added
    func gestureCoordinator(_ coordinator: GestureCoordinator, didAddZone zone: InteractionZone)
    
    /// Called when a zone is removed
    func gestureCoordinator(_ coordinator: GestureCoordinator, didRemoveZoneWithId id: UUID)
    
    /// Called when configuration is updated
    func gestureCoordinator(_ coordinator: GestureCoordinator, didUpdateConfiguration configuration: GestureConfiguration)
    
    /// Called when gesture detection starts
    func gestureCoordinatorDidStartGestureDetection(_ coordinator: GestureCoordinator)
    
    /// Called when gesture detection stops
    func gestureCoordinatorDidStopGestureDetection(_ coordinator: GestureCoordinator)
}

// MARK: - Default Implementations

extension GestureCoordinatorDelegate {
    public func gestureCoordinator(_ coordinator: GestureCoordinator, didUpdateGesture gesture: GestureData, at location: CGPoint, in zone: InteractionZone?) {}
    public func gestureCoordinator(_ coordinator: GestureCoordinator, didRejectGesture gesture: GestureData, at location: CGPoint, reason: String) {}
    public func gestureCoordinator(_ coordinator: GestureCoordinator, didAddZone zone: InteractionZone) {}
    public func gestureCoordinator(_ coordinator: GestureCoordinator, didRemoveZoneWithId id: UUID) {}
    public func gestureCoordinator(_ coordinator: GestureCoordinator, didUpdateConfiguration configuration: GestureConfiguration) {}
    public func gestureCoordinatorDidStartGestureDetection(_ coordinator: GestureCoordinator) {}
    public func gestureCoordinatorDidStopGestureDetection(_ coordinator: GestureCoordinator) {}
}