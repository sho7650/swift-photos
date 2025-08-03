import SwiftUI
import Combine
import AppKit
import os.log

/// Advanced gesture manager for photo slideshow interactions
/// Provides sophisticated pinch-to-zoom, swipe navigation, and multi-touch support
@MainActor
public class AdvancedGestureManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isZoomEnabled: Bool = true
    @Published public var isSwipeNavigationEnabled: Bool = true
    @Published public var isZooming: Bool = false
    
    // MARK: - Private Properties
    
    public let slideshowViewModel: any SlideshowViewModelProtocol
    private let gestureCoordinator: GestureCoordinator
    public let photoZoomState: PhotoZoomState
    private let logger = Logger(subsystem: "SwiftPhotos", category: "AdvancedGestureManager")
    
    private var cancellables = Set<AnyCancellable>()
    
    // Zoom configuration - allow shrinking to 0.25
    public let minimumZoom: Double = 0.25
    public let maximumZoom: Double = 8.0
    public let zoomSensitivity: Double = 1.5  // Increased for faster pinch zoom
    private let panSensitivity: Double = 1.0
    
    // Swipe configuration
    private let swipeThreshold: Double = 50.0
    public let swipeVelocityThreshold: Double = 200.0
    
    // State management
    private var lastZoomScale: Double = 1.0
    private var initialZoomCenter: CGPoint = .zero
    private var isGestureActive: Bool = false
    private var swipeStartLocation: CGPoint = .zero
    private var lastPanTranslation: CGVector = .zero
    
    // Performance optimization
    private var lastGestureUpdate: Date = Date()
    private let gestureUpdateThrottle: TimeInterval = 0.016 // 60fps
    
    // MARK: - Initialization
    
    public init(
        slideshowViewModel: any SlideshowViewModelProtocol,
        gestureCoordinator: GestureCoordinator,
        photoZoomState: PhotoZoomState
    ) {
        self.slideshowViewModel = slideshowViewModel
        self.gestureCoordinator = gestureCoordinator
        self.photoZoomState = photoZoomState
        
        setupGestureHandling()
        setupSlideshowIntegration()
        
        logger.info("🎮 AdvancedGestureManager: Initialized with zoom and swipe support")
    }
    
    // MARK: - Public Interface
    
    /// Reset zoom to fit the current photo
    public func resetZoom(animated: Bool = true) {
        photoZoomState.resetZoom(animated: animated)
        logger.debug("🎮 AdvancedGestureManager: Reset zoom to fit screen")
    }
    
    /// Zoom to a specific level at a point
    public func zoomTo(level: Double, at point: CGPoint = .zero, animated: Bool = true) {
        let clampedZoom = max(minimumZoom, min(maximumZoom, level))
        
        if point == .zero {
            photoZoomState.setZoom(clampedZoom, animated: animated)
        } else {
            // For specific point zoom, we'll use the PhotoZoomState's zoomIn method at point
            // This is a simplification - could be enhanced with point-specific zoom
            photoZoomState.setZoom(clampedZoom, animated: animated)
        }
        
        logger.debug("🎮 AdvancedGestureManager: Zoomed to level \(clampedZoom)")
    }
    
    /// Enable or disable specific gesture types
    public func setGestureEnabled(_ gestureType: GestureType, enabled: Bool) {
        switch gestureType {
        case .pinch, .magnify:
            isZoomEnabled = enabled
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            isSwipeNavigationEnabled = enabled
        default:
            break
        }
        
        gestureCoordinator.setGestureEnabled(gestureType, enabled: enabled)
        logger.info("🎮 AdvancedGestureManager: \(gestureType.rawValue) gesture \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get current gesture configuration for photo interactions
    public func getPhotoGestureConfiguration() -> GestureConfiguration {
        var enabledGestures: Set<GestureType> = []
        
        if isZoomEnabled {
            enabledGestures.insert(.pinch)
            enabledGestures.insert(.magnify)
            enabledGestures.insert(.pan)
        }
        
        if isSwipeNavigationEnabled {
            enabledGestures.insert(.swipeLeft)
            enabledGestures.insert(.swipeRight)
            enabledGestures.insert(.swipeUp)
            enabledGestures.insert(.swipeDown)
        }
        
        enabledGestures.insert(.tap)
        enabledGestures.insert(.doubleTap)
        
        return GestureConfiguration(
            enabledGestures: enabledGestures,
            minimumTouchCount: 1,
            maximumTouchCount: 2,
            recognitionDelay: 0.05,
            simultaneousRecognition: true,
            pressureSupport: false
        )
    }
    
    /// Create enhanced gesture view for photo display
    public func createPhotoGestureView<Content: View>(
        content: @escaping () -> Content,
        bounds: CGRect
    ) -> some View {
        PhotoGestureView(
            gestureManager: self,
            bounds: bounds,
            content: content
        )
    }
    
    // MARK: - Gesture Processing
    
    /// Process pinch/zoom gesture
    public func processPinchGesture(_ gestureData: GestureData, at location: CGPoint) {
        guard isZoomEnabled, let scale = gestureData.scale else { return }
        
        switch gestureData.phase {
        case .began:
            isZooming = true
            lastZoomScale = photoZoomState.currentZoomLevel
            initialZoomCenter = location
            logger.debug("🎮 AdvancedGestureManager: Pinch gesture began at (\(location.x), \(location.y))")
            
        case .changed:
            guard shouldUpdateGesture() else { return }
            
            let newZoom = lastZoomScale * scale
            let clampedZoom = max(minimumZoom, min(maximumZoom, newZoom))
            
            // Update PhotoZoomState with new zoom level
            photoZoomState.setZoom(clampedZoom, offset: photoZoomState.zoomOffset, animated: false)
            logger.debug("🎮 AdvancedGestureManager: Pinch gesture changed - zoom: \(clampedZoom)")
            
        case .ended, .cancelled:
            isZooming = false
            
            // Snap to sensible zoom levels
            let currentZoom = photoZoomState.currentZoomLevel
            let snappedZoom = snapToZoomLevel(currentZoom)
            if abs(snappedZoom - currentZoom) > 0.1 {
                photoZoomState.setZoom(snappedZoom, animated: true)
            }
            
            logger.debug("🎮 AdvancedGestureManager: Pinch gesture ended, final zoom: \(self.photoZoomState.currentZoomLevel)")
            
        default:
            break
        }
    }
    
    /// Process pan gesture for zoomed image navigation
    public func processPanGesture(_ gestureData: GestureData, at location: CGPoint) {
        guard photoZoomState.currentZoomLevel > 1.0, let translation = gestureData.translation else { return }
        
        switch gestureData.phase {
        case .began:
            lastPanTranslation = .zero
            
        case .changed:
            guard shouldUpdateGesture() else { return }
            
            let deltaX = translation.dx - lastPanTranslation.dx
            let deltaY = translation.dy - lastPanTranslation.dy
            
            // Use PhotoZoomState's pan method for consistent pan handling
            let panDelta = CGPoint(x: deltaX * panSensitivity, y: deltaY * panSensitivity)
            photoZoomState.pan(by: panDelta)
            
            lastPanTranslation = translation
            logger.debug("🎮 AdvancedGestureManager: Pan gesture - delta: (\(panDelta.x), \(panDelta.y))")
            
        case .ended, .cancelled:
            // Apply momentum if velocity is high
            // Note: Velocity tracking could be added to PhotoMetadata if needed
            // For now, skip momentum application
            break
            
        default:
            break
        }
    }
    
    /// Process swipe gesture for navigation
    public func processSwipeGesture(_ gestureData: GestureData, at location: CGPoint) {
        guard isSwipeNavigationEnabled else { return }
        
        switch gestureData.gestureType {
        case .swipeLeft:
            navigateToNextPhoto()
        case .swipeRight:
            navigateToPreviousPhoto()
        case .swipeUp:
            // Could be used for additional functionality like showing info
            handleUpSwipe()
        case .swipeDown:
            // Could be used for dismissing overlays or exiting
            handleDownSwipe()
        default:
            break
        }
    }
    
    /// Process double-tap gesture for smart zoom
    public func processDoubleTapGesture(_ gestureData: GestureData, at location: CGPoint) {
        guard isZoomEnabled else { return }
        
        if photoZoomState.currentZoomLevel <= 1.1 {
            // Zoom in to 2x at tap location
            photoZoomState.setZoom(2.0, animated: true)
        } else {
            // Reset zoom
            photoZoomState.resetZoom(animated: true)
        }
        
        logger.debug("🎮 AdvancedGestureManager: Double-tap zoom toggle at (\(location.x), \(location.y))")
    }
    
    // MARK: - Private Methods
    
    private func setupGestureHandling() {
        // Set up gesture coordinator as delegate to receive gesture events
        gestureCoordinator.delegate = self
        
        // Update gesture configuration for photo interactions
        let photoGestureConfig = getPhotoGestureConfiguration()
        gestureCoordinator.updateConfiguration(photoGestureConfig)
    }
    
    private func setupSlideshowIntegration() {
        // TODO: With @Observable, we'll need a different approach for photo change observation
        // For now, zoom reset can be handled manually when needed
    }
    
    private func shouldUpdateGesture() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastGestureUpdate) >= gestureUpdateThrottle else {
            return false
        }
        lastGestureUpdate = now
        return true
    }
    
    
    public func snapToZoomLevel(_ zoom: Double) -> Double {
        let snapLevels: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
        let snapThreshold: Double = 0.2
        
        for snapLevel in snapLevels {
            if abs(zoom - snapLevel) < snapThreshold {
                return snapLevel
            }
        }
        
        return zoom
    }
    
    private func constrainPanOffset(current: CGPoint, delta: CGPoint, zoomLevel: Double) -> CGPoint {
        // Calculate maximum pan bounds based on zoom level
        guard let mainScreen = NSScreen.main else { return current }
        let screenBounds = mainScreen.frame
        let maxPanX = (screenBounds.width * (zoomLevel - 1.0)) / 2.0
        let maxPanY = (screenBounds.height * (zoomLevel - 1.0)) / 2.0
        
        let newX = current.x + delta.x
        let newY = current.y + delta.y
        
        return CGPoint(
            x: max(-CGFloat(maxPanX), min(CGFloat(maxPanX), newX)),
            y: max(-CGFloat(maxPanY), min(CGFloat(maxPanY), newY))
        )
    }
    
    private func applyPanMomentum(velocity: CGVector) {
        let momentumDuration: TimeInterval = 0.5
        let momentumDamping: Double = 0.8
        
        let currentOffset = photoZoomState.zoomOffset
        let finalOffset = CGPoint(
            x: currentOffset.x + velocity.dx * momentumDamping,
            y: currentOffset.y + velocity.dy * momentumDamping
        )
        
        // Use PhotoZoomState's pan method for momentum
        let momentumDelta = CGPoint(
            x: finalOffset.x - currentOffset.x,
            y: finalOffset.y - currentOffset.y
        )
        
        withAnimation(.easeOut(duration: momentumDuration)) {
            photoZoomState.pan(by: momentumDelta)
        }
    }
    
    public func navigateToNextPhoto() {
        // Only navigate if not zoomed in
        guard photoZoomState.currentZoomLevel <= 1.1 else { return }
        
        // Swipe functionality removed
        Task {
            await slideshowViewModel.nextPhoto()
            logger.debug("🎮 AdvancedGestureManager: Navigated to next photo via swipe")
        }
    }
    
    public func navigateToPreviousPhoto() {
        // Only navigate if not zoomed in
        guard photoZoomState.currentZoomLevel <= 1.1 else { return }
        
        // Swipe functionality removed
        Task {
            await slideshowViewModel.previousPhoto()
            logger.debug("🎮 AdvancedGestureManager: Navigated to previous photo via swipe")
        }
    }
    
    private func handleUpSwipe() {
        // Could toggle detailed info or controls
        logger.debug("🎮 AdvancedGestureManager: Up swipe detected")
        // Implementation depends on UI control integration
    }
    
    private func handleDownSwipe() {
        // Could hide controls or return to fit-to-screen if zoomed
        if photoZoomState.currentZoomLevel > 1.0 {
            resetZoom(animated: true)
        }
        logger.debug("🎮 AdvancedGestureManager: Down swipe detected")
    }
}

// MARK: - GestureCoordinatorDelegate

extension AdvancedGestureManager: GestureCoordinatorDelegate {
    public func gestureCoordinator(
        _ coordinator: GestureCoordinator,
        didProcessGesture gesture: GestureData,
        at location: CGPoint,
        in zone: InteractionZone?
    ) {
        switch gesture.gestureType {
        case .pinch, .magnify:
            processPinchGesture(gesture, at: location)
        case .pan:
            processPanGesture(gesture, at: location)
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            processSwipeGesture(gesture, at: location)
        case .doubleTap:
            processDoubleTapGesture(gesture, at: location)
        default:
            break
        }
    }
    
    public func gestureCoordinator(
        _ coordinator: GestureCoordinator,
        didCompleteGesture gesture: GestureData,
        at location: CGPoint,
        in zone: InteractionZone?
    ) {
        // Handle gesture completion cleanup if needed
        if gesture.gestureType == .pinch || gesture.gestureType == .magnify {
            isZooming = false
        }
    }
}

// MARK: - PhotoGestureView

/// SwiftUI view that integrates advanced gesture handling with photo display
public struct PhotoGestureView<Content: View>: View {
    @ObservedObject private var gestureManager: AdvancedGestureManager
    
    private let bounds: CGRect
    private let content: () -> Content
    
    @State private var lastMagnification: Double = 1.0
    @State private var initialZoomLevel: Double = 0.0
    @State private var isGestureActive: Bool = false
    
    public init(
        gestureManager: AdvancedGestureManager,
        bounds: CGRect,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.gestureManager = gestureManager
        self.bounds = bounds
        self.content = content
    }
    
    public var body: some View {
        content()
            .gesture(combinedGesture)
            .clipped()
    }
    
    private var combinedGesture: some Gesture {
        // Combined magnification and swipe gestures
        SimultaneousGesture(
            magnificationGesture,
            dragGesture
        )
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.001) // Very low threshold for immediate response
            .onChanged { value in
                // Initialize zoom level on first gesture event
                if !isGestureActive {
                    isGestureActive = true
                    initialZoomLevel = gestureManager.photoZoomState.currentZoomLevel
                    lastMagnification = value
                }
                
                // Calculate zoom based on initial level and current magnification with sensitivity
                // Apply exponential scaling for more responsive zoom
                let scaledValue = pow(value, gestureManager.zoomSensitivity)
                let newZoomLevel = initialZoomLevel * scaledValue
                let clampedZoom = max(gestureManager.minimumZoom, min(gestureManager.maximumZoom, newZoomLevel))
                
                gestureManager.photoZoomState.setZoom(clampedZoom, animated: false)
                
                lastMagnification = value
            }
            .onEnded { value in
                isGestureActive = false
                initialZoomLevel = 0.0
                lastMagnification = 1.0
                
                // Apply snapping to nice zoom levels
                let finalZoom = gestureManager.photoZoomState.currentZoomLevel
                let snappedZoom = gestureManager.snapToZoomLevel(finalZoom)
                if abs(snappedZoom - finalZoom) > 0.1 {
                    gestureManager.photoZoomState.setZoom(snappedZoom, animated: true)
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)  // Very low threshold for maximum sensitivity
            .onChanged { value in
                // Debug output to check if gesture is detected
                ProductionLogger.debug("Drag detected: translation=\(value.translation), predictedEnd=\(value.predictedEndTranslation)")
                
                // Only allow swipe navigation when not heavily zoomed
                guard gestureManager.photoZoomState.currentZoomLevel <= 1.5 else { 
                    ProductionLogger.debug("Swipe blocked: zoom level too high (\(gestureManager.photoZoomState.currentZoomLevel))")
                    return 
                }
                
                // Provide visual feedback during swipe (horizontal only)
                let progress = value.translation.width / 150.0  // Even more sensitive feedback
                if abs(progress) > 0.02 {
                    // Swipe progress functionality removed
                    ProductionLogger.debug("Swipe progress: \(progress)")
                }
            }
            .onEnded { value in
                ProductionLogger.debug("Drag ended: translation=\(value.translation)")
                
                // Swipe progress functionality removed
                
                // Only allow swipe navigation when not heavily zoomed
                guard gestureManager.photoZoomState.currentZoomLevel <= 1.5 else { 
                    ProductionLogger.debug("Swipe navigation blocked: zoom level too high")
                    return 
                }
                
                // Very simple and sensitive swipe detection
                let translation = value.translation
                
                if abs(translation.width) > 15 {  // Very low threshold
                    if translation.width > 15 {
                        // Swipe right - previous photo
                        print("🌊 SWIPE RIGHT: Going to previous photo")
                        gestureManager.navigateToPreviousPhoto()
                    } else if translation.width < -15 {
                        // Swipe left - next photo
                        print("🌊 SWIPE LEFT: Going to next photo")
                        gestureManager.navigateToNextPhoto()
                    }
                } else {
                    print("🌊 Swipe distance too small: \(abs(translation.width))")
                }
            }
    }
    
    private func determineSwipeDirection(_ translation: CGSize) -> GestureType {
        let absX = abs(translation.width)
        let absY = abs(translation.height)
        
        if absX > absY {
            return translation.width > 0 ? .swipeRight : .swipeLeft
        } else {
            return translation.height > 0 ? .swipeDown : .swipeUp
        }
    }
}

// MARK: - Extensions

// Note: CGRect center extension is provided by PositionUtilities.swift

extension AdvancedGestureManager {
    /// Convenience access to common properties
    public var isZoomedIn: Bool {
        return photoZoomState.currentZoomLevel > 1.1
    }
    
    public var canNavigate: Bool {
        return !isZoomedIn
    }
}