import AppKit
import SwiftUI

/// Manages window transparency settings for the application
class WindowTransparencyManager: ObservableObject {
    static let shared = WindowTransparencyManager()
    
    private var isTransparencyEnabled = false
    
    private init() {}
    
    func enableTransparency() {
        print("🔍 WindowTransparencyManager: enableTransparency called")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Try all possible ways to get the window
            var targetWindow: NSWindow?
            
            if let keyWindow = NSApplication.shared.keyWindow {
                targetWindow = keyWindow
                print("🔍 WindowTransparencyManager: Using keyWindow")
            } else if let mainWindow = NSApplication.shared.mainWindow {
                targetWindow = mainWindow
                print("🔍 WindowTransparencyManager: Using mainWindow")
            } else if let firstWindow = NSApplication.shared.windows.first {
                targetWindow = firstWindow
                print("🔍 WindowTransparencyManager: Using first window")
            }
            
            guard let window = targetWindow else {
                print("❌ WindowTransparencyManager: No window found")
                return
            }
            
            print("🔍 WindowTransparencyManager: Before - isOpaque: \(window.isOpaque), backgroundColor: \(window.backgroundColor?.description ?? "nil")")
            
            // Configure window for transparency
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = true
            
            // Additional transparency settings
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            
            // Force the window to update
            window.invalidateShadow()
            window.display()
            
            self.isTransparencyEnabled = true
            
            print("🔍 WindowTransparencyManager: After - isOpaque: \(window.isOpaque), backgroundColor: \(window.backgroundColor?.description ?? "nil")")
            print("✅ WindowTransparencyManager: Window transparency enabled successfully")
        }
    }
    
    func disableTransparency() {
        print("🔍 WindowTransparencyManager: disableTransparency called")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Try all possible ways to get the window
            var targetWindow: NSWindow?
            
            if let keyWindow = NSApplication.shared.keyWindow {
                targetWindow = keyWindow
            } else if let mainWindow = NSApplication.shared.mainWindow {
                targetWindow = mainWindow
            } else if let firstWindow = NSApplication.shared.windows.first {
                targetWindow = firstWindow
            }
            
            guard let window = targetWindow else {
                print("❌ WindowTransparencyManager: No window found")
                return
            }
            
            print("🔍 WindowTransparencyManager: Before - isOpaque: \(window.isOpaque), backgroundColor: \(window.backgroundColor?.description ?? "nil")")
            
            // Configure window for opacity
            window.isOpaque = true
            window.backgroundColor = NSColor.black
            window.hasShadow = false
            
            // Force the window to update
            window.invalidateShadow()
            window.display()
            
            self.isTransparencyEnabled = false
            
            print("🔍 WindowTransparencyManager: After - isOpaque: \(window.isOpaque), backgroundColor: \(window.backgroundColor?.description ?? "nil")")
            print("✅ WindowTransparencyManager: Window transparency disabled successfully")
        }
    }
}

/// SwiftUI view modifier to enable/disable window transparency
struct WindowTransparency: ViewModifier {
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                print("🔍 WindowTransparency: onAppear called with isEnabled: \(isEnabled)")
                if isEnabled {
                    WindowTransparencyManager.shared.enableTransparency()
                } else {
                    WindowTransparencyManager.shared.disableTransparency()
                }
            }
            .onChange(of: isEnabled) { _, newValue in
                print("🔍 WindowTransparency: onChange called with newValue: \(newValue)")
                if newValue {
                    WindowTransparencyManager.shared.enableTransparency()
                } else {
                    WindowTransparencyManager.shared.disableTransparency()
                }
            }
    }
}

extension View {
    func windowTransparency(_ isEnabled: Bool) -> some View {
        self.modifier(WindowTransparency(isEnabled: isEnabled))
    }
}