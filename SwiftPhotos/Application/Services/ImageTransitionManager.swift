import SwiftUI
import AppKit

/// Manager for handling image transition effects during slideshow
@MainActor
public class ImageTransitionManager: ObservableObject {
    @Published public private(set) var isTransitioning = false
    @Published public private(set) var transitionProgress: Double = 0.0
    
    private let transitionSettings: ModernTransitionSettingsManager
    private var currentTransitionTask: Task<Void, Never>?
    
    public init(transitionSettings: ModernTransitionSettingsManager) {
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
    
    /// Get transition modifier for SwiftUI views using Strategy pattern
    public func getTransitionModifier(for effectType: TransitionSettings.TransitionEffectType) -> AnyTransition {
        let strategy = TransitionStrategyFactory.strategy(for: effectType)
        return strategy.createSwiftUITransition()
    }
    
    /// Get animation for transition using Strategy pattern
    public func getAnimation() -> Animation? {
        let settings = transitionSettings.settings
        guard settings.isEnabled else { return nil }
        
        let strategy = TransitionStrategyFactory.strategy(for: settings.effectType)
        return strategy.getAnimation(duration: settings.duration, easing: settings.easing)
    }
    
    deinit {
        currentTransitionTask?.cancel()
    }
}

/// SwiftUI View extension for transition effects using Strategy pattern
public extension View {
    /// Apply transition effect based on settings using Strategy pattern
    func transitionEffect(
        manager: ImageTransitionManager,
        effectType: TransitionSettings.TransitionEffectType,
        isVisible: Bool,
        bounds: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 800)
    ) -> some View {
        let strategy = TransitionStrategyFactory.strategy(for: effectType)
        let progress = manager.isTransitioning ? manager.transitionProgress : (isVisible ? 1.0 : 0.0)
        
        return strategy.applyCustomEffects(
            to: self,
            progress: progress,
            isVisible: isVisible,
            bounds: bounds
        )
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
        let strategy = TransitionStrategyFactory.strategy(for: effectType)
        return strategy.createSwiftUITransition()
    }
    
    private func startPreview() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: duration + 0.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(easing.toSwiftUIAnimation(duration: duration)) {
                    isVisible.toggle()
                }
            }
        }
        
        // Start first animation after small delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            withAnimation(easing.toSwiftUIAnimation(duration: duration)) {
                isVisible.toggle()
            }
        }
    }
}