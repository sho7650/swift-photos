import SwiftUI
import AppKit

/// Advanced gesture handling view with invisible interaction zones
/// Provides sophisticated multi-touch and gesture recognition capabilities
public struct InteractionZoneView: View {
    // MARK: - Properties
    
    @State public var zones: [InteractionZone] = []
    public var gestureConfiguration: GestureConfiguration
    
    /// Callback for zone interactions
    public var onZoneInteraction: ((InteractionZone, GestureData) -> Void)?
    
    /// Callback for general interactions
    public var onInteraction: ((InteractionData) -> Void)?
    
    @State private var activeZones: Set<UUID> = []
    @State private var currentGesture: GestureData?
    @State private var lastInteractionTime: Date = Date()
    
    // MARK: - Initialization
    
    public init(
        zones: [InteractionZone] = [],
        gestureConfiguration: GestureConfiguration = GestureConfiguration(),
        onZoneInteraction: ((InteractionZone, GestureData) -> Void)? = nil,
        onInteraction: ((InteractionData) -> Void)? = nil
    ) {
        self._zones = State(initialValue: zones)
        self.gestureConfiguration = gestureConfiguration
        self.onZoneInteraction = onZoneInteraction
        self.onInteraction = onInteraction
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible base layer that captures all interactions
                Color.clear
                    .contentShape(Rectangle())
                    .overlay(
                        // Zone-specific gesture detection
                        ForEach(zones.filter { $0.isEnabled }) { zone in
                            zoneView(for: zone, in: geometry)
                        }
                    )
                    // Global gesture handlers
                    .onTapGesture { location in
                        handleTap(at: location, in: geometry)
                    }
                    .gesture(
                        DragGesture(minimumDistance: gestureConfiguration.minimumDragDistance)
                            .onChanged { value in
                                handleDrag(value: value, in: geometry)
                            }
                            .onEnded { value in
                                handleDragEnded(value: value, in: geometry)
                            }
                    )
                    .gesture(
                        MagnificationGesture(minimumScaleDelta: gestureConfiguration.minimumPinchDelta)
                            .onChanged { value in
                                handleMagnification(scale: value, in: geometry)
                            }
                            .onEnded { value in
                                handleMagnificationEnded(scale: value, in: geometry)
                            }
                    )
                    .gesture(
                        RotationGesture(minimumAngleDelta: Angle(degrees: gestureConfiguration.minimumRotationDelta))
                            .onChanged { angle in
                                handleRotation(angle: angle, in: geometry)
                            }
                            .onEnded { angle in
                                handleRotationEnded(angle: angle, in: geometry)
                            }
                    )
                    .simultaneousGesture(
                        // Allow multiple gestures simultaneously
                        SimultaneousGesture(
                            MagnificationGesture(),
                            RotationGesture()
                        )
                    )
            }
            .onAppear {
                setupNSEventMonitoring()
            }
        }
    }
    
    // MARK: - Zone Management
    
    public func addZone(_ zone: InteractionZone) {
        zones.append(zone)
        zones.sort { $0.priority > $1.priority }
    }
    
    public func removeZone(id: UUID) {
        zones.removeAll { $0.id == id }
        activeZones.remove(id)
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
        }
        activeZones.remove(id)
    }
    
    // MARK: - Private Zone View
    
    @ViewBuilder
    private func zoneView(for zone: InteractionZone, in geometry: GeometryProxy) -> some View {
        Color.clear
            .frame(width: zone.frame.width, height: zone.frame.height)
            .position(
                x: zone.frame.midX,
                y: zone.frame.midY
            )
            .onTapGesture {
                if zone.allowedGestures.contains(.tap) {
                    handleZoneTap(zone: zone)
                }
            }
            .onHover { hovering in
                if zone.allowedGestures.contains(.hover) {
                    handleZoneHover(zone: zone, isHovering: hovering)
                }
            }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleTap(at location: CGPoint, in geometry: GeometryProxy) {
        let gestureData = GestureData(
            gestureType: .tap,
            phase: .ended
        )
        
        // Check which zones contain the tap
        let tappedZones = zones.filter { zone in
            zone.isEnabled && zone.frame.contains(location) && zone.allowedGestures.contains(.tap)
        }.sorted { $0.priority > $1.priority }
        
        if let topZone = tappedZones.first {
            onZoneInteraction?(topZone, gestureData)
        } else {
            // General tap outside zones
            let interactionData = InteractionData(
                position: location,
                gestureData: gestureData
            )
            onInteraction?(interactionData)
        }
        
        lastInteractionTime = Date()
    }
    
    private func handleDrag(value: DragGesture.Value, in geometry: GeometryProxy) {
        let translation = CGVector(dx: value.translation.width, dy: value.translation.height)
        let velocity = calculateVelocity(from: value)
        
        let gestureData = GestureData(
            gestureType: determineSwipeType(from: translation),
            phase: .changed,
            translation: translation
        )
        
        currentGesture = gestureData
        
        // Find affected zones
        let affectedZones = zones.filter { zone in
            zone.isEnabled && zone.frame.contains(value.location) &&
            zone.allowedGestures.includesSwipeGestures
        }
        
        for zone in affectedZones {
            onZoneInteraction?(zone, gestureData)
        }
        
        let interactionData = InteractionData(
            position: value.location,
            velocity: velocity,
            gestureData: gestureData
        )
        onInteraction?(interactionData)
    }
    
    private func handleDragEnded(value: DragGesture.Value, in geometry: GeometryProxy) {
        let translation = CGVector(dx: value.translation.width, dy: value.translation.height)
        let velocity = calculateVelocity(from: value)
        
        let gestureData = GestureData(
            gestureType: determineSwipeType(from: translation),
            phase: .ended,
            translation: translation
        )
        
        // Determine if it was a swipe based on velocity
        if velocity.magnitude > gestureConfiguration.swipeVelocityThreshold {
            handleSwipeGesture(gestureData: gestureData, at: value.location, in: geometry)
        }
        
        currentGesture = nil
        lastInteractionTime = Date()
    }
    
    private func handleMagnification(scale: CGFloat, in geometry: GeometryProxy) {
        let gestureData = GestureData(
            gestureType: .magnify,
            phase: .changed,
            scale: Double(scale)
        )
        
        currentGesture = gestureData
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let affectedZones = zones.filter { zone in
            zone.isEnabled && zone.frame.contains(center) &&
            zone.allowedGestures.contains(.magnify)
        }
        
        for zone in affectedZones {
            onZoneInteraction?(zone, gestureData)
        }
        
        let interactionData = InteractionData(
            position: center,
            gestureData: gestureData
        )
        onInteraction?(interactionData)
    }
    
    private func handleMagnificationEnded(scale: CGFloat, in geometry: GeometryProxy) {
        let gestureData = GestureData(
            gestureType: .magnify,
            phase: .ended,
            scale: Double(scale)
        )
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let interactionData = InteractionData(
            position: center,
            gestureData: gestureData
        )
        onInteraction?(interactionData)
        
        currentGesture = nil
        lastInteractionTime = Date()
    }
    
    private func handleRotation(angle: Angle, in geometry: GeometryProxy) {
        let gestureData = GestureData(
            gestureType: .rotation,
            phase: .changed,
            rotation: angle.degrees
        )
        
        currentGesture = gestureData
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let affectedZones = zones.filter { zone in
            zone.isEnabled && zone.frame.contains(center) &&
            zone.allowedGestures.contains(.rotation)
        }
        
        for zone in affectedZones {
            onZoneInteraction?(zone, gestureData)
        }
        
        let interactionData = InteractionData(
            position: center,
            gestureData: gestureData
        )
        onInteraction?(interactionData)
    }
    
    private func handleRotationEnded(angle: Angle, in geometry: GeometryProxy) {
        let gestureData = GestureData(
            gestureType: .rotation,
            phase: .ended,
            rotation: angle.degrees
        )
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let interactionData = InteractionData(
            position: center,
            gestureData: gestureData
        )
        onInteraction?(interactionData)
        
        currentGesture = nil
        lastInteractionTime = Date()
    }
    
    private func handleSwipeGesture(gestureData: GestureData, at location: CGPoint, in geometry: GeometryProxy) {
        let swipeZones = zones.filter { zone in
            zone.isEnabled && zone.frame.contains(location) &&
            zone.allowedGestures.contains(gestureData.gestureType)
        }
        
        for zone in swipeZones {
            onZoneInteraction?(zone, gestureData)
        }
    }
    
    private func handleZoneTap(zone: InteractionZone) {
        activeZones.insert(zone.id)
        
        let gestureData = GestureData(
            gestureType: .tap,
            phase: .ended
        )
        
        onZoneInteraction?(zone, gestureData)
        
        // Remove from active after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            activeZones.remove(zone.id)
        }
    }
    
    private func handleZoneHover(zone: InteractionZone, isHovering: Bool) {
        if isHovering {
            activeZones.insert(zone.id)
        } else {
            activeZones.remove(zone.id)
        }
        
        let gestureData = GestureData(
            gestureType: .hover,
            phase: isHovering ? .began : .ended
        )
        
        onZoneInteraction?(zone, gestureData)
    }
    
    // MARK: - Helper Methods
    
    private func determineSwipeType(from translation: CGVector) -> GestureType {
        let absX = abs(translation.dx)
        let absY = abs(translation.dy)
        
        if absX > absY {
            return translation.dx > 0 ? .swipeRight : .swipeLeft
        } else {
            return translation.dy > 0 ? .swipeDown : .swipeUp
        }
    }
    
    private func calculateVelocity(from value: DragGesture.Value) -> CGVector {
        // Simple velocity estimation based on translation
        let timeDiff = Date().timeIntervalSince(lastInteractionTime)
        guard timeDiff > 0 else { return .zero }
        
        return CGVector(
            dx: value.translation.width / timeDiff,
            dy: value.translation.height / timeDiff
        )
    }
    
    private func setupNSEventMonitoring() {
        // Monitor for advanced trackpad gestures that SwiftUI doesn't handle
        NSEvent.addLocalMonitorForEvents(matching: [
            .magnify, .rotate, .swipe, .smartMagnify, .beginGesture, .endGesture
        ]) { event in
            Task { @MainActor in
                // Note: Since this is a struct, we can't capture self here
                // This is a limitation of the current architecture
            }
            return event
        }
    }
    
    private func handleAdvancedNSEvent(_ event: NSEvent) {
        switch event.type {
        case .beginGesture:
            handleGesturePhase(.began)
        case .endGesture:
            handleGesturePhase(.ended)
        case .magnify:
            handleNSMagnificationGesture(event)
        case .rotate:
            handleNSRotationGesture(event)
        case .swipe:
            handleNSSwipeGesture(event)
        case .smartMagnify:
            handleSmartMagnify(event)
        default:
            break
        }
    }
    
    private func handleNSMagnificationGesture(_ event: NSEvent) {
        guard gestureConfiguration.enablePinchToZoom else { return }
        
        let gestureData = GestureData(
            gestureType: .magnify,
            phase: .changed,
            scale: Double(event.magnification + 1.0)
        )
        
        processGestureEvent(gestureData, at: convertToLocalCoordinates(event.locationInWindow))
    }
    
    private func handleNSRotationGesture(_ event: NSEvent) {
        guard gestureConfiguration.enableRotation else { return }
        
        let gestureData = GestureData(
            gestureType: .rotation,
            phase: .changed,
            rotation: Double(event.rotation)
        )
        
        processGestureEvent(gestureData, at: convertToLocalCoordinates(event.locationInWindow))
    }
    
    private func handleNSSwipeGesture(_ event: NSEvent) {
        let swipeType: GestureType
        if abs(event.deltaX) > abs(event.deltaY) {
            swipeType = event.deltaX > 0 ? .swipeRight : .swipeLeft
        } else {
            swipeType = event.deltaY > 0 ? .swipeUp : .swipeDown
        }
        
        let gestureData = GestureData(
            gestureType: swipeType,
            phase: .ended,
            translation: CGVector(dx: event.deltaX, dy: event.deltaY)
        )
        
        processGestureEvent(gestureData, at: convertToLocalCoordinates(event.locationInWindow))
    }
    
    private func handleSmartMagnify(_ event: NSEvent) {
        let gestureData = GestureData(
            gestureType: .smartMagnify,
            phase: .ended
        )
        
        processGestureEvent(gestureData, at: convertToLocalCoordinates(event.locationInWindow))
    }
    
    private func handleGesturePhase(_ phase: GesturePhase) {
        if phase == .ended {
            currentGesture = nil
        }
    }
    
    private func processGestureEvent(_ gestureData: GestureData, at location: CGPoint) {
        
        // Find zones that can handle this gesture
        let handlingZones = zones.filter { zone in
            zone.isEnabled && 
            zone.frame.contains(location) && 
            zone.allowedGestures.contains(gestureData.gestureType)
        }.sorted { $0.priority > $1.priority }
        
        // Process in order of priority
        for zone in handlingZones {
            onZoneInteraction?(zone, gestureData)
        }
        
        // Also send to general interaction handler
        let interactionData = InteractionData(
            position: location,
            gestureData: gestureData
        )
        onInteraction?(interactionData)
        
        lastInteractionTime = Date()
    }
    
    private func convertToLocalCoordinates(_ windowPoint: CGPoint) -> CGPoint {
        // Convert window coordinates to local view coordinates
        // In a real implementation, this would use proper coordinate conversion
        return windowPoint
    }
}

// MARK: - Extensions

extension Set where Element == GestureType {
    var includesSwipeGestures: Bool {
        return contains(.swipeLeft) || contains(.swipeRight) ||
               contains(.swipeUp) || contains(.swipeDown)
    }
}


// MARK: - Preview

struct InteractionZoneView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionZoneView(
            zones: [
                InteractionZone(
                    frame: CGRect(x: 50, y: 50, width: 200, height: 200),
                    sensitivity: 1.0,
                    name: "Left Zone",
                    isEnabled: true,
                    priority: 1,
                    allowedGestures: [.tap, .swipeLeft, .swipeRight]
                ),
                InteractionZone(
                    frame: CGRect(x: 300, y: 50, width: 200, height: 200),
                    sensitivity: 0.8,
                    name: "Right Zone",
                    isEnabled: true,
                    priority: 2,
                    allowedGestures: [.magnify, .rotation]
                )
            ]
        ) { zone, gesture in
            print("Zone \(zone.id) interaction: \(gesture.gestureType)")
        } onInteraction: { data in
            print("General interaction at: \(data.position ?? .zero)")
        }
        .frame(width: 600, height: 400)
        .background(Color.gray.opacity(0.1))
    }
}