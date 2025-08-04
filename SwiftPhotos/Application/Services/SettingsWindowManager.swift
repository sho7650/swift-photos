import SwiftUI
import AppKit

/// Manager for the standalone settings window with modern sidebar-based design
@MainActor
public class SettingsWindowManager: ObservableObject {
    private var settingsWindow: NSWindow?
    
    public func openSettingsWindow(
        settingsCoordinator: UnifiedAppSettingsCoordinator,
        recentFilesManager: RecentFilesManager? = nil
    ) {
        // Close existing window if open
        closeSettingsWindow()
        
        // CRITICAL FIX: Use the SAME settings coordinator that UnifiedSlideshowViewModel uses
        // This ensures both components are synchronized and use the same settings manager instances
        let settingsCoordinatorAddress = "\(Unmanaged.passUnretained(settingsCoordinator).toOpaque())"
        ProductionLogger.debug("SettingsWindowManager: Using settings coordinator instance: \(settingsCoordinatorAddress)")
        
        // Extract the underlying Modern* managers from UnifiedAppSettingsCoordinator
        // These are the SAME instances that UnifiedSlideshowViewModel uses via UnifiedSortSettingsManager
        let modernSortSettings = settingsCoordinator.sort.underlyingManager
        let modernSortSettingsAddress = "\(Unmanaged.passUnretained(modernSortSettings).toOpaque())"
        ProductionLogger.debug("SettingsWindowManager: Using ModernSortSettingsManager instance: \(modernSortSettingsAddress)")
        
        // Create new modern sidebar-based settings window using the SAME settings managers
        let settingsView = SidebarSettingsWindow(
            performanceSettings: createPerformanceManagerFromCoordinator(settingsCoordinator),
            slideshowSettings: createSlideshowManagerFromCoordinator(settingsCoordinator),
            sortSettings: modernSortSettings, // Use the SAME instance as UnifiedSlideshowViewModel
            transitionSettings: createTransitionManagerFromCoordinator(settingsCoordinator),
            uiControlSettings: createUIControlManagerFromCoordinator(settingsCoordinator),
            localizationSettings: ModernLocalizationSettingsManager()
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
        
        window.title = "Swift Photos Settings"
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
        
        ProductionLogger.debug("SettingsWindowManager: Created modern sidebar settings window with synchronized settings managers")
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        
        ProductionLogger.userAction("SettingsWindowManager: Opened modern settings window with synchronized settings")
    }
    
    public func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
        ProductionLogger.userAction("SettingsWindowManager: Closed settings window")
    }
    
    public var isWindowOpen: Bool {
        return settingsWindow?.isVisible ?? false
    }
    
    // MARK: - Helper Methods for Settings Manager Extraction
    
    private func createPerformanceManagerFromCoordinator(_ coordinator: UnifiedAppSettingsCoordinator) -> ModernPerformanceSettingsManager {
        // Create a ModernPerformanceSettingsManager that uses the same settings
        let manager = ModernPerformanceSettingsManager()
        manager.updateSettings(coordinator.performance.settings)
        return manager
    }
    
    private func createSlideshowManagerFromCoordinator(_ coordinator: UnifiedAppSettingsCoordinator) -> ModernSlideshowSettingsManager {
        // Create a ModernSlideshowSettingsManager that uses the same settings
        let manager = ModernSlideshowSettingsManager()
        manager.updateSettings(coordinator.slideshow.settings)
        return manager
    }
    
    private func createTransitionManagerFromCoordinator(_ coordinator: UnifiedAppSettingsCoordinator) -> ModernTransitionSettingsManager {
        // Create a ModernTransitionSettingsManager that uses the same settings
        let manager = ModernTransitionSettingsManager()
        manager.updateSettings(coordinator.transition.settings)
        return manager
    }
    
    private func createUIControlManagerFromCoordinator(_ coordinator: UnifiedAppSettingsCoordinator) -> ModernUIControlSettingsManager {
        // Create a ModernUIControlSettingsManager that uses the same settings
        let manager = ModernUIControlSettingsManager()
        manager.updateSettings(coordinator.uiControl.settings)
        return manager
    }
}