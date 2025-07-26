import SwiftUI
import Combine

/// SwiftUI coordinator for integrating OverlayPositionManager with SwiftUI views
/// Provides reactive positioning and automatic layout management
@MainActor
public class OverlayPositionCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var positions: [OverlayType: CGPoint] = [:]
    @Published public private(set) var isAnimating: Bool = false
    @Published public var bounds: CGRect = .zero {
        didSet {
            if bounds != oldValue {
                positionManager.screenConfigurationDidChange(bounds)
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let positionManager: OverlayPositionManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        strategy: PositioningStrategy = SmartPositioningStrategy(),
        configuration: PositionConfiguration = PositionConfiguration()
    ) {
        self.positionManager = OverlayPositionManager(
            strategy: strategy,
            configuration: configuration
        )
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Register an overlay for position management
    public func registerOverlay(_ overlay: OverlayType, initialPosition: CGPoint? = nil) {
        let position = initialPosition ?? getDefaultPosition(for: overlay)
        positionManager.registerOverlay(overlay, initialPosition: position, in: bounds)
        updatePosition(for: overlay)
    }
    
    /// Unregister an overlay
    public func unregisterOverlay(_ overlay: OverlayType) {
        positionManager.unregisterOverlay(overlay)
        positions.removeValue(forKey: overlay)
    }
    
    /// Set overlay visibility and recalculate position if needed
    public func setOverlayVisible(_ overlay: OverlayType, visible: Bool) {
        positionManager.setOverlayVisible(overlay, visible: visible)
        if visible {
            updatePosition(for: overlay, animated: true)
        }
    }
    
    /// Force recalculation of position for an overlay
    public func updatePosition(for overlay: OverlayType, animated: Bool = false) {
        let newPosition = positionManager.calculatePosition(for: overlay, in: bounds)
        
        if animated {
            withAnimation(.easeInOut(duration: positionManager.configuration.animationDuration)) {
                positions[overlay] = newPosition
            }
        } else {
            positions[overlay] = newPosition
        }
    }
    
    /// Update all overlay positions
    public func updateAllPositions(animated: Bool = false) {
        let registeredOverlays = positions.keys
        
        if animated {
            isAnimating = true
            withAnimation(.easeInOut(duration: positionManager.configuration.animationDuration)) {
                for overlay in registeredOverlays {
                    updatePosition(for: overlay, animated: false) // Animation already started
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + positionManager.configuration.animationDuration) {
                self.isAnimating = false
            }
        } else {
            for overlay in registeredOverlays {
                updatePosition(for: overlay)
            }
        }
    }
    
    /// Get current position for an overlay
    public func position(for overlay: OverlayType) -> CGPoint {
        return positions[overlay] ?? getDefaultPosition(for: overlay)
    }
    
    /// Update positioning strategy
    public func updateStrategy(_ strategy: PositioningStrategy) {
        positionManager.strategy = strategy
        updateAllPositions(animated: true)
    }
    
    /// Update configuration
    public func updateConfiguration(_ configuration: PositionConfiguration) {
        positionManager.configuration = configuration
    }
    
    /// Check if there are any position conflicts
    public var hasConflicts: Bool {
        return positionManager.hasPositionConflicts()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe screen bounds changes
        positionManager.$screenBounds
            .sink { [weak self] newBounds in
                self?.bounds = newBounds
            }
            .store(in: &cancellables)
    }
    
    private func getDefaultPosition(for overlay: OverlayType) -> CGPoint {
        switch overlay {
        case .controls:
            return CGPoint(x: bounds.midX, y: bounds.maxY - 100)
        case .information:
            return CGPoint(x: bounds.midX, y: bounds.maxY - 200)
        case .progress:
            return CGPoint(x: bounds.midX, y: bounds.minY + 50)
        case .menu:
            return CGPoint(x: bounds.maxX - 100, y: bounds.minY + 100)
        case .tooltip:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .notification:
            return CGPoint(x: bounds.maxX - 200, y: bounds.minY + 100)
        }
    }
}

// MARK: - SwiftUI View Modifier

/// View modifier for positioning overlays using the OverlayPositionCoordinator
public struct PositionedOverlay: ViewModifier {
    let overlayType: OverlayType
    @ObservedObject var coordinator: OverlayPositionCoordinator
    let autoRegister: Bool
    let onPositionChange: ((CGPoint) -> Void)?
    
    public init(
        overlayType: OverlayType,
        coordinator: OverlayPositionCoordinator,
        autoRegister: Bool = true,
        onPositionChange: ((CGPoint) -> Void)? = nil
    ) {
        self.overlayType = overlayType
        self.coordinator = coordinator
        self.autoRegister = autoRegister
        self.onPositionChange = onPositionChange
    }
    
    public func body(content: Content) -> some View {
        content
            .position(coordinator.position(for: overlayType))
            .onAppear {
                if autoRegister {
                    coordinator.registerOverlay(overlayType)
                }
            }
            .onDisappear {
                if autoRegister {
                    coordinator.unregisterOverlay(overlayType)
                }
            }
            .onChange(of: coordinator.position(for: overlayType)) { _, newPosition in
                onPositionChange?(newPosition)
            }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    /// Apply positioned overlay management to this view
    func positionedOverlay(
        _ overlayType: OverlayType,
        coordinator: OverlayPositionCoordinator,
        autoRegister: Bool = true,
        onPositionChange: ((CGPoint) -> Void)? = nil
    ) -> some View {
        modifier(PositionedOverlay(
            overlayType: overlayType,
            coordinator: coordinator,
            autoRegister: autoRegister,
            onPositionChange: onPositionChange
        ))
    }
}

// MARK: - Smart Overlay Container

/// Container view that automatically manages overlay positioning
public struct SmartOverlayContainer<Content: View>: View {
    @StateObject private var coordinator: OverlayPositionCoordinator
    @State private var containerBounds: CGRect = .zero
    
    private let content: Content
    private let strategy: PositioningStrategy
    private let configuration: PositionConfiguration
    
    public init(
        strategy: PositioningStrategy = SmartPositioningStrategy(),
        configuration: PositionConfiguration = PositionConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.strategy = strategy
        self.configuration = configuration
        self.content = content()
        self._coordinator = StateObject(wrappedValue: OverlayPositionCoordinator(
            strategy: strategy,
            configuration: configuration
        ))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
                    .environmentObject(coordinator)
            }
            .onAppear {
                containerBounds = geometry.frame(in: .local)
                coordinator.bounds = containerBounds
            }
            .onChange(of: geometry.frame(in: .local)) { _, newBounds in
                containerBounds = newBounds
                coordinator.bounds = newBounds
            }
        }
    }
}

// MARK: - Overlay Position Preference

/// Preference key for collecting overlay position requirements
public struct OverlayPositionPreference: PreferenceKey {
    public static var defaultValue: [OverlayPositionRequirement] = []
    
    public static func reduce(value: inout [OverlayPositionRequirement], nextValue: () -> [OverlayPositionRequirement]) {
        value.append(contentsOf: nextValue())
    }
}

/// Requirement for overlay positioning
public struct OverlayPositionRequirement: Equatable {
    public let overlayType: OverlayType
    public let preferredPosition: CGPoint?
    public let constraints: [PositionConstraint]
    public let priority: Int
    
    public init(
        overlayType: OverlayType,
        preferredPosition: CGPoint? = nil,
        constraints: [PositionConstraint] = [],
        priority: Int = 0
    ) {
        self.overlayType = overlayType
        self.preferredPosition = preferredPosition
        self.constraints = constraints
        self.priority = priority
    }
}

// MARK: - Preference-based View Modifier

/// View modifier that sets overlay position preferences
public struct OverlayPositionPreferenceModifier: ViewModifier {
    let requirement: OverlayPositionRequirement
    
    public func body(content: Content) -> some View {
        content
            .preference(key: OverlayPositionPreference.self, value: [requirement])
    }
}

public extension View {
    /// Set position preferences for this overlay
    func overlayPositionPreference(
        _ overlayType: OverlayType,
        preferredPosition: CGPoint? = nil,
        constraints: [PositionConstraint] = [],
        priority: Int = 0
    ) -> some View {
        modifier(OverlayPositionPreferenceModifier(
            requirement: OverlayPositionRequirement(
                overlayType: overlayType,
                preferredPosition: preferredPosition,
                constraints: constraints,
                priority: priority
            )
        ))
    }
}

// MARK: - Adaptive Overlay View

/// View that automatically adapts its position based on content and constraints
public struct AdaptiveOverlayView<Content: View>: View {
    @EnvironmentObject private var coordinator: OverlayPositionCoordinator
    @State private var overlaySize: CGSize = .zero
    
    private let overlayType: OverlayType
    private let content: Content
    private let isVisible: Bool
    private let onPositionChange: ((CGPoint) -> Void)?
    
    public init(
        overlayType: OverlayType,
        isVisible: Bool = true,
        onPositionChange: ((CGPoint) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.overlayType = overlayType
        self.isVisible = isVisible
        self.onPositionChange = onPositionChange
        self.content = content()
    }
    
    public var body: some View {
        if isVisible {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                overlaySize = geometry.size
                            }
                            .onChange(of: geometry.size) { _, newSize in
                                overlaySize = newSize
                                // Update overlay size and recalculate position
                                coordinator.updatePosition(for: overlayType, animated: true)
                            }
                    }
                )
                .positionedOverlay(
                    overlayType,
                    coordinator: coordinator,
                    onPositionChange: onPositionChange
                )
                .onAppear {
                    coordinator.setOverlayVisible(overlayType, visible: true)
                }
                .onDisappear {
                    coordinator.setOverlayVisible(overlayType, visible: false)
                }
        }
    }
}

// MARK: - Position Debug View

/// Debug view for visualizing overlay positions and conflicts
public struct OverlayPositionDebugView: View {
    @ObservedObject var coordinator: OverlayPositionCoordinator
    let showZones: Bool
    let showConflicts: Bool
    
    public init(
        coordinator: OverlayPositionCoordinator,
        showZones: Bool = true,
        showConflicts: Bool = true
    ) {
        self.coordinator = coordinator
        self.showZones = showZones
        self.showConflicts = showConflicts
    }
    
    public var body: some View {
        ZStack {
            // Show positioning zones
            if showZones {
                ForEach(Array(coordinator.positions.keys), id: \.self) { overlayType in
                    let position = coordinator.position(for: overlayType)
                    let size = overlayType.defaultSize
                    
                    Rectangle()
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        .frame(width: size.width, height: size.height)
                        .position(position)
                        .overlay(
                            Text(overlayType.rawValue)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .position(x: position.x, y: position.y - size.height/2 - 15)
                        )
                }
            }
            
            // Show conflicts
            if showConflicts && coordinator.hasConflicts {
                Text("⚠️ Position Conflicts Detected")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                    .position(x: coordinator.bounds.midX, y: coordinator.bounds.minY + 30)
            }
        }
    }
}