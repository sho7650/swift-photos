import SwiftUI
import Combine
import AppKit
import os.log

/// Controller for smooth gesture-driven animations with intelligent easing and physics
/// Provides high-performance animation management for gesture interactions
@MainActor
public class GestureAnimationController: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isAnimating: Bool = false
    @Published public var animationProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "PhotoSlideshow", category: "GestureAnimationController")
    private var activeAnimations: [UUID: GestureAnimation] = [:]
    private var animationUpdateTimer: Timer?
    
    // Animation configuration
    private let animationFrameRate: Double = 60.0 // 60fps
    private let animationUpdateInterval: TimeInterval
    
    // Physics configuration
    private let springDamping: Double = 0.75
    private let springResponse: Double = 0.4
    private let decelerationRate: Double = 0.92
    
    // MARK: - Initialization
    
    public init() {
        self.animationUpdateInterval = 1.0 / animationFrameRate
        logger.info("🎬 GestureAnimationController: Initialized with \\(animationFrameRate)fps animation engine")
        setupAnimationEngine()
    }
    
    deinit {
        animationUpdateTimer?.invalidate()
        animationUpdateTimer = nil
    }
    
    // MARK: - Public Interface
    
    /// Start a zoom animation with physics-based easing
    public func animateZoom(
        from startZoom: Double,
        to endZoom: Double,
        duration: TimeInterval = 0.3,
        easing: AnimationEasing = .easeInOut,
        completion: @escaping (Double) -> Void
    ) -> UUID {
        let animationId = UUID()
        
        let animation = GestureAnimation(
            id: animationId,
            type: .zoom,
            startValue: startZoom,
            endValue: endZoom,
            duration: duration,
            easing: easing,
            startTime: CACurrentMediaTime(),
            completion: { finalValue in
                if let doubleValue = finalValue as? Double {
                    completion(doubleValue)
                }
            }
        )
        
        activeAnimations[animationId] = animation
        startAnimationEngineIfNeeded()
        
        logger.debug("🎬 GestureAnimationController: Started zoom animation from \\(startZoom) to \\(endZoom)")
        return animationId
    }
    
    /// Start a position animation with momentum and deceleration
    public func animatePosition(
        from startPosition: CGPoint,
        to endPosition: CGPoint,
        duration: TimeInterval = 0.3,
        velocity: CGVector = .zero,
        easing: AnimationEasing = .easeOut,
        completion: @escaping (CGPoint) -> Void
    ) -> UUID {
        let animationId = UUID()
        
        let animation = GestureAnimation(
            id: animationId,
            type: .position,
            startPoint: startPosition,
            endPoint: endPosition,
            velocity: velocity,
            duration: duration,
            easing: easing,
            startTime: CACurrentMediaTime(),
            completion: { finalValue in
                if let point = finalValue as? CGPoint {
                    completion(point)
                }
            }
        )
        
        activeAnimations[animationId] = animation
        startAnimationEngineIfNeeded()
        
        logger.debug("🎬 GestureAnimationController: Started position animation with velocity \\(velocity)")
        return animationId
    }
    
    /// Start a spring-based animation with natural physics
    public func animateSpring(
        from startValue: Double,
        to endValue: Double,
        velocity: Double = 0.0,
        damping: Double? = nil,
        response: Double? = nil,
        completion: @escaping (Double) -> Void
    ) -> UUID {
        let animationId = UUID()
        
        let animation = GestureAnimation(
            id: animationId,
            type: .spring,
            startValue: startValue,
            endValue: endValue,
            velocity: CGVector(dx: velocity, dy: 0),
            duration: calculateSpringDuration(damping: damping ?? springDamping, response: response ?? springResponse),
            easing: .spring,
            startTime: CACurrentMediaTime(),
            springDamping: damping ?? springDamping,
            springResponse: response ?? springResponse,
            completion: { finalValue in
                if let doubleValue = finalValue as? Double {
                    completion(doubleValue)
                }
            }
        )
        
        activeAnimations[animationId] = animation
        startAnimationEngineIfNeeded()
        
        logger.debug("🎬 GestureAnimationController: Started spring animation with damping \\(animation.springDamping ?? 0)")
        return animationId
    }
    
    /// Create momentum-based deceleration animation
    public func animateDeceleration(
        from startValue: Double,
        velocity: Double,
        decelerationRate: Double? = nil,
        completion: @escaping (Double) -> Void
    ) -> UUID {
        let animationId = UUID()
        let effectiveDecelerationRate = decelerationRate ?? self.decelerationRate
        
        // Calculate final value based on velocity and deceleration
        let finalValue = startValue + (velocity / (1.0 - effectiveDecelerationRate))
        let duration = calculateDecelerationDuration(velocity: velocity, decelerationRate: effectiveDecelerationRate)
        
        let animation = GestureAnimation(
            id: animationId,
            type: .deceleration,
            startValue: startValue,
            endValue: finalValue,
            velocity: CGVector(dx: velocity, dy: 0),
            duration: duration,
            easing: .deceleration,
            startTime: CACurrentMediaTime(),
            decelerationRate: effectiveDecelerationRate,
            completion: { finalValue in
                if let doubleValue = finalValue as? Double {
                    completion(doubleValue)
                }
            }
        )
        
        activeAnimations[animationId] = animation
        startAnimationEngineIfNeeded()
        
        logger.debug("🎬 GestureAnimationController: Started deceleration animation with velocity \\(velocity)")
        return animationId
    }
    
    /// Cancel a specific animation
    public func cancelAnimation(_ animationId: UUID) {
        if let animation = activeAnimations.removeValue(forKey: animationId) {
            logger.debug("🎬 GestureAnimationController: Cancelled animation \\(animationId)")
            
            // Call completion with current progress
            let currentTime = CACurrentMediaTime()
            let progress = min(1.0, (currentTime - animation.startTime) / animation.duration)
            let currentValue = interpolateValue(animation: animation, progress: progress)
            animation.completion(currentValue)
        }
        
        stopAnimationEngineIfEmpty()
    }
    
    /// Cancel all active animations
    public func cancelAllAnimations() {
        let cancelledCount = activeAnimations.count
        activeAnimations.removeAll()
        stopAnimationEngine()
        
        if cancelledCount > 0 {
            logger.debug("🎬 GestureAnimationController: Cancelled all \\(cancelledCount) animations")
        }
    }
    
    /// Check if a specific animation is active
    public func isAnimationActive(_ animationId: UUID) -> Bool {
        return activeAnimations[animationId] != nil
    }
    
    /// Get the current progress of an animation (0.0 to 1.0)
    public func getAnimationProgress(_ animationId: UUID) -> Double {
        guard let animation = activeAnimations[animationId] else { return 0.0 }
        
        let currentTime = CACurrentMediaTime()
        return min(1.0, (currentTime - animation.startTime) / animation.duration)
    }
    
    // MARK: - Private Methods
    
    private func setupAnimationEngine() {
        // Animation engine will be started when first animation is added
    }
    
    private func startAnimationEngineIfNeeded() {
        guard animationUpdateTimer == nil && !activeAnimations.isEmpty else { return }
        
        animationUpdateTimer = Timer.scheduledTimer(withTimeInterval: animationUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimations()
            }
        }
        
        isAnimating = true
        logger.debug("🎬 GestureAnimationController: Started animation engine")
    }
    
    private func stopAnimationEngine() {
        animationUpdateTimer?.invalidate()
        animationUpdateTimer = nil
        isAnimating = false
        logger.debug("🎬 GestureAnimationController: Stopped animation engine")
    }
    
    private func stopAnimationEngineIfEmpty() {
        if activeAnimations.isEmpty {
            stopAnimationEngine()
        }
    }
    
    private func updateAnimations() {
        let currentTime = CACurrentMediaTime()
        var completedAnimations: [UUID] = []
        
        // Calculate total progress for UI
        var totalProgress: Double = 0.0
        
        for (animationId, animation) in activeAnimations {
            let elapsed = currentTime - animation.startTime
            let progress = min(1.0, elapsed / animation.duration)
            totalProgress += progress
            
            let currentValue = interpolateValue(animation: animation, progress: progress)
            
            // Update the animation target with the current value
            animation.updateCallback(currentValue)
            
            // Check if animation is complete
            if progress >= 1.0 {
                completedAnimations.append(animationId)
                animation.completion(currentValue)
            }
        }
        
        // Update overall progress
        animationProgress = activeAnimations.isEmpty ? 0.0 : totalProgress / Double(activeAnimations.count)
        
        // Remove completed animations
        for animationId in completedAnimations {
            activeAnimations.removeValue(forKey: animationId)
            logger.debug("🎬 GestureAnimationController: Animation \\(animationId) completed")
        }
        
        stopAnimationEngineIfEmpty()
    }
    
    private func interpolateValue(animation: GestureAnimation, progress: Double) -> Any {
        let easedProgress = applyEasing(progress: progress, easing: animation.easing, animation: animation)
        
        switch animation.type {
        case .zoom, .spring, .deceleration:
            return interpolateDouble(
                from: animation.startValue,
                to: animation.endValue,
                progress: easedProgress
            )
        case .position:
            return interpolatePoint(
                from: animation.startPoint ?? .zero,
                to: animation.endPoint ?? .zero,
                progress: easedProgress
            )
        }
    }
    
    private func interpolateDouble(from start: Double, to end: Double, progress: Double) -> Double {
        return start + (end - start) * progress
    }
    
    private func interpolatePoint(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        return CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
    
    private func applyEasing(progress: Double, easing: AnimationEasing, animation: GestureAnimation) -> Double {
        switch easing {
        case .linear:
            return progress
        case .easeIn:
            return progress * progress
        case .easeOut:
            return 1.0 - (1.0 - progress) * (1.0 - progress)
        case .easeInOut:
            return progress < 0.5 
                ? 2.0 * progress * progress 
                : 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
        case .spring:
            return applySpringEasing(progress: progress, animation: animation)
        case .deceleration:
            return applyDecelerationEasing(progress: progress, animation: animation)
        }
    }
    
    private func applySpringEasing(progress: Double, animation: GestureAnimation) -> Double {
        let damping = animation.springDamping ?? springDamping
        let response = animation.springResponse ?? springResponse
        
        // Simplified spring calculation
        let omega = 2.0 * Double.pi / response
        let dampedOmega = omega * sqrt(1.0 - damping * damping)
        let exponentialDecay = exp(-damping * omega * progress)
        
        return 1.0 - exponentialDecay * cos(dampedOmega * progress)
    }
    
    private func applyDecelerationEasing(progress: Double, animation: GestureAnimation) -> Double {
        let decelerationRate = animation.decelerationRate ?? self.decelerationRate
        return 1.0 - pow(decelerationRate, progress * 60.0) // 60fps assumption
    }
    
    private func calculateSpringDuration(damping: Double, response: Double) -> TimeInterval {
        // Estimate duration for spring to settle (within 1% of final value)
        let settlementThreshold = 0.01
        let omega = 2.0 * Double.pi / response
        
        if damping >= 1.0 {
            // Overdamped or critically damped
            return response * 4.0
        } else {
            // Underdamped
            let settlingTime = -log(settlementThreshold) / (damping * omega)
            return max(response, settlingTime)
        }
    }
    
    private func calculateDecelerationDuration(velocity: Double, decelerationRate: Double) -> TimeInterval {
        // Calculate time for velocity to reach negligible value
        let minVelocity = 0.1
        let frames = log(minVelocity / abs(velocity)) / log(decelerationRate)
        return max(0.1, frames / 60.0) // Convert frames to seconds at 60fps
    }
}

// MARK: - Supporting Types

/// Types of gesture animations
public enum GestureAnimationType {
    case zoom
    case position
    case spring
    case deceleration
}

/// Animation easing functions
public enum AnimationEasing {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring
    case deceleration
}

/// Internal animation representation
private class GestureAnimation {
    let id: UUID
    let type: GestureAnimationType
    let startValue: Double
    let endValue: Double
    let startPoint: CGPoint?
    let endPoint: CGPoint?
    let velocity: CGVector?
    let duration: TimeInterval
    let easing: AnimationEasing
    let startTime: TimeInterval
    let springDamping: Double?
    let springResponse: Double?
    let decelerationRate: Double?
    let completion: (Any) -> Void
    let updateCallback: (Any) -> Void
    
    init(
        id: UUID,
        type: GestureAnimationType,
        startValue: Double = 0.0,
        endValue: Double = 0.0,
        startPoint: CGPoint? = nil,
        endPoint: CGPoint? = nil,
        velocity: CGVector? = nil,
        duration: TimeInterval,
        easing: AnimationEasing,
        startTime: TimeInterval,
        springDamping: Double? = nil,
        springResponse: Double? = nil,
        decelerationRate: Double? = nil,
        completion: @escaping (Any) -> Void,
        updateCallback: @escaping (Any) -> Void = { _ in }
    ) {
        self.id = id
        self.type = type
        self.startValue = startValue
        self.endValue = endValue
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.velocity = velocity
        self.duration = duration
        self.easing = easing
        self.startTime = startTime
        self.springDamping = springDamping
        self.springResponse = springResponse
        self.decelerationRate = decelerationRate
        self.completion = completion
        self.updateCallback = updateCallback
    }
}

// MARK: - Convenience Extensions

public extension GestureAnimationController {
    /// Animate with SwiftUI's built-in animation types
    func animateWithSwiftUI(
        _ animation: Animation,
        _ updates: @escaping () -> Void
    ) {
        withAnimation(animation) {
            updates()
        }
    }
    
    /// Create smooth zoom transition animation
    func createZoomTransition(
        from startZoom: Double,
        to endZoom: Double,
        duration: TimeInterval = 0.3
    ) -> Animation {
        return .interpolatingSpring(
            mass: 1.0,
            stiffness: 100.0,
            damping: springDamping * 10.0,
            initialVelocity: 0.0
        )
        .speed(1.0 / duration)
    }
    
    /// Create position transition with momentum
    func createMomentumTransition(
        velocity: CGVector,
        decelerationRate: Double? = nil
    ) -> Animation {
        let effectiveRate = decelerationRate ?? self.decelerationRate
        return .interpolatingSpring(
            mass: 1.0,
            stiffness: 50.0,
            damping: (1.0 - effectiveRate) * 20.0,
            initialVelocity: sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy) / 100.0
        )
    }
}