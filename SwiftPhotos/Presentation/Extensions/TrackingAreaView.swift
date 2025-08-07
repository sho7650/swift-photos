//
//  TrackingAreaView.swift
//  Swift Photos
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import AppKit
import os.log

// MARK: - Tracking Area View

/// NSViewRepresentable that provides precise mouse tracking with window boundary detection
/// Offers enhanced tracking capabilities beyond standard SwiftUI hover detection
public struct TrackingAreaView: NSViewRepresentable {
    
    // MARK: - Bindings and Callbacks
    
    @Binding var isCursorInside: Bool
    @Binding var mousePosition: CGPoint
    
    let onMouseEntered: () -> Void
    let onMouseExited: () -> Void
    let onMouseMoved: (CGPoint) -> Void
    
    // MARK: - Configuration
    
    let trackingOptions: NSTrackingArea.Options
    let enableContinuousTracking: Bool
    let sensitivityThreshold: Double
    
    // MARK: - Initialization
    
    public init(
        isCursorInside: Binding<Bool>,
        mousePosition: Binding<CGPoint> = .constant(.zero),
        trackingOptions: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
        enableContinuousTracking: Bool = true,
        sensitivityThreshold: Double = 1.0,
        onMouseEntered: @escaping () -> Void = {},
        onMouseExited: @escaping () -> Void = {},
        onMouseMoved: @escaping (CGPoint) -> Void = { _ in }
    ) {
        self._isCursorInside = isCursorInside
        self._mousePosition = mousePosition
        self.trackingOptions = trackingOptions
        self.enableContinuousTracking = enableContinuousTracking
        self.sensitivityThreshold = sensitivityThreshold
        self.onMouseEntered = onMouseEntered
        self.onMouseExited = onMouseExited
        self.onMouseMoved = onMouseMoved
    }
    
    // MARK: - NSViewRepresentable Implementation
    
    public func makeNSView(context: Context) -> EnhancedTrackingView {
        let view = EnhancedTrackingView()
        view.delegate = context.coordinator
        view.trackingOptions = trackingOptions
        view.enableContinuousTracking = enableContinuousTracking
        view.sensitivityThreshold = sensitivityThreshold
        return view
    }
    
    public func updateNSView(_ nsView: EnhancedTrackingView, context: Context) {
        nsView.trackingOptions = trackingOptions
        nsView.enableContinuousTracking = enableContinuousTracking
        nsView.sensitivityThreshold = sensitivityThreshold
        nsView.updateTrackingArea()
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(
            isCursorInside: $isCursorInside,
            mousePosition: $mousePosition,
            onMouseEntered: onMouseEntered,
            onMouseExited: onMouseExited,
            onMouseMoved: onMouseMoved
        )
    }
}

// MARK: - Enhanced Tracking View

/// Custom NSView that provides advanced mouse tracking capabilities
public final class EnhancedTrackingView: NSView, @unchecked Sendable {
    
    weak var delegate: TrackingAreaView.Coordinator?
    
    var trackingOptions: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect]
    var enableContinuousTracking: Bool = true
    var sensitivityThreshold: Double = 1.0
    
    private var trackingArea: NSTrackingArea?
    private var lastMousePosition: CGPoint = .zero
    private let logger = Logger(subsystem: "SwiftPhotos", category: "TrackingAreaView")
    
    // MARK: - Lifecycle
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupTrackingArea()
        logger.debug("🖱️ TrackingAreaView: View moved to window, tracking area setup")
    }
    
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        
        if newWindow == nil {
            removeTrackingArea()
            logger.debug("🖱️ TrackingAreaView: View removed from window, tracking area cleaned up")
        }
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }
    
    // MARK: - Tracking Area Management
    
    func setupTrackingArea() {
        removeTrackingArea()
        createTrackingArea()
    }
    
    func updateTrackingArea() {
        setupTrackingArea()
    }
    
    private func createTrackingArea() {
        guard window != nil else { return }
        
        let options = trackingOptions
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
            logger.debug("🖱️ TrackingAreaView: Tracking area created with bounds \(String(describing: self.bounds))")
        }
    }
    
    private func removeTrackingArea() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
    }
    
    // MARK: - Mouse Event Handling
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        let locationInView = convert(event.locationInWindow, from: nil)
        delegate?.mouseEntered(at: locationInView)
        
        logger.debug("🖱️ TrackingAreaView: Mouse entered at \(String(describing: locationInView))")
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        let locationInView = convert(event.locationInWindow, from: nil)
        delegate?.mouseExited(at: locationInView)
        
        logger.debug("🖱️ TrackingAreaView: Mouse exited at \(String(describing: locationInView))")
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        guard enableContinuousTracking else { return }
        
        let locationInView = convert(event.locationInWindow, from: nil)
        
        // Apply sensitivity threshold
        let distance = sqrt(
            pow(locationInView.x - lastMousePosition.x, 2) +
            pow(locationInView.y - lastMousePosition.y, 2)
        )
        
        if distance >= sensitivityThreshold {
            delegate?.mouseMoved(at: locationInView)
            lastMousePosition = locationInView
        }
    }
    
    // MARK: - Additional Mouse Events
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let locationInView = convert(event.locationInWindow, from: nil)
        delegate?.mouseClicked(at: locationInView, clickCount: event.clickCount)
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        
        let locationInView = convert(event.locationInWindow, from: nil)
        delegate?.rightMouseClicked(at: locationInView)
    }
    
    public override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        
        let locationInView = convert(event.locationInWindow, from: nil)
        let scrollDelta = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        delegate?.mouseScrolled(at: locationInView, delta: scrollDelta)
    }
}

// MARK: - Coordinator

extension TrackingAreaView {
    
    public final class Coordinator: NSObject, @unchecked Sendable {
        
        @Binding var isCursorInside: Bool
        @Binding var mousePosition: CGPoint
        
        let onMouseEntered: () -> Void
        let onMouseExited: () -> Void
        let onMouseMoved: (CGPoint) -> Void
        
        private let logger = Logger(subsystem: "SwiftPhotos", category: "TrackingAreaView.Coordinator")
        
        init(
            isCursorInside: Binding<Bool>,
            mousePosition: Binding<CGPoint>,
            onMouseEntered: @escaping () -> Void,
            onMouseExited: @escaping () -> Void,
            onMouseMoved: @escaping (CGPoint) -> Void
        ) {
            self._isCursorInside = isCursorInside
            self._mousePosition = mousePosition
            self.onMouseEntered = onMouseEntered
            self.onMouseExited = onMouseExited
            self.onMouseMoved = onMouseMoved
        }
        
        // MARK: - Event Handlers
        
        func mouseEntered(at position: CGPoint) {
            Task<Void, Never> { @MainActor @Sendable [weak self] in
                guard let self = self else { return }
                isCursorInside = true
                mousePosition = position
                onMouseEntered()
            }
        }
        
        func mouseExited(at position: CGPoint) {
            Task<Void, Never> { @MainActor @Sendable [weak self] in
                guard let self = self else { return }
                isCursorInside = false
                mousePosition = position
                onMouseExited()
            }
        }
        
        func mouseMoved(at position: CGPoint) {
            Task<Void, Never> { @MainActor @Sendable [weak self] in
                guard let self = self else { return }
                mousePosition = position
                onMouseMoved(position)
            }
        }
        
        func mouseClicked(at position: CGPoint, clickCount: Int) {
            Task<Void, Never> { @MainActor @Sendable [weak self] in
                guard let self = self else { return }
                mousePosition = position
                // Additional click handling can be added here
                logger.debug("🖱️ TrackingAreaView: Mouse clicked at \(String(describing: position)), count: \(clickCount)")
            }
        }
        
        func rightMouseClicked(at position: CGPoint) {
            Task<Void, Never> { @MainActor @Sendable [weak self] in
                guard let self = self else { return }
                mousePosition = position
                // Right-click handling can be added here
                logger.debug("🖱️ TrackingAreaView: Right mouse clicked at \(String(describing: position))")
            }
        }
        
        func mouseScrolled(at position: CGPoint, delta: CGVector) {
            Task<Void, Never> { @MainActor @Sendable [weak self] in
                guard let self = self else { return }
                mousePosition = position
                // Scroll handling can be added here
                logger.debug("🖱️ TrackingAreaView: Mouse scrolled at \(String(describing: position)), delta: \(String(describing: delta))")
            }
        }
    }
}

// MARK: - Convenience Extensions

extension TrackingAreaView {
    
    /// Create a basic tracking area for cursor in/out detection
    public static func basic(
        isCursorInside: Binding<Bool>,
        onMouseEntered: @escaping () -> Void = {},
        onMouseExited: @escaping () -> Void = {}
    ) -> TrackingAreaView {
        return TrackingAreaView(
            isCursorInside: isCursorInside,
            trackingOptions: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            enableContinuousTracking: false,
            onMouseEntered: onMouseEntered,
            onMouseExited: onMouseExited
        )
    }
    
    /// Create a full-featured tracking area with mouse movement tracking
    public static func enhanced(
        isCursorInside: Binding<Bool>,
        mousePosition: Binding<CGPoint>,
        sensitivityThreshold: Double = 2.0,
        onMouseEntered: @escaping () -> Void = {},
        onMouseExited: @escaping () -> Void = {},
        onMouseMoved: @escaping (CGPoint) -> Void = { _ in }
    ) -> TrackingAreaView {
        return TrackingAreaView(
            isCursorInside: isCursorInside,
            mousePosition: mousePosition,
            trackingOptions: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            enableContinuousTracking: true,
            sensitivityThreshold: sensitivityThreshold,
            onMouseEntered: onMouseEntered,
            onMouseExited: onMouseExited,
            onMouseMoved: onMouseMoved
        )
    }
    
    /// Create tracking area optimized for slideshow applications
    public static func slideshow(
        isCursorInside: Binding<Bool>,
        mousePosition: Binding<CGPoint>,
        onCursorActivity: @escaping () -> Void = {}
    ) -> TrackingAreaView {
        return TrackingAreaView(
            isCursorInside: isCursorInside,
            mousePosition: mousePosition,
            trackingOptions: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            enableContinuousTracking: true,
            sensitivityThreshold: 5.0,
            onMouseEntered: onCursorActivity,
            onMouseExited: onCursorActivity,
            onMouseMoved: { _ in onCursorActivity() }
        )
    }
}

// MARK: - View Extension

extension View {
    /// Add enhanced mouse tracking to any SwiftUI view
    public func trackingArea(
        isCursorInside: Binding<Bool>,
        mousePosition: Binding<CGPoint> = .constant(.zero),
        onMouseEntered: @escaping () -> Void = {},
        onMouseExited: @escaping () -> Void = {},
        onMouseMoved: @escaping (CGPoint) -> Void = { _ in }
    ) -> some View {
        background(
            TrackingAreaView.enhanced(
                isCursorInside: isCursorInside,
                mousePosition: mousePosition,
                onMouseEntered: onMouseEntered,
                onMouseExited: onMouseExited,
                onMouseMoved: onMouseMoved
            )
        )
    }
    
    /// Add basic cursor in/out tracking
    public func basicTracking(
        isCursorInside: Binding<Bool>,
        onMouseEntered: @escaping () -> Void = {},
        onMouseExited: @escaping () -> Void = {}
    ) -> some View {
        background(
            TrackingAreaView.basic(
                isCursorInside: isCursorInside,
                onMouseEntered: onMouseEntered,
                onMouseExited: onMouseExited
            )
        )
    }
}