import SwiftUI
import Foundation
import os.log

/// Simple SwiftUI view for invisible gesture detection areas
/// Works with InteractionZoneManager for zone-based gesture handling
public struct SimpleInteractionZoneView: View {
    
    // MARK: - Properties
    
    @ObservedObject private var zoneManager: InteractionZoneManager
    @State private var isActive: Bool = true
    private let logger = Logger(subsystem: "PhotoSlideshow", category: "SimpleInteractionZoneView")
    
    // MARK: - Initialization
    
    public init(zoneManager: InteractionZoneManager) {
        self.zoneManager = zoneManager
    }
    
    // MARK: - View Body
    
    public var body: some View {
        ZStack {
            // Invisible background that captures all gestures
            Color.clear
                .contentShape(Rectangle())
                .clipped()
                .gesture(combinedGesture)
                .allowsHitTesting(isActive && zoneManager.isEnabled)
            
            // Individual interaction zones (invisible but detectable)
            ForEach(zoneManager.zones.filter { $0.isEnabled }, id: \.id) { zone in
                zoneOverlay(for: zone)
            }
        }
        .onAppear {
            logger.info("🎯 SimpleInteractionZoneView: Appeared with \(zoneManager.zones.count) zones")
        }
        .onDisappear {
            logger.info("🎯 SimpleInteractionZoneView: Disappeared")
        }
    }
    
    // MARK: - Zone Overlay
    
    @ViewBuilder
    private func zoneOverlay(for zone: InteractionZone) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: zone.frame.width, height: zone.frame.height)
            .position(x: zone.frame.midX, y: zone.frame.midY)
            .contentShape(Rectangle())
            .gesture(zoneSpecificGesture(for: zone))
            .allowsHitTesting(zone.isEnabled && zoneManager.isEnabled)
    }
    
    // MARK: - Gesture Handling
    
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                magnifyGesture,
                rotateGesture
            ),
            SimultaneousGesture(
                dragGesture,
                tapGesture
            )
        )
    }
    
    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let gestureData = GestureData(
                    gestureType: .magnify,
                    phase: .changed,
                    scale: Double(value)
                )
                handleGesture(gestureData, at: getCurrentLocation())
            }
            .onEnded { value in
                let gestureData = GestureData(
                    gestureType: .magnify,
                    phase: .ended,
                    scale: Double(value)
                )
                handleGesture(gestureData, at: getCurrentLocation())
            }
    }
    
    private var rotateGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                let gestureData = GestureData(
                    gestureType: .rotation,
                    phase: .changed,
                    rotation: value.radians
                )
                handleGesture(gestureData, at: getCurrentLocation())
            }
            .onEnded { value in
                let gestureData = GestureData(
                    gestureType: .rotation,
                    phase: .ended,
                    rotation: value.radians
                )
                handleGesture(gestureData, at: getCurrentLocation())
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let gestureData = GestureData(
                    gestureType: .pan,
                    phase: .changed,
                    translation: CGVector(dx: value.translation.width, dy: value.translation.height)
                )
                handleGesture(gestureData, at: value.location)
            }
            .onEnded { value in
                let gestureData = GestureData(
                    gestureType: .pan,
                    phase: .ended,
                    translation: CGVector(dx: value.translation.width, dy: value.translation.height)
                )
                handleGesture(gestureData, at: value.location)
            }
    }
    
    private var tapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded { _ in
                let gestureData = GestureData(
                    gestureType: .tap,
                    phase: .ended
                )
                handleGesture(gestureData, at: getCurrentLocation())
            }
    }
    
    private func zoneSpecificGesture(for zone: InteractionZone) -> some Gesture {
        let allowedGestures = zone.allowedGestures
        
        // Simple approach: just use tap gesture for zones
        return TapGesture()
            .onEnded { _ in
                let gestureData = GestureData(gestureType: .tap, phase: .ended)
                handleZoneGesture(gestureData, in: zone, at: CGPoint(x: zone.frame.midX, y: zone.frame.midY))
            }
    }
    
    // MARK: - Gesture Processing
    
    private func handleGesture(_ gestureData: GestureData, at location: CGPoint) {
        guard zoneManager.isGestureAllowed(gestureData.gestureType, at: location) else {
            return
        }
        
        zoneManager.processGesture(gestureData, at: location)
    }
    
    private func handleZoneGesture(_ gestureData: GestureData, in zone: InteractionZone, at location: CGPoint) {
        guard zone.allowedGestures.contains(gestureData.gestureType) else {
            return
        }
        
        logger.debug("🎯 SimpleInteractionZoneView: Zone gesture \(gestureData.gestureType.rawValue) in zone '\(zone.name)'")
        zoneManager.processGesture(gestureData, at: location)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentLocation() -> CGPoint {
        // In a real implementation, this would get the actual gesture location
        // For now, return center of view
        return CGPoint(x: 0, y: 0)
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable gesture detection
    public func setActive(_ active: Bool) {
        isActive = active
    }
    
    /// Setup common interaction zones within the given bounds
    public func setupCommonZones(in bounds: CGRect) {
        zoneManager.setupCommonZones(in: bounds)
    }
}