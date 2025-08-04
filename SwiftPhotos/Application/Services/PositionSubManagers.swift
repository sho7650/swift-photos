import Foundation
import SwiftUI
import CoreGraphics
import AppKit
import os.log

// MARK: - Position Strategy Coordinator

/// Coordinates and manages positioning strategies
/// Automatically selects optimal strategies based on context
@MainActor
public final class PositionStrategyCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var currentStrategy: PositioningStrategy
    @Published public var availableStrategies: [String: PositioningStrategy] = [:]
    
    private let displayCoordinator: MultiDisplayCoordinator
    private let performanceManager: PositionPerformanceManager  
    private let settingsManager: PositionSettingsManager
    private let logger = Logger(subsystem: "SwiftPhotos", category: "PositionStrategyCoordinator")
    
    // MARK: - Initialization
    
    public init(
        displayCoordinator: MultiDisplayCoordinator,
        performanceManager: PositionPerformanceManager,
        settingsManager: PositionSettingsManager
    ) {
        self.displayCoordinator = displayCoordinator
        self.performanceManager = performanceManager
        self.settingsManager = settingsManager
        
        // Initialize available strategies first
        let strategies = Self.createAvailableStrategies()
        self.availableStrategies = strategies
        
        // Select initial strategy using the local variable
        self.currentStrategy = Self.selectOptimalStrategy(
            for: displayCoordinator.screenConfiguration,
            settings: settingsManager.positionSettings,
            availableStrategies: strategies
        )
        
        logger.info("🎯 PositionStrategyCoordinator: Initialized with \(self.availableStrategies.count) strategies")
    }
    
    // MARK: - Public Methods
    
    /// Calculate optimal position using current strategy
    public func calculateOptimalPosition(
        for overlayType: OverlayType,
        preferredPosition: CGPoint? = nil,
        constraints: [UnifiedPositionConstraint] = [],
        avoiding obstacles: [CGRect] = []
    ) async -> CGPoint {
        
        let bounds = displayCoordinator.getEffectiveBounds()
        let positionConstraints = SimplePositionConstraints(
            bounds: bounds,
            margins: settingsManager.positionSettings.margins,
            constraints: constraints
        )
        
        // Try preferred position first
        if let preferred = preferredPosition,
           validatePositionWithAdapter(preferred, for: overlayType, constraints: positionConstraints) {
            return preferred
        }
        
        // Calculate using current strategy
        return currentStrategy.position(for: overlayType, in: bounds, avoiding: obstacles)
    }
    
    /// Update settings and potentially switch strategies
    public func updateSettings(_ newSettings: PositionSettings) async {
        settingsManager.updateSettings(newSettings)
        
        // Re-evaluate optimal strategy
        let newStrategy = Self.selectOptimalStrategy(
            for: displayCoordinator.screenConfiguration,
            settings: newSettings,
            availableStrategies: availableStrategies
        )
        
        if type(of: newStrategy) != type(of: currentStrategy) {
            currentStrategy = newStrategy
            logger.info("🎯 Strategy switched to \(type(of: newStrategy))")
        }
    }
    
    /// Manually set strategy
    public func setStrategy(_ strategyName: String) {
        guard let strategy = availableStrategies[strategyName] else {
            logger.warning("🎯 Strategy '\(strategyName)' not found")
            return
        }
        
        currentStrategy = strategy
        logger.info("🎯 Manually set strategy to \(strategyName)")
    }
    
    // MARK: - Private Methods
    
    /// Adapter function to bridge between SimplePositionConstraints and PositionConstraints
    private func validatePositionWithAdapter(
        _ position: CGPoint,
        for overlayType: OverlayType,
        constraints: SimplePositionConstraints
    ) -> Bool {
        // Convert SimplePositionConstraints to PositionConstraints
        let convertedConstraints = PositionConstraints(
            bounds: constraints.bounds,
            obstacles: [], // No obstacles in SimplePositionConstraints
            margins: EdgeInsets(
                top: constraints.margins.top,
                leading: constraints.margins.left,
                bottom: constraints.margins.bottom,
                trailing: constraints.margins.right
            ),
            minimumSpacing: 10.0 // Default spacing
        )
        
        return currentStrategy.validatePosition(position, for: overlayType, constraints: convertedConstraints)
    }
    
    private static func createAvailableStrategies() -> [String: PositioningStrategy] {
        return [
            "smart": SmartPositioningStrategy(),
            "adaptive": AdaptivePositioningStrategy(),
            "edge": EdgePositioningStrategy(edgeMappings: [
                .controls: .bottom,
                .information: .topRight,
                .progress: .bottomLeft,
                .menu: .topLeft
            ]),
            "grid": GridPositioningStrategy(gridSize: 3),
            "magnetic": MagneticPositioningStrategy(anchorPoints: [CGPoint(x: 0.5, y: 0.5)], magneticRadius: 50.0),
            "fixed": FixedPositioningStrategy(positions: [
                .controls: CGPoint(x: 0.5, y: 0.9),
                .information: CGPoint(x: 0.9, y: 0.1),
                .progress: CGPoint(x: 0.1, y: 0.9),
                .menu: CGPoint(x: 0.1, y: 0.1)
            ])
        ]
    }
    
    private static func selectOptimalStrategy(
        for screenConfig: ScreenConfiguration,
        settings: PositionSettings,
        availableStrategies: [String: PositioningStrategy]
    ) -> PositioningStrategy {
        
        // Multi-display: prefer adaptive or smart
        if screenConfig.screens.count > 1 {
            return availableStrategies["adaptive"] ?? availableStrategies["smart"]!
        }
        
        // Single display: use user preference or smart default
        if let preferredStrategy = settings.preferredStrategy,
           let strategy = availableStrategies[preferredStrategy] {
            return strategy
        }
        
        return availableStrategies["smart"]!
    }
}

// MARK: - Multi Display Coordinator

/// Manages multi-display positioning and coordination
@MainActor
public final class MultiDisplayCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var screenConfiguration: ScreenConfiguration
    @Published public var primaryScreen: ScreenInfo
    @Published public var secondaryScreens: [ScreenInfo] = []
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "MultiDisplayCoordinator")
    
    // MARK: - Initialization
    
    public init(screenConfiguration: ScreenConfiguration) {
        self.screenConfiguration = screenConfiguration
        self.primaryScreen = screenConfiguration.primaryScreen
        self.secondaryScreens = screenConfiguration.secondaryScreens
        
        logger.info("🖥️ MultiDisplayCoordinator: Initialized with \(screenConfiguration.screens.count) screens")
    }
    
    // MARK: - Public Methods
    
    /// Update screen configuration
    public func updateConfiguration(_ newConfiguration: ScreenConfiguration) {
        screenConfiguration = newConfiguration
        primaryScreen = newConfiguration.primaryScreen
        secondaryScreens = newConfiguration.secondaryScreens
        
        logger.info("🖥️ Screen configuration updated: \(newConfiguration.screens.count) screens")
    }
    
    /// Get effective bounds for positioning (considering all screens)
    public func getEffectiveBounds() -> CGRect {
        if screenConfiguration.screens.count == 1 {
            return primaryScreen.bounds
        }
        
        // Multi-display: return union of all screen bounds
        return screenConfiguration.screens.reduce(CGRect.zero) { result, screen in
            result.union(screen.bounds)
        }
    }
    
    /// Get optimal screen for overlay type
    public func getOptimalScreen(for overlayType: OverlayType) -> ScreenInfo {
        // Simple logic: controls on primary, others on secondary if available
        switch overlayType {
        case .controls, .progress:
            return primaryScreen
        case .information, .menu, .tooltip, .notification:
            return secondaryScreens.first ?? primaryScreen
        }
    }
    
    /// Check if point is within any screen
    public func isPointOnScreen(_ point: CGPoint) -> Bool {
        return screenConfiguration.screens.contains { screen in
            screen.bounds.contains(point)
        }
    }
    
    /// Get screen containing point
    public func getScreen(containing point: CGPoint) -> ScreenInfo? {
        return screenConfiguration.screens.first { screen in
            screen.bounds.contains(point)
        }
    }
}

// MARK: - Position Performance Manager

/// Manages performance optimization for positioning operations
@MainActor
public final class PositionPerformanceManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var currentMetrics: PositionPerformanceMetrics
    
    private let performanceSettings: PerformanceSettings
    private let logger = Logger(subsystem: "SwiftPhotos", category: "PositionPerformanceManager")
    
    // Performance tracking
    private var calculationTimes: [TimeInterval] = []
    private var totalCalculations: Int = 0
    private var conflictsResolved: Int = 0
    private var cacheHits: Int = 0
    private var cacheRequests: Int = 0
    
    // Position cache
    private var positionCache: [String: (position: CGPoint, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 1.0 // 1 second
    
    // MARK: - Initialization
    
    public init(performanceSettings: PerformanceSettings) {
        self.performanceSettings = performanceSettings
        self.currentMetrics = PositionPerformanceMetrics()
        
        logger.info("⚡ PositionPerformanceManager: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Record a position calculation
    public func recordCalculation(duration: TimeInterval) async {
        calculationTimes.append(duration)
        totalCalculations += 1
        
        // Keep only recent calculations for average
        if calculationTimes.count > 100 {
            calculationTimes.removeFirst()
        }
        
        await updateMetrics()
    }
    
    /// Record a conflict resolution
    public func recordConflictResolution() async {
        conflictsResolved += 1
        await updateMetrics()
    }
    
    /// Try to get cached position
    public func getCachedPosition(for key: String) -> CGPoint? {
        cacheRequests += 1
        
        guard let cached = positionCache[key] else {
            return nil
        }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) > cacheValidityDuration {
            positionCache.removeValue(forKey: key)
            return nil
        }
        
        cacheHits += 1
        return cached.position
    }
    
    /// Cache a position
    public func cachePosition(_ position: CGPoint, for key: String) {
        positionCache[key] = (position: position, timestamp: Date())
        
        // Clean old cache entries periodically
        if positionCache.count > 50 {
            cleanCache()
        }
    }
    
    /// Get current performance metrics
    public func getCurrentMetrics() async -> PositionPerformanceMetrics {
        await updateMetrics()
        return currentMetrics
    }
    
    /// Check if performance optimization is needed
    public func shouldOptimize() -> Bool {
        return currentMetrics.averageCalculationTime > 0.016 // More than 16ms (60fps)
    }
    
    // MARK: - Private Methods
    
    private func updateMetrics() async {
        let averageTime = calculationTimes.isEmpty ? 0 : calculationTimes.reduce(0, +) / Double(calculationTimes.count)
        let hitRate = cacheRequests == 0 ? 0 : Double(cacheHits) / Double(cacheRequests)
        
        currentMetrics = PositionPerformanceMetrics(
            averageCalculationTime: averageTime,
            totalCalculations: totalCalculations,
            conflictsResolved: conflictsResolved,
            cacheHitRate: hitRate
        )
    }
    
    private func cleanCache() {
        let now = Date()
        positionCache = positionCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) <= cacheValidityDuration
        }
    }
}

// MARK: - Position Settings Manager

/// Manages position-related settings integration
@MainActor
public final class PositionSettingsManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var positionSettings: PositionSettings
    
    private let settingsCoordinator: AppSettingsCoordinator
    private let logger = Logger(subsystem: "SwiftPhotos", category: "PositionSettingsManager")
    
    // MARK: - Initialization
    
    public init(settingsCoordinator: AppSettingsCoordinator) {
        self.settingsCoordinator = settingsCoordinator
        
        // Initialize with default settings (extend UIControlSettings or create new)
        self.positionSettings = PositionSettings(
            preferredStrategy: nil,
            margins: NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
            animationDuration: 0.3,
            conflictResolutionEnabled: true,
            cacheEnabled: true
        )
        
        logger.info("⚙️ PositionSettingsManager: Initialized")
        
        setupSettingsObserver()
    }
    
    // MARK: - Public Methods
    
    /// Update position settings
    public func updateSettings(_ newSettings: PositionSettings) {
        positionSettings = newSettings
        logger.debug("⚙️ Position settings updated")
    }
    
    /// Get positioning preferences from UI control settings
    public func getPositioningPreferences() -> PositionSettings {
        let uiSettings = settingsCoordinator.uiControl.settings
        
        return PositionSettings(
            preferredStrategy: getStrategyFromUISettings(uiSettings),
            margins: NSEdgeInsets(
                top: 20,
                left: 20,
                bottom: 20,
                right: 20
            ),
            animationDuration: 0.3,
            conflictResolutionEnabled: true,
            cacheEnabled: true
        )
    }
    
    // MARK: - Private Methods
    
    private func setupSettingsObserver() {
        // Observe UI control settings changes via NotificationCenter
        NotificationCenter.default.addObserver(
            forName: .uiControlSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateFromUISettings()
            }
        }
    }
    
    private func updateFromUISettings() {
        positionSettings = getPositioningPreferences()
        logger.debug("⚙️ Updated position settings from UI control settings")
    }
    
    private func getStrategyFromUISettings(_ uiSettings: UIControlSettings) -> String? {
        // Map UI control presets to positioning strategies
        switch uiSettings.preset {
        case .default:
            return "smart"
        case .minimal:
            return "edge"
        case .alwaysVisible:
            return "fixed"
        case .subtle:
            return "adaptive"
        case .none:
            return nil
        }
    }
}

// MARK: - Unified Position Coordinator

/// SwiftUI view coordination for unified positioning
@MainActor
public final class UnifiedPositionCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var activePositions: [UUID: CGPoint] = [:]
    @Published public var animatingOverlays: Set<UUID> = []
    
    private let strategyCoordinator: PositionStrategyCoordinator
    private let displayCoordinator: MultiDisplayCoordinator
    private let logger = Logger(subsystem: "SwiftPhotos", category: "UnifiedPositionCoordinator")
    
    // MARK: - Initialization
    
    public init(
        strategyCoordinator: PositionStrategyCoordinator,
        displayCoordinator: MultiDisplayCoordinator
    ) {
        self.strategyCoordinator = strategyCoordinator
        self.displayCoordinator = displayCoordinator
        
        logger.info("🔗 UnifiedPositionCoordinator: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Position an overlay with animation
    public func positionOverlay(
        id: UUID,
        type: OverlayType,
        animated: Bool = true
    ) async {
        if animated {
            animatingOverlays.insert(id)
        }
        
        let position = await strategyCoordinator.calculateOptimalPosition(for: type)
        
        if animated {
            // Animate to position
            withAnimation(.easeInOut(duration: 0.3)) {
                activePositions[id] = position
            }
            
            // Remove from animating set after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.animatingOverlays.remove(id)
            }
        } else {
            activePositions[id] = position
        }
        
        logger.debug("🔗 Positioned overlay \(type.rawValue) at (\(position.x), \(position.y))")
    }
    
    /// Remove overlay position
    public func removeOverlayPosition(id: UUID) {
        activePositions.removeValue(forKey: id)
        animatingOverlays.remove(id)
    }
    
    /// Get position for overlay
    public func getPosition(for id: UUID) -> CGPoint? {
        return activePositions[id]
    }
    
    /// Check if overlay is animating
    public func isAnimating(_ id: UUID) -> Bool {
        return animatingOverlays.contains(id)
    }
}

// MARK: - Supporting Types

/// Position settings configuration
public struct PositionSettings {
    public var preferredStrategy: String?
    public var margins: NSEdgeInsets
    public var animationDuration: TimeInterval
    public var conflictResolutionEnabled: Bool
    public var cacheEnabled: Bool
    
    public init(
        preferredStrategy: String? = nil,
        margins: NSEdgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
        animationDuration: TimeInterval = 0.3,
        conflictResolutionEnabled: Bool = true,
        cacheEnabled: Bool = true
    ) {
        self.preferredStrategy = preferredStrategy
        self.margins = margins
        self.animationDuration = animationDuration
        self.conflictResolutionEnabled = conflictResolutionEnabled
        self.cacheEnabled = cacheEnabled
    }
}

/// Simple position constraints for validation (distinct from InteractionProtocols version)
public struct SimplePositionConstraints {
    public let bounds: CGRect
    public let margins: NSEdgeInsets
    public let constraints: [UnifiedPositionConstraint]
    
    public init(bounds: CGRect, margins: NSEdgeInsets, constraints: [UnifiedPositionConstraint]) {
        self.bounds = bounds
        self.margins = margins
        self.constraints = constraints
    }
}

/// Screen configuration information
public struct ScreenConfiguration {
    public let screens: [ScreenInfo]
    public let primaryScreen: ScreenInfo
    public let secondaryScreens: [ScreenInfo]
    
    public init(screens: [ScreenInfo]) {
        self.screens = screens
        self.primaryScreen = screens.first { $0.isMain } ?? screens[0]
        self.secondaryScreens = screens.filter { !$0.isMain }
    }
    
    public static var current: ScreenConfiguration {
        let screens = NSScreen.screens.map { screen in
            ScreenInfo(
                bounds: screen.frame,
                visibleBounds: screen.visibleFrame,
                scaleFactor: screen.backingScaleFactor,
                isMain: screen == NSScreen.main
            )
        }
        return ScreenConfiguration(screens: screens)
    }
}

/// Individual screen information
public struct ScreenInfo {
    public let bounds: CGRect
    public let visibleBounds: CGRect
    public let scaleFactor: CGFloat
    public let isMain: Bool
    
    public init(bounds: CGRect, visibleBounds: CGRect, scaleFactor: CGFloat, isMain: Bool) {
        self.bounds = bounds
        self.visibleBounds = visibleBounds
        self.scaleFactor = scaleFactor
        self.isMain = isMain
    }
}