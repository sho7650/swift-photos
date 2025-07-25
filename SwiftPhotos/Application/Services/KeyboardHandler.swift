import SwiftUI
import AppKit

@MainActor
public class KeyboardHandler: ObservableObject {
    public weak var viewModel: ModernSlideshowViewModel?
    public weak var performanceSettings: ModernPerformanceSettingsManager?
    public var onOpenSettings: (() -> Void)?
    public var onOpenFolder: (() -> Void)?
    
    /// Callback for UI control state manager to be notified of keyboard interactions
    public var onKeyboardInteraction: (() -> Void)?
    
    /// Callback for UI control actions (toggle info, show/hide controls)
    public var onToggleDetailedInfo: (() -> Void)?
    public var onToggleControlsVisibility: (() -> Void)?
    
    // Zoom callback functionality removed
    
    public init() {}
    
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let viewModel = viewModel else { return false }
        
        var handled = false
        
        switch event.keyCode {
        case 49: // Space key - Play/Pause
            if viewModel.slideshow?.isPlaying == true {
                viewModel.pause()
            } else {
                viewModel.play()
            }
            handled = true
            
        case 124, 125: // Right arrow, Down arrow - Next photo
            viewModel.nextPhoto()
            handled = true
            
        case 123, 126: // Left arrow, Up arrow - Previous photo
            viewModel.previousPhoto()
            handled = true
            
        case 53: // Escape - Stop/Pause
            if viewModel.slideshow?.isPlaying == true {
                viewModel.stop()
            }
            handled = true
            
        // Settings shortcut (Cmd+,)
        case 43: // ',' key
            if event.modifierFlags.contains(.command) {
                onOpenSettings?()
                handled = true
            }
            
        // Open Folder shortcut (Cmd+O)
        case 31: // 'O' key
            if event.modifierFlags.contains(.command) {
                ProductionLogger.userAction("KeyboardHandler: Open folder shortcut pressed")
                onOpenFolder?()
                handled = true
            }
            
        // Toggle detailed info (I key)
        case 34: // 'I' key
            if !event.modifierFlags.contains(.command) {
                ProductionLogger.userAction("KeyboardHandler: Toggle detailed info shortcut pressed")
                onToggleDetailedInfo?()
                handled = true
            }
            
        // Toggle controls visibility (H key)
        case 4: // 'H' key
            if !event.modifierFlags.contains(.command) {
                ProductionLogger.userAction("KeyboardHandler: Toggle controls visibility shortcut pressed")
                onToggleControlsVisibility?()
                handled = true
            }
            
        // Zoom functionality removed
            
        // Fullscreen toggle (F key)
        case 3: // 'F' key
            if !event.modifierFlags.contains(.command) {
                ProductionLogger.userAction("KeyboardHandler: Fullscreen toggle shortcut pressed")
                TransparencyManager.shared.toggleFullscreen()
                handled = true
            }
            
        // Reserved for future debug functionality
        case 17: // 'T' key  
            if event.modifierFlags.contains(.command) {
                ProductionLogger.debug("DEBUG: Debug shortcut pressed")
                handled = true
            }
            
        default:
            break
        }
        
        // Notify UI control state manager of any keyboard interaction
        if handled {
            ProductionLogger.debug("KeyboardHandler: Keyboard interaction detected, notifying UI state manager")
            onKeyboardInteraction?()
        }
        
        return handled
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