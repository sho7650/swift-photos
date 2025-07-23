import SwiftUI
import AppKit

@MainActor
public class KeyboardHandler: ObservableObject {
    public weak var viewModel: SlideshowViewModel?
    public weak var blurSettings: BlurSettingsManager?
    public weak var performanceSettings: PerformanceSettingsManager?
    public var onOpenSettings: (() -> Void)?
    
    // Debug functionality
    private let blurTestManager = BlurTestWindowManager()
    public var onOpenBlurTest: (() -> Void)?
    
    public init() {}
    
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let viewModel = viewModel else { return false }
        
        switch event.keyCode {
        case 49:
            if viewModel.slideshow?.isPlaying == true {
                viewModel.pause()
            } else {
                viewModel.play()
            }
            return true
            
        case 124, 125:
            viewModel.nextPhoto()
            return true
            
        case 123, 126:
            viewModel.previousPhoto()
            return true
            
        case 53:
            if viewModel.slideshow?.isPlaying == true {
                viewModel.stop()
            }
            return true
            
        // Blur controls
        case 11: // 'B' key - toggle blur
            if let blurSettings = blurSettings {
                let currentSettings = blurSettings.settings
                let newSettings = BlurSettings(
                    isEnabled: !currentSettings.isEnabled,
                    intensity: currentSettings.intensity,
                    style: currentSettings.style,
                    backgroundOpacity: currentSettings.backgroundOpacity
                )
                blurSettings.updateSettings(newSettings)
            }
            return true
            
        case 69: // '+' key - increase blur intensity
            if let blurSettings = blurSettings {
                let currentSettings = blurSettings.settings
                let newIntensity = min(1.0, currentSettings.intensity + 0.1)
                let newSettings = BlurSettings(
                    isEnabled: currentSettings.isEnabled,
                    intensity: newIntensity,
                    style: currentSettings.style,
                    backgroundOpacity: currentSettings.backgroundOpacity
                )
                blurSettings.updateSettings(newSettings)
            }
            return true
            
        case 78: // '-' key - decrease blur intensity
            if let blurSettings = blurSettings {
                let currentSettings = blurSettings.settings
                let newIntensity = max(0.0, currentSettings.intensity - 0.1)
                let newSettings = BlurSettings(
                    isEnabled: currentSettings.isEnabled,
                    intensity: newIntensity,
                    style: currentSettings.style,
                    backgroundOpacity: currentSettings.backgroundOpacity
                )
                blurSettings.updateSettings(newSettings)
            }
            return true
            
        // Settings shortcut (Cmd+,)
        case 43: // ',' key
            if event.modifierFlags.contains(.command) {
                onOpenSettings?()
                return true
            }
            return false
            
        // Debug: Blur test window (Cmd+T)
        case 17: // 'T' key  
            if event.modifierFlags.contains(.command) {
                print("🔍 DEBUG: Opening blur test window")
                blurTestManager.openTestWindow()
                return true
            }
            return false
            
        default:
            return false
        }
    }
}

public struct KeyboardHandlerViewModifier: ViewModifier {
    let keyboardHandler: KeyboardHandler
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if keyboardHandler.handleKeyEvent(event) {
                        return nil
                    }
                    return event
                }
            }
    }
}

extension View {
    public func keyboardHandler(_ handler: KeyboardHandler) -> some View {
        self.modifier(KeyboardHandlerViewModifier(keyboardHandler: handler))
    }
}