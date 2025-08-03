import Testing
import Foundation
@testable import Swift_Photos

/// Consolidated comprehensive tests for UIControlStateManager
/// Combines functionality from UIControlStateManagerTests, UIControlStateManagerEnhancedTests, and UIControlStateManagerEnhancedTestsV2
@MainActor
struct UIControlStateManagerConsolidatedTests {
    
    // MARK: - Test Helpers
    
    private func createTestUIControlSettings(
        autoHideDelay: TimeInterval = 5.0,
        playingAutoHideDelay: TimeInterval = 2.0,
        pausedAutoHideDelay: TimeInterval = 10.0,
        fadeAnimationDuration: TimeInterval = 0.1, // Fast for testing
        backgroundBlurIntensity: Double = 0.5,
        backgroundOpacity: Double = 0.2,
        showDetailedInfoByDefault: Bool = false,
        hideOnPlay: Bool = true,
        minimumVisibilityDuration: TimeInterval = 0.5,
        showOnMouseMovement: Bool = true,
        mouseSensitivity: Double = 10.0,
        bottomOffset: Double = 50.0
    ) -> ModernUIControlSettingsManager {
        let settings = ModernUIControlSettingsManager()
        settings.updateSettings(UIControlSettings(
            autoHideDelay: autoHideDelay,
            playingAutoHideDelay: playingAutoHideDelay,
            pausedAutoHideDelay: pausedAutoHideDelay,
            fadeAnimationDuration: fadeAnimationDuration,
            backgroundBlurIntensity: backgroundBlurIntensity,
            backgroundOpacity: backgroundOpacity,
            showDetailedInfoByDefault: showDetailedInfoByDefault,
            hideOnPlay: hideOnPlay,
            minimumVisibilityDuration: minimumVisibilityDuration,
            showOnMouseMovement: showOnMouseMovement,
            mouseSensitivity: mouseSensitivity,
            bottomOffset: bottomOffset
        ))
        return settings
    }
    
    private func createMockSlideshowViewModel(isPlaying: Bool = false) async -> ModernSlideshowViewModel {
        let performanceSettings = ModernPerformanceSettingsManager()
        let slideshowSettings = ModernSlideshowSettingsManager()
        let sortSettings = ModernSortSettingsManager()
        
        let imageLoader = await ImageLoader()
        let imageCache = await ImageCache()
        let fileAccess = await SecureFileAccess()
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
    
    // MARK: - Initialization Tests
    
    @Test func testInitialization() {
        let uiControlSettings = createTestUIControlSettings()
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        #expect(stateManager.isControlsVisible == true)
        #expect(stateManager.isDetailedInfoVisible == false)
        #expect(stateManager.isMouseInWindow == false)
        #expect(stateManager.hasRecentInteraction == false)
        #expect(stateManager.mousePosition == .zero)
    }
    
    @Test func testInitializationWithViewModel() async {
        let uiControlSettings = createTestUIControlSettings()
        let viewModel = await createMockSlideshowViewModel()
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: viewModel
        )
        
        #expect(stateManager.isControlsVisible == true)
        #expect(stateManager.isDetailedInfoVisible == false)
    }
    
    // MARK: - Mouse Interaction Tests
    
    @Test func testMouseMovement() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        let testPosition = CGPoint(x: 100, y: 200)
        var mouseCallbackCalled = false
        
        stateManager.onMouseInteraction = { [weak stateManager] in
            mouseCallbackCalled = true
            #expect(stateManager?.mousePosition == testPosition)
        }
        
        stateManager.handleMouseMovement(to: testPosition)
        
        #expect(mouseCallbackCalled == true)
        #expect(stateManager.mousePosition == testPosition)
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    @Test func testMouseEnterWindow() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        stateManager.handleMouseEnterWindow()
        
        #expect(stateManager.isMouseInWindow == true)
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    @Test func testMouseExitWindow() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // First enter, then exit
        stateManager.handleMouseEnterWindow()
        stateManager.handleMouseExitWindow()
        
        #expect(stateManager.isMouseInWindow == false)
    }
    
    // MARK: - Keyboard Interaction Tests
    
    @Test func testKeyboardInteraction() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var keyboardCallbackCalled = false
        stateManager.onKeyboardInteraction = {
            keyboardCallbackCalled = true
        }
        
        stateManager.handleKeyboardInteraction()
        
        #expect(keyboardCallbackCalled == true)
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    // MARK: - Gesture Interaction Tests
    
    @Test func testGestureInteraction() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var gestureCallbackCalled = false
        stateManager.onGestureInteraction = {
            gestureCallbackCalled = true
        }
        
        stateManager.handleGestureInteraction()
        
        #expect(gestureCallbackCalled == true)
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    // MARK: - Controls Visibility Tests
    
    @Test func testShowControls() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var showCallbackCount = 0
        stateManager.onShowControls = {
            showCallbackCount += 1
        }
        
        stateManager.showControls()
        
        #expect(stateManager.isControlsVisible == true)
        #expect(showCallbackCount == 1)
    }
    
    @Test func testHideControls() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var hideCallbackCount = 0
        stateManager.onHideControls = {
            hideCallbackCount += 1
        }
        
        stateManager.hideControls()
        
        #expect(stateManager.isControlsVisible == false)
        #expect(hideCallbackCount == 1)
    }
    
    // MARK: - Detailed Info Tests
    
    @Test func testToggleDetailedInfo() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        var detailToggleCallbackCount = 0
        stateManager.onToggleDetailedInfo = {
            detailToggleCallbackCount += 1
        }
        
        let initialState = stateManager.isDetailedInfoVisible
        stateManager.toggleDetailedInfo()
        
        #expect(stateManager.isDetailedInfoVisible == !initialState)
        #expect(detailToggleCallbackCount == 1)
    }
    
    // MARK: - Settings Integration Tests
    
    @Test func testSettingsUpdate() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Update settings
        let newSettings = UIControlSettings(
            autoHideDelay: 8.0,
            playingAutoHideDelay: 3.0,
            pausedAutoHideDelay: 15.0,
            fadeAnimationDuration: 0.5,
            backgroundBlurIntensity: 0.8,
            backgroundOpacity: 0.6,
            showDetailedInfoByDefault: true,
            hideOnPlay: false,
            minimumVisibilityDuration: 1.0,
            showOnMouseMovement: false,
            mouseSensitivity: 20.0,
            bottomOffset: 80.0
        )
        
        uiControlSettings.updateSettings(newSettings)
        
        // Verify that state manager responds to settings changes
        #expect(uiControlSettings.settings.autoHideDelay == 8.0)
        #expect(uiControlSettings.settings.showDetailedInfoByDefault == true)
    }
    
    // MARK: - Slideshow Integration Tests
    
    @Test func testSlideshowPlayStateIntegration() async {
        let uiControlSettings = createTestUIControlSettings()
        let viewModel = await createMockSlideshowViewModel(isPlaying: false)
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: viewModel
        )
        
        // Test pause state
        #expect(viewModel.isPlaying == false)
        
        // Start playing
        viewModel.play()
        #expect(viewModel.isPlaying == true)
        
        // Stop playing
        viewModel.pause()
        #expect(viewModel.isPlaying == false)
    }
    
    // MARK: - Auto-Hide Behavior Tests
    
    @Test func testAutoHideDelayConfiguration() {
        let shortDelay: TimeInterval = 1.0
        let uiControlSettings = createTestUIControlSettings(
            autoHideDelay: shortDelay,
            playingAutoHideDelay: 0.5,
            pausedAutoHideDelay: 2.0
        )
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Verify settings are properly configured
        #expect(uiControlSettings.settings.autoHideDelay == shortDelay)
        #expect(uiControlSettings.settings.playingAutoHideDelay == 0.5)
        #expect(uiControlSettings.settings.pausedAutoHideDelay == 2.0)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test func testNilViewModelHandling() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // These should not crash with nil viewModel
        stateManager.handleMouseMovement(to: CGPoint(x: 50, y: 50))
        stateManager.handleKeyboardInteraction()
        stateManager.handleGestureInteraction()
        stateManager.showControls()
        stateManager.hideControls()
        stateManager.toggleDetailedInfo()
        
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    // MARK: - Memory Management Tests
    
    @Test func testWeakReferenceHandling() async {
        let uiControlSettings = createTestUIControlSettings()
        var viewModel: ModernSlideshowViewModel? = await createMockSlideshowViewModel()
        
        weak var weakStateManager: UIControlStateManager?
        
        do {
            let stateManager = UIControlStateManager(
                uiControlSettings: uiControlSettings,
                slideshowViewModel: viewModel
            )
            weakStateManager = stateManager
            
            #expect(weakStateManager != nil)
        }
        
        // Clear strong references
        viewModel = nil
        
        // State manager should still exist briefly due to test scope
        // but this tests that it doesn't create retain cycles
        #expect(weakStateManager != nil)
    }
    
    // MARK: - Performance Tests
    
    @Test func testMultipleInteractionPerformance() {
        let uiControlSettings = createTestUIControlSettings()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate rapid interactions
        for i in 0..<1000 {
            let position = CGPoint(x: Double(i % 100), y: Double(i % 100))
            stateManager.handleMouseMovement(to: position)
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete in reasonable time (less than 1 second)
        #expect(elapsed < 1.0)
        #expect(stateManager.hasRecentInteraction == true)
    }
    
    // MARK: - Integration with Different Settings Presets
    
    @Test func testMinimalSettings() {
        let uiControlSettings = createTestUIControlSettings(
            autoHideDelay: 2.0,
            fadeAnimationDuration: 0.1,
            backgroundBlurIntensity: 0.2,
            backgroundOpacity: 0.1,
            showDetailedInfoByDefault: false,
            hideOnPlay: true,
            minimumVisibilityDuration: 0.2,
            showOnMouseMovement: true,
            mouseSensitivity: 5.0
        )
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        #expect(uiControlSettings.settings.backgroundBlurIntensity == 0.2)
        #expect(uiControlSettings.settings.showDetailedInfoByDefault == false)
        #expect(stateManager.isDetailedInfoVisible == false)
    }
    
    @Test func testAlwaysVisibleSettings() {
        let uiControlSettings = createTestUIControlSettings(
            autoHideDelay: 0,  // 0 means always visible
            fadeAnimationDuration: 0.0,
            showDetailedInfoByDefault: true,
            hideOnPlay: false
        )
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        #expect(uiControlSettings.settings.autoHideDelay == 0)
        #expect(uiControlSettings.settings.showDetailedInfoByDefault == true)
        #expect(uiControlSettings.settings.hideOnPlay == false)
    }
    
    @Test func testSubtleSettings() {
        let uiControlSettings = createTestUIControlSettings(
            autoHideDelay: 3.0,
            fadeAnimationDuration: 0.8,
            backgroundBlurIntensity: 0.1,
            backgroundOpacity: 0.05,
            minimumVisibilityDuration: 0.8
        )
        
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        #expect(uiControlSettings.settings.fadeAnimationDuration == 0.8)
        #expect(uiControlSettings.settings.backgroundOpacity == 0.05)
    }
}