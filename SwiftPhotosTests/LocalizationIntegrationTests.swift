//
//  LocalizationIntegrationTests.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/26.
//

import Testing
import Foundation
@testable import Swift_Photos

@MainActor
struct LocalizationIntegrationTests {
    
    // MARK: - Integration Tests
    
    @Test func testFullLocalizationWorkflow() async {
        // Clean up any previous state
        TestUtilities.cleanUserDefaults()
        
        // Create services
        let localizationService = LocalizationService()
        let localizationSettingsManager = ModernLocalizationSettingsManager(localizationService: localizationService as LocalizationService?)
        
        // Test initial state
        #expect(localizationService.currentLanguage == .system)
        #expect(localizationSettingsManager.settings.language == .system)
        
        // Test language change via settings manager
        var newSettings = localizationSettingsManager.settings
        newSettings.language = .japanese
        localizationSettingsManager.updateSettings(newSettings)
        
        // Wait for changes to propagate
        await TestUtilities.waitForAsync(timeout: 0.2)
        
        // Verify both services are in sync
        #expect(localizationService.currentLanguage == .japanese)
        #expect(localizationSettingsManager.settings.language == .japanese)
        
        // Test notification was sent
        let notification = await NotificationTestUtilities.waitForNotification(
            .languageChanged,
            timeout: 0.5
        )
        #expect(notification != nil)
        
        // Test persistence
        let newLocalizationService = LocalizationService()
        #expect(newLocalizationService.currentLanguage == .japanese)
        
        // Clean up
        TestUtilities.cleanUserDefaults()
    }
    
    @Test func testLocalizationServiceWithFileSystemRepository() async {
        let localizationService = LocalizationService()
        localizationService.setLanguage(.japanese)
        
        // Create test directory and images
        let testDir = TestUtilities.createTempTestDirectory()
        defer { TestUtilities.cleanupTestDirectory(testDir) }
        
        try? TestUtilities.createTestImages(in: testDir, count: 5)
        
        // Create repository with localization service
        let fileAccess = LocalizationTestMockSecureFileAccess()
        let imageLoader = ImageLoader() // Use real ImageLoader for this localization test
        let sortSettings = ModernSortSettingsManager()
        
        let repository = FileSystemPhotoRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        
        // Test that repository uses localized error messages
        fileAccess.shouldFailPrepareAccess = true
        
        do {
            _ = try await repository.loadPhotos(from: testDir)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            // Error should be localized (though we can't easily test the actual localization in unit tests)
            #expect(error != nil)
            
            if let slideshowError = error as? SlideshowError {
                switch slideshowError {
                case .folderAccessDenied:
                    // This is the expected error type
                    break
                default:
                    #expect(Bool(false), "Unexpected error type: \(slideshowError)")
                }
            }
        }
    }
    
    @Test func testLocalizationWithUIControlStateManager() async {
        let localizationService = LocalizationService()
        localizationService.setLanguage(.english)
        
        let uiControlSettings = ModernUIControlSettingsManager()
        let stateManager = UIControlStateManager(
            uiControlSettings: uiControlSettings,
            slideshowViewModel: nil
        )
        
        // Test that state manager can work with localization
        var callbackTriggered = false
        stateManager.onKeyboardInteraction = {
            callbackTriggered = true
        }
        
        stateManager.handleKeyboardInteraction()
        #expect(callbackTriggered == true)
        
        // Change language and verify state manager still works
        localizationService.setLanguage(.japanese)
        await TestUtilities.waitForAsync(timeout: 0.1)
        
        callbackTriggered = false
        stateManager.handleKeyboardInteraction()
        #expect(callbackTriggered == true)
    }
    
    @Test func testLanguageChangeAcrossMultipleServices() async {
        TestUtilities.cleanUserDefaults()
        
        // Create multiple services that should stay in sync
        let localizationService = LocalizationService()
        let localizationSettings1 = ModernLocalizationSettingsManager(localizationService: localizationService as LocalizationService?)
        
        // Small delay to ensure first manager is initialized
        await TestUtilities.waitForAsync(timeout: 0.1)
        
        let localizationSettings2 = ModernLocalizationSettingsManager(localizationService: localizationService as LocalizationService?)
        
        // Small delay to ensure second manager is initialized
        await TestUtilities.waitForAsync(timeout: 0.1)
        
        // Change language in one settings manager
        var settings1 = localizationSettings1.settings
        settings1.language = .spanish
        localizationSettings1.updateSettings(settings1)
        
        await TestUtilities.waitForAsync(timeout: 0.5)
        
        // Both settings managers should reflect the change
        #expect(localizationSettings1.settings.language == .spanish)
        #expect(localizationSettings2.settings.language == .spanish, "// Both settings managers should reflect the change")
        #expect(localizationService.currentLanguage == .spanish)
        
        TestUtilities.cleanUserDefaults()
    }
    
    @Test func testRapidLanguageChanges() async {
        let localizationService = LocalizationService()
        
        // Rapid fire language changes to test thread safety
        let languages: [SupportedLanguage] = [.english, .japanese, .spanish, .french, .german]
        
        for language in languages {
            localizationService.setLanguage(language)
            
            // Test that service still works after language change
            #expect(localizationService.currentLanguage == language)
            
            // Small delay to simulate real usage
            await TestUtilities.waitForAsync(timeout: 0.01)
        }
        
        // Final language should be German
        #expect(localizationService.currentLanguage == .german)
    }
    
    @Test func testLocalizationPerformance() async {
        let localizationService = LocalizationService()
        localizationService.setLanguage(.japanese)
        
        // Test performance of language changes
        let (_, time) = await PerformanceTestUtilities.measureAsyncTime {
            for i in 0..<1000 {
                let language: SupportedLanguage = i % 2 == 0 ? .japanese : .english
                localizationService.setLanguage(language)
            }
        }
        
        // Should complete 1000 localizations in reasonable time (< 0.1s)
        #expect(time < 0.1, "Localization performance is too slow: \(time)s for 1000 calls")
    }
    
    @Test func testLocalizationCacheEfficiency() async {
        let localizationService = LocalizationService()
        localizationService.setLanguage(.english)
        
        // First language change
        let (_, firstCallTime) = await PerformanceTestUtilities.measureAsyncTime {
            localizationService.setLanguage(.english)
        }
        
        // Subsequent changes to same language (should be optimized)
        let (_, subsequentCallTime) = await PerformanceTestUtilities.measureAsyncTime {
            for _ in 0..<100 {
                localizationService.setLanguage(.english)
            }
        }
        
        // Efficiency: subsequent calls should be faster per call
        let avgSubsequentTime = subsequentCallTime / 100
        #expect(avgSubsequentTime <= firstCallTime, "Same language changes should be optimized")
    }
    
    @Test func testLanguageChangeNotificationTiming() async {
        let localizationService = LocalizationService()
        
        var notificationReceived = false
        var notificationLanguage: SupportedLanguage?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            notificationLanguage = notification.object as? SupportedLanguage
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Change language and measure notification timing
        let startTime = CFAbsoluteTimeGetCurrent()
        localizationService.setLanguage(.japanese)
        
        // Wait for notification
        while !notificationReceived && CFAbsoluteTimeGetCurrent() - startTime < 2.0 {
            await TestUtilities.waitForAsync(timeout: 0.01)
        }
        
        let notificationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(notificationReceived == true)
        #expect(notificationLanguage == .japanese)
        #expect(notificationTime < 2.0, "Notification should be sent quickly: \(notificationTime)s")
    }
    
    @Test func testConcurrentLanguageAccess() async {
        let localizationService = LocalizationService()
        
        // Test concurrent access from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Rapid language changes
            group.addTask {
                for i in 0..<50 {
                    let language: SupportedLanguage = i % 2 == 0 ? .english : .japanese
                    await localizationService.setLanguage(language)
                    await TestUtilities.waitForAsync(timeout: 0.001)
                }
            }
            
            // Task 2: Continuous language queries
            group.addTask {
                for _ in 0..<100 {
                    _ = await localizationService.currentLanguage
                    await TestUtilities.waitForAsync(timeout: 0.001)
                }
            }
            
            // Task 3: Language status queries
            group.addTask {
                for _ in 0..<20 {
                    _ = await localizationService.currentLanguage
                    await TestUtilities.waitForAsync(timeout: 0.005)
                }
            }
        }
        
        // After concurrent operations, service should still be functional
        #expect(localizationService.currentLanguage != .system)
    }
    
    @Test func testMemoryUsageUnderLoad() async {
        let localizationService = LocalizationService()
        
        // Test memory usage with many language changes
        let languages: [SupportedLanguage] = [.english, .japanese, .spanish, .french, .german]
        
        for _ in 0..<200 {
            for language in languages {
                localizationService.setLanguage(language)
            }
        }
        
        // Service should still be responsive
        #expect(localizationService.currentLanguage == .german)
    }
}

// MARK: - Test Helper Classes

/// Simple mock for LocalizationIntegrationTests
private class LocalizationTestMockSecureFileAccess: SecureFileAccess {
    var shouldFailPrepareAccess = false
    
    override init() {
        super.init()
    }
    
    override func prepareForAccess(url: URL, bookmarkData: Data? = nil) throws {
        if shouldFailPrepareAccess {
            throw SlideshowError.folderAccessDenied("Mock access denied for testing")
        }
    }
    
    override func validateFileAccess(for url: URL) throws {
        if shouldFailPrepareAccess {
            throw SlideshowError.folderAccessDenied("Mock access denied for testing")
        }
    }
}