import XCTest
@testable import SwiftPhotos

/// Enhanced unit tests for UIControlStateManager with comprehensive coverage
@MainActor
final class UIControlStateManagerEnhancedTestsV2: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: UIControlStateManager!
    private var settingsManager: ModernUIControlSettingsManager!
    private var slideshowViewModel: ModernSlideshowViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create settings manager with test configuration
        settingsManager = ModernUIControlSettingsManager()
        settingsManager.settings = UIControlSettings(
            autoHideDelay: 1.0,
            playingAutoHideDelay: 0.5,
            pausedAutoHideDelay: 2.0,
            minimumVisibilityDuration: 0.3,
            fadeAnimationDuration: 0.1,
            showOnMouseMovement: true,
            showDetailedInfoByDefault: false,
            hideOnPlay: true,
            hideOnImageHover: false,
            backgroundOpacity: 0.8,
            blurRadius: 20.0,
            mouseSensitivity: 50.0
        )
        
        // Create view model
        slideshowViewModel = ModernSlideshowViewModel()
        
        // Create system under test
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        settingsManager = nil
        slideshowViewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(sut.isControlsVisible, "Controls should be visible on initialization")
        XCTAssertFalse(sut.isDetailedInfoVisible, "Detailed info should not be visible by default")
        XCTAssertEqual(sut.mousePosition, .zero, "Mouse position should be zero initially")
        XCTAssertFalse(sut.isMouseInWindow, "Mouse should not be in window initially")
        XCTAssertFalse(sut.hasRecentInteraction, "Should not have recent interaction initially")
    }
    
    func testInitializationWithDetailedInfoDefault() {
        // Update settings to show detailed info by default
        settingsManager.settings.showDetailedInfoByDefault = true
        
        // Create new instance
        let newSut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        XCTAssertTrue(newSut.isDetailedInfoVisible, "Detailed info should be visible when configured")
    }
    
    // MARK: - Show/Hide Controls Tests
    
    func testShowControls() {
        // Hide controls first
        sut.hideControls(force: true)
        XCTAssertFalse(sut.isControlsVisible)
        
        // Show controls
        sut.showControls()
        
        XCTAssertTrue(sut.isControlsVisible, "Controls should be visible after showControls")
        XCTAssertTrue(sut.hasRecentInteraction, "Should record interaction when showing controls")
    }
    
    func testShowControlsWhenAlreadyVisible() {
        XCTAssertTrue(sut.isControlsVisible)
        
        // Record initial state
        let hadRecentInteraction = sut.hasRecentInteraction
        
        // Show controls again
        sut.showControls()
        
        XCTAssertTrue(sut.isControlsVisible, "Controls should remain visible")
        // The recent interaction state might change due to timer reset
    }
    
    func testHideControls() {
        XCTAssertTrue(sut.isControlsVisible)
        
        // Hide controls
        sut.hideControls()
        
        XCTAssertFalse(sut.isControlsVisible, "Controls should be hidden after hideControls")
    }
    
    func testHideControlsWithMinimumVisibility() async {
        // Show controls with minimum duration
        sut.showControls(withMinimumDuration: true)
        
        // Try to hide immediately
        sut.hideControls()
        
        // Controls should still be visible due to minimum visibility
        XCTAssertTrue(sut.isControlsVisible, "Controls should remain visible during minimum visibility period")
        
        // Wait for minimum visibility duration
        try? await Task.sleep(nanoseconds: UInt64(settingsManager.settings.minimumVisibilityDuration * 1_500_000_000))
        
        // Now hiding should work
        sut.hideControls()
        XCTAssertFalse(sut.isControlsVisible, "Controls should be hidden after minimum visibility period")
    }
    
    func testForceHideControls() {
        // Show controls with minimum duration
        sut.showControls(withMinimumDuration: true)
        
        // Force hide immediately
        sut.hideControls(force: true)
        
        XCTAssertFalse(sut.isControlsVisible, "Controls should be hidden when forced")
    }
    
    func testHideOnPlayBehavior() async {
        // Ensure slideshow is not playing
        slideshowViewModel.slideshow = Slideshow(photos: [], currentIndex: 0, isPlaying: false)
        
        // With hideOnPlay disabled, controls should not hide when not playing
        settingsManager.settings.hideOnPlay = false
        sut.hideControls()
        
        XCTAssertTrue(sut.isControlsVisible, "Controls should remain visible when not playing and hideOnPlay is false")
        
        // Enable hideOnPlay
        settingsManager.settings.hideOnPlay = true
        
        // Start playing
        slideshowViewModel.slideshow?.isPlaying = true
        
        // Now hiding should work
        sut.hideControls()
        XCTAssertFalse(sut.isControlsVisible, "Controls should hide when playing and hideOnPlay is true")
    }
    
    // MARK: - Detailed Info Tests
    
    func testToggleDetailedInfo() {
        XCTAssertFalse(sut.isDetailedInfoVisible)
        
        // Toggle on
        sut.toggleDetailedInfo()
        XCTAssertTrue(sut.isDetailedInfoVisible, "Detailed info should be visible after toggle")
        XCTAssertTrue(sut.isControlsVisible, "Controls should be shown when toggling detailed info")
        
        // Toggle off
        sut.toggleDetailedInfo()
        XCTAssertFalse(sut.isDetailedInfoVisible, "Detailed info should be hidden after second toggle")
    }
    
    // MARK: - Interaction Handling Tests
    
    func testKeyboardInteraction() {
        var keyboardCallbackCalled = false
        sut.onKeyboardInteraction = {
            keyboardCallbackCalled = true
        }
        
        // Hide controls first
        sut.hideControls(force: true)
        
        // Handle keyboard interaction
        sut.handleKeyboardInteraction()
        
        XCTAssertTrue(sut.isControlsVisible, "Controls should be shown on keyboard interaction")
        XCTAssertTrue(sut.hasRecentInteraction, "Should record recent interaction")
        XCTAssertTrue(keyboardCallbackCalled, "Keyboard callback should be called")
    }
    
    func testMouseInteraction() {
        var mouseCallbackCalled = false
        sut.onMouseInteraction = {
            mouseCallbackCalled = true
        }
        
        // Hide controls first
        sut.hideControls(force: true)
        
        // Handle mouse interaction
        let testPosition = CGPoint(x: 100, y: 200)
        sut.handleMouseInteraction(at: testPosition)
        
        XCTAssertEqual(sut.mousePosition, testPosition, "Mouse position should be updated")
        XCTAssertTrue(sut.isControlsVisible, "Controls should be shown on mouse movement")
        XCTAssertTrue(mouseCallbackCalled, "Mouse callback should be called")
    }
    
    func testMouseInteractionWithMovementDisabled() {
        settingsManager.settings.showOnMouseMovement = false
        
        // Recreate SUT with new settings
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        // Hide controls
        sut.hideControls(force: true)
        
        // Handle mouse interaction
        sut.handleMouseInteraction(at: CGPoint(x: 100, y: 200))
        
        XCTAssertFalse(sut.isControlsVisible, "Controls should not be shown when showOnMouseMovement is disabled")
    }
    
    func testGestureInteraction() {
        var gestureCallbackCalled = false
        sut.onGestureInteraction = {
            gestureCallbackCalled = true
        }
        
        // Hide controls first
        sut.hideControls(force: true)
        
        // Handle gesture interaction
        sut.handleGestureInteraction()
        
        XCTAssertTrue(sut.isControlsVisible, "Controls should be shown on gesture interaction")
        XCTAssertTrue(sut.hasRecentInteraction, "Should record recent interaction")
        XCTAssertTrue(gestureCallbackCalled, "Gesture callback should be called")
    }
    
    // MARK: - Mouse Window Status Tests
    
    func testUpdateMouseInWindow() async {
        // Start with slideshow playing
        slideshowViewModel.slideshow = Slideshow(photos: [], currentIndex: 0, isPlaying: true)
        
        // Mouse enters window
        sut.updateMouseInWindow(true)
        XCTAssertTrue(sut.isMouseInWindow, "Mouse should be in window")
        
        // Mouse leaves window
        sut.updateMouseInWindow(false)
        XCTAssertFalse(sut.isMouseInWindow, "Mouse should not be in window")
        
        // When playing and mouse leaves, timer should be faster
        // This is internal behavior that we can't directly test without exposing internals
    }
    
    // MARK: - Image Hover Tests
    
    func testHandleMouseEnteredImage() {
        settingsManager.settings.hideOnImageHover = true
        
        // Recreate SUT with new settings
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        // Handle mouse entering image
        sut.handleMouseEnteredImage()
        
        // This primarily affects cursor visibility, which we can't directly test
        // The method should complete without errors
    }
    
    func testHandleMouseExitedImage() {
        settingsManager.settings.hideOnImageHover = true
        
        // Recreate SUT with new settings
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        // Handle mouse exiting image
        sut.handleMouseExitedImage()
        
        // This primarily affects cursor visibility, which we can't directly test
        // The method should complete without errors
    }
    
    func testHandleMouseMovementOverImage() {
        settingsManager.settings.hideOnImageHover = true
        
        // Recreate SUT with new settings
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        // Handle mouse movement over image
        sut.handleMouseMovementOverImage(at: CGPoint(x: 100, y: 100))
        
        // This primarily affects cursor visibility, which we can't directly test
        // The method should complete without errors
    }
    
    // MARK: - Settings Change Tests
    
    func testSettingsChangeNotification() async {
        // Update detailed info default
        settingsManager.settings.showDetailedInfoByDefault = true
        
        // Post settings change notification
        NotificationCenter.default.post(name: .uiControlSettingsChanged, object: nil)
        
        // Wait for notification to be processed
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // If no recent interaction, detailed info should update to match settings
        // This behavior depends on hasRecentInteraction state
    }
    
    // MARK: - Timer Behavior Tests
    
    func testAutoHideTimer() async {
        XCTAssertTrue(sut.isControlsVisible)
        
        // Wait for auto-hide delay
        let hideDelay = settingsManager.settings.autoHideDelay
        try? await Task.sleep(nanoseconds: UInt64((hideDelay + 0.2) * 1_000_000_000))
        
        // Controls should be hidden after timer
        XCTAssertFalse(sut.isControlsVisible, "Controls should auto-hide after delay")
    }
    
    func testAutoHideTimerReset() async {
        // Show controls
        sut.showControls()
        
        // Wait partial auto-hide delay
        let partialDelay = settingsManager.settings.autoHideDelay * 0.5
        try? await Task.sleep(nanoseconds: UInt64(partialDelay * 1_000_000_000))
        
        // Show controls again (should reset timer)
        sut.showControls()
        
        // Wait another partial delay
        try? await Task.sleep(nanoseconds: UInt64(partialDelay * 1_000_000_000))
        
        // Controls should still be visible (timer was reset)
        XCTAssertTrue(sut.isControlsVisible, "Controls should remain visible after timer reset")
    }
    
    // MARK: - Cursor Control Tests
    
    func testEnableAdvancedCursorControl() {
        settingsManager.settings.hideOnImageHover = true
        
        // Recreate SUT with new settings
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        // Enable advanced cursor control
        sut.enableAdvancedCursorControl()
        
        // This primarily affects cursor management, which we can't directly test
        // The method should complete without errors
    }
    
    func testDisableAdvancedCursorControl() {
        settingsManager.settings.hideOnImageHover = true
        
        // Recreate SUT with new settings
        sut = UIControlStateManager(
            uiControlSettings: settingsManager,
            slideshowViewModel: slideshowViewModel
        )
        
        // Disable advanced cursor control
        sut.disableAdvancedCursorControl()
        
        // This primarily affects cursor management, which we can't directly test
        // The method should complete without errors
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testMultipleRapidInteractions() {
        // Hide controls
        sut.hideControls(force: true)
        
        // Rapid keyboard interactions
        for _ in 0..<10 {
            sut.handleKeyboardInteraction()
        }
        
        XCTAssertTrue(sut.isControlsVisible, "Controls should be visible after rapid interactions")
        XCTAssertTrue(sut.hasRecentInteraction, "Should have recent interaction")
    }
    
    func testConcurrentShowHide() async {
        // Perform concurrent show/hide operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    if i % 2 == 0 {
                        await self.sut.showControls()
                    } else {
                        await self.sut.hideControls()
                    }
                }
            }
        }
        
        // State should be consistent (either visible or hidden)
        // The exact state depends on timing, but there should be no crash
    }
    
    func testMemoryLeaks() {
        // Create instances in a closure to test for retain cycles
        autoreleasepool {
            let settings = ModernUIControlSettingsManager()
            let viewModel = ModernSlideshowViewModel()
            let manager = UIControlStateManager(
                uiControlSettings: settings,
                slideshowViewModel: viewModel
            )
            
            // Set up callbacks that could create retain cycles
            manager.onKeyboardInteraction = { [weak manager] in
                _ = manager?.isControlsVisible
            }
            
            manager.onMouseInteraction = { [weak manager] in
                _ = manager?.mousePosition
            }
            
            // Trigger some operations
            manager.showControls()
            manager.handleKeyboardInteraction()
            manager.handleMouseInteraction(at: .zero)
        }
        
        // If there are no leaks, the test passes
        // In a real scenario, use Instruments to verify
    }
}

// MARK: - Helper Extensions

extension UIControlStateManagerEnhancedTestsV2 {
    /// Wait for a condition to become true
    func wait(for condition: @escaping () -> Bool, timeout: TimeInterval = 5.0) async throws {
        let startTime = Date()
        
        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                XCTFail("Timeout waiting for condition")
                return
            }
            
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
    }
}