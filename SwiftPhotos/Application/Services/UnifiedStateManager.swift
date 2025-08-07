import Foundation
import SwiftUI
import Observation

/// State Manager pattern for optimizing view state management and reducing @State variable proliferation
/// Consolidates common state patterns used across multiple views
@MainActor
@Observable
public class UnifiedStateManager {
    
    // MARK: - UI State Management
    
    /// Hover states consolidated
    public struct HoverState {
        public var isHovering: Bool = false
        public var hoveredIndex: Int? = nil
        public var hoveredItem: String? = nil
        public var hoverStartTime: Date? = nil
        
        public mutating func enter(index: Int? = nil, item: String? = nil) {
            isHovering = true
            hoveredIndex = index
            hoveredItem = item
            hoverStartTime = Date()
        }
        
        public mutating func exit() {
            isHovering = false
            hoveredIndex = nil
            hoveredItem = nil
            hoverStartTime = nil
        }
        
        public var hoverDuration: TimeInterval {
            guard let startTime = hoverStartTime else { return 0 }
            return Date().timeIntervalSince(startTime)
        }
    }
    
    /// Press states consolidated
    public struct PressState {
        public var isPressed: Bool = false
        public var pressLocation: CGPoint = .zero
        public var pressStartTime: Date? = nil
        
        public mutating func start(at location: CGPoint = .zero) {
            isPressed = true
            pressLocation = location
            pressStartTime = Date()
        }
        
        public mutating func end() {
            isPressed = false
            pressLocation = .zero
            pressStartTime = nil
        }
        
        public var pressDuration: TimeInterval {
            guard let startTime = pressStartTime else { return 0 }
            return Date().timeIntervalSince(startTime)
        }
    }
    
    /// Drag states consolidated
    public struct DragState {
        public var isDragging: Bool = false
        public var dragStart: CGPoint = .zero
        public var currentPosition: CGPoint = .zero
        public var dragVelocity: CGSize = .zero
        public var dragDistance: CGFloat = 0
        
        public mutating func start(at point: CGPoint) {
            isDragging = true
            dragStart = point
            currentPosition = point
            dragDistance = 0
        }
        
        public mutating func update(to point: CGPoint) {
            guard isDragging else { return }
            let previousPosition = currentPosition
            currentPosition = point
            
            // Calculate velocity
            dragVelocity = CGSize(
                width: point.x - previousPosition.x,
                height: point.y - previousPosition.y
            )
            
            // Calculate total distance
            dragDistance = sqrt(
                pow(currentPosition.x - dragStart.x, 2) + 
                pow(currentPosition.y - dragStart.y, 2)
            )
        }
        
        public mutating func end() {
            isDragging = false
            dragStart = .zero
            currentPosition = .zero
            dragVelocity = .zero
            dragDistance = 0
        }
        
        public var dragOffset: CGSize {
            CGSize(
                width: currentPosition.x - dragStart.x,
                height: currentPosition.y - dragStart.y
            )
        }
    }
    
    /// Expansion states consolidated
    public struct ExpansionState {
        public var isExpanded: Bool = false
        public var canExpand: Bool = true
        public var expandDirection: ExpandDirection = .down
        public var animationDuration: Double = 0.3
        
        public enum ExpandDirection {
            case up, down, left, right
        }
        
        public mutating func toggle() {
            guard canExpand else { return }
            isExpanded.toggle()
        }
        
        public mutating func expand() {
            guard canExpand else { return }
            isExpanded = true
        }
        
        public mutating func collapse() {
            isExpanded = false
        }
    }
    
    /// Focus states consolidated
    public struct FocusState {
        public var isFocused: Bool = false
        public var focusedField: String? = nil
        public var canReceiveFocus: Bool = true
        public var focusStartTime: Date? = nil
        
        public mutating func focus(on field: String? = nil) {
            guard canReceiveFocus else { return }
            isFocused = true
            focusedField = field
            focusStartTime = Date()
        }
        
        public mutating func blur() {
            isFocused = false
            focusedField = nil
            focusStartTime = nil
        }
        
        public var focusDuration: TimeInterval {
            guard let startTime = focusStartTime else { return 0 }
            return Date().timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Position State Management
    
    /// Position states consolidated
    public struct PositionState {
        public var offset: CGSize = .zero
        public var scale: CGFloat = 1.0
        public var rotation: Angle = .zero
        public var anchor: UnitPoint = .center
        public var isAnimating: Bool = false
        
        public mutating func reset(animated: Bool = true) {
            if animated {
                isAnimating = true
            }
            offset = .zero
            scale = 1.0
            rotation = .zero
            anchor = .center
        }
        
        public mutating func applyTransform(
            offset: CGSize? = nil,
            scale: CGFloat? = nil,
            rotation: Angle? = nil,
            anchor: UnitPoint? = nil
        ) {
            if let offset = offset { self.offset = offset }
            if let scale = scale { self.scale = scale }
            if let rotation = rotation { self.rotation = rotation }
            if let anchor = anchor { self.anchor = anchor }
        }
        
        public var transform: CGAffineTransform {
            CGAffineTransform.identity
                .translatedBy(x: offset.width, y: offset.height)
                .scaledBy(x: scale, y: scale)
                .rotated(by: rotation.radians)
        }
    }
    
    /// Viewport states consolidated
    public struct ViewportState {
        public var size: CGSize = .zero
        public var safeAreaInsets: EdgeInsets = EdgeInsets()
        public var contentScale: CGFloat = 1.0
        public var isFullscreen: Bool = false
        
        public mutating func update(size: CGSize, safeArea: EdgeInsets = EdgeInsets()) {
            self.size = size
            self.safeAreaInsets = safeArea
        }
        
        public var aspectRatio: CGFloat {
            guard size.height > 0 else { return 1.0 }
            return size.width / size.height
        }
        
        public var contentSize: CGSize {
            CGSize(
                width: size.width * contentScale,
                height: size.height * contentScale
            )
        }
    }
    
    // MARK: - Animation State Management
    
    /// Animation states consolidated
    public struct AnimationState {
        public var isAnimating: Bool = false
        public var animationType: AnimationType = .none
        public var duration: Double = 0.3
        public var delay: Double = 0.0
        public var repeatCount: Int = 1
        public var autoreverses: Bool = false
        
        public enum AnimationType {
            case none, fade, scale, slide, rotate, bounce
        }
        
        public mutating func start(_ type: AnimationType, duration: Double = 0.3) {
            animationType = type
            self.duration = duration
            isAnimating = true
        }
        
        public mutating func stop() {
            isAnimating = false
            animationType = .none
        }
        
        public var swiftUIAnimation: Animation {
            switch animationType {
            case .none:
                return .linear(duration: 0)
            case .fade:
                return .easeInOut(duration: duration)
            case .scale:
                return .spring(response: duration, dampingFraction: 0.8)
            case .slide:
                return .easeOut(duration: duration)
            case .rotate:
                return .linear(duration: duration)
            case .bounce:
                return .interpolatingSpring(stiffness: 300, damping: 15)
            }
        }
    }
    
    // MARK: - State Collections
    
    public var hoverState = HoverState()
    public var pressState = PressState()
    public var dragState = DragState()
    public var expansionState = ExpansionState()
    public var focusState = FocusState()
    public var positionState = PositionState()
    public var viewportState = ViewportState()
    public var animationState = AnimationState()
    
    // MARK: - Initialization
    
    public init() {
        ProductionLogger.lifecycle("UnifiedStateManager: Initialized with consolidated state management")
    }
    
    // MARK: - State Coordination
    
    /// Reset all states to default values
    public func resetAllStates(animated: Bool = true) {
        hoverState.exit()
        pressState.end()
        dragState.end()
        expansionState.collapse()
        focusState.blur()
        positionState.reset(animated: animated)
        animationState.stop()
        
        ProductionLogger.debug("UnifiedStateManager: All states reset")
    }
    
    /// Batch state updates for performance
    public func batchUpdate(_ updates: () -> Void) {
        updates()
    }
    
    /// Get state summary for debugging
    public func getStateSummary() -> [String: Any] {
        return [
            "hover_active": hoverState.isHovering,
            "press_active": pressState.isPressed,
            "drag_active": dragState.isDragging,
            "expanded": expansionState.isExpanded,
            "focused": focusState.isFocused,
            "animating": animationState.isAnimating,
            "viewport_size": "\(viewportState.size.width)x\(viewportState.size.height)",
            "position_offset": "\(positionState.offset.width),\(positionState.offset.height)",
            "scale": positionState.scale
        ]
    }
}

// MARK: - Specialized State Managers

/// Button-specific state management
@MainActor
@Observable
public class ButtonStateManager: UnifiedStateManager {
    
    public var isEnabled: Bool = true
    public var style: ButtonStyle = .primary
    public var size: ButtonSize = .medium
    
    public enum ButtonStyle {
        case primary, secondary, destructive, ghost
    }
    
    public enum ButtonSize {
        case small, medium, large
    }
    
    public override init() {
        super.init()
        ProductionLogger.lifecycle("ButtonStateManager: Specialized button state manager initialized")
    }
    
    public func handlePress(at location: CGPoint = .zero) {
        guard isEnabled else { return }
        pressState.start(at: location)
        animationState.start(.scale, duration: 0.1)
    }
    
    public func handleRelease() {
        pressState.end()
        animationState.stop()
    }
    
    public func handleHover() {
        guard isEnabled else { return }
        hoverState.enter()
        animationState.start(.fade, duration: 0.2)
    }
    
    public func handleExitHover() {
        hoverState.exit()
        animationState.stop()
    }
}

/// Image display state management
@MainActor
@Observable
public class ImageDisplayStateManager: UnifiedStateManager {
    
    public var imageSize: CGSize = .zero
    public var contentMode: ContentMode = .fit
    public var isZoomed: Bool = false
    public var minScale: CGFloat = 0.5
    public var maxScale: CGFloat = 3.0
    
    public enum ContentMode {
        case fit, fill, original
    }
    
    public override init() {
        super.init()
        ProductionLogger.lifecycle("ImageDisplayStateManager: Specialized image display state manager initialized")
    }
    
    public func handleZoom(to scale: CGFloat, at point: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        let clampedScale = max(minScale, min(maxScale, scale))
        positionState.scale = clampedScale
        isZoomed = clampedScale > 1.0
        
        // Calculate offset to zoom into the specified point
        if clampedScale > 1.0 {
            let scaleChange = clampedScale - 1.0
            positionState.offset = CGSize(
                width: -(point.x - 0.5) * imageSize.width * scaleChange,
                height: -(point.y - 0.5) * imageSize.height * scaleChange
            )
        }
        
        animationState.start(.scale, duration: 0.3)
        ProductionLogger.debug("ImageDisplayStateManager: Zoom to \(clampedScale)x at \(point)")
    }
    
    public func resetZoom(animated: Bool = true) {
        positionState.reset(animated: animated)
        isZoomed = false
        if animated {
            animationState.start(.scale, duration: 0.4)
        }
        ProductionLogger.debug("ImageDisplayStateManager: Zoom reset")
    }
    
    public func handlePan(by offset: CGSize) {
        guard isZoomed else { return }
        
        // Calculate bounds for panning
        let scaledImageSize = CGSize(
            width: imageSize.width * positionState.scale,
            height: imageSize.height * positionState.scale
        )
        
        let maxOffsetX = max(0, (scaledImageSize.width - viewportState.size.width) / 2)
        let maxOffsetY = max(0, (scaledImageSize.height - viewportState.size.height) / 2)
        
        let newOffset = CGSize(
            width: max(-maxOffsetX, min(maxOffsetX, positionState.offset.width + offset.width)),
            height: max(-maxOffsetY, min(maxOffsetY, positionState.offset.height + offset.height))
        )
        
        positionState.offset = newOffset
    }
}

/// Overlay positioning state management
@MainActor
@Observable
public class OverlayStateManager: UnifiedStateManager {
    
    public var position: OverlayPosition = .topTrailing
    public var isVisible: Bool = true
    public var autoHideDelay: TimeInterval = 3.0
    private var autoHideTask: Task<Void, Never>?
    
    public enum OverlayPosition {
        case topLeading, topCenter, topTrailing
        case centerLeading, center, centerTrailing
        case bottomLeading, bottomCenter, bottomTrailing
        
        public var alignment: Alignment {
            switch self {
            case .topLeading: return .topLeading
            case .topCenter: return .top
            case .topTrailing: return .topTrailing
            case .centerLeading: return .leading
            case .center: return .center
            case .centerTrailing: return .trailing
            case .bottomLeading: return .bottomLeading
            case .bottomCenter: return .bottom
            case .bottomTrailing: return .bottomTrailing
            }
        }
    }
    
    public override init() {
        super.init()
        ProductionLogger.lifecycle("OverlayStateManager: Specialized overlay positioning state manager initialized")
    }
    
    public func show(at position: OverlayPosition? = nil, autoHide: Bool = true) {
        if let position = position {
            self.position = position
        }
        
        isVisible = true
        expansionState.expand()
        animationState.start(.fade, duration: 0.2)
        
        if autoHide {
            scheduleAutoHide()
        }
        
        ProductionLogger.debug("OverlayStateManager: Showing overlay at \(self.position)")
    }
    
    public func hide(animated: Bool = true) {
        Task { await cancelAutoHide() }
        
        if animated {
            animationState.start(.fade, duration: 0.2)
        }
        
        isVisible = false
        expansionState.collapse()
        
        ProductionLogger.debug("OverlayStateManager: Hiding overlay")
    }
    
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    private func scheduleAutoHide() {
        Task { await cancelAutoHide() }
        
        autoHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.autoHideDelay ?? 3.0))
            
            if !Task.isCancelled {
                await MainActor.run {
                    self?.hide()
                }
            }
        }
    }
    
    private func cancelAutoHide() async {
        autoHideTask?.cancel()
        autoHideTask = nil
    }
    
    deinit {
        // Cannot access main actor properties from deinit
        // Let the task naturally cancel when the object is deallocated
    }
}

// MARK: - State Manager Factory

/// Factory for creating appropriate state managers
@MainActor
public struct StateManagerFactory {
    
    public static func createButtonStateManager() -> ButtonStateManager {
        return ButtonStateManager()
    }
    
    public static func createImageDisplayStateManager() -> ImageDisplayStateManager {
        return ImageDisplayStateManager()
    }
    
    public static func createOverlayStateManager() -> OverlayStateManager {
        return OverlayStateManager()
    }
    
    public static func createUnifiedStateManager() -> UnifiedStateManager {
        return UnifiedStateManager()
    }
}

// MARK: - SwiftUI Integration

/// View modifier for easy state manager integration
public struct StateManagerModifier<StateManager: UnifiedStateManager>: ViewModifier {
    
    @State private var stateManager: StateManager
    
    public init(stateManager: StateManager) {
        self._stateManager = State(initialValue: stateManager)
    }
    
    public func body(content: Content) -> some View {
        content
            .environment(\.stateManager, stateManager)
    }
}

/// Environment key for state manager
private struct StateManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: UnifiedStateManager? = nil
}

extension EnvironmentValues {
    public var stateManager: UnifiedStateManager? {
        get { self[StateManagerEnvironmentKey.self] }
        set { self[StateManagerEnvironmentKey.self] = newValue }
    }
}

/// View extension for easy state manager usage
extension View {
    public func stateManager<SM: UnifiedStateManager>(_ stateManager: SM) -> some View {
        modifier(StateManagerModifier(stateManager: stateManager))
    }
}

// MARK: - Performance Optimization

/// State update batching for performance
@MainActor
public class StateBatchProcessor {
    
    private var pendingUpdates: [() -> Void] = []
    private var isProcessing = false
    
    public static let shared = StateBatchProcessor()
    
    private init() {}
    
    public func addUpdate(_ update: @escaping () -> Void) {
        pendingUpdates.append(update)
        
        if !isProcessing {
            processPendingUpdates()
        }
    }
    
    private func processPendingUpdates() {
        guard !isProcessing, !pendingUpdates.isEmpty else { return }
        
        isProcessing = true
        
        Task { @MainActor in
            // Process all pending updates in a single frame
            let updates = pendingUpdates
            pendingUpdates.removeAll()
            
            for update in updates {
                update()
            }
            
            isProcessing = false
            
            // Process any updates that were added during processing
            if !pendingUpdates.isEmpty {
                processPendingUpdates()
            }
        }
    }
}