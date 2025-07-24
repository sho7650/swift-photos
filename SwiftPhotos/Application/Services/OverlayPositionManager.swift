import Foundation
import SwiftUI
import Combine
import os.log

/// Intelligent overlay positioning manager with collision detection and adaptive algorithms
/// Provides precise positioning for UI overlays with smart conflict resolution
@MainActor
public class OverlayPositionManager: ObservableObject, @preconcurrency PositionManaging {
    
    // MARK: - Public Properties
    
    @Published public var strategy: PositioningStrategy
    @Published public var configuration: PositionConfiguration
    @Published public var screenBounds: CGRect
    @Published public var constraints: [PositionConstraint] = []
    
    public weak var delegate: OverlayPositionManagerDelegate?
    
    // MARK: - Private Properties
    
    private var activeOverlays: [UUID: ActiveOverlay] = [:]
    private var positionObservers: [WeakPositionObserver] = []
    private let logger = Logger(subsystem: "SwiftPhotos", category: "OverlayPositionManager")
    
    // Performance optimization
    private var positionCalculationQueue = DispatchQueue(label: "position.calculation", qos: .userInteractive)
    private var lastCalculationTime: TimeInterval = 0
    private let calculationThrottle: TimeInterval = 0.033 // ~30fps
    
    // Screen monitoring
    private var screenObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    public init(
        strategy: PositioningStrategy = SmartPositioningStrategy(),
        configuration: PositionConfiguration = PositionConfiguration(),
        screenBounds: CGRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    ) {
        self.strategy = strategy
        self.configuration = configuration
        self.screenBounds = screenBounds
        
        logger.info("🎯 OverlayPositionManager: Initialized with bounds (\(screenBounds.width)x\(screenBounds.height))")
        
        setupScreenObserver()
        setupDefaultConstraints()
    }
    
    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        logger.debug("🎯 OverlayPositionManager: Deinitialized")
    }
    
    // MARK: - PositionManaging Implementation
    
    public func calculatePosition(for overlay: OverlayType, in bounds: CGRect) -> CGPoint {
        let now = Date().timeIntervalSince1970
        
        // Throttle calculation for performance
        guard now - lastCalculationTime >= calculationThrottle else {
            // Return cached position if available
            if let activeOverlay = activeOverlays.values.first(where: { $0.type == overlay }) {
                return activeOverlay.currentPosition
            }
            return getDefaultPosition(for: overlay, in: bounds)
        }
        lastCalculationTime = now
        
        // Get existing obstacles from other overlays
        let obstacles = getObstacles(excluding: overlay)
        
        // Calculate optimal position using strategy
        let position = strategy.position(for: overlay, in: bounds, avoiding: obstacles)
        
        logger.debug("🎯 OverlayPositionManager: Calculated position (\(position.x), \(position.y)) for \(overlay.rawValue)")
        
        // Update active overlay
        updateActiveOverlay(type: overlay, position: position, bounds: bounds)
        
        return position
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, in bounds: CGRect) -> ValidationResult {
        let overlaySize = overlay.defaultSize
        _ = CGRect(
            x: position.x - overlaySize.width / 2,
            y: position.y - overlaySize.height / 2,
            width: overlaySize.width,
            height: overlaySize.height
        )
        
        // Check bounds constraints
        let boundsConstraints = PositionConstraints(
            bounds: bounds,
            obstacles: getObstacles(excluding: overlay),
            margins: configuration.margins,
            minimumSpacing: configuration.minimumSpacing
        )
        
        if !strategy.validatePosition(position, for: overlay, constraints: boundsConstraints) {
            // Try to find adjusted position
            if let adjustedPosition = findAdjustedPosition(for: overlay, near: position, in: bounds) {
                return .adjusted(to: adjustedPosition, violations: ["Position adjusted to avoid conflicts"])
            } else {
                return .invalid(violations: ["No valid position found"])
            }
        }
        
        return .valid
    }
    
    public func animateToPosition(_ position: CGPoint, overlay: OverlayType, duration: TimeInterval, completion: @escaping () -> Void) {
        guard let activeOverlay = activeOverlays.values.first(where: { $0.type == overlay }) else {
            completion()
            return
        }
        
        let oldPosition = activeOverlay.currentPosition
        
        // Update position immediately for calculation purposes
        updateActiveOverlay(type: overlay, position: position, bounds: activeOverlay.bounds)
        
        // Notify observers of position change
        notifyPositionObservers(overlay: overlay, from: oldPosition, to: position)
        
        // Animate with SwiftUI
        withAnimation(.easeInOut(duration: duration)) {
            // The actual animation will be handled by SwiftUI views observing this manager
        }
        
        // Complete after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }
    
    nonisolated public func addPositionObserver(_ observer: PositionObserver) {
        Task { @MainActor in
            positionObservers.append(WeakPositionObserver(observer))
            cleanupObservers()
        }
    }
    
    nonisolated public func removePositionObserver(_ observer: PositionObserver) {
        Task { @MainActor in
            positionObservers.removeAll { $0.observer === observer }
        }
    }
    
    nonisolated public func screenConfigurationDidChange(_ newBounds: CGRect) {
        Task { @MainActor in
            let oldBounds = screenBounds
            screenBounds = newBounds
            
            logger.info("🎯 OverlayPositionManager: Screen bounds changed from (\(oldBounds.width)x\(oldBounds.height)) to (\(newBounds.width)x\(newBounds.height))")
            
            // Recalculate positions for all active overlays
            recalculateAllPositions()
            
            delegate?.overlayPositionManagerDidUpdateScreenBounds(self, from: oldBounds, to: newBounds)
        }
    }
    
    // MARK: - Public Management Methods
    
    /// Register an overlay for position management
    public func registerOverlay(_ overlay: OverlayType, initialPosition: CGPoint, in bounds: CGRect) {
        let activeOverlay = ActiveOverlay(
            id: UUID(),
            type: overlay,
            currentPosition: initialPosition,
            bounds: bounds,
            isVisible: true,
            lastUpdated: Date().timeIntervalSince1970
        )
        
        activeOverlays[activeOverlay.id] = activeOverlay
        
        logger.debug("🎯 OverlayPositionManager: Registered \(overlay.rawValue) overlay")
        delegate?.overlayPositionManager(self, didRegisterOverlay: overlay, at: initialPosition)
    }
    
    /// Unregister an overlay from position management
    public func unregisterOverlay(_ overlay: OverlayType) {
        if let overlayId = activeOverlays.first(where: { $0.value.type == overlay })?.key {
            activeOverlays.removeValue(forKey: overlayId)
            
            logger.debug("🎯 OverlayPositionManager: Unregistered \(overlay.rawValue) overlay")
            delegate?.overlayPositionManager(self, didUnregisterOverlay: overlay)
        }
    }
    
    /// Update overlay visibility
    public func setOverlayVisible(_ overlay: OverlayType, visible: Bool) {
        if let overlayId = activeOverlays.first(where: { $0.value.type == overlay })?.key,
           var activeOverlay = activeOverlays[overlayId] {
            activeOverlay.isVisible = visible
            activeOverlay.lastUpdated = Date().timeIntervalSince1970
            activeOverlays[overlayId] = activeOverlay
            
            // Recalculate positions when visibility changes
            if visible {
                let newPosition = calculatePosition(for: overlay, in: activeOverlay.bounds)
                animateToPosition(newPosition, overlay: overlay, duration: configuration.animationDuration) {}
            }
        }
    }
    
    /// Get current position for an overlay
    public func getCurrentPosition(for overlay: OverlayType) -> CGPoint? {
        return activeOverlays.values.first(where: { $0.type == overlay })?.currentPosition
    }
    
    /// Check if overlays are conflicting
    public func hasPositionConflicts() -> Bool {
        let visibleOverlays = activeOverlays.values.filter { $0.isVisible }
        
        for i in 0..<visibleOverlays.count {
            for j in (i+1)..<visibleOverlays.count {
                let overlay1 = visibleOverlays[i]
                let overlay2 = visibleOverlays[j]
                
                if overlaysConflict(overlay1, overlay2) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func setupScreenObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let newBounds = NSScreen.main?.frame {
                self?.screenConfigurationDidChange(newBounds)
            }
        }
    }
    
    private func setupDefaultConstraints() {
        // Add basic boundary constraints
        constraints.append(
            PositionConstraint(
                type: .stayWithinBounds,
                area: screenBounds,
                priority: 100,
                isEnabled: true
            )
        )
        
        // Add margin constraints
        let marginArea = CGRect(
            x: screenBounds.minX + configuration.margins.leading,
            y: screenBounds.minY + configuration.margins.bottom,
            width: screenBounds.width - configuration.margins.leading - configuration.margins.trailing,
            height: screenBounds.height - configuration.margins.top - configuration.margins.bottom
        )
        
        constraints.append(
            PositionConstraint(
                type: .preferArea,
                area: marginArea,
                priority: 50,
                isEnabled: true
            )
        )
    }
    
    private func updateActiveOverlay(type: OverlayType, position: CGPoint, bounds: CGRect) {
        if let overlayId = activeOverlays.first(where: { $0.value.type == type })?.key,
           var activeOverlay = activeOverlays[overlayId] {
            activeOverlay.currentPosition = position
            activeOverlay.bounds = bounds
            activeOverlay.lastUpdated = Date().timeIntervalSince1970
            activeOverlays[overlayId] = activeOverlay
        }
    }
    
    private func getObstacles(excluding overlay: OverlayType) -> [CGRect] {
        return activeOverlays.values
            .filter { $0.type != overlay && $0.isVisible }
            .map { activeOverlay in
                let size = activeOverlay.type.defaultSize
                return CGRect(
                    x: activeOverlay.currentPosition.x - size.width / 2,
                    y: activeOverlay.currentPosition.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            }
    }
    
    private func getDefaultPosition(for overlay: OverlayType, in bounds: CGRect) -> CGPoint {
        switch overlay {
        case .controls:
            return CGPoint(x: bounds.midX, y: bounds.maxY - 100)
        case .information:
            return CGPoint(x: bounds.midX, y: bounds.maxY - 200)
        case .progress:
            return CGPoint(x: bounds.midX, y: bounds.maxY - 50)
        case .menu:
            return CGPoint(x: bounds.maxX - 100, y: bounds.minY + 100)
        case .tooltip:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .notification:
            return CGPoint(x: bounds.maxX - 200, y: bounds.minY + 100)
        }
    }
    
    private func findAdjustedPosition(for overlay: OverlayType, near targetPosition: CGPoint, in bounds: CGRect) -> CGPoint? {
        let size = overlay.defaultSize
        let searchRadius: CGFloat = 50
        let stepSize: CGFloat = 10
        
        for radius in stride(from: stepSize, through: searchRadius, by: stepSize) {
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 8) {
                let x = targetPosition.x + radius * cos(angle)
                let y = targetPosition.y + radius * sin(angle)
                let candidatePosition = CGPoint(x: x, y: y)
                
                let candidateFrame = CGRect(
                    x: x - size.width / 2,
                    y: y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                
                if bounds.contains(candidateFrame) && !hasConflicts(candidateFrame, excluding: overlay) {
                    return candidatePosition
                }
            }
        }
        
        return nil
    }
    
    private func hasConflicts(_ frame: CGRect, excluding overlay: OverlayType) -> Bool {
        let obstacles = getObstacles(excluding: overlay)
        
        for obstacle in obstacles {
            if frame.intersects(obstacle) {
                return true
            }
        }
        
        return false
    }
    
    private func overlaysConflict(_ overlay1: ActiveOverlay, _ overlay2: ActiveOverlay) -> Bool {
        let frame1 = CGRect(
            x: overlay1.currentPosition.x - overlay1.type.defaultSize.width / 2,
            y: overlay1.currentPosition.y - overlay1.type.defaultSize.height / 2,
            width: overlay1.type.defaultSize.width,
            height: overlay1.type.defaultSize.height
        )
        
        let frame2 = CGRect(
            x: overlay2.currentPosition.x - overlay2.type.defaultSize.width / 2,
            y: overlay2.currentPosition.y - overlay2.type.defaultSize.height / 2,
            width: overlay2.type.defaultSize.width,
            height: overlay2.type.defaultSize.height
        )
        
        return frame1.intersects(frame2)
    }
    
    private func recalculateAllPositions() {
        let visibleOverlays = activeOverlays.values.filter { $0.isVisible }
        
        for activeOverlay in visibleOverlays {
            let newPosition = calculatePosition(for: activeOverlay.type, in: activeOverlay.bounds)
            animateToPosition(newPosition, overlay: activeOverlay.type, duration: configuration.animationDuration) {}
        }
    }
    
    private func notifyPositionObservers(overlay: OverlayType, from oldPosition: CGPoint, to newPosition: CGPoint) {
        cleanupObservers()
        
        for weakObserver in positionObservers {
            weakObserver.observer?.positionDidChange(overlay: overlay, from: oldPosition, to: newPosition)
        }
    }
    
    private func cleanupObservers() {
        positionObservers.removeAll { $0.observer == nil }
    }
}

// MARK: - Supporting Types

/// Active overlay being managed
private struct ActiveOverlay {
    let id: UUID
    let type: OverlayType
    var currentPosition: CGPoint
    var bounds: CGRect
    var isVisible: Bool
    var lastUpdated: TimeInterval
}

/// Weak reference wrapper for position observers
private class WeakPositionObserver {
    weak var observer: PositionObserver?
    
    init(_ observer: PositionObserver) {
        self.observer = observer
    }
}

/// Smart positioning strategy with collision avoidance
public class SmartPositioningStrategy: PositioningStrategy {
    
    public init() {}
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        let preferredZones = getPreferredZones(for: overlay, in: bounds)
        
        // Try each preferred zone
        for zone in preferredZones {
            if let position = findBestPositionInZone(zone, for: overlay, avoiding: obstacles) {
                return position
            }
        }
        
        // Fall back to center if no zones work
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        let size = overlay.defaultSize
        let overlayFrame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        // Check bounds
        if !constraints.bounds.contains(overlayFrame) {
            return false
        }
        
        // Check obstacles
        for obstacle in constraints.obstacles {
            if overlayFrame.intersects(obstacle) {
                return false
            }
        }
        
        return true
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        let margin: CGFloat = 20
        
        switch overlay {
        case .controls:
            return [
                // Bottom center (primary)
                CGRect(x: bounds.midX - 150, y: bounds.maxY - 120, width: 300, height: 80),
                // Bottom left
                CGRect(x: bounds.minX + margin, y: bounds.maxY - 120, width: 200, height: 80),
                // Bottom right
                CGRect(x: bounds.maxX - 220, y: bounds.maxY - 120, width: 200, height: 80)
            ]
            
        case .information:
            return [
                // Bottom center (below controls)
                CGRect(x: bounds.midX - 200, y: bounds.maxY - 250, width: 400, height: 150),
                // Top center
                CGRect(x: bounds.midX - 200, y: bounds.minY + margin, width: 400, height: 150),
                // Right side
                CGRect(x: bounds.maxX - 420, y: bounds.midY - 75, width: 400, height: 150)
            ]
            
        case .progress:
            return [
                // Top of screen
                CGRect(x: bounds.midX - 200, y: bounds.minY + margin, width: 400, height: 40),
                // Bottom (above controls)
                CGRect(x: bounds.midX - 200, y: bounds.maxY - 180, width: 400, height: 40)
            ]
            
        case .menu:
            return [
                // Top right
                CGRect(x: bounds.maxX - 170, y: bounds.minY + margin, width: 150, height: 200),
                // Top left
                CGRect(x: bounds.minX + margin, y: bounds.minY + margin, width: 150, height: 200)
            ]
            
        case .tooltip, .notification:
            return [
                // Top right
                CGRect(x: bounds.maxX - 320, y: bounds.minY + margin, width: 300, height: 100),
                // Top center
                CGRect(x: bounds.midX - 150, y: bounds.minY + margin, width: 300, height: 100),
                // Center right
                CGRect(x: bounds.maxX - 320, y: bounds.midY - 50, width: 300, height: 100)
            ]
        }
    }
    
    private func findBestPositionInZone(_ zone: CGRect, for overlay: OverlayType, avoiding obstacles: [CGRect]) -> CGPoint? {
        let size = overlay.defaultSize
        let stepSize: CGFloat = 20
        
        // Try positions within the zone
        for y in stride(from: zone.minY, through: zone.maxY - size.height, by: stepSize) {
            for x in stride(from: zone.minX, through: zone.maxX - size.width, by: stepSize) {
                let position = CGPoint(x: x + size.width / 2, y: y + size.height / 2)
                let frame = CGRect(
                    x: x,
                    y: y,
                    width: size.width,
                    height: size.height
                )
                
                // Check if this position conflicts with obstacles
                var hasConflict = false
                for obstacle in obstacles {
                    if frame.intersects(obstacle) {
                        hasConflict = true
                        break
                    }
                }
                
                if !hasConflict {
                    return position
                }
            }
        }
        
        return nil
    }
}

/// Delegate protocol for overlay position management events
@MainActor
public protocol OverlayPositionManagerDelegate: AnyObject {
    /// Called when an overlay is registered
    func overlayPositionManager(_ manager: OverlayPositionManager, didRegisterOverlay overlay: OverlayType, at position: CGPoint)
    
    /// Called when an overlay is unregistered
    func overlayPositionManager(_ manager: OverlayPositionManager, didUnregisterOverlay overlay: OverlayType)
    
    /// Called when screen bounds change
    func overlayPositionManagerDidUpdateScreenBounds(_ manager: OverlayPositionManager, from oldBounds: CGRect, to newBounds: CGRect)
    
    /// Called when position conflicts are detected
    func overlayPositionManagerDidDetectConflicts(_ manager: OverlayPositionManager, overlays: [OverlayType])
}

// MARK: - Default Implementations

extension OverlayPositionManagerDelegate {
    public func overlayPositionManager(_ manager: OverlayPositionManager, didRegisterOverlay overlay: OverlayType, at position: CGPoint) {}
    public func overlayPositionManager(_ manager: OverlayPositionManager, didUnregisterOverlay overlay: OverlayType) {}
    public func overlayPositionManagerDidUpdateScreenBounds(_ manager: OverlayPositionManager, from oldBounds: CGRect, to newBounds: CGRect) {}
    public func overlayPositionManagerDidDetectConflicts(_ manager: OverlayPositionManager, overlays: [OverlayType]) {}
}