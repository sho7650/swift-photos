import SwiftUI
import AppKit

@MainActor
public class KeyboardHandler: ObservableObject {
    public weak var viewModel: SlideshowViewModel?
    
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