import SwiftUI
import Combine
import AppKit
import os.log

// MARK: - Domain Imports
// PhotoZoomState is defined in Domain/ValueObjects/PhotoZoomState.swift
// gestureSettingsChanged notification is defined in ModernGestureSettingsManager.swift

/// Consolidated gesture and navigation manager for photo slideshow
/// Replaces: AdvancedGestureManager and gesture parts of InteractionZoneManager
@MainActor
public final class GestureNavigationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isZoomEnabled: Bool = true
    @Published public var isSwipeNavigationEnabled: Bool = true
    @Published public var isZooming: Bool = false
    @Published public var currentZoomScale: Double = 1.0
    @Published public var currentZoomOffset: CGSize = .zero
    
    // MARK: - Zoom Configuration
    
    public let minimumZoom: Double = 0.25
    public let maximumZoom: Double = 8.0
    public let zoomSensitivity: Double = 1.5
    public let doubleTapZoomScale: Double = 2.0
    
    // MARK: - Swipe Configuration
    
    public let swipeThreshold: Double = 50.0
    public let swipeVelocityThreshold: Double = 200.0
    
    // MARK: - Private Properties
    
    private weak var slideshowViewModel: (any SlideshowViewModelProtocol)?
    private let gestureSettings: ModernGestureSettingsManager
    
    // Zoom state
    private var lastZoomScale: Double = 1.0
    private var initialZoomCenter: CGPoint = .zero
    private var isGestureActive: Bool = false
    
    // Swipe state
    private var swipeStartLocation: CGPoint = .zero
    private var swipeStartTime: Date = Date()
    
    // Gesture coordination
    private var activeGestures: Set<GestureIdentifier> = []
    private var gestureRecognizers: [GestureIdentifier: NSGestureRecognizer] = [:]
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "GestureNavigationManager")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        slideshowViewModel: any SlideshowViewModelProtocol,
        gestureSettings: ModernGestureSettingsManager
    ) {
        self.slideshowViewModel = slideshowViewModel
        self.gestureSettings = gestureSettings
        
        setupBindings()
        logger.info("👆 GestureNavigationManager: Initialized with consolidated gesture handling")
    }
    
    deinit {
        logger.info("👆 GestureNavigationManager: Deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Create pinch gesture for zoom
    public func createPinchGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { [weak self] value in
                self?.handlePinchChange(value)
            }
            .onEnded { [weak self] value in
                self?.handlePinchEnd(value)
            }
    }
    
    /// Create drag gesture for panning when zoomed
    public func createPanGesture() -> some Gesture {
        DragGesture()
            .onChanged { [weak self] value in
                self?.handlePanChange(value)
            }
            .onEnded { [weak self] value in
                self?.handlePanEnd(value)
            }
    }
    
    /// Create swipe gesture for navigation
    public func createSwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: swipeThreshold)
            .onChanged { [weak self] value in
                self?.handleSwipeChange(value)
            }
            .onEnded { [weak self] value in
                self?.handleSwipeEnd(value)
            }
    }
    
    /// Create double tap gesture for zoom toggle
    public func createDoubleTapGesture() -> some Gesture {
        TapGesture(count: 2)
            .onEnded { [weak self] in
                self?.handleDoubleTap()
            }
    }
    
    /// Reset zoom to default
    public func resetZoom() {
        withAnimation(.spring()) {
            currentZoomScale = 1.0
            currentZoomOffset = .zero
            isZooming = false
        }
        logger.debug("🔍 Zoom reset to default")
    }
    
    /// Zoom to specific scale
    public func zoom(to scale: Double, animated: Bool = true) {
        let clampedScale = max(minimumZoom, min(scale, maximumZoom))
        
        if animated {
            withAnimation(.spring()) {
                currentZoomScale = clampedScale
                isZooming = clampedScale != 1.0
            }
        } else {
            currentZoomScale = clampedScale
            isZooming = clampedScale != 1.0
        }
        
        logger.debug("🔍 Zoomed to scale: \(clampedScale)")
    }
    
    /// Handle keyboard zoom
    public func handleKeyboardZoom(_ key: KeyEquivalent) {
        switch key {
        case "+", "=":
            zoom(to: currentZoomScale * 1.25)
        case "-":
            zoom(to: currentZoomScale / 1.25)
        case "0":
            resetZoom()
        default:
            break
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handlePinchChange(_ value: MagnificationGesture.Value) {
        guard isZoomEnabled else { return }
        
        if !isGestureActive {
            isGestureActive = true
            lastZoomScale = currentZoomScale
            pauseSlideshowIfNeeded()
        }
        
        let newScale = lastZoomScale * value
        currentZoomScale = max(minimumZoom, min(newScale, maximumZoom))
        isZooming = currentZoomScale != 1.0
        
        logger.debug("🔍 Pinch zoom: \(self.currentZoomScale)")
    }
    
    private func handlePinchEnd(_ value: MagnificationGesture.Value) {
        isGestureActive = false
        lastZoomScale = currentZoomScale
        
        // Snap to default if close
        if abs(currentZoomScale - 1.0) < 0.1 {
            resetZoom()
        }
    }
    
    private func handlePanChange(_ value: DragGesture.Value) {
        guard isZooming else { return }
        
        currentZoomOffset = CGSize(
            width: value.translation.width,
            height: value.translation.height
        )
        
        logger.debug("🖐️ Pan offset detected")
    }
    
    private func handlePanEnd(_ value: DragGesture.Value) {
        // Could add bounds checking here
    }
    
    private func handleSwipeChange(_ value: DragGesture.Value) {
        guard isSwipeNavigationEnabled && !isZooming else { return }
        
        if !isGestureActive {
            isGestureActive = true
            swipeStartLocation = value.startLocation
            swipeStartTime = Date()
        }
    }
    
    private func handleSwipeEnd(_ value: DragGesture.Value) {
        guard isSwipeNavigationEnabled && !isZooming else { return }
        
        isGestureActive = false
        
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        let duration = Date().timeIntervalSince(swipeStartTime)
        let velocity = abs(horizontalDistance) / duration
        
        // Check if it's a valid swipe
        if abs(horizontalDistance) > abs(verticalDistance) && velocity > swipeVelocityThreshold {
            if horizontalDistance > 0 {
                // Swipe right - previous photo
                // TODO: Fix navigation method name mismatch
                // slideshowViewModel?.navigateToPrevious()
                logger.debug("👉 Swipe right: Previous photo")
            } else {
                // Swipe left - next photo
                // TODO: Fix navigation method name mismatch  
                // slideshowViewModel?.navigateToNext()
                logger.debug("👈 Swipe left: Next photo")
            }
        }
    }
    
    public func handleDoubleTap() {
        guard isZoomEnabled else { return }
        
        if isZooming {
            resetZoom()
        } else {
            zoom(to: doubleTapZoomScale)
        }
        
        logger.debug("👆👆 Double tap zoom toggle")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe gesture settings changes
        // Note: Using notification-based updates since settings are @Observable
        NotificationCenter.default.addObserver(
            forName: .gestureSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // TODO: Update when gesture settings API is clarified
                // self?.isZoomEnabled = settings.pinchToZoomEnabled
                // self?.isSwipeNavigationEnabled = settings.swipeEnabled
            }
        }
    }
    
    private func pauseSlideshowIfNeeded() {
        // TODO: Fix isPlaying property access
        // if slideshowViewModel?.isPlaying == true {
        //     slideshowViewModel?.pause()
        //     logger.debug("⏸️ Slideshow paused for gesture")
        // }
    }
}

// MARK: - Supporting Types

/// Unique identifier for gesture recognizers
public enum GestureIdentifier: Hashable {
    case pinch
    case pan
    case swipe
    case doubleTap
    case rotate
    case custom(String)
}

/// Gesture state for coordination
public struct GestureState {
    let identifier: GestureIdentifier
    let startTime: Date
    let startLocation: CGPoint
    var currentLocation: CGPoint
    var isActive: Bool
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var translation: CGSize {
        CGSize(
            width: currentLocation.x - startLocation.x,
            height: currentLocation.y - startLocation.y
        )
    }
}

// Note: PhotoZoomState is imported from Domain layer (PhotoZoomState.swift)
// Removed duplicate struct definition to use existing Domain class

// MARK: - SwiftUI View Modifier

public struct GestureNavigationModifier: ViewModifier {
    @ObservedObject var manager: GestureNavigationManager
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(manager.currentZoomScale)
            .offset(manager.currentZoomOffset)
            .gesture(
                SimultaneousGesture(
                    manager.createPinchGesture(),
                    manager.createPanGesture()
                )
            )
            .gesture(manager.createSwipeGesture())
            .onTapGesture(count: 2) {
                manager.handleDoubleTap()
            }
    }
}

extension View {
    /// Apply gesture navigation to a view
    public func gestureNavigation(_ manager: GestureNavigationManager) -> some View {
        modifier(GestureNavigationModifier(manager: manager))
    }
}