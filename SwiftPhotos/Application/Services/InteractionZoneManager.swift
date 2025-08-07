import Foundation
import SwiftUI
import Combine
import os.log

/// Manager for invisible interaction zones with gesture detection
/// Provides zone-based interaction management without being a SwiftUI View
@MainActor
public class InteractionZoneManager: ObservableObject, InteractionZoneProviding {
    
    // MARK: - Public Properties
    
    @Published public var zones: [InteractionZone] = []
    @Published public var gestureConfiguration: GestureConfiguration
    @Published public var isEnabled: Bool = true
    
    public weak var delegate: InteractionZoneManagerDelegate?
    
    // MARK: - Private Properties
    
    private var activeGestures: Set<UUID> = []
    private var gestureStates: [UUID: ZoneGestureState] = [:]
    private let logger = Logger(subsystem: "SwiftPhotos", category: "InteractionZoneManager")
    
    // Performance optimization
    private var gestureDebounceTimer: Timer?
    private let gestureDebounceInterval: TimeInterval = 0.016 // ~60fps
    
    // MARK: - Initialization
    
    public init(
        zones: [InteractionZone] = [],
        gestureConfiguration: GestureConfiguration = GestureConfiguration()
    ) {
        self.zones = zones
        self.gestureConfiguration = gestureConfiguration
        
        logger.debug("🎯 InteractionZoneManager: Initialized with \(zones.count) zones")
    }
    
    deinit {
        logger.debug("🎯 InteractionZoneManager: Deinitialized")
    }
    
    // MARK: - Zone Management
    
    public func addZone(_ zone: InteractionZone) {
        zones.append(zone)
        zones.sort { $0.priority > $1.priority }
        
        logger.debug("🎯 InteractionZoneManager: Added zone '\(zone.name)' (total: \(self.zones.count))")
        delegate?.interactionZoneManager(self, didAddZone: zone)
    }
    
    public func removeZone(id: UUID) {
        let originalCount = zones.count
        zones.removeAll { $0.id == id }
        
        if zones.count < originalCount {
            logger.debug("🎯 InteractionZoneManager: Removed zone \(id) (remaining: \(self.zones.count))")
            delegate?.interactionZoneManager(self, didRemoveZoneWithId: id)
        }
        
        // Clean up any active gestures in this zone
        cleanupActiveGesturesInZone(id: id)
    }
    
    public func enableZone(id: UUID) {
        if let index = zones.firstIndex(where: { $0.id == id }) {
            zones[index] = InteractionZone(
                id: zones[index].id,
                frame: zones[index].frame,
                sensitivity: zones[index].sensitivity,
                name: zones[index].name,
                isEnabled: true,
                priority: zones[index].priority,
                allowedGestures: zones[index].allowedGestures
            )
            
            logger.debug("🎯 InteractionZoneManager: Enabled zone \(id)")
            delegate?.interactionZoneManager(self, didEnableZone: zones[index])
        }
    }
    
    public func disableZone(id: UUID) {
        if let index = zones.firstIndex(where: { $0.id == id }) {
            zones[index] = InteractionZone(
                id: zones[index].id,
                frame: zones[index].frame,
                sensitivity: zones[index].sensitivity,
                name: zones[index].name,
                isEnabled: false,
                priority: zones[index].priority,
                allowedGestures: zones[index].allowedGestures
            )
            
            logger.debug("🎯 InteractionZoneManager: Disabled zone \(id)")
            delegate?.interactionZoneManager(self, didDisableZone: zones[index])
        }
        
        // Clean up any active gestures in this zone
        cleanupActiveGesturesInZone(id: id)
    }
    
    public func updateZone(_ zone: InteractionZone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index] = zone
            zones.sort { $0.priority > $1.priority }
            
            logger.debug("🎯 InteractionZoneManager: Updated zone '\(zone.name)'")
            delegate?.interactionZoneManager(self, didUpdateZone: zone)
        }
    }
    
    public func clearAllZones() {
        let count = zones.count
        zones.removeAll()
        cleanupActiveGestures()
        
        logger.debug("🎯 InteractionZoneManager: Cleared all \(count) zones")
        delegate?.interactionZoneManagerDidClearAllZones(self)
    }
    
    // MARK: - Gesture Processing
    
    /// Process a gesture at a specific location
    public func processGesture(_ gestureData: GestureData, at location: CGPoint) {
        guard isEnabled && gestureConfiguration.enabledGestures.contains(gestureData.gestureType) else {
            return
        }
        
        debounceGestureUpdate {
            Task { @MainActor in
                self.performGestureProcessing(gestureData, at: location)
            }
        }
    }
    
    /// Check if a point is within any interaction zone
    public func findZone(containing point: CGPoint) -> InteractionZone? {
        return zones.first { zone in
            zone.isEnabled && zone.contains(point)
        }
    }
    
    /// Get all zones containing a point, sorted by priority
    public func getZonesContaining(_ point: CGPoint) -> [InteractionZone] {
        return zones.filter { zone in
            zone.isEnabled && zone.contains(point)
        }.sorted { $0.priority > $1.priority }
    }
    
    /// Check if a specific gesture type is allowed at a location
    public func isGestureAllowed(_ gestureType: GestureType, at location: CGPoint) -> Bool {
        guard isEnabled && gestureConfiguration.enabledGestures.contains(gestureType) else {
            return false
        }
        
        if let zone = findZone(containing: location) {
            return zone.allowedGestures.contains(gestureType)
        }
        
        // Allow gesture if no specific zone restrictions
        return true
    }
    
    // MARK: - Zone Factory Methods
    
    /// Create common interaction zones for the application
    public func setupCommonZones(in bounds: CGRect) {
        // Controls zone at bottom center
        let controlsFrame = CGRect(
            x: bounds.midX - 100,
            y: bounds.maxY - 80,
            width: 200,
            height: 60
        )
        addZone(.controlsZone(frame: controlsFrame))
        
        // Navigation zones on left and right edges
        let leftNavFrame = CGRect(x: 0, y: 0, width: 50, height: bounds.height)
        let rightNavFrame = CGRect(x: bounds.maxX - 50, y: 0, width: 50, height: bounds.height)
        
        addZone(.navigationZone(frame: leftNavFrame, allowSwipe: true))
        addZone(.navigationZone(frame: rightNavFrame, allowSwipe: true))
        
        // Center zoom zone
        let zoomFrame = CGRect(
            x: bounds.midX - 150,
            y: bounds.midY - 150,
            width: 300,
            height: 300
        )
        addZone(.zoomZone(frame: zoomFrame))
    }
    
    // MARK: - Private Methods
    
    private func performGestureProcessing(_ gestureData: GestureData, at location: CGPoint) {
        let zone = findZone(containing: location)
        
        // Check if gesture is allowed in this zone
        if let zone = zone {
            guard zone.allowedGestures.contains(gestureData.gestureType) else {
                logger.debug("🎯 InteractionZoneManager: Gesture \(gestureData.gestureType.rawValue) not allowed in zone '\(zone.name)'")
                return
            }
        }
        
        logger.debug("🎯 InteractionZoneManager: Processing \(gestureData.gestureType.rawValue) gesture at (\(location.x), \(location.y))")
        
        // Notify delegate
        delegate?.interactionZoneManager(self, didDetectGesture: gestureData, in: zone, at: location, sensitivity: zone?.sensitivity ?? 1.0)
        
        // Track gesture state if needed
        if gestureData.phase == .began {
            startTrackingGesture(gestureData, at: location, in: zone)
        } else if gestureData.phase == .ended || gestureData.phase == .cancelled || gestureData.phase == .failed {
            endTrackingGesture(gestureData)
        }
    }
    
    private func startTrackingGesture(_ gestureData: GestureData, at location: CGPoint, in zone: InteractionZone?) {
        let gestureId = UUID()
        let gestureState = ZoneGestureState(
            id: gestureId,
            type: gestureData.gestureType,
            zoneId: zone?.id,
            startLocation: location
        )
        
        activeGestures.insert(gestureId)
        gestureStates[gestureId] = gestureState
        
        logger.debug("🎯 InteractionZoneManager: Started tracking \(gestureData.gestureType.rawValue) gesture")
    }
    
    private func endTrackingGesture(_ gestureData: GestureData) {
        // Find and remove the gesture state
        if let gestureId = gestureStates.first(where: { $0.value.type == gestureData.gestureType })?.key {
            activeGestures.remove(gestureId)
            gestureStates.removeValue(forKey: gestureId)
            
            logger.debug("🎯 InteractionZoneManager: Ended tracking \(gestureData.gestureType.rawValue) gesture")
        }
    }
    
    private func debounceGestureUpdate(_ action: @escaping @Sendable () -> Void) {
        gestureDebounceTimer?.invalidate()
        gestureDebounceTimer = Timer.scheduledTimer(withTimeInterval: gestureDebounceInterval, repeats: false) { _ in
            Task { @MainActor in
                action()
            }
        }
    }
    
    private func cleanupActiveGestures() {
        activeGestures.removeAll()
        gestureStates.removeAll()
        gestureDebounceTimer?.invalidate()
        gestureDebounceTimer = nil
    }
    
    private func cleanupActiveGesturesInZone(id: UUID) {
        let gesturesToRemove = gestureStates.filter { $0.value.zoneId == id }.map { $0.key }
        
        for gestureId in gesturesToRemove {
            activeGestures.remove(gestureId)
            gestureStates.removeValue(forKey: gestureId)
        }
    }
}

// MARK: - Supporting Types

/// State tracking for individual gestures in zones
private struct ZoneGestureState {
    let id: UUID
    let type: GestureType
    let zoneId: UUID?
    let startTime: TimeInterval
    let startLocation: CGPoint
    var lastUpdate: TimeInterval
    var isActive: Bool
    
    init(id: UUID = UUID(), type: GestureType, zoneId: UUID? = nil, startLocation: CGPoint) {
        self.id = id
        self.type = type
        self.zoneId = zoneId
        self.startTime = Date().timeIntervalSince1970
        self.startLocation = startLocation
        self.lastUpdate = self.startTime
        self.isActive = true
    }
}

/// Delegate protocol for interaction zone management
@MainActor
public protocol InteractionZoneManagerDelegate: AnyObject {
    /// Called when a gesture is detected in a zone
    func interactionZoneManager(_ manager: InteractionZoneManager, didDetectGesture gesture: GestureData, in zone: InteractionZone?, at location: CGPoint, sensitivity: Double)
    
    /// Called when a zone is added
    func interactionZoneManager(_ manager: InteractionZoneManager, didAddZone zone: InteractionZone)
    
    /// Called when a zone is removed
    func interactionZoneManager(_ manager: InteractionZoneManager, didRemoveZoneWithId id: UUID)
    
    /// Called when a zone is enabled
    func interactionZoneManager(_ manager: InteractionZoneManager, didEnableZone zone: InteractionZone)
    
    /// Called when a zone is disabled
    func interactionZoneManager(_ manager: InteractionZoneManager, didDisableZone zone: InteractionZone)
    
    /// Called when a zone is updated
    func interactionZoneManager(_ manager: InteractionZoneManager, didUpdateZone zone: InteractionZone)
    
    /// Called when all zones are cleared
    func interactionZoneManagerDidClearAllZones(_ manager: InteractionZoneManager)
}

// MARK: - Default Implementations

extension InteractionZoneManagerDelegate {
    public func interactionZoneManager(_ manager: InteractionZoneManager, didAddZone zone: InteractionZone) {}
    public func interactionZoneManager(_ manager: InteractionZoneManager, didRemoveZoneWithId id: UUID) {}
    public func interactionZoneManager(_ manager: InteractionZoneManager, didEnableZone zone: InteractionZone) {}
    public func interactionZoneManager(_ manager: InteractionZoneManager, didDisableZone zone: InteractionZone) {}
    public func interactionZoneManager(_ manager: InteractionZoneManager, didUpdateZone zone: InteractionZone) {}
    public func interactionZoneManagerDidClearAllZones(_ manager: InteractionZoneManager) {}
}