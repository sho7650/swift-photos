import SwiftUI
import AppKit

/// Manager for handling image transition effects during slideshow
@MainActor
public class ImageTransitionManager: ObservableObject {
    @Published public private(set) var isTransitioning = false
    @Published public private(set) var transitionProgress: Double = 0.0
    
    private let transitionSettings: TransitionSettingsManager
    private var currentTransitionTask: Task<Void, Never>?
    
    public init(transitionSettings: TransitionSettingsManager) {
        self.transitionSettings = transitionSettings
        ProductionLogger.lifecycle("ImageTransitionManager: Initialized")
    }
    
    /// Execute transition between two images
    public func executeTransition<Content: View>(
        @ViewBuilder content: @escaping () -> Content,
        completion: @escaping () -> Void = {}
    ) async {
        guard transitionSettings.settings.isEnabled else {
            // No transition - execute immediately
            completion()
            return
        }
        
        // Cancel any ongoing transition
        currentTransitionTask?.cancel()
        
        currentTransitionTask = Task { @MainActor in
            await performTransition(completion: completion)
        }
        
        await currentTransitionTask?.value
    }
    
    /// Perform the actual transition animation
    private func performTransition(completion: @escaping () -> Void) async {
        let settings = transitionSettings.settings
        let duration = settings.duration
        
        isTransitioning = true
        transitionProgress = 0.0
        
        ProductionLogger.debug("ImageTransitionManager: Starting \(settings.effectType.displayName) transition (duration: \(duration)s)")
        
        // Create animation steps
        let steps = 60 // 60 FPS
        let stepDuration = duration / Double(steps)
        
        for step in 0...steps {
            if Task.isCancelled { break }
            
            let progress = Double(step) / Double(steps)
            transitionProgress = progress
            
            if step < steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
        }
        
        isTransitioning = false
        transitionProgress = 1.0
        completion()
        
        ProductionLogger.debug("ImageTransitionManager: Completed transition")
    }
    
    /// Cancel current transition
    public func cancelTransition() {
        currentTransitionTask?.cancel()
        currentTransitionTask = nil
        isTransitioning = false
        transitionProgress = 0.0
        ProductionLogger.debug("ImageTransitionManager: Cancelled transition")
    }
    
    /// Get transition modifier for SwiftUI views
    public func getTransitionModifier(for effectType: TransitionSettings.TransitionEffectType) -> AnyTransition {
        switch effectType {
        case .none:
            return .identity
            
        case .fade:
            return .opacity
            
        case .slideLeft:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
            
        case .slideRight:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
            
        case .slideUp:
            return .asymmetric(
                insertion: .move(edge: .bottom),
                removal: .move(edge: .top)
            )
            
        case .slideDown:
            return .asymmetric(
                insertion: .move(edge: .top),
                removal: .move(edge: .bottom)
            )
            
        case .zoomIn:
            return .asymmetric(
                insertion: .scale(scale: 0.1).combined(with: .opacity),
                removal: .scale(scale: 1.5).combined(with: .opacity)
            )
            
        case .zoomOut:
            return .asymmetric(
                insertion: .scale(scale: 1.5).combined(with: .opacity),
                removal: .scale(scale: 0.1).combined(with: .opacity)
            )
            
        case .rotateClockwise:
            return .asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .scale(scale: 1.5).combined(with: .opacity)
            )
            
        case .rotateCounterClockwise:
            return .asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .scale(scale: 1.5).combined(with: .opacity)
            )
            
        case .pushLeft:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
            
        case .pushRight:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
            
        case .crossfade:
            return .opacity
        }
    }
    
    /// Get animation for transition
    public func getAnimation() -> Animation? {
        let settings = transitionSettings.settings
        guard settings.isEnabled else { return nil }
        
        return settings.easing.toSwiftUIAnimation(duration: settings.duration)
    }
    
    deinit {
        currentTransitionTask?.cancel()
    }
}

/// SwiftUI View extension for transition effects
public extension View {
    /// Apply transition effect based on settings
    func transitionEffect(
        manager: ImageTransitionManager,
        effectType: TransitionSettings.TransitionEffectType,
        isVisible: Bool
    ) -> some View {
        self
            .opacity(manager.isTransitioning ? manager.transitionProgress : (isVisible ? 1.0 : 0.0))
            .scaleEffect(getScaleEffect(for: effectType, progress: manager.transitionProgress, isVisible: isVisible))
            .rotationEffect(getRotationEffect(for: effectType, progress: manager.transitionProgress))
            .offset(getOffsetEffect(for: effectType, progress: manager.transitionProgress, isVisible: isVisible))
    }
    
    private func getScaleEffect(
        for effectType: TransitionSettings.TransitionEffectType,
        progress: Double,
        isVisible: Bool
    ) -> CGFloat {
        switch effectType {
        case .zoomIn:
            if isVisible {
                return CGFloat(0.1 + (0.9 * progress))
            } else {
                return CGFloat(1.0 + (0.5 * progress))
            }
        case .zoomOut:
            if isVisible {
                return CGFloat(1.5 - (0.5 * progress))
            } else {
                return CGFloat(1.0 - (0.9 * progress))
            }
        default:
            return 1.0
        }
    }
    
    private func getRotationEffect(
        for effectType: TransitionSettings.TransitionEffectType,
        progress: Double
    ) -> Angle {
        switch effectType {
        case .rotateClockwise:
            return .degrees(-90 + (90 * progress))
        case .rotateCounterClockwise:
            return .degrees(90 - (90 * progress))
        default:
            return .degrees(0)
        }
    }
    
    private func getOffsetEffect(
        for effectType: TransitionSettings.TransitionEffectType,
        progress: Double,
        isVisible: Bool
    ) -> CGSize {
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let screenHeight = NSScreen.main?.frame.height ?? 800
        
        switch effectType {
        case .slideLeft:
            if isVisible {
                return CGSize(width: screenWidth * (1.0 - progress), height: 0)
            } else {
                return CGSize(width: -screenWidth * progress, height: 0)
            }
        case .slideRight:
            if isVisible {
                return CGSize(width: -screenWidth * (1.0 - progress), height: 0)
            } else {
                return CGSize(width: screenWidth * progress, height: 0)
            }
        case .slideUp:
            if isVisible {
                return CGSize(width: 0, height: screenHeight * (1.0 - progress))
            } else {
                return CGSize(width: 0, height: -screenHeight * progress)
            }
        case .slideDown:
            if isVisible {
                return CGSize(width: 0, height: -screenHeight * (1.0 - progress))
            } else {
                return CGSize(width: 0, height: screenHeight * progress)
            }
        case .pushLeft, .pushRight:
            // Push effects use combination of slide and fade
            return getOffsetEffect(
                for: effectType == .pushLeft ? .slideLeft : .slideRight,
                progress: progress,
                isVisible: isVisible
            )
        default:
            return .zero
        }
    }
}

/// Transition preview helper for settings UI
public struct TransitionPreview: View {
    let effectType: TransitionSettings.TransitionEffectType
    let duration: Double
    let easing: TransitionSettings.EasingFunction
    @State private var isVisible = true
    @State private var timer: Timer?
    
    public init(
        effectType: TransitionSettings.TransitionEffectType,
        duration: Double,
        easing: TransitionSettings.EasingFunction
    ) {
        self.effectType = effectType
        self.duration = duration
        self.easing = easing
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.3))
                .frame(width: 60, height: 40)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue)
                .frame(width: 60, height: 40)
                .transition(getTransition())
                .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            startPreview()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func getTransition() -> AnyTransition {
        switch effectType {
        case .none: return .identity
        case .fade: return .opacity
        case .slideLeft: return .move(edge: .leading)
        case .slideRight: return .move(edge: .trailing)
        case .slideUp: return .move(edge: .top)
        case .slideDown: return .move(edge: .bottom)
        case .zoomIn: return .scale(scale: 0.1).combined(with: .opacity)
        case .zoomOut: return .scale(scale: 1.5).combined(with: .opacity)
        case .rotateClockwise: return .scale(scale: 0.5).combined(with: .opacity)
        case .rotateCounterClockwise: return .scale(scale: 0.5).combined(with: .opacity)
        case .pushLeft: return .move(edge: .leading).combined(with: .opacity)
        case .pushRight: return .move(edge: .trailing).combined(with: .opacity)
        case .crossfade: return .opacity
        }
    }
    
    private func startPreview() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: duration + 0.5, repeats: true) { _ in
            withAnimation(easing.toSwiftUIAnimation(duration: duration)) {
                isVisible.toggle()
            }
        }
        
        // Start first animation after small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(easing.toSwiftUIAnimation(duration: duration)) {
                isVisible.toggle()
            }
        }
    }
}