import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Position Calculation Utilities

/// Utility functions for common position calculations and constraints
public enum PositionUtilities {
    
    // MARK: - Safe Area Calculations
    
    /// Calculate safe area insets for macOS windows
    public static func calculateSafeAreaInsets(for bounds: CGRect) -> EdgeInsets {
        // macOS specific safe area considerations
        let topInset: Double = 28 // For title bar
        let bottomInset: Double = 0 // No home indicator on macOS
        let sideInset: Double = 0 // No notches on macOS
        
        return EdgeInsets(
            top: topInset,
            leading: sideInset,
            bottom: bottomInset,
            trailing: sideInset
        )
    }
    
    /// Apply safe area insets to bounds
    public static func applySafeAreaInsets(_ insets: EdgeInsets, to bounds: CGRect) -> CGRect {
        return CGRect(
            x: bounds.minX + insets.leading,
            y: bounds.minY + insets.bottom,
            width: bounds.width - insets.leading - insets.trailing,
            height: bounds.height - insets.top - insets.bottom
        )
    }
    
    // MARK: - Distance Calculations
    
    /// Calculate distance between two points
    public static func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate minimum distance between a point and a rectangle
    public static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(0, max(rect.minX - point.x, point.x - rect.maxX))
        let dy = max(0, max(rect.minY - point.y, point.y - rect.maxY))
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Check if two rectangles overlap with a margin
    public static func rectanglesOverlap(_ rect1: CGRect, _ rect2: CGRect, margin: CGFloat = 0) -> Bool {
        let expandedRect1 = rect1.insetBy(dx: -margin, dy: -margin)
        return expandedRect1.intersects(rect2)
    }
    
    // MARK: - Anchor Point Calculations
    
    /// Calculate anchor points for a rectangle
    public static func anchorPoints(for rect: CGRect) -> [CGPoint] {
        return [
            // Corners
            CGPoint(x: rect.minX, y: rect.minY), // Top-left
            CGPoint(x: rect.maxX, y: rect.minY), // Top-right
            CGPoint(x: rect.minX, y: rect.maxY), // Bottom-left
            CGPoint(x: rect.maxX, y: rect.maxY), // Bottom-right
            
            // Edge centers
            CGPoint(x: rect.midX, y: rect.minY), // Top-center
            CGPoint(x: rect.midX, y: rect.maxY), // Bottom-center
            CGPoint(x: rect.minX, y: rect.midY), // Left-center
            CGPoint(x: rect.maxX, y: rect.midY), // Right-center
            
            // Center
            CGPoint(x: rect.midX, y: rect.midY)
        ]
    }
    
    /// Find the nearest anchor point to a given position
    public static func nearestAnchorPoint(to position: CGPoint, in rect: CGRect) -> CGPoint {
        let anchors = anchorPoints(for: rect)
        
        return anchors.min { anchor1, anchor2 in
            distance(from: position, to: anchor1) < distance(from: position, to: anchor2)
        } ?? CGPoint(x: rect.midX, y: rect.midY)
    }
    
    // MARK: - Grid Positioning
    
    /// Calculate grid positions within bounds
    public static func gridPositions(
        in bounds: CGRect,
        rows: Int,
        columns: Int,
        spacing: CGFloat = 20
    ) -> [[CGPoint]] {
        let cellWidth = (bounds.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
        let cellHeight = (bounds.height - spacing * CGFloat(rows + 1)) / CGFloat(rows)
        
        var grid: [[CGPoint]] = []
        
        for row in 0..<rows {
            var rowPoints: [CGPoint] = []
            for col in 0..<columns {
                let x = bounds.minX + spacing + CGFloat(col) * (cellWidth + spacing) + cellWidth / 2
                let y = bounds.minY + spacing + CGFloat(row) * (cellHeight + spacing) + cellHeight / 2
                rowPoints.append(CGPoint(x: x, y: y))
            }
            grid.append(rowPoints)
        }
        
        return grid
    }
    
    /// Find the nearest grid position
    public static func nearestGridPosition(
        to position: CGPoint,
        in bounds: CGRect,
        rows: Int,
        columns: Int,
        spacing: CGFloat = 20
    ) -> CGPoint {
        let grid = gridPositions(in: bounds, rows: rows, columns: columns, spacing: spacing)
        var nearest = CGPoint(x: bounds.midX, y: bounds.midY)
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for row in grid {
            for point in row {
                let dist = distance(from: position, to: point)
                if dist < minDistance {
                    minDistance = dist
                    nearest = point
                }
            }
        }
        
        return nearest
    }
    
    // MARK: - Constraint Validation
    
    /// Validate position against constraints
    public static func validatePosition(
        _ position: CGPoint,
        size: CGSize,
        constraints: PositionConstraints
    ) -> (isValid: Bool, violations: [String]) {
        var violations: [String] = []
        
        let rect = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        // Check bounds constraint
        if !constraints.bounds.contains(rect) {
            violations.append("Position extends outside bounds")
        }
        
        // Check margin constraints
        let marginsRect = CGRect(
            x: constraints.bounds.minX + constraints.margins.leading,
            y: constraints.bounds.minY + constraints.margins.bottom,
            width: constraints.bounds.width - constraints.margins.leading - constraints.margins.trailing,
            height: constraints.bounds.height - constraints.margins.top - constraints.margins.bottom
        )
        
        if !marginsRect.contains(rect) {
            violations.append("Position violates margin constraints")
        }
        
        // Check obstacle constraints
        for (index, obstacle) in constraints.obstacles.enumerated() {
            if rect.intersects(obstacle) {
                violations.append("Position conflicts with obstacle \(index + 1)")
            }
        }
        
        // Check minimum spacing
        for (index, obstacle) in constraints.obstacles.enumerated() {
            if distance(from: position, to: obstacle) < constraints.minimumSpacing {
                violations.append("Position too close to obstacle \(index + 1)")
            }
        }
        
        return (violations.isEmpty, violations)
    }
    
    // MARK: - Animation Utilities
    
    /// Calculate optimal animation duration based on distance
    public static func optimalAnimationDuration(
        from startPosition: CGPoint,
        to endPosition: CGPoint,
        baseSpeed: CGFloat = 500, // points per second
        minimumDuration: TimeInterval = 0.1,
        maximumDuration: TimeInterval = 1.0
    ) -> TimeInterval {
        let distance = distance(from: startPosition, to: endPosition)
        let calculatedDuration = TimeInterval(distance / baseSpeed)
        
        return max(minimumDuration, min(maximumDuration, calculatedDuration))
    }
    
    /// Create easing curve for position animations
    public static func easingCurve(for animationType: PositionAnimationType) -> Animation {
        switch animationType {
        case .linear:
            return .linear
        case .easeIn:
            return .easeIn
        case .easeOut:
            return .easeOut
        case .easeInOut:
            return .easeInOut
        case .spring:
            return .spring(response: 0.6, dampingFraction: 0.8)
        case .bouncy:
            return .spring(response: 0.4, dampingFraction: 0.6)
        }
    }
    
    // MARK: - Collision Detection
    
    /// Advanced collision detection with prediction
    public static func predictCollision(
        movingRect: CGRect,
        velocity: CGVector,
        staticObstacles: [CGRect],
        timeHorizon: TimeInterval = 1.0
    ) -> CollisionPrediction? {
        let futurePosition = CGPoint(
            x: movingRect.midX + velocity.dx * timeHorizon,
            y: movingRect.midY + velocity.dy * timeHorizon
        )
        
        let futureRect = CGRect(
            x: futurePosition.x - movingRect.width / 2,
            y: futurePosition.y - movingRect.height / 2,
            width: movingRect.width,
            height: movingRect.height
        )
        
        for (index, obstacle) in staticObstacles.enumerated() {
            if futureRect.intersects(obstacle) {
                // Calculate time to collision
                let timeToCollision = calculateTimeToCollision(
                    movingRect: movingRect,
                    velocity: velocity,
                    obstacle: obstacle
                )
                
                return CollisionPrediction(
                    willCollide: true,
                    timeToCollision: timeToCollision,
                    obstacleIndex: index,
                    collisionPoint: futurePosition
                )
            }
        }
        
        return nil
    }
    
    private static func calculateTimeToCollision(
        movingRect: CGRect,
        velocity: CGVector,
        obstacle: CGRect
    ) -> TimeInterval {
        // Simplified collision time calculation
        // In practice, this would be more sophisticated
        
        let dx = velocity.dx
        let dy = velocity.dy
        
        if abs(dx) < 0.001 && abs(dy) < 0.001 {
            return .infinity // No movement
        }
        
        // Calculate time for x and y directions
        let timeX: TimeInterval
        if dx > 0 {
            timeX = TimeInterval((obstacle.minX - movingRect.maxX) / dx)
        } else if dx < 0 {
            timeX = TimeInterval((obstacle.maxX - movingRect.minX) / dx)
        } else {
            timeX = .infinity
        }
        
        let timeY: TimeInterval
        if dy > 0 {
            timeY = TimeInterval((obstacle.minY - movingRect.maxY) / dy)
        } else if dy < 0 {
            timeY = TimeInterval((obstacle.maxY - movingRect.minY) / dy)
        } else {
            timeY = .infinity
        }
        
        return max(0, max(timeX, timeY))
    }
    
    // MARK: - Screen Adaptation
    
    /// Adapt position for different screen sizes
    public static func adaptPositionForScreen(
        _ position: CGPoint,
        fromBounds: CGRect,
        toBounds: CGRect,
        adaptationMode: ScreenAdaptationMode = .proportional
    ) -> CGPoint {
        switch adaptationMode {
        case .proportional:
            let xRatio = toBounds.width / fromBounds.width
            let yRatio = toBounds.height / fromBounds.height
            
            return CGPoint(
                x: toBounds.minX + (position.x - fromBounds.minX) * xRatio,
                y: toBounds.minY + (position.y - fromBounds.minY) * yRatio
            )
            
        case .absolute:
            // Keep absolute position, but ensure it's within new bounds
            let clampedX = max(toBounds.minX, min(toBounds.maxX, position.x))
            let clampedY = max(toBounds.minY, min(toBounds.maxY, position.y))
            
            return CGPoint(x: clampedX, y: clampedY)
            
        case .anchored(let anchor):
            return anchorPosition(anchor, in: toBounds)
        }
    }
    
    private static func anchorPosition(_ anchor: PositionAnchor, in bounds: CGRect) -> CGPoint {
        switch anchor {
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topCenter:
            return CGPoint(x: bounds.midX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .centerLeft:
            return CGPoint(x: bounds.minX, y: bounds.midY)
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .centerRight:
            return CGPoint(x: bounds.maxX, y: bounds.midY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomCenter:
            return CGPoint(x: bounds.midX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
}

// MARK: - Supporting Types

/// Animation types for position transitions
public enum PositionAnimationType {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring
    case bouncy
}

/// Collision prediction result
public struct CollisionPrediction {
    public let willCollide: Bool
    public let timeToCollision: TimeInterval
    public let obstacleIndex: Int
    public let collisionPoint: CGPoint
}

/// Screen adaptation modes
public enum ScreenAdaptationMode {
    case proportional
    case absolute
    case anchored(PositionAnchor)
}

/// Position anchors for screen adaptation
public enum PositionAnchor {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight
}

// MARK: - Position Constraint Builders

/// Builder for creating complex position constraints
public class PositionConstraintBuilder {
    private var constraints: [PositionConstraint] = []
    
    public init() {}
    
    /// Add a boundary constraint
    public func withinBounds(_ bounds: CGRect, priority: Int = 100) -> PositionConstraintBuilder {
        constraints.append(
            PositionConstraint(
                type: .stayWithinBounds,
                area: bounds,
                priority: priority,
                isEnabled: true
            )
        )
        return self
    }
    
    /// Add an area to avoid
    public func avoiding(_ area: CGRect, priority: Int = 80) -> PositionConstraintBuilder {
        constraints.append(
            PositionConstraint(
                type: .avoidArea,
                area: area,
                priority: priority,
                isEnabled: true
            )
        )
        return self
    }
    
    /// Add a preferred area
    public func preferring(_ area: CGRect, priority: Int = 50) -> PositionConstraintBuilder {
        constraints.append(
            PositionConstraint(
                type: .preferArea,
                area: area,
                priority: priority,
                isEnabled: true
            )
        )
        return self
    }
    
    /// Add minimum distance constraint
    public func minimumDistance(_ distance: Double, priority: Int = 60) -> PositionConstraintBuilder {
        constraints.append(
            PositionConstraint(
                id: UUID(),
                type: .minimumDistance,
                area: nil,
                priority: priority,
                isEnabled: true
            )
        )
        return self
    }
    
    /// Build the constraints array
    public func build() -> [PositionConstraint] {
        return constraints
    }
}

// MARK: - Convenience Extensions

public extension CGRect {
    /// Check if this rectangle contains another rectangle with a margin
    func contains(_ rect: CGRect, margin: CGFloat) -> Bool {
        let expandedSelf = self.insetBy(dx: -margin, dy: -margin)
        return expandedSelf.contains(rect)
    }
    
    /// Get the center point of the rectangle
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    /// Create a rectangle centered at a point
    static func centered(at point: CGPoint, size: CGSize) -> CGRect {
        return CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

public extension CGPoint {
    /// Calculate distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        return PositionUtilities.distance(from: self, to: other)
    }
    
    /// Move point by a vector
    func moved(by vector: CGVector) -> CGPoint {
        return CGPoint(x: x + vector.dx, y: y + vector.dy)
    }
    
    /// Clamp point within bounds
    func clamped(to bounds: CGRect) -> CGPoint {
        return CGPoint(
            x: max(bounds.minX, min(bounds.maxX, x)),
            y: max(bounds.minY, min(bounds.maxY, y))
        )
    }
}