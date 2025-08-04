import Foundation
import SwiftUI
import Combine
import CoreGraphics
import os.log

/// Unified position and layout management system
/// Consolidates all positioning strategies, display management, and performance optimization
/// Part of Phase 7: Position & Layout Management統合
@MainActor
@Observable
public final class UnifiedPositionLayoutManager {
    
    // MARK: - Sub-Managers
    
    /// Strategy coordination and selection
    public let strategyCoordinator: PositionStrategyCoordinator
    
    /// Multi-display management
    public let displayCoordinator: MultiDisplayCoordinator
    
    /// Performance optimization for positioning
    public let performanceManager: PositionPerformanceManager
    
    /// Settings integration
    public let settingsManager: PositionSettingsManager
    
    /// View coordination for SwiftUI
    public let viewCoordinator: UnifiedPositionCoordinator
    
    // MARK: - Observable State
    
    /// Current active overlays with their positions
    public var activeOverlays: [UUID: UnifiedPositionedOverlay] = [:]
    
    /// Current screen configuration
    public var screenConfiguration: ScreenConfiguration
    
    /// Performance metrics
    public var performanceMetrics: PositionPerformanceMetrics
    
    /// Whether positioning is currently active
    public var isActive: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UnifiedPositionLayoutManager")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        settingsCoordinator: UnifiedAppSettingsCoordinator,
        performanceSettings: PerformanceSettings? = nil
    ) {
        // Initialize screen configuration first
        let currentScreenConfig = ScreenConfiguration.current
        self.screenConfiguration = currentScreenConfig
        
        // Initialize performance metrics
        self.performanceMetrics = PositionPerformanceMetrics()
        
        // Create sub-managers
        self.settingsManager = PositionSettingsManager(settingsCoordinator: settingsCoordinator)
        self.performanceManager = PositionPerformanceManager(
            performanceSettings: performanceSettings ?? settingsCoordinator.performance.settings
        )
        self.displayCoordinator = MultiDisplayCoordinator(
            screenConfiguration: currentScreenConfig
        )
        self.strategyCoordinator = PositionStrategyCoordinator(
            displayCoordinator: displayCoordinator,
            performanceManager: performanceManager,
            settingsManager: settingsManager
        )
        self.viewCoordinator = UnifiedPositionCoordinator(
            strategyCoordinator: strategyCoordinator,
            displayCoordinator: displayCoordinator
        )
        
        logger.info("🎯 UnifiedPositionLayoutManager: Initialized with \(self.screenConfiguration.screens.count) screens")
        
        setupObservers()
        setupPerformanceMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Calculate optimal position for an overlay
    public func calculatePosition(
        for overlayType: OverlayType,
        preferredPosition: CGPoint? = nil,
        constraints: [UnifiedPositionConstraint] = []
    ) async -> CGPoint {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let position = await strategyCoordinator.calculateOptimalPosition(
            for: overlayType,
            preferredPosition: preferredPosition,
            constraints: constraints,
            avoiding: Array(activeOverlays.values.map { $0.frame })
        )
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        await performanceManager.recordCalculation(duration: duration)
        
        logger.debug("🎯 Position calculated for \(overlayType.rawValue) in \(String(format: "%.3f", duration))s")
        
        return position
    }
    
    /// Register an overlay at a specific position
    public func registerOverlay(
        id: UUID,
        type: OverlayType,
        position: CGPoint,
        size: CGSize,
        priority: OverlayPriority = .normal
    ) {
        let overlay = UnifiedPositionedOverlay(
            id: id,
            type: type,
            position: position,
            size: size,
            priority: priority,
            timestamp: Date()
        )
        
        activeOverlays[id] = overlay
        
        // Trigger conflict resolution if needed
        Task {
            await resolveConflictsIfNeeded()
        }
        
        logger.debug("🎯 Registered overlay \(type.rawValue) at (\(position.x), \(position.y))")
    }
    
    /// Unregister an overlay
    public func unregisterOverlay(id: UUID) {
        if let overlay = activeOverlays.removeValue(forKey: id) {
            logger.debug("🎯 Unregistered overlay \(overlay.type.rawValue)")
        }
    }
    
    /// Update screen configuration (e.g., when displays change)
    public func updateScreenConfiguration(_ newConfiguration: ScreenConfiguration) {
        screenConfiguration = newConfiguration
        displayCoordinator.updateConfiguration(newConfiguration)
        
        // Recalculate all positions
        Task {
            await recalculateAllPositions()
        }
        
        logger.info("🎯 Screen configuration updated: \(newConfiguration.screens.count) screens")
    }
    
    /// Enable/disable positioning system
    public func setActive(_ active: Bool) {
        isActive = active
        
        if active {
            startPositioning()
        } else {
            stopPositioning()
        }
        
        logger.info("🎯 Positioning system \(active ? "activated" : "deactivated")")
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Monitor screen changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenConfigurationChange()
                }
            }
            .store(in: &cancellables)
        
        // Monitor settings changes
        settingsManager.$positionSettings
            .dropFirst()
            .sink { [weak self] newSettings in
                Task { @MainActor [weak self] in
                    await self?.handleSettingsChange(newSettings)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        // Update metrics every second
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updatePerformanceMetrics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleScreenConfigurationChange() {
        let newConfiguration = ScreenConfiguration.current
        updateScreenConfiguration(newConfiguration)
    }
    
    private func handleSettingsChange(_ newSettings: PositionSettings) async {
        await strategyCoordinator.updateSettings(newSettings)
        await recalculateAllPositions()
        
        logger.debug("🎯 Position settings updated, recalculated all positions")
    }
    
    private func resolveConflictsIfNeeded() async {
        let conflicts = await detectConflicts()
        
        if !conflicts.isEmpty {
            logger.info("🎯 Resolving \(conflicts.count) position conflicts")
            await resolveConflicts(conflicts)
        }
    }
    
    private func detectConflicts() async -> [PositionConflict] {
        var conflicts: [PositionConflict] = []
        let overlays = Array(activeOverlays.values)
        
        for i in 0..<overlays.count {
            for j in (i+1)..<overlays.count {
                let overlay1 = overlays[i]
                let overlay2 = overlays[j]
                
                if overlay1.frame.intersects(overlay2.frame) {
                    conflicts.append(PositionConflict(
                        overlay1: overlay1,
                        overlay2: overlay2,
                        severity: calculateConflictSeverity(overlay1.frame, overlay2.frame)
                    ))
                }
            }
        }
        
        return conflicts
    }
    
    private func resolveConflicts(_ conflicts: [PositionConflict]) async {
        // Sort conflicts by severity (highest first)
        let sortedConflicts = conflicts.sorted { $0.severity > $1.severity }
        
        for conflict in sortedConflicts {
            await resolveConflict(conflict)
        }
    }
    
    private func resolveConflict(_ conflict: PositionConflict) async {
        // Determine which overlay to move based on priority
        let overlayToMove = conflict.overlay1.priority.rawValue < conflict.overlay2.priority.rawValue 
            ? conflict.overlay1 
            : conflict.overlay2
        
        // Calculate new position
        let newPosition = await calculatePosition(
            for: overlayToMove.type,
            constraints: [UnifiedPositionConstraint.avoidOverlaps]
        )
        
        // Update overlay position
        var updatedOverlay = overlayToMove
        updatedOverlay.position = newPosition
        activeOverlays[updatedOverlay.id] = updatedOverlay
        
        logger.debug("🎯 Resolved conflict: moved \(overlayToMove.type.rawValue) to (\(newPosition.x), \(newPosition.y))")
    }
    
    private func calculateConflictSeverity(_ frame1: CGRect, _ frame2: CGRect) -> Double {
        let intersection = frame1.intersection(frame2)
        let unionArea = frame1.union(frame2).width * frame1.union(frame2).height
        return (intersection.width * intersection.height) / unionArea
    }
    
    private func recalculateAllPositions() async {
        logger.debug("🎯 Recalculating all overlay positions")
        
        let overlays = Array(activeOverlays.values)
        var updatedOverlays: [UUID: UnifiedPositionedOverlay] = [:]
        
        // Sort by priority to calculate higher priority overlays first
        let sortedOverlays = overlays.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        for overlay in sortedOverlays {
            let newPosition = await calculatePosition(
                for: overlay.type,
                preferredPosition: overlay.position,
                constraints: [UnifiedPositionConstraint.respectBounds, UnifiedPositionConstraint.avoidOverlaps]
            )
            
            var updatedOverlay = overlay
            updatedOverlay.position = newPosition
            updatedOverlays[overlay.id] = updatedOverlay
        }
        
        activeOverlays = updatedOverlays
        
        logger.info("🎯 Recalculated \(overlays.count) overlay positions")
    }
    
    private func updatePerformanceMetrics() async {
        performanceMetrics = await performanceManager.getCurrentMetrics()
    }
    
    private func startPositioning() {
        // Start background positioning tasks
        logger.debug("🎯 Starting positioning system")
    }
    
    private func stopPositioning() {
        // Stop background positioning tasks
        logger.debug("🎯 Stopping positioning system")
    }
    
    // MARK: - Performance Metrics
    
    public func getDetailedMetrics() -> [String: Any] {
        return [
            "activeOverlays": activeOverlays.count,
            "screenCount": self.screenConfiguration.screens.count,
            "performanceMetrics": performanceMetrics.toDictionary(),
            "strategiesAvailable": strategyCoordinator.availableStrategies.count,
            "currentStrategy": String(describing: type(of: strategyCoordinator.currentStrategy)),
            "isActive": isActive
        ]
    }
    
    deinit {
        logger.info("🎯 UnifiedPositionLayoutManager deinitialized")
    }
}

// MARK: - Supporting Types

/// Represents a positioned overlay in the system
public struct UnifiedPositionedOverlay {
    public let id: UUID
    public let type: OverlayType
    public var position: CGPoint
    public let size: CGSize
    public let priority: OverlayPriority
    public let timestamp: Date
    
    public var frame: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

/// Priority levels for overlay positioning
public enum OverlayPriority: Int, Comparable {
    case low = 1
    case normal = 5
    case high = 10
    case critical = 20
    
    public static func < (lhs: OverlayPriority, rhs: OverlayPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Represents a position conflict between two overlays
public struct PositionConflict {
    public let overlay1: UnifiedPositionedOverlay
    public let overlay2: UnifiedPositionedOverlay
    public let severity: Double // 0.0 to 1.0
}

/// Constraints for position calculation
public enum UnifiedPositionConstraint {
    case respectBounds
    case avoidOverlaps
    case maintainVisibility
    case preferredZone(CGRect)
    case minimumDistance(CGFloat)
}

/// Performance metrics for positioning operations
public struct PositionPerformanceMetrics {
    public var averageCalculationTime: TimeInterval = 0
    public var totalCalculations: Int = 0
    public var conflictsResolved: Int = 0
    public var cacheHitRate: Double = 0
    
    public func toDictionary() -> [String: Any] {
        return [
            "averageCalculationTime": averageCalculationTime,
            "totalCalculations": totalCalculations,
            "conflictsResolved": conflictsResolved,
            "cacheHitRate": cacheHitRate
        ]
    }
}