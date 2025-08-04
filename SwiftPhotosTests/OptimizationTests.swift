import XCTest
import SwiftUI
@testable import Swift_Photos

/// Comprehensive test suite for all optimization phases
final class OptimizationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var settingsFactory: SettingsManagerFactory!
    var commandContext: CommandContext!
    var commandManager: SlideshowCommandManager!
    var mockViewModel: MockSlideshowViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize test dependencies
        await MainActor.run {
            mockViewModel = MockSlideshowViewModel()
            settingsFactory = SettingsManagerFactory.shared
            
            commandContext = CommandContext(
                viewModel: mockViewModel,
                settings: nil,
                telemetry: nil
            )
            
            commandManager = SlideshowCommandManager(
                context: commandContext,
                enableCommandMerging: true,
                enableMacroRecording: true
            )
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            settingsFactory.clearRegistry()
            commandManager.clearHistory()
        }
        
        mockViewModel = nil
        settingsFactory = nil
        commandContext = nil
        commandManager = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Phase 1 Tests: Play/Pause State & Transitions
    
    func testPlayPauseIconStateUpdate() async throws {
        // Test that play/pause state properly updates in the view model
        await MainActor.run {
            XCTAssertFalse(mockViewModel.slideshow?.isPlaying ?? true)
            
            mockViewModel.play()
            XCTAssertTrue(mockViewModel.slideshow?.isPlaying ?? false)
            
            mockViewModel.pause()
            XCTAssertFalse(mockViewModel.slideshow?.isPlaying ?? true)
        }
    }
    
    func testAllTransitionEffects() async throws {
        // Test that all 13 transition effects are properly defined
        let allEffects = TransitionSettings.TransitionEffectType.allCases
        XCTAssertEqual(allEffects.count, 13)
        
        // Test each transition creates a valid strategy
        for effect in allEffects {
            let strategy = TransitionStrategyFactory.strategy(for: effect)
            XCTAssertNotNil(strategy)
            XCTAssertEqual(strategy.effectType, effect)
            
            // Test transition creation doesn't crash
            let transition = strategy.createSwiftUITransition()
            XCTAssertNotNil(transition)
            
            // Test animation creation
            let animation = strategy.getAnimation(duration: 1.0, easing: .linear)
            if effect != .none {
                XCTAssertNotNil(animation)
            }
        }
    }
    
    func testRotationTransitions() async throws {
        // Specifically test rotation transitions work correctly
        let clockwise = TransitionStrategyFactory.strategy(for: .rotateClockwise)
        let counterClockwise = TransitionStrategyFactory.strategy(for: .rotateCounterClockwise)
        
        XCTAssertTrue(clockwise is RotationTransitionStrategy)
        XCTAssertTrue(counterClockwise is RotationTransitionStrategy)
        
        // Test rotation calculations
        let testView = Text("Test")
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        _ = clockwise.applyCustomEffects(
            to: testView,
            progress: 0.5,
            isVisible: true,
            bounds: bounds
        )
        
        _ = counterClockwise.applyCustomEffects(
            to: testView,
            progress: 0.5,
            isVisible: true,
            bounds: bounds
        )
    }
    
    // MARK: - Phase 2 Tests: Architecture Cleanup
    
    func testUnifiedInteractionManagerSimplification() async throws {
        // Test that UnifiedInteractionManager no longer depends on EnhancedInteractionCoordinator
        await MainActor.run {
            let uiSettings = ModernUIControlSettingsManager()
            let interactionManager = UnifiedInteractionManager(
                uiControlSettings: uiSettings,
                enableEnhancedFeatures: true // Should be ignored
            )
            
            // Test basic functionality works
            XCTAssertNotNil(interactionManager.uiControlManager)
            XCTAssertTrue(interactionManager.isControlsVisible)
            
            // Test interaction handling
            interactionManager.handleUserInteraction()
            interactionManager.handleKeyboardInteraction()
            
            // Test deprecated methods don't crash
            interactionManager.setEnhancedFeaturesEnabled(false)
            let timer = interactionManager.createAdaptiveTimer(for: "test")
            XCTAssertNil(timer)
        }
    }
    
    // MARK: - Phase 3 Tests: Strategy Pattern
    
    func testTransitionStrategyFactory() async throws {
        // Test factory creates correct strategies
        let strategies = TransitionStrategyFactory.allStrategies()
        XCTAssertEqual(strategies.count, 13)
        
        // Test each strategy type
        let testCases: [(TransitionSettings.TransitionEffectType, String)] = [
            (.none, "NoneTransitionStrategy"),
            (.fade, "FadeTransitionStrategy"),
            (.slideLeft, "SlideTransitionStrategy"),
            (.zoomIn, "ScaleTransitionStrategy"),
            (.rotateClockwise, "RotationTransitionStrategy"),
            (.pushLeft, "PushTransitionStrategy"),
            (.crossfade, "CrossfadeTransitionStrategy")
        ]
        
        for (effectType, expectedClassName) in testCases {
            let strategy = TransitionStrategyFactory.strategy(for: effectType)
            let className = String(describing: type(of: strategy))
            XCTAssertTrue(className.contains(expectedClassName), 
                         "Expected \(expectedClassName) for \(effectType), got \(className)")
        }
    }
    
    func testStrategyPatternSendability() async throws {
        // Test all strategies conform to Sendable
        let strategies = TransitionStrategyFactory.allStrategies()
        
        for strategy in strategies {
            // This will compile only if strategy is Sendable
            let _: any TransitionStrategy = strategy
        }
    }
    
    // MARK: - Phase 4 Tests: Factory Pattern & Unified Button
    
    @MainActor
    func testSettingsManagerFactory() async throws {
        // Test factory creates all managers
        let bundle = settingsFactory.createAllSettings()
        
        XCTAssertNotNil(bundle.performance)
        XCTAssertNotNil(bundle.slideshow)
        XCTAssertNotNil(bundle.sort)
        XCTAssertNotNil(bundle.transition)
        XCTAssertNotNil(bundle.uiControl)
        XCTAssertNotNil(bundle.localization)
        
        // Test preset application
        let highPerfBundle = settingsFactory.createPresetBundle(for: .highPerformance)
        XCTAssertEqual(highPerfBundle.performance.settings, .extreme)
        XCTAssertEqual(highPerfBundle.slideshow.settings, .quick)
        
        // Test validation
        let validationResults = bundle.validateAll()
        XCTAssertEqual(validationResults.count, 6)
        XCTAssertTrue(validationResults[.performance] ?? false)
    }
    
    @MainActor
    func testUnifiedSlideshowButton() async throws {
        // Test button creation
        let playButton = UnifiedSlideshowButton.Factory.playPauseButton(
            isPlaying: false,
            action: {}
        )
        XCTAssertNotNil(playButton)
        
        let navButton = UnifiedSlideshowButton.Factory.navigationButton(
            direction: .next,
            action: {}
        )
        XCTAssertNotNil(navButton)
        
        // Test all button types
        for buttonType in UnifiedSlideshowButton.ButtonType.allCases {
            let button = UnifiedSlideshowButton(
                type: buttonType,
                action: {}
            )
            XCTAssertNotNil(button)
            XCTAssertNotNil(buttonType.systemImageName)
            XCTAssertNotNil(buttonType.displayName)
        }
    }
    
    // MARK: - Phase 5 Tests: Command Pattern
    
    @MainActor
    func testCommandExecution() async throws {
        // Test play command
        let playCommand = PlayCommand(context: commandContext)
        await commandManager.execute(playCommand)
        
        XCTAssertTrue(mockViewModel.playWasCalled)
        XCTAssertTrue(commandManager.canUndo)
        XCTAssertFalse(commandManager.canRedo)
        
        // Test undo
        await commandManager.undo()
        XCTAssertTrue(mockViewModel.pauseWasCalled)
        XCTAssertFalse(commandManager.canUndo)
        XCTAssertTrue(commandManager.canRedo)
        
        // Test redo
        await commandManager.redo()
        XCTAssertTrue(commandManager.canUndo)
        XCTAssertFalse(commandManager.canRedo)
    }
    
    @MainActor
    func testCommandMerging() async throws {
        // Test consecutive navigation commands merge
        let next1 = NextPhotoCommand(context: commandContext)
        let next2 = NextPhotoCommand(context: commandContext)
        
        await commandManager.execute(next1)
        
        // Execute second command immediately
        await commandManager.execute(next2)
        
        // Should have merged into a single batch command
        let history = commandManager.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertTrue(history.first?.command is NavigationBatchCommand)
    }
    
    @MainActor
    func testMacroRecording() async throws {
        // Start recording
        commandManager.startMacroRecording()
        
        // Execute some commands
        await commandManager.execute(PlayCommand(context: commandContext))
        await commandManager.execute(NextPhotoCommand(context: commandContext))
        await commandManager.execute(PauseCommand(context: commandContext))
        
        // Stop recording
        let macro = commandManager.stopMacroRecording()
        XCTAssertNotNil(macro)
        XCTAssertEqual(macro?.commands.count, 3)
        
        // Execute macro
        if let macro = macro {
            await commandManager.execute(macro)
        }
    }
    
    @MainActor
    func testCommandFactory() async throws {
        let factory = SlideshowCommandFactory(context: commandContext)
        
        // Test all command creation methods
        let commands = [
            factory.makePlayCommand(),
            factory.makePauseCommand(),
            factory.makeStopCommand(),
            factory.makeNextPhotoCommand(),
            factory.makePreviousPhotoCommand(),
            factory.makeJumpToPhotoCommand(index: 5),
            factory.makeSelectFolderCommand()
        ]
        
        for command in commands {
            XCTAssertNotNil(command.id)
            XCTAssertNotNil(command.displayName)
            XCTAssertNotNil(command.timestamp)
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testFullOptimizationIntegration() async throws {
        // Create all components
        let settingsBundle = settingsFactory.createPresetBundle(for: .highPerformance)
        let commandFactory = SlideshowCommandFactory(context: commandContext)
        
        // Test integrated workflow
        await commandManager.execute(commandFactory.makeSelectFolderCommand())
        await commandManager.execute(commandFactory.makePlayCommand())
        
        for _ in 0..<5 {
            await commandManager.execute(commandFactory.makeNextPhotoCommand())
        }
        
        await commandManager.execute(commandFactory.makePauseCommand())
        
        // Verify state
        XCTAssertTrue(mockViewModel.selectFolderWasCalled)
        XCTAssertTrue(mockViewModel.playWasCalled)
        XCTAssertEqual(mockViewModel.nextPhotoCallCount, 5)
        XCTAssertTrue(mockViewModel.pauseWasCalled)
        
        // Test settings are applied
        XCTAssertEqual(settingsBundle.performance.settings, .extreme)
    }
    
    // MARK: - Performance Tests
    
    func testCommandExecutionPerformance() async throws {
        await MainActor.run {
            measure {
                // Measure command execution performance
                let expectation = self.expectation(description: "Commands executed")
                
                Task {
                    for _ in 0..<100 {
                        await commandManager.execute(NextPhotoCommand(context: commandContext))
                    }
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    func testTransitionCreationPerformance() {
        measure {
            // Measure transition strategy creation performance
            for _ in 0..<1000 {
                for effectType in TransitionSettings.TransitionEffectType.allCases {
                    _ = TransitionStrategyFactory.strategy(for: effectType)
                }
            }
        }
    }
}

// MARK: - Mock ViewModel for Testing

@MainActor
class MockSlideshowViewModel: SlideshowViewModelProtocol {
    // Track method calls
    var playWasCalled = false
    var pauseWasCalled = false
    var stopWasCalled = false
    var selectFolderWasCalled = false
    var nextPhotoCallCount = 0
    var previousPhotoCallCount = 0
    var jumpToPhotoCallCount = 0
    var lastJumpIndex: Int?
    
    // Mock properties
    var slideshow: Slideshow? = Slideshow(photos: [
        Photo(id: UUID(), url: ImageURL(url: URL(fileURLWithPath: "/test1.jpg")), name: "Test1", state: .loaded),
        Photo(id: UUID(), url: ImageURL(url: URL(fileURLWithPath: "/test2.jpg")), name: "Test2", state: .loaded),
        Photo(id: UUID(), url: ImageURL(url: URL(fileURLWithPath: "/test3.jpg")), name: "Test3", state: .loaded)
    ])
    
    var currentPhoto: Photo? {
        slideshow?.currentPhoto
    }
    
    var isLoading = false
    var error: Error?
    var canNavigateNext: Bool { true }
    var canNavigatePrevious: Bool { true }
    var progress: Double { 0.5 }
    var stats: PerformanceMonitor.Statistics?
    var folderSelectionState: FolderSelectionState { .idle }
    var loadingProgress: Double { 0.0 }
    var estimatedTimeRemaining: TimeInterval? { nil }
    var processedPhotoCount: Int { 0 }
    var totalPhotoCount: Int { 3 }
    var isGlobalSlideshow: Bool { false }
    var refreshCounter: Int = 0
    
    // Mock implementations
    func selectFolder() async {
        selectFolderWasCalled = true
    }
    
    func play() {
        playWasCalled = true
        slideshow?.play()
    }
    
    func pause() {
        pauseWasCalled = true
        slideshow?.pause()
    }
    
    func stop() {
        stopWasCalled = true
        slideshow?.stop()
    }
    
    func nextPhoto() async {
        nextPhotoCallCount += 1
        slideshow?.navigateNext()
    }
    
    func previousPhoto() async {
        previousPhotoCallCount += 1
        slideshow?.navigatePrevious()
    }
    
    func jumpToPhoto(at index: Int) async {
        jumpToPhotoCallCount += 1
        lastJumpIndex = index
        slideshow?.navigate(to: index)
    }
    
    func updatePerformanceSettings(_ settings: PerformanceSettings) {}
    func clearSlideshow() {}
    func refreshSlideshow() async {}
    func updateLoadingState() {}
    func recreateImageLoader(with photos: [Photo]) {}
    func setupRepositorySlideshow(from folderURL: URL) async throws {}
    func setupLegacySlideshow(from photos: [Photo]) async {}
}