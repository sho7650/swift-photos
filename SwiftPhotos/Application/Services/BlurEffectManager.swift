import SwiftUI
import Combine
import os.log

/// Advanced blur effect manager with customizable styles, animations, and performance optimization
/// Provides centralized blur management for all overlay components
@MainActor
public class BlurEffectManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentStyle: BlurStyle = .regular
    @Published public var isPerformanceMode: Bool = false
    @Published public var globalBlurIntensity: Double = 1.0
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "BlurEffectManager")
    private var cachedEffects: [BlurEffectKey: BlurEffectConfiguration] = [:]
    private var animationQueue: [BlurAnimationRequest] = []
    private var isAnimating: Bool = false
    
    // Performance monitoring
    private var renderCount: Int = 0
    private var lastPerformanceCheck: Date = Date()
    private let performanceThreshold: Int = 30 // renders per second
    
    // MARK: - Initialization
    
    public init() {
        logger.info("🎨 BlurEffectManager: Initializing with default configuration")
        setupDefaultEffects()
        setupPerformanceMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Get blur effect configuration for a specific overlay type
    public func getBlurEffect(for overlayType: OverlayType, style: BlurStyle? = nil) -> BlurEffectConfiguration {
        let effectiveStyle = style ?? currentStyle
        let key = BlurEffectKey(overlayType: overlayType, style: effectiveStyle)
        
        if let cached = cachedEffects[key] {
            return applyGlobalSettings(to: cached)
        }
        
        let configuration = createBlurConfiguration(for: overlayType, style: effectiveStyle)
        cachedEffects[key] = configuration
        
        logger.debug("🎨 BlurEffectManager: Created blur effect for \(overlayType.rawValue) with style \(effectiveStyle.rawValue)")
        return applyGlobalSettings(to: configuration)
    }
    
    /// Create animated blur view with automatic performance optimization
    public func createBlurView(
        for overlayType: OverlayType,
        style: BlurStyle? = nil,
        customIntensity: Double? = nil
    ) -> some View {
        let configuration = getBlurEffect(for: overlayType, style: style)
        let effectiveIntensity = customIntensity ?? configuration.intensity
        
        return AdaptiveBlurView(
            configuration: configuration,
            intensity: effectiveIntensity,
            performanceMode: isPerformanceMode,
            onRender: { [weak self] in
                self?.trackRenderPerformance()
            }
        )
    }
    
    /// Animate between blur styles
    public func animateToStyle(_ newStyle: BlurStyle, duration: TimeInterval = 0.3) {
        let request = BlurAnimationRequest(
            fromStyle: currentStyle,
            toStyle: newStyle,
            duration: duration
        )
        
        animationQueue.append(request)
        processAnimationQueue()
    }
    
    /// Update global blur intensity
    public func updateGlobalIntensity(_ intensity: Double, animated: Bool = true) {
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                globalBlurIntensity = clampedIntensity
            }
        } else {
            globalBlurIntensity = clampedIntensity
        }
        
        logger.debug("🎨 BlurEffectManager: Updated global intensity to \(clampedIntensity)")
    }
    
    /// Toggle performance mode
    public func setPerformanceMode(_ enabled: Bool) {
        isPerformanceMode = enabled
        
        if enabled {
            // Clear cache to force regeneration with performance settings
            cachedEffects.removeAll()
            logger.info("🎨 BlurEffectManager: Performance mode enabled - simplified blur effects")
        } else {
            logger.info("🎨 BlurEffectManager: Performance mode disabled - full quality blur effects")
        }
    }
    
    /// Get preset blur configurations
    public func getPresetConfiguration(_ preset: BlurPreset) -> BlurEffectConfiguration {
        return BlurPresetFactory.configuration(for: preset)
    }
    
    /// Create custom blur configuration
    public func createCustomConfiguration(
        material: Material = .regularMaterial,
        intensity: Double = 0.8,
        tintColor: Color = .clear,
        tintOpacity: Double = 0.0,
        animationDuration: TimeInterval = 0.3,
        cornerRadius: Double = 0
    ) -> BlurEffectConfiguration {
        return BlurEffectConfiguration(
            material: material,
            intensity: intensity,
            tintColor: tintColor,
            tintOpacity: tintOpacity,
            animationDuration: animationDuration,
            cornerRadius: cornerRadius,
            isPerformanceOptimized: isPerformanceMode
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultEffects() {
        // Pre-cache common blur effects
        for overlayType in OverlayType.allCases {
            for style in BlurStyle.allCases {
                let key = BlurEffectKey(overlayType: overlayType, style: style)
                cachedEffects[key] = createBlurConfiguration(for: overlayType, style: style)
            }
        }
        
        logger.debug("🎨 BlurEffectManager: Pre-cached \(self.cachedEffects.count) blur configurations")
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor performance every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPerformance()
            }
        }
    }
    
    private func createBlurConfiguration(for overlayType: OverlayType, style: BlurStyle) -> BlurEffectConfiguration {
        let baseConfig = BlurStyleFactory.configuration(for: style)
        let overlayAdjustments = getOverlayAdjustments(for: overlayType)
        
        return BlurEffectConfiguration(
            material: baseConfig.material,
            intensity: min(1.0, baseConfig.intensity * overlayAdjustments.intensityMultiplier),
            tintColor: overlayAdjustments.tintColor ?? baseConfig.tintColor,
            tintOpacity: baseConfig.tintOpacity * overlayAdjustments.tintOpacityMultiplier,
            animationDuration: baseConfig.animationDuration,
            cornerRadius: overlayAdjustments.cornerRadius ?? baseConfig.cornerRadius,
            isPerformanceOptimized: isPerformanceMode
        )
    }
    
    private func getOverlayAdjustments(for overlayType: OverlayType) -> OverlayBlurAdjustments {
        switch overlayType {
        case .controls:
            return OverlayBlurAdjustments(
                intensityMultiplier: 1.0,
                tintColor: .black,
                tintOpacityMultiplier: 0.3,
                cornerRadius: 12
            )
        case .information:
            return OverlayBlurAdjustments(
                intensityMultiplier: 1.2,
                tintColor: .black,
                tintOpacityMultiplier: 0.4,
                cornerRadius: 16
            )
        case .progress:
            return OverlayBlurAdjustments(
                intensityMultiplier: 0.8,
                tintColor: .clear,
                tintOpacityMultiplier: 0.1,
                cornerRadius: 8
            )
        case .menu:
            return OverlayBlurAdjustments(
                intensityMultiplier: 1.1,
                tintColor: .black,
                tintOpacityMultiplier: 0.2,
                cornerRadius: 10
            )
        case .tooltip:
            return OverlayBlurAdjustments(
                intensityMultiplier: 0.9,
                tintColor: .black,
                tintOpacityMultiplier: 0.25,
                cornerRadius: 8
            )
        case .notification:
            return OverlayBlurAdjustments(
                intensityMultiplier: 1.0,
                tintColor: .clear,
                tintOpacityMultiplier: 0.15,
                cornerRadius: 12
            )
        }
    }
    
    private func applyGlobalSettings(to configuration: BlurEffectConfiguration) -> BlurEffectConfiguration {
        return BlurEffectConfiguration(
            material: configuration.material,
            intensity: configuration.intensity * globalBlurIntensity,
            tintColor: configuration.tintColor,
            tintOpacity: configuration.tintOpacity,
            animationDuration: configuration.animationDuration,
            cornerRadius: configuration.cornerRadius,
            isPerformanceOptimized: configuration.isPerformanceOptimized
        )
    }
    
    private func processAnimationQueue() {
        guard !isAnimating && !animationQueue.isEmpty else { return }
        
        isAnimating = true
        let request = animationQueue.removeFirst()
        
        withAnimation(.easeInOut(duration: request.duration)) {
            currentStyle = request.toStyle
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + request.duration) {
            self.isAnimating = false
            self.processAnimationQueue()
        }
    }
    
    private func trackRenderPerformance() {
        renderCount += 1
        
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastPerformanceCheck)
        
        if timeDiff >= 1.0 {
            let fps = Double(renderCount) / timeDiff
            
            if fps > Double(performanceThreshold) && !isPerformanceMode {
                logger.warning("🎨 BlurEffectManager: High render frequency detected (\(fps) fps) - consider enabling performance mode")
            }
            
            renderCount = 0
            lastPerformanceCheck = now
        }
    }
    
    private func checkPerformance() {
        let cacheSize = cachedEffects.count
        let maxCacheSize = 50
        
        if cacheSize > maxCacheSize {
            // Remove least recently used configurations
            let sortedByUsage = cachedEffects.sorted { _, _ in Bool.random() }
            let toRemove = sortedByUsage.prefix(cacheSize - maxCacheSize)
            
            for (key, _) in toRemove {
                cachedEffects.removeValue(forKey: key)
            }
            
            logger.debug("🎨 BlurEffectManager: Cleaned cache - removed \(toRemove.count) configurations")
        }
    }
}

// MARK: - Supporting Types

/// Blur effect configuration
public struct BlurEffectConfiguration {
    public let material: Material
    public let intensity: Double
    public let tintColor: Color
    public let tintOpacity: Double
    public let animationDuration: TimeInterval
    public let cornerRadius: Double
    public let isPerformanceOptimized: Bool
    
    public init(
        material: Material = .regularMaterial,
        intensity: Double = 0.8,
        tintColor: Color = .clear,
        tintOpacity: Double = 0.0,
        animationDuration: TimeInterval = 0.3,
        cornerRadius: Double = 0,
        isPerformanceOptimized: Bool = false
    ) {
        self.material = material
        self.intensity = max(0.0, min(1.0, intensity))
        self.tintColor = tintColor
        self.tintOpacity = max(0.0, min(1.0, tintOpacity))
        self.animationDuration = animationDuration
        self.cornerRadius = cornerRadius
        self.isPerformanceOptimized = isPerformanceOptimized
    }
}

/// Blur styles available
public enum BlurStyle: String, CaseIterable {
    case none = "none"
    case light = "light"
    case regular = "regular"
    case prominent = "prominent"
    case ultraThin = "ultraThin"
    case thin = "thin"
    case thick = "thick"
    case ultraThick = "ultraThick"
    case custom = "custom"
}

/// Blur presets for common use cases
public enum BlurPreset: String, CaseIterable {
    case minimal = "minimal"
    case standard = "standard"
    case enhanced = "enhanced"
    case dramatic = "dramatic"
    case accessibility = "accessibility"
}

/// Key for caching blur effects
private struct BlurEffectKey: Hashable {
    let overlayType: OverlayType
    let style: BlurStyle
}

/// Overlay-specific blur adjustments
private struct OverlayBlurAdjustments {
    let intensityMultiplier: Double
    let tintColor: Color?
    let tintOpacityMultiplier: Double
    let cornerRadius: Double?
    
    init(
        intensityMultiplier: Double = 1.0,
        tintColor: Color? = nil,
        tintOpacityMultiplier: Double = 1.0,
        cornerRadius: Double? = nil
    ) {
        self.intensityMultiplier = intensityMultiplier
        self.tintColor = tintColor
        self.tintOpacityMultiplier = tintOpacityMultiplier
        self.cornerRadius = cornerRadius
    }
}

/// Animation request for blur style transitions
private struct BlurAnimationRequest {
    let fromStyle: BlurStyle
    let toStyle: BlurStyle
    let duration: TimeInterval
}

// MARK: - Factories

/// Factory for creating blur style configurations
public class BlurStyleFactory {
    public static func configuration(for style: BlurStyle) -> BlurEffectConfiguration {
        switch style {
        case .none:
            return BlurEffectConfiguration(
                material: .regularMaterial,
                intensity: 0.0,
                tintOpacity: 0.0
            )
        case .light:
            return BlurEffectConfiguration(
                material: .ultraThinMaterial,
                intensity: 0.3,
                tintColor: .white,
                tintOpacity: 0.1
            )
        case .regular:
            return BlurEffectConfiguration(
                material: .regularMaterial,
                intensity: 0.6,
                tintColor: .black,
                tintOpacity: 0.2
            )
        case .prominent:
            return BlurEffectConfiguration(
                material: .thickMaterial,
                intensity: 0.8,
                tintColor: .black,
                tintOpacity: 0.3
            )
        case .ultraThin:
            return BlurEffectConfiguration(
                material: .ultraThinMaterial,
                intensity: 0.4,
                tintOpacity: 0.1
            )
        case .thin:
            return BlurEffectConfiguration(
                material: .thinMaterial,
                intensity: 0.5,
                tintOpacity: 0.15
            )
        case .thick:
            return BlurEffectConfiguration(
                material: .thickMaterial,
                intensity: 0.9,
                tintOpacity: 0.25
            )
        case .ultraThick:
            return BlurEffectConfiguration(
                material: .ultraThickMaterial,
                intensity: 1.0,
                tintColor: .black,
                tintOpacity: 0.4
            )
        case .custom:
            return BlurEffectConfiguration()
        }
    }
}

/// Factory for creating preset configurations
public class BlurPresetFactory {
    public static func configuration(for preset: BlurPreset) -> BlurEffectConfiguration {
        switch preset {
        case .minimal:
            return BlurEffectConfiguration(
                material: .ultraThinMaterial,
                intensity: 0.3,
                tintOpacity: 0.05,
                animationDuration: 0.2
            )
        case .standard:
            return BlurEffectConfiguration(
                material: .regularMaterial,
                intensity: 0.7,
                tintColor: .black,
                tintOpacity: 0.2,
                animationDuration: 0.3
            )
        case .enhanced:
            return BlurEffectConfiguration(
                material: .thickMaterial,
                intensity: 0.85,
                tintColor: .black,
                tintOpacity: 0.3,
                animationDuration: 0.4
            )
        case .dramatic:
            return BlurEffectConfiguration(
                material: .ultraThickMaterial,
                intensity: 1.0,
                tintColor: .black,
                tintOpacity: 0.5,
                animationDuration: 0.5
            )
        case .accessibility:
            return BlurEffectConfiguration(
                material: .thickMaterial,
                intensity: 1.0,
                tintColor: .black,
                tintOpacity: 0.8,
                animationDuration: 0.1,
                isPerformanceOptimized: true
            )
        }
    }
}

// MARK: - Adaptive Blur View

/// High-performance adaptive blur view with automatic optimization
public struct AdaptiveBlurView: View {
    let configuration: BlurEffectConfiguration
    let intensity: Double
    let performanceMode: Bool
    let onRender: () -> Void
    
    @State private var isVisible: Bool = true
    
    public var body: some View {
        ZStack {
            // Base material layer
            if configuration.intensity > 0 {
                Rectangle()
                    .fill(configuration.material)
                    .opacity(effectiveIntensity)
                    .animation(.easeInOut(duration: configuration.animationDuration), value: effectiveIntensity)
            }
            
            // Tint layer
            if configuration.tintOpacity > 0 {
                Rectangle()
                    .fill(configuration.tintColor.opacity(configuration.tintOpacity))
                    .animation(.easeInOut(duration: configuration.animationDuration), value: configuration.tintOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            isVisible = true
            onRender()
        }
        .onChange(of: configuration.intensity) { _, _ in
            onRender()
        }
    }
    
    private var effectiveIntensity: Double {
        let baseIntensity = configuration.intensity * intensity
        return performanceMode ? min(0.6, baseIntensity) : baseIntensity
    }
}

// MARK: - Extensions for Material

// Note: Material already conforms to the needed protocols in SwiftUI
// No additional extensions needed for basic functionality