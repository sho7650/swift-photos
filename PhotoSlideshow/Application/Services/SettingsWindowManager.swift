import SwiftUI
import AppKit

/// Manager for the standalone settings window with modern sidebar-based design
@MainActor
public class SettingsWindowManager: ObservableObject {
    private var settingsWindow: NSWindow?
    
    public func openSettingsWindow(
        performanceSettings: PerformanceSettingsManager,
        slideshowSettings: SlideshowSettingsManager,
        sortSettings: SortSettingsManager,
        transitionSettings: TransitionSettingsManager,
        uiControlSettings: UIControlSettingsManager? = nil,
        recentFilesManager: RecentFilesManager? = nil
    ) {
        // Close existing window if open
        closeSettingsWindow()
        
        // Create new modern sidebar-based settings window
        let settingsView = SidebarSettingsWindow(
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings,
            transitionSettings: transitionSettings,
            uiControlSettings: uiControlSettings ?? UIControlSettingsManager()
        )
        .environmentObject(recentFilesManager ?? RecentFilesManager())
        
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Set optimal size for sidebar layout
        hostingController.preferredContentSize = NSSize(width: 900, height: 650)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "PhotoSlideshow Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        
        // Set window properties optimized for sidebar design
        window.minSize = NSSize(width: 720, height: 520)
        window.maxSize = NSSize(width: 1400, height: 1000)
        
        // Modern window appearance
        window.titlebarAppearsTransparent = false
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // Force window size and center
        window.setContentSize(NSSize(width: 900, height: 650))
        window.center()
        
        print("⚙️ SettingsWindowManager: Created modern sidebar settings window with size: \(window.frame.size)")
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        
        print("⚙️ SettingsWindowManager: Opened modern settings window")
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