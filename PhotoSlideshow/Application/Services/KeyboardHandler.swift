import SwiftUI
import AppKit

@MainActor
public class KeyboardHandler: ObservableObject {
    public weak var viewModel: SlideshowViewModel?
    public weak var performanceSettings: PerformanceSettingsManager?
    public var onOpenSettings: (() -> Void)?
    public var onOpenFolder: (() -> Void)?
    
    /// Callback for UI control state manager to be notified of keyboard interactions
    public var onKeyboardInteraction: (() -> Void)?
    
    /// Callback for UI control actions (toggle info, show/hide controls)
    public var onToggleDetailedInfo: (() -> Void)?
    public var onToggleControlsVisibility: (() -> Void)?
    
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
                print("🎮 KeyboardHandler: Open folder shortcut pressed")
                onOpenFolder?()
                handled = true
            }
            
        // Toggle detailed info (I key)
        case 34: // 'I' key
            if !event.modifierFlags.contains(.command) {
                print("🎮 KeyboardHandler: Toggle detailed info shortcut pressed")
                onToggleDetailedInfo?()
                handled = true
            }
            
        // Toggle controls visibility (H key)
        case 4: // 'H' key
            if !event.modifierFlags.contains(.command) {
                print("🎮 KeyboardHandler: Toggle controls visibility shortcut pressed")
                onToggleControlsVisibility?()
                handled = true
            }
            
        // Reserved for future debug functionality
        case 17: // 'T' key  
            if event.modifierFlags.contains(.command) {
                print("🔍 DEBUG: Debug shortcut pressed")
                handled = true
            }
            
        default:
            break
        }
        
        // Notify UI control state manager of any keyboard interaction
        if handled {
            print("🎮 KeyboardHandler: Keyboard interaction detected, notifying UI state manager")
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