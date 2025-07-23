import SwiftUI
import AppKit

/// Modern background blur view using SwiftUI Material - following Xcode 16/Swift 6 best practices
public struct BackgroundBlurView: View {
    let image: NSImage
    let settings: BlurSettings
    
    public init(image: NSImage, settings: BlurSettings) {
        self.image = image
        self.settings = settings
    }
    
    public var body: some View {
        ZStack {
            if settings.isEnabled {
                // Primary SwiftUI Material blur - following best practices
                Rectangle()
                    .fill(getMaterial(for: settings))
                    .ignoresSafeArea()
                
                // Flexible transparency overlay for fine-grained control
                FlexibleTransparencyOverlay(settings: settings)
                    .ignoresSafeArea()
                
                // Optional NSVisualEffectView for enhanced effect
                OptimizedVisualEffectView(settings: settings)
                    .ignoresSafeArea()
                    .opacity(Double(0.5 + (max(settings.intensity, 0.1) * 0.5)))  // CORRECTED: Higher intensity = higher opacity (0.5-1.0)
                
            } else {
                // Solid black background
                Color.black
                    .ignoresSafeArea()
            }
            
            // Window configuration overlay
            WindowConfigurationView(
                isTransparent: settings.isEnabled
            ) { window in
                configureWindowForBlur(window: window, isEnabled: settings.isEnabled)
            }
        }
        .onAppear {
            print("🎨 BackgroundBlurView: Material blur \(settings.isEnabled ? "enabled" : "disabled")")
        }
    }
    
    /// Get appropriate SwiftUI Material based on settings - higher intensity = stronger blur
    private func getMaterial(for settings: BlurSettings) -> Material {
        // CORRECTED: Higher intensity values produce stronger blur effects
        let effectiveIntensity = max(settings.intensity, 0.1)  // Minimum 0.1 for visibility
        print("🔍 BackgroundBlurView: Selecting Material for intensity: \(settings.intensity) → effective: \(effectiveIntensity)")
        
        let material: Material
        
        // Progressive Material selection: higher intensity = stronger material
        switch effectiveIntensity {
        case 0.0...0.2:
            material = .thinMaterial           // Light blur for low intensity
        case 0.2...0.4:
            material = .regularMaterial       // Medium blur for medium-low intensity
        case 0.4...0.6:
            material = .thickMaterial         // Strong blur for medium-high intensity
        case 0.6...0.8:
            material = .ultraThickMaterial    // Very strong blur for high intensity
        default:
            material = .ultraThickMaterial    // Maximum blur for maximum intensity
        }
        
        print("🎨 BackgroundBlurView: CORRECTED Material selection: \(material) (intensity: \(effectiveIntensity) = stronger blur)")
        return material
    }
    
    private func configureWindowForBlur(window: NSWindow, isEnabled: Bool) {
        print("🔍 BackgroundBlurView: Configuring window for blur - enabled: \(isEnabled)")
        
        if isEnabled {
            // Enable transparency for blur effect
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = false
            
            // Best practices for blur window configuration
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            
            // Performance optimizations
            window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            window.level = NSWindow.Level.normal
            
            // Enhanced: Window-level transparency control
            let windowAlpha = calculateWindowAlpha(for: settings)
            window.alphaValue = windowAlpha
            
            print("✅ BackgroundBlurView: Window configured for Material blur (alpha: \(windowAlpha))")
        } else {
            // Disable transparency for normal black background
            window.isOpaque = true
            window.backgroundColor = NSColor.black
            window.hasShadow = false
            window.alphaValue = 1.0  // Fully opaque
            
            // Reset window settings
            window.level = NSWindow.Level.normal
            window.collectionBehavior = []
            
            print("✅ BackgroundBlurView: Window transparency disabled")
        }
        
        window.invalidateShadow()
        window.display()
    }
    
    /// Calculate window-level alpha for enhanced transparency control
    private func calculateWindowAlpha(for settings: BlurSettings) -> CGFloat {
        // CORRECTED: Lower backgroundOpacity = more transparent (lower alpha)
        let transparentAlpha = 1.0 - settings.backgroundOpacity  // Invert: 0.0 = opaque, 1.0 = transparent
        let baseAlpha = 0.3 + (transparentAlpha * 0.7)  // Range: 0.3 (opaque) to 1.0 (transparent)
        let intensityModifier = 1.0 - (settings.intensity * 0.1)   // Slight reduction for high blur intensity
        
        let finalAlpha = baseAlpha * intensityModifier
        
        print("🎯 BackgroundBlurView: CORRECTED Window alpha: \(finalAlpha) (backgroundOpacity: \(settings.backgroundOpacity) → transparency: \(transparentAlpha))")
        return CGFloat(max(min(finalAlpha, 1.0), 0.2))  // Range: 0.2 to 1.0
    }
}

/// Optimized NSVisualEffectView following best practices
private struct OptimizedVisualEffectView: NSViewRepresentable {
    let settings: BlurSettings
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        print("🔧 OptimizedVisualEffectView: Creating optimized NSVisualEffectView")
        
        let visualEffectView = NSVisualEffectView()
        
        // AGGRESSIVE: Configuration for maximum blur visibility
        visualEffectView.material = getOptimizedMaterial(for: settings)
        visualEffectView.blendingMode = .behindWindow  // Blur through to desktop for stronger effect
        visualEffectView.state = .active
        
        // Performance optimization
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.shouldRasterize = true
        visualEffectView.layer?.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Controlled opacity
        let opacity = calculateOptimizedOpacity(for: settings)
        visualEffectView.alphaValue = opacity
        
        visualEffectView.autoresizingMask = [.width, .height]
        
        print("✅ OptimizedVisualEffectView: Created with material: \(visualEffectView.material), alpha: \(opacity)")
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        print("🔄 OptimizedVisualEffectView: Updating view")
        
        // Update only if changed - performance optimization
        let newMaterial = getOptimizedMaterial(for: settings)
        if nsView.material != newMaterial {
            nsView.material = newMaterial
        }
        
        let newOpacity = calculateOptimizedOpacity(for: settings)
        if abs(nsView.alphaValue - newOpacity) > 0.01 {
            nsView.alphaValue = newOpacity
        }
        
        nsView.state = .active
        
        print("🔄 OptimizedVisualEffectView: Updated to material: \(newMaterial), alpha: \(newOpacity)")
    }
    
    private func getOptimizedMaterial(for settings: BlurSettings) -> NSVisualEffectView.Material {
        // CORRECTED: Higher intensity = stronger materials progressively
        let effectiveIntensity = max(settings.intensity, 0.1)  // Minimum intensity
        
        switch settings.style {
        case .gaussian:
            switch effectiveIntensity {
            case 0.0...0.25:
                return .sidebar           // Light material for low intensity
            case 0.25...0.5:
                return .menu              // Medium material for medium intensity
            case 0.5...0.75:
                return .hudWindow         // Strong material for high intensity
            default:
                return .fullScreenUI      // Strongest material for maximum intensity
            }
        case .motion:
            switch effectiveIntensity {
            case 0.0...0.3:
                return .popover           // Light material for low intensity
            case 0.3...0.6:
                return .menu              // Medium material for medium intensity
            default:
                return .hudWindow         // Strong material for high intensity
            }
        case .zoom:
            switch effectiveIntensity {
            case 0.0...0.2:
                return .sidebar           // Light material for low intensity
            case 0.2...0.5:
                return .menu              // Medium material for medium intensity
            case 0.5...0.8:
                return .hudWindow         // Strong material for high intensity
            default:
                return .fullScreenUI      // Strongest material for maximum intensity
            }
        }
    }
    
    private func calculateOptimizedOpacity(for settings: BlurSettings) -> CGFloat {
        // CORRECTED: Higher intensity = higher opacity, lower backgroundOpacity = more transparent
        let effectiveIntensity = max(settings.intensity, 0.1)  // Minimum intensity
        let baseOpacity = 0.3 + (effectiveIntensity * 0.6)  // Range: 0.3 to 0.9 based on intensity
        
        // CORRECTED: Lower backgroundOpacity = more transparent (multiply by backgroundOpacity)
        let transparencyFactor = settings.backgroundOpacity  // 0.0 = fully transparent, 1.0 = opaque
        
        let finalOpacity = baseOpacity * transparencyFactor
        
        print("🎯 OptimizedVisualEffectView: CORRECTED opacity: \(finalOpacity) (base: \(baseOpacity), intensity: \(effectiveIntensity), transparency factor: \(transparencyFactor))")
        return CGFloat(max(min(finalOpacity, 0.9), 0.1))  // Range: 0.1 to 0.9
    }
}

/// Flexible transparency overlay for fine-grained opacity control
private struct FlexibleTransparencyOverlay: View {
    let settings: BlurSettings
    
    var body: some View {
        Rectangle()
            .fill(.clear)
            .background(createTransparencyOverlay())
    }
    
    private func createTransparencyOverlay() -> some View {
        let transparencyLevel = calculateTransparencyLevel()
        let overlayColor = getOverlayColor()
        
        print("🌟 FlexibleTransparencyOverlay: Transparency level: \(transparencyLevel), color: \(overlayColor)")
        
        return Rectangle()
            .fill(overlayColor)
            .opacity(transparencyLevel)
    }
    
    private func calculateTransparencyLevel() -> Double {
        // CORRECTED: Lower backgroundOpacity = more transparent overlay
        let transparency = 1.0 - settings.backgroundOpacity  // Invert: low backgroundOpacity = high transparency
        let baseTransparency = transparency * 0.5  // Scale down overlay influence
        let intensityModifier = 1.0 - (settings.intensity * 0.3)  // Reduce overlay as blur increases
        
        let finalTransparency = baseTransparency * intensityModifier
        
        print("🎯 FlexibleTransparencyOverlay: CORRECTED transparency: \(finalTransparency) (backgroundOpacity: \(settings.backgroundOpacity) → transparency: \(transparency), modifier: \(intensityModifier))")
        return max(min(finalTransparency, 0.4), 0.0)  // Range: 0.0 to 0.4
    }
    
    private func getOverlayColor() -> Color {
        // ENHANCED: Even more subtle colors to not interfere with blur
        switch settings.style {
        case .gaussian:
            return Color.black.opacity(0.15)  // Reduced from 0.3
        case .motion:
            return Color.gray.opacity(0.1)    // Reduced from 0.2
        case .zoom:
            return Color.white.opacity(0.05)  // Reduced from 0.1
        }
    }
}

#Preview {
    if let sampleImage = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) {
        BackgroundBlurView(
            image: sampleImage,
            settings: .medium
        )
        .frame(width: 400, height: 300)
    }
}