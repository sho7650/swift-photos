import Foundation
import SwiftUI
import Combine
import os.log

/// Migration bridge for transitioning from individual position managers to unified system
/// Provides backward compatibility while enabling gradual migration
/// Part of Phase 7: Position & Layout Management統合
@MainActor
public final class PositionMigrationBridge: ObservableObject {
    
    // MARK: - Properties
    
    /// The new unified position manager
    public let unifiedManager: UnifiedPositionLayoutManager
    
    /// Legacy overlay position manager (for compatibility)
    public let legacyManager: OverlayPositionManager?
    
    /// Whether to use unified system (migration flag)
    @Published public var useUnifiedSystem: Bool
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "PositionMigrationBridge")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        settingsCoordinator: UnifiedAppSettingsCoordinator,
        legacyManager: OverlayPositionManager? = nil,
        enableUnifiedSystem: Bool = true
    ) {
        self.unifiedManager = UnifiedPositionLayoutManager(
            settingsCoordinator: settingsCoordinator
        )
        self.legacyManager = legacyManager
        self.useUnifiedSystem = enableUnifiedSystem
        
        logger.info("🔄 PositionMigrationBridge: Initialized (unified: \(enableUnifiedSystem))")
        
        setupMigrationObservers()
    }
    
    // MARK: - Public Interface (Unified API)
    
    /// Calculate position using appropriate system
    public func calculatePosition(
        for overlayType: OverlayType,
        preferredPosition: CGPoint? = nil,
        constraints: [UnifiedPositionConstraint] = []
    ) async -> CGPoint {
        
        if useUnifiedSystem {
            return await unifiedManager.calculatePosition(
                for: overlayType,
                preferredPosition: preferredPosition,
                constraints: constraints
            )
        } else {
            // Fallback to legacy system
            return await calculateLegacyPosition(
                for: overlayType,
                preferredPosition: preferredPosition
            )
        }
    }
    
    /// Register overlay using appropriate system
    public func registerOverlay(
        id: UUID,
        type: OverlayType,
        position: CGPoint,
        size: CGSize,
        priority: OverlayPriority = .normal
    ) {
        if useUnifiedSystem {
            unifiedManager.registerOverlay(
                id: id,
                type: type,
                position: position,
                size: size,
                priority: priority
            )
        } else {
            // Legacy registration if needed
            registerLegacyOverlay(id: id, type: type, position: position, size: size)
        }
        
        logger.debug("🔄 Registered overlay \(type.rawValue) using \(self.useUnifiedSystem ? "unified" : "legacy") system")
    }
    
    /// Unregister overlay using appropriate system  
    public func unregisterOverlay(id: UUID) {
        if useUnifiedSystem {
            unifiedManager.unregisterOverlay(id: id)
        } else {
            // Legacy unregistration if needed
            unregisterLegacyOverlay(id: id)
        }
    }
    
    /// Enable/disable positioning system
    public func setActive(_ active: Bool) {
        if useUnifiedSystem {
            unifiedManager.setActive(active)
        } else {
            // Legacy activation if needed
            setLegacyActive(active)
        }
        
        logger.info("🔄 Positioning system \(active ? "activated" : "deactivated") using \(self.useUnifiedSystem ? "unified" : "legacy") system")
    }
    
    /// Switch between unified and legacy systems
    public func switchToUnifiedSystem(_ enable: Bool) {
        let wasUsing = useUnifiedSystem
        useUnifiedSystem = enable
        
        if wasUsing != enable {
            logger.info("🔄 Switched to \(enable ? "unified" : "legacy") positioning system")
            
            if enable {
                migrateFromLegacyToUnified()
            } else {
                migrateFromUnifiedToLegacy()
            }
        }
    }
    
    /// Get performance metrics from appropriate system
    public func getPerformanceMetrics() -> [String: Any] {
        if useUnifiedSystem {
            return unifiedManager.getDetailedMetrics()
        } else {
            return getLegacyMetrics()
        }
    }
    
    // MARK: - Legacy System Interface
    
    private func calculateLegacyPosition(
        for overlayType: OverlayType,
        preferredPosition: CGPoint? = nil
    ) async -> CGPoint {
        
        guard let legacyManager = legacyManager else {
            logger.warning("🔄 No legacy manager available, using fallback position")
            return preferredPosition ?? CGPoint(x: 100, y: 100)
        }
        
        // Use legacy manager's strategy
        let bounds = legacyManager.screenBounds
        let obstacles: [CGRect] = [] // Legacy obstacles would need public API
        
        return legacyManager.strategy.position(
            for: overlayType,
            in: bounds,
            avoiding: obstacles
        )
    }
    
    private func registerLegacyOverlay(
        id: UUID,
        type: OverlayType,
        position: CGPoint,
        size: CGSize
    ) {
        // Legacy registration logic if needed
        logger.debug("🔄 Legacy overlay registration for \(type.rawValue)")
    }
    
    private func unregisterLegacyOverlay(id: UUID) {
        // Legacy unregistration logic if needed
        logger.debug("🔄 Legacy overlay unregistration")
    }
    
    private func setLegacyActive(_ active: Bool) {
        // Legacy activation logic if needed
        logger.debug("🔄 Legacy system \(active ? "activated" : "deactivated")")
    }
    
    private func getLegacyMetrics() -> [String: Any] {
        return [
            "system": "legacy",
            "overlaysCount": 0, // Legacy overlay count would need public API
            "strategy": String(describing: type(of: legacyManager?.strategy)),
            "screenBounds": legacyManager?.screenBounds.debugDescription ?? "unknown"
        ]
    }
    
    // MARK: - Migration Methods
    
    private func setupMigrationObservers() {
        // Monitor system performance to decide on migration
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateMigrationStatus()
            }
            .store(in: &cancellables)
    }
    
    private func evaluateMigrationStatus() {
        // Evaluate whether to suggest switching systems based on performance
        let metrics = getPerformanceMetrics()
        
        if let avgTime = metrics["averageCalculationTime"] as? TimeInterval,
           avgTime > 0.020 { // More than 20ms
            logger.info("🔄 Performance issue detected, consider optimizing positioning system")
        }
    }
    
    private func migrateFromLegacyToUnified() {
        guard let legacyManager = legacyManager else { return }
        
        logger.info("🔄 Migrating from legacy to unified positioning system")
        
        // Migrate active overlays
        // Legacy overlay migration would need public API access
        // TODO: Implement when OverlayPositionManager exposes public API
        /*
        for (id, overlay) in legacyManager.getActiveOverlays() {
            let overlayType = determineOverlayType(from: overlay)
            unifiedManager.registerOverlay(
                id: id,
                type: overlayType,
                position: overlay.position,
                size: overlay.size,
                priority: .normal
            )
        }
        */
        
        // Copy configuration if possible
        unifiedManager.updateScreenConfiguration(ScreenConfiguration.current)
        
        logger.info("🔄 Migration to unified system completed")
    }
    
    private func migrateFromUnifiedToLegacy() {
        logger.info("🔄 Migrating from unified to legacy positioning system")
        
        // Clear unified system state
        for overlayId in unifiedManager.activeOverlays.keys {
            unifiedManager.unregisterOverlay(id: overlayId)
        }
        
        logger.info("🔄 Migration to legacy system completed")
    }
    
    private func determineOverlayType(from overlay: LegacyActiveOverlay) -> OverlayType {
        // Try to determine overlay type from overlay properties
        // This is a simplified mapping - in real implementation,
        // you might store the type information in ActiveOverlay
        
        let size = overlay.size
        
        if size.width > 250 && size.height > 150 {
            return .information
        } else if size.height < 20 {
            return .progress
        } else if size.width < 150 {
            return .tooltip
        } else {
            return .controls
        }
    }
    
    // MARK: - Factory Methods
    
    /// Create bridge with automatic legacy manager detection
    public static func createWithAutoDetection(
        settingsCoordinator: UnifiedAppSettingsCoordinator,
        enableUnifiedByDefault: Bool = true
    ) -> PositionMigrationBridge {
        
        // Try to find existing overlay position manager instance
        let legacyManager: OverlayPositionManager? = nil // Would be injected in real implementation
        
        return PositionMigrationBridge(
            settingsCoordinator: settingsCoordinator,
            legacyManager: legacyManager,
            enableUnifiedSystem: enableUnifiedByDefault
        )
    }
    
    /// Create bridge for testing with specific managers
    public static func createForTesting(
        settingsCoordinator: UnifiedAppSettingsCoordinator,
        legacyManager: OverlayPositionManager?,
        useUnified: Bool
    ) -> PositionMigrationBridge {
        
        return PositionMigrationBridge(
            settingsCoordinator: settingsCoordinator,
            legacyManager: legacyManager,
            enableUnifiedSystem: useUnified
        )
    }
    
    deinit {
        logger.info("🔄 PositionMigrationBridge deinitialized")
    }
}

// MARK: - SwiftUI Integration Helper

/// SwiftUI view modifier for unified positioning
public struct UnifiedPositionModifier: ViewModifier {
    
    let bridge: PositionMigrationBridge
    let overlayType: OverlayType
    let overlayId: UUID
    
    @State private var position: CGPoint = .zero
    @State private var isRegistered = false
    
    public func body(content: Content) -> some View {
        content
            .position(position)
            .onAppear {
                registerAndPosition()
            }
            .onDisappear {
                unregister()
            }
            .onChange(of: bridge.useUnifiedSystem) { _, _ in
                // Re-register when system changes
                Task {
                    await repositionOverlay()
                }
            }
    }
    
    private func registerAndPosition() {
        Task {
            let calculatedPosition = await bridge.calculatePosition(for: overlayType)
            
            position = calculatedPosition
            
            bridge.registerOverlay(
                id: overlayId,
                type: overlayType,
                position: calculatedPosition,
                size: overlayType.defaultSize
            )
            
            isRegistered = true
        }
    }
    
    private func unregister() {
        if isRegistered {
            bridge.unregisterOverlay(id: overlayId)
            isRegistered = false
        }
    }
    
    private func repositionOverlay() async {
        let newPosition = await bridge.calculatePosition(for: overlayType)
        position = newPosition
        
        if isRegistered {
            bridge.registerOverlay(
                id: overlayId,
                type: overlayType,
                position: newPosition,
                size: overlayType.defaultSize
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply unified positioning to a view
    public func unifiedPosition(
        _ overlayType: OverlayType,
        bridge: PositionMigrationBridge,
        id: UUID = UUID()
    ) -> some View {
        self.modifier(UnifiedPositionModifier(
            bridge: bridge,
            overlayType: overlayType,
            overlayId: id
        ))
    }
}

// MARK: - Compatibility Types

/// Compatibility type for legacy ActiveOverlay
public struct LegacyActiveOverlay {
    public let id: UUID
    public let position: CGPoint
    public let size: CGSize
    public let timestamp: Date
    
    public var frame: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
    
    public init(id: UUID, position: CGPoint, size: CGSize, timestamp: Date = Date()) {
        self.id = id
        self.position = position
        self.size = size
        self.timestamp = timestamp
    }
}