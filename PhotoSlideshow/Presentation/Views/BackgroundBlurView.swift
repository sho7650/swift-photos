import SwiftUI
import AppKit

/// Terminal-style background blur view inspired by iTerm/Wezterm
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
                // TERMINAL-STYLE: Layer 1 - Base image with blur
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: settings.intensity * 30)  // Strong gaussian blur
                    .ignoresSafeArea()
                    .opacity(0.4)  // Subtle background image
                
                // TERMINAL-STYLE: Layer 2 - Dark overlay for better contrast
                Color.black
                    .opacity(0.3 + (1.0 - settings.backgroundOpacity) * 0.3)  // Dynamic darkness
                    .ignoresSafeArea()
                
                // TERMINAL-STYLE: Layer 3 - NSVisualEffectView for system blur
                TerminalStyleVisualEffectView(settings: settings)
                    .ignoresSafeArea()
                
                // TERMINAL-STYLE: Layer 4 - Additional material for depth
                Rectangle()
                    .fill(getTerminalMaterial(for: settings))
                    .ignoresSafeArea()
                    .opacity(0.3)  // Subtle material overlay
                
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
            print("🎨 BackgroundBlurView: Terminal-style blur \(settings.isEnabled ? "enabled" : "disabled")")
        }
    }
    
    /// Get terminal-style material - always use strongest available
    private func getTerminalMaterial(for settings: BlurSettings) -> Material {
        // TERMINAL-STYLE: Always use thick materials for terminal effect
        let effectiveIntensity = max(settings.intensity, 0.3)
        
        let material: Material
        
        // Terminal apps typically use very strong blur
        switch effectiveIntensity {
        case 0.0...0.5:
            material = .thickMaterial         // Minimum terminal blur
        case 0.5...0.8:
            material = .ultraThickMaterial    // Standard terminal blur  
        default:
            material = .ultraThickMaterial    // Maximum terminal blur
        }
        
        print("🎨 BackgroundBlurView: Terminal material: \(material) (intensity: \(effectiveIntensity))")
        return material
    }
    
    private func configureWindowForBlur(window: NSWindow, isEnabled: Bool) {
        print("🔍 BackgroundBlurView: Configuring window for blur - enabled: \(isEnabled)")
        
        if isEnabled {
            // TERMINAL-STYLE BLUR: Enhanced configuration based on iTerm/Wezterm
            window.isOpaque = false
            // CRITICAL: Use 0.01 alpha instead of clear to avoid performance issues
            window.backgroundColor = NSColor.black.withAlphaComponent(0.01)
            window.hasShadow = true  // Changed to true for depth
            
            // Terminal-style window configuration
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            
            // Enhanced performance and behavior
            window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            window.level = NSWindow.Level.normal
            
            // Calculate appropriate alpha for terminal-style transparency
            let windowAlpha = calculateTerminalStyleAlpha(for: settings)
            window.alphaValue = windowAlpha
            
            print("✅ BackgroundBlurView: Terminal-style blur configured (alpha: \(windowAlpha))")
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
    
    /// Calculate terminal-style window alpha for enhanced transparency
    private func calculateTerminalStyleAlpha(for settings: BlurSettings) -> CGFloat {
        // TERMINAL-STYLE: More aggressive transparency like iTerm/Wezterm
        let transparentAlpha = 1.0 - settings.backgroundOpacity
        
        // Terminal apps typically use 0.8-0.95 alpha range
        let baseAlpha = 0.8 + (settings.backgroundOpacity * 0.15)  // Range: 0.8 to 0.95
        
        // Blur intensity slightly affects transparency
        let intensityBoost = settings.intensity * 0.05  // Slight boost for higher blur
        
        let finalAlpha = min(baseAlpha + intensityBoost, 0.98)  // Cap at 0.98
        
        print("🎯 BackgroundBlurView: Terminal-style alpha: \(finalAlpha) (opacity: \(settings.backgroundOpacity))")
        return CGFloat(finalAlpha)
    }
}

/// Terminal-style NSVisualEffectView inspired by iTerm/Wezterm
private struct TerminalStyleVisualEffectView: NSViewRepresentable {
    let settings: BlurSettings
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        print("🔧 TerminalStyleVisualEffectView: Creating terminal-style blur")
        
        let visualEffectView = NSVisualEffectView()
        
        // TERMINAL-STYLE: Configuration based on terminal apps
        visualEffectView.material = getTerminalMaterial(for: settings)
        visualEffectView.blendingMode = .behindWindow  // Key for terminal transparency
        visualEffectView.state = .active
        
        // Terminal-style appearance
        visualEffectView.appearance = NSAppearance(named: .vibrantDark)
        
        // Performance optimization
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.shouldRasterize = true
        visualEffectView.layer?.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Terminal-style opacity
        let opacity = calculateTerminalOpacity(for: settings)
        visualEffectView.alphaValue = opacity
        
        visualEffectView.autoresizingMask = [.width, .height]
        
        print("✅ TerminalStyleVisualEffectView: Created with material: \(visualEffectView.material), alpha: \(opacity)")
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        print("🔄 TerminalStyleVisualEffectView: Updating view")
        
        // Update only if changed - performance optimization
        let newMaterial = getTerminalMaterial(for: settings)
        if nsView.material != newMaterial {
            nsView.material = newMaterial
        }
        
        let newOpacity = calculateTerminalOpacity(for: settings)
        if abs(nsView.alphaValue - newOpacity) > 0.01 {
            nsView.alphaValue = newOpacity
        }
        
        nsView.state = .active
        
        print("🔄 TerminalStyleVisualEffectView: Updated to material: \(newMaterial), alpha: \(newOpacity)")
    }
    
    private func getTerminalMaterial(for settings: BlurSettings) -> NSVisualEffectView.Material {
        // TERMINAL-STYLE: Use materials that match terminal apps
        let effectiveIntensity = max(settings.intensity, 0.3)
        
        switch settings.style {
        case .gaussian:
            // iTerm default style
            switch effectiveIntensity {
            case 0.0...0.4:
                return .hudWindow         // Minimum terminal blur
            case 0.4...0.7:
                return .fullScreenUI      // Standard terminal blur
            default:
                return .underWindowBackground  // Maximum terminal blur
            }
        case .motion:
            // Dynamic blur style
            switch effectiveIntensity {
            case 0.0...0.5:
                return .hudWindow
            default:
                return .fullScreenUI
            }
        case .zoom:
            // Wezterm-like style
            switch effectiveIntensity {
            case 0.0...0.3:
                return .hudWindow
            case 0.3...0.6:
                return .fullScreenUI
            default:
                return .underWindowBackground
            }
        }
    }
    
    private func calculateTerminalOpacity(for settings: BlurSettings) -> CGFloat {
        // TERMINAL-STYLE: High opacity for terminal effect
        let effectiveIntensity = max(settings.intensity, 0.3)
        
        // Terminal apps use high opacity visual effects
        let baseOpacity = 0.7 + (effectiveIntensity * 0.25)  // Range: 0.7 to 0.95
        
        // Slight adjustment based on background opacity
        let opacityBoost = (1.0 - settings.backgroundOpacity) * 0.1
        
        let finalOpacity = min(baseOpacity + opacityBoost, 0.95)
        
        print("🎯 TerminalStyleVisualEffectView: Terminal opacity: \(finalOpacity)")
        return CGFloat(finalOpacity)
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