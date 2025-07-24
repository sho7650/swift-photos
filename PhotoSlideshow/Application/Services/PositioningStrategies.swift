import Foundation
import CoreGraphics

// MARK: - Positioning Strategies

/// Fixed positioning strategy for predictable layouts
public class FixedPositioningStrategy: PositioningStrategy {
    private let positions: [OverlayType: CGPoint]
    
    public init(positions: [OverlayType: CGPoint]) {
        self.positions = positions
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        return positions[overlay] ?? CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        let size = overlay.defaultSize
        let overlayFrame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        return constraints.bounds.contains(overlayFrame)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        if let position = positions[overlay] {
            let size = overlay.defaultSize
            return [CGRect(
                x: position.x - size.width / 2,
                y: position.y - size.height / 2,
                width: size.width,
                height: size.height
            )]
        }
        return []
    }
}

/// Edge-based positioning strategy that positions overlays along screen edges
public class EdgePositioningStrategy: PositioningStrategy {
    public enum Edge {
        case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }
    
    private let edgeMappings: [OverlayType: Edge]
    private let margin: CGFloat
    
    public init(edgeMappings: [OverlayType: Edge] = [:], margin: CGFloat = 20) {
        self.edgeMappings = edgeMappings
        self.margin = margin
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        let edge = edgeMappings[overlay] ?? getDefaultEdge(for: overlay)
        let size = overlay.defaultSize
        
        let basePosition = calculateEdgePosition(edge: edge, size: size, bounds: bounds)
        
        // Check for conflicts and adjust if necessary
        if hasConflicts(at: basePosition, size: size, obstacles: obstacles) {
            return findAlternativeEdgePosition(for: overlay, size: size, bounds: bounds, obstacles: obstacles)
        }
        
        return basePosition
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        let size = overlay.defaultSize
        let overlayFrame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        // Check bounds
        if !constraints.bounds.contains(overlayFrame) {
            return false
        }
        
        // Check obstacles
        for obstacle in constraints.obstacles {
            if overlayFrame.intersects(obstacle) {
                return false
            }
        }
        
        return true
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        let edge = edgeMappings[overlay] ?? getDefaultEdge(for: overlay)
        let zoneSize: CGFloat = 100
        
        switch edge {
        case .top:
            return [CGRect(x: 0, y: 0, width: bounds.width, height: zoneSize)]
        case .bottom:
            return [CGRect(x: 0, y: bounds.height - zoneSize, width: bounds.width, height: zoneSize)]
        case .left:
            return [CGRect(x: 0, y: 0, width: zoneSize, height: bounds.height)]
        case .right:
            return [CGRect(x: bounds.width - zoneSize, y: 0, width: zoneSize, height: bounds.height)]
        case .topLeft:
            return [CGRect(x: 0, y: 0, width: zoneSize, height: zoneSize)]
        case .topRight:
            return [CGRect(x: bounds.width - zoneSize, y: 0, width: zoneSize, height: zoneSize)]
        case .bottomLeft:
            return [CGRect(x: 0, y: bounds.height - zoneSize, width: zoneSize, height: zoneSize)]
        case .bottomRight:
            return [CGRect(x: bounds.width - zoneSize, y: bounds.height - zoneSize, width: zoneSize, height: zoneSize)]
        }
    }
    
    private func getDefaultEdge(for overlay: OverlayType) -> Edge {
        switch overlay {
        case .controls: return .bottom
        case .information: return .bottom
        case .progress: return .top
        case .menu: return .topRight
        case .tooltip: return .topRight
        case .notification: return .topRight
        }
    }
    
    private func calculateEdgePosition(edge: Edge, size: CGSize, bounds: CGRect) -> CGPoint {
        switch edge {
        case .top:
            return CGPoint(x: bounds.midX, y: margin + size.height / 2)
        case .bottom:
            return CGPoint(x: bounds.midX, y: bounds.height - margin - size.height / 2)
        case .left:
            return CGPoint(x: margin + size.width / 2, y: bounds.midY)
        case .right:
            return CGPoint(x: bounds.width - margin - size.width / 2, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: margin + size.width / 2, y: margin + size.height / 2)
        case .topRight:
            return CGPoint(x: bounds.width - margin - size.width / 2, y: margin + size.height / 2)
        case .bottomLeft:
            return CGPoint(x: margin + size.width / 2, y: bounds.height - margin - size.height / 2)
        case .bottomRight:
            return CGPoint(x: bounds.width - margin - size.width / 2, y: bounds.height - margin - size.height / 2)
        }
    }
    
    private func hasConflicts(at position: CGPoint, size: CGSize, obstacles: [CGRect]) -> Bool {
        let frame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        for obstacle in obstacles {
            if frame.intersects(obstacle) {
                return true
            }
        }
        
        return false
    }
    
    private func findAlternativeEdgePosition(for overlay: OverlayType, size: CGSize, bounds: CGRect, obstacles: [CGRect]) -> CGPoint {
        let allEdges: [Edge] = [.top, .bottom, .left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight]
        
        for edge in allEdges {
            let position = calculateEdgePosition(edge: edge, size: size, bounds: bounds)
            if !hasConflicts(at: position, size: size, obstacles: obstacles) {
                return position
            }
        }
        
        // Fallback to center
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

/// Grid-based positioning strategy that arranges overlays in a grid pattern
public class GridPositioningStrategy: PositioningStrategy {
    private let gridSize: Int
    private let spacing: CGFloat
    
    public init(gridSize: Int = 3, spacing: CGFloat = 20) {
        self.gridSize = gridSize
        self.spacing = spacing
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        let cellWidth = (bounds.width - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)
        let cellHeight = (bounds.height - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)
        
        // Try to find an empty grid cell
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = spacing + CGFloat(col) * (cellWidth + spacing) + cellWidth / 2
                let y = spacing + CGFloat(row) * (cellHeight + spacing) + cellHeight / 2
                let position = CGPoint(x: x, y: y)
                
                let size = overlay.defaultSize
                let frame = CGRect(
                    x: position.x - size.width / 2,
                    y: position.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                
                // Check if this cell is free
                var isFree = true
                for obstacle in obstacles {
                    if frame.intersects(obstacle) {
                        isFree = false
                        break
                    }
                }
                
                if isFree {
                    return position
                }
            }
        }
        
        // Fallback to center if no grid cells are available
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        let size = overlay.defaultSize
        let overlayFrame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        return constraints.bounds.contains(overlayFrame)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        let cellWidth = (bounds.width - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)
        let cellHeight = (bounds.height - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)
        
        var zones: [CGRect] = []
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = spacing + CGFloat(col) * (cellWidth + spacing)
                let y = spacing + CGFloat(row) * (cellHeight + spacing)
                zones.append(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
            }
        }
        
        return zones
    }
}

/// Magnetic positioning strategy that attracts overlays to predefined anchor points
public class MagneticPositioningStrategy: PositioningStrategy {
    private let anchorPoints: [CGPoint]
    private let magneticRadius: CGFloat
    
    public init(anchorPoints: [CGPoint], magneticRadius: CGFloat = 50) {
        self.anchorPoints = anchorPoints
        self.magneticRadius = magneticRadius
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        let size = overlay.defaultSize
        
        // Find the nearest available anchor point
        for anchor in anchorPoints {
            let frame = CGRect(
                x: anchor.x - size.width / 2,
                y: anchor.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            
            // Check if this anchor point is free
            var isFree = true
            for obstacle in obstacles {
                if frame.intersects(obstacle) {
                    isFree = false
                    break
                }
            }
            
            if isFree && bounds.contains(frame) {
                return anchor
            }
        }
        
        // If no anchor points are available, find the closest free position near an anchor
        for anchor in anchorPoints {
            if let position = findNearbyPosition(anchor: anchor, size: size, bounds: bounds, obstacles: obstacles) {
                return position
            }
        }
        
        // Fallback to center
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        let size = overlay.defaultSize
        let overlayFrame = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        return constraints.bounds.contains(overlayFrame)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        return anchorPoints.map { anchor in
            CGRect(
                x: anchor.x - magneticRadius,
                y: anchor.y - magneticRadius,
                width: magneticRadius * 2,
                height: magneticRadius * 2
            )
        }
    }
    
    private func findNearbyPosition(anchor: CGPoint, size: CGSize, bounds: CGRect, obstacles: [CGRect]) -> CGPoint? {
        let stepSize: CGFloat = 10
        
        for radius in stride(from: stepSize, through: magneticRadius, by: stepSize) {
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 8) {
                let x = anchor.x + radius * cos(angle)
                let y = anchor.y + radius * sin(angle)
                let position = CGPoint(x: x, y: y)
                
                let frame = CGRect(
                    x: x - size.width / 2,
                    y: y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                
                if bounds.contains(frame) {
                    var hasConflict = false
                    for obstacle in obstacles {
                        if frame.intersects(obstacle) {
                            hasConflict = true
                            break
                        }
                    }
                    
                    if !hasConflict {
                        return position
                    }
                }
            }
        }
        
        return nil
    }
}

/// Adaptive positioning strategy that learns from user preferences
public class AdaptivePositioningStrategy: PositioningStrategy {
    private var userPreferences: [OverlayType: [CGPoint]] = [:]
    private let fallbackStrategy: PositioningStrategy
    private let learningWeight: Double
    
    public init(fallbackStrategy: PositioningStrategy = SmartPositioningStrategy(), learningWeight: Double = 0.8) {
        self.fallbackStrategy = fallbackStrategy
        self.learningWeight = learningWeight
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        // Check if we have learned preferences for this overlay type
        if let preferences = userPreferences[overlay], !preferences.isEmpty {
            // Find the most suitable learned position
            for preferredPosition in preferences {
                let size = overlay.defaultSize
                let frame = CGRect(
                    x: preferredPosition.x - size.width / 2,
                    y: preferredPosition.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                
                if bounds.contains(frame) {
                    var hasConflict = false
                    for obstacle in obstacles {
                        if frame.intersects(obstacle) {
                            hasConflict = true
                            break
                        }
                    }
                    
                    if !hasConflict {
                        return preferredPosition
                    }
                }
            }
        }
        
        // Fall back to the base strategy
        return fallbackStrategy.position(for: overlay, in: bounds, avoiding: obstacles)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        return fallbackStrategy.validatePosition(position, for: overlay, constraints: constraints)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        return fallbackStrategy.getPreferredZones(for: overlay, in: bounds)
    }
    
    /// Learn from user positioning behavior
    public func learnFromUserPosition(_ position: CGPoint, for overlay: OverlayType) {
        if userPreferences[overlay] == nil {
            userPreferences[overlay] = []
        }
        
        // Add new preference with weight-based influence
        userPreferences[overlay]?.append(position)
        
        // Limit the number of stored preferences to prevent memory growth
        if let count = userPreferences[overlay]?.count, count > 10 {
            userPreferences[overlay] = Array(userPreferences[overlay]!.suffix(10))
        }
    }
    
    /// Reset learned preferences
    public func resetLearning(for overlay: OverlayType? = nil) {
        if let overlay = overlay {
            userPreferences[overlay] = []
        } else {
            userPreferences.removeAll()
        }
    }
}

// MARK: - Strategy Factory

/// Factory for creating positioning strategies with common configurations
public class PositioningStrategyFactory {
    
    /// Create a smart strategy with collision avoidance
    public static func createSmartStrategy() -> PositioningStrategy {
        return SmartPositioningStrategy()
    }
    
    /// Create an edge-based strategy for minimal UI
    public static func createMinimalStrategy() -> PositioningStrategy {
        let edgeMappings: [OverlayType: EdgePositioningStrategy.Edge] = [
            .controls: .bottom,
            .information: .bottomLeft,
            .progress: .top,
            .menu: .topRight,
            .tooltip: .topRight,
            .notification: .topRight
        ]
        return EdgePositioningStrategy(edgeMappings: edgeMappings, margin: 10)
    }
    
    /// Create a grid strategy for organized layouts
    public static func createGridStrategy(gridSize: Int = 3) -> PositioningStrategy {
        return GridPositioningStrategy(gridSize: gridSize, spacing: 20)
    }
    
    /// Create a magnetic strategy with common anchor points
    public static func createMagneticStrategy(for bounds: CGRect) -> PositioningStrategy {
        let anchors = [
            // Corners
            CGPoint(x: bounds.minX + 50, y: bounds.minY + 50),
            CGPoint(x: bounds.maxX - 50, y: bounds.minY + 50),
            CGPoint(x: bounds.minX + 50, y: bounds.maxY - 50),
            CGPoint(x: bounds.maxX - 50, y: bounds.maxY - 50),
            
            // Centers of edges
            CGPoint(x: bounds.midX, y: bounds.minY + 50),
            CGPoint(x: bounds.midX, y: bounds.maxY - 50),
            CGPoint(x: bounds.minX + 50, y: bounds.midY),
            CGPoint(x: bounds.maxX - 50, y: bounds.midY),
            
            // Center
            CGPoint(x: bounds.midX, y: bounds.midY)
        ]
        
        return MagneticPositioningStrategy(anchorPoints: anchors, magneticRadius: 100)
    }
    
    /// Create an adaptive strategy that learns from user behavior
    public static func createAdaptiveStrategy(basedOn fallback: PositioningStrategy? = nil) -> AdaptivePositioningStrategy {
        let fallbackStrategy = fallback ?? createSmartStrategy()
        return AdaptivePositioningStrategy(fallbackStrategy: fallbackStrategy, learningWeight: 0.8)
    }
}