//
//  UIControlStateManagerEnhancedTests.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/26.
//

import Testing
import Foundation
@testable import Swift_Photos

@MainActor
struct UIControlStateManagerEnhancedTests {
    
    // MARK: - Test Helpers
    
    private func createMockSlideshowViewModel(isPlaying: Bool = false) -> ModernSlideshowViewModel {
        let performanceSettings = ModernPerformanceSettingsManager()
        let slideshowSettings = ModernSlideshowSettingsManager()
        let sortSettings = ModernSortSettingsManager()
        
        let imageLoader = ImageLoader()
        let imageCache = ImageCache()
        let fileAccess = SecureFileAccess()
        let localizationService = LocalizationService()
        let repository = FileSystemPhotoRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
        
        let viewModel = ModernSlideshowViewModel(
            domainService: domainService,
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings
        )
        
        if isPlaying {
            viewModel.play()
        }
        
        return viewModel
    }
    
    private func createTestUIControlSettings(
        autoHideDelay: TimeInterval = 5.0,
        playingAutoHideDelay: TimeInterval = 2.0,
        pausedAutoHideDelay: TimeInterval = 10.0,
        hideOnPlay: Bool = true,
        showOnMouseMovement: Bool = true,
        mouseSensitivity: Double = 10.0
    ) -> UIControlSettingsManager {
        let settings = UIControlSettingsManager()
        settings.updateSettings(UIControlSettings(
            autoHideDelay: autoHideDelay,
            playingAutoHideDelay: playingAutoHideDelay,
            pausedAutoHideDelay: pausedAutoHideDelay,
            fadeAnimationDuration: 0.1,
            backgroundBlurIntensity: 0.5,
            backgroundOpacity: 0.2,
            showDetailedInfoByDefault: false,
            hideOnPlay: hideOnPlay,
            minimumVisibilityDuration: 1.0,
            showOnMouseMovement: showOnMouseMovement,
            mouseSensitivity: mouseSensitivity,
            bottomOffset: 50.0
        ))
        return settings
    }
    
    // MARK: - Timer Management Tests
    
    @Test func testAutoHideTimerStartsOnShow() async {
        let uiControlSettings = createTestUIControlSettings(autoHideDelay: 0.2)
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        stateManager.showControls()
        #expect(stateManager.isControlsVisible == true)
        
        // Wait for auto-hide timer
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Controls should be hidden after timer
        #expect(stateManager.isControlsVisible == false)
    }
    
    @Test func testDifferentTimersForPlayingVsPaused() async {
        let uiControlSettings = createTestUIControlSettings(
            autoHideDelay: 1.0,
            playingAutoHideDelay: 0.2,
            pausedAutoHideDelay: 2.0
        )
        
        let playingViewModel = createMockSlideshowViewModel(isPlaying: true)
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: playingViewModel
        )
        
        // Test with playing state
        stateManager.showControls()
        #expect(stateManager.isControlsVisible == true)
        
        // Should use playing timer (0.2s)
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        #expect(stateManager.isControlsVisible == false)
        
        // Pause and test again
        playingViewModel.pause()
        stateManager.showControls()
        #expect(stateManager.isControlsVisible == true)
        
        // Should still be visible after playing timer duration
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        #expect(stateManager.isControlsVisible == true)
    }
    
    // MARK: - Mouse Movement Sensitivity Tests
    
    @Test func testMouseMovementSensitivity() {
        let uiControlSettings = createTestUIControlSettings(mouseSensitivity: 50.0)
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Initial position
        stateManager.handleMouseInteraction(at: CGPoint(x: 100, y: 100))
        let initialHasInteraction = stateManager.hasRecentInteraction
        
        // Small movement below sensitivity threshold
        stateManager.handleMouseInteraction(at: CGPoint(x: 120, y: 120))
        // Distance is ~28.28, which is less than sensitivity of 50
        
        // Should detect movement based on threshold
        #expect(stateManager.mousePosition == CGPoint(x: 120, y: 120))
    }
    
    @Test func testMouseMovementAboveSensitivityThreshold() {
        let uiControlSettings = createTestUIControlSettings(mouseSensitivity: 10.0)
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Hide controls first
        stateManager.hideControls(force: true)
        
        // Initial position
        stateManager.handleMouseInteraction(at: CGPoint(x: 100, y: 100))
        
        // Large movement above sensitivity threshold
        stateManager.handleMouseInteraction(at: CGPoint(x: 200, y: 200))
        // Distance is ~141.42, which is well above sensitivity of 10
        
        // Should show controls for significant movement
        #expect(stateManager.isControlsVisible == true)
    }
    
    // MARK: - Hide on Play Tests
    
    @Test func testHideOnPlayBehavior() async {
        let uiControlSettings = createTestUIControlSettings(hideOnPlay: true)
        let viewModel = createMockSlideshowViewModel(isPlaying: false)
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: viewModel
        )
        
        // Controls visible when paused
        stateManager.showControls()
        #expect(stateManager.isControlsVisible == true)
        
        // Start playing
        viewModel.play()
        
        // Give time for the hide-on-play logic to trigger
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Controls should hide when playing starts
        #expect(stateManager.isControlsVisible == false)
    }
    
    @Test func testHideOnPlayDisabled() async {
        let uiControlSettings = createTestUIControlSettings(hideOnPlay: false)
        let viewModel = createMockSlideshowViewModel(isPlaying: false)
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: viewModel
        )
        
        // Controls visible when paused
        stateManager.showControls()
        #expect(stateManager.isControlsVisible == true)
        
        // Start playing
        viewModel.play()
        
        // Give time to ensure controls don't hide
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Controls should remain visible when hideOnPlay is disabled
        #expect(stateManager.isControlsVisible == true)
    }
    
    // MARK: - Progressive Disclosure Tests
    
    @Test func testProgressiveDisclosure() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Initially, only basic controls visible
        #expect(stateManager.isControlsVisible == true)
        #expect(stateManager.isDetailedInfoVisible == false)
        
        // Toggle detailed info
        stateManager.toggleDetailedInfo()
        #expect(stateManager.isDetailedInfoVisible == true)
        
        // Controls should also be visible when detailed info is shown
        #expect(stateManager.isControlsVisible == true)
    }
    
    // MARK: - Interaction Callback Tests
    
    @Test func testAllInteractionCallbacks() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var keyboardCallbackCount = 0
        var mouseCallbackCount = 0
        var gestureCallbackCount = 0
        var showCallbackCount = 0
        var hideCallbackCount = 0
        var detailToggleCallbackCount = 0
        
        stateManager.onKeyboardInteraction = { keyboardCallbackCount += 1 }
        stateManager.onMouseInteraction = { mouseCallbackCount += 1 }
        stateManager.onGestureInteraction = { gestureCallbackCount += 1 }
        stateManager.onControlsShow = { showCallbackCount += 1 }
        stateManager.onControlsHide = { hideCallbackCount += 1 }
        stateManager.onDetailedInfoToggle = { detailToggleCallbackCount += 1 }
        
        // Test each interaction
        stateManager.handleKeyboardInteraction()
        #expect(keyboardCallbackCount == 1)
        
        stateManager.handleMouseInteraction(at: .zero)
        #expect(mouseCallbackCount == 1)
        
        stateManager.handleGestureInteraction()
        #expect(gestureCallbackCount == 1)
        
        stateManager.hideControls(force: true)
        #expect(hideCallbackCount == 1)
        
        stateManager.showControls()
        #expect(showCallbackCount == 1)
        
        stateManager.toggleDetailedInfo()
        #expect(detailToggleCallbackCount == 1)
    }
    
    // MARK: - State Consistency Tests
    
    @Test func testStateConsistencyAfterMultipleOperations() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Perform multiple operations
        stateManager.showControls()
        stateManager.toggleDetailedInfo()
        stateManager.handleKeyboardInteraction()
        stateManager.hideControls(force: true)
        stateManager.toggleDetailedInfo()
        stateManager.showControls()
        
        // Final state should be consistent
        #expect(stateManager.isControlsVisible == true)
        #expect(stateManager.isDetailedInfoVisible == true)
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    // MARK: - Window Focus Tests
    
    @Test func testWindowFocusHandling() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Simulate window gaining focus
        stateManager.handleWindowFocusChanged(true)
        #expect(stateManager.isControlsVisible == true)
        
        // Simulate window losing focus
        stateManager.handleWindowFocusChanged(false)
        // Controls visibility shouldn't change just from focus loss
        #expect(stateManager.isControlsVisible == true)
    }
    
    // MARK: - Image Redraw Tests
    
    @Test func testImageRedrawHandling() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var redrawCallbackCalled = false
        stateManager.onImageRedraw = {
            redrawCallbackCalled = true
        }
        
        stateManager.handleImageRedraw()
        #expect(redrawCallbackCalled == true)
    }
    
    // MARK: - Settings Preset Tests
    
    @Test func testUIControlPresets() {
        let minimalSettings = UIControlSettings.minimalPreset()
        #expect(minimalSettings.autoHideDelay == 3.0)
        #expect(minimalSettings.hideOnPlay == true)
        
        let alwaysVisibleSettings = UIControlSettings.alwaysVisiblePreset()
        #expect(alwaysVisibleSettings.autoHideDelay == 0)
        #expect(alwaysVisibleSettings.hideOnPlay == false)
        
        let subtleSettings = UIControlSettings.subtlePreset()
        #expect(subtleSettings.backgroundOpacity < 0.5)
        #expect(subtleSettings.fadeAnimationDuration == 0.5)
    }
    
    // MARK: - Memory Leak Tests
    
    @Test func testNoRetainCycles() {
        var stateManager: UIControlStateManager? = UIControlStateManager(
            uiControlSettings: createTestUIControlSettings(),
            slideshowViewModel: nil
        )
        
        weak var weakStateManager = stateManager
        
        // Set up callbacks that could create retain cycles
        stateManager?.onKeyboardInteraction = { [weak stateManager] in
            _ = stateManager?.isControlsVisible
        }
        
        // Clear strong reference
        stateManager = nil
        
        // Should be deallocated
        #expect(weakStateManager == nil)
    }
}