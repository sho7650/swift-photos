import SwiftUI
import AppKit

/// Manager for the standalone settings window
@MainActor
public class SettingsWindowManager: ObservableObject {
    private var settingsWindow: NSWindow?
    
    public func openSettingsWindow(
        performanceSettings: PerformanceSettingsManager,
        slideshowSettings: SlideshowSettingsManager
    ) {
        // Close existing window if open
        closeSettingsWindow()
        
        // Create new window
        let settingsView = SettingsWindow(
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings
        )
        
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Force the hosting controller to have proper size
        hostingController.preferredContentSize = NSSize(width: 700, height: 600)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "PhotoSlideshow Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        
        // Set window properties before centering
        window.minSize = NSSize(width: 600, height: 500)
        window.maxSize = NSSize(width: 1000, height: 800)
        
        // Force window size
        window.setContentSize(NSSize(width: 700, height: 600))
        window.center()
        
        print("⚙️ SettingsWindowManager: Created window with size: \(window.frame.size)")
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        
        print("⚙️ SettingsWindowManager: Opened settings window")
    }
    
    public func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
        print("⚙️ SettingsWindowManager: Closed settings window")
    }
    
    public var isWindowOpen: Bool {
        return settingsWindow?.isVisible ?? false
    }
}