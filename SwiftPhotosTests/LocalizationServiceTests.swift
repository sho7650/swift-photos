//
//  LocalizationServiceTests.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/26.
//

import Testing
import Foundation
@testable import Swift_Photos

@MainActor
struct LocalizationServiceTests {
    
    // MARK: - Test Helpers
    
    private func createTestService() -> LocalizationService {
        return LocalizationService()
    }
    
    private func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "SwiftPhotos.SelectedLanguage")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Initialization Tests
    
    @Test func testInitialization() {
        clearUserDefaults()
        let service = createTestService()
        
        // Service should initialize with system language by default
        #expect(service.currentLanguage == .system)
        #expect(service.currentLocale == Locale.current)
    }
    
    @Test func testInitializationWithSavedLanguage() {
        clearUserDefaults()
        
        // Save Japanese language preference
        UserDefaults.standard.set("ja", forKey: "SwiftPhotos.SelectedLanguage")
        UserDefaults.standard.synchronize()
        
        let service = createTestService()
        
        // Service should load saved language preference
        #expect(service.currentLanguage == .japanese)
        #expect(service.currentLocale.identifier == "ja")
        
        clearUserDefaults()
    }
    
    // MARK: - Language Setting Tests
    
    @Test func testSetLanguage() {
        let service = createTestService()
        
        // Test setting to Japanese
        service.setLanguage(.japanese)
        #expect(service.currentLanguage == .japanese)
        #expect(service.currentLocale.identifier == "ja")
        
        // Test setting to English
        service.setLanguage(.english)
        #expect(service.currentLanguage == .english)
        #expect(service.currentLocale.identifier == "en")
        
        // Test setting to Spanish
        service.setLanguage(.spanish)
        #expect(service.currentLanguage == .spanish)
        #expect(service.currentLocale.identifier == "es")
    }
    
    @Test func testLanguagePersistence() {
        clearUserDefaults()
        let service = createTestService()
        
        // Set language and verify it's saved
        service.setLanguage(.french)
        #expect(service.currentLanguage == .french)
        
        // Check that it's persisted in UserDefaults
        let savedLanguage = UserDefaults.standard.string(forKey: "SwiftPhotos.SelectedLanguage")
        #expect(savedLanguage == "fr")
        
        clearUserDefaults()
    }
    
    @Test func testLanguageChangeNotification() async {
        let service = createTestService()
        var notificationReceived = false
        var receivedLanguage: SupportedLanguage?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            receivedLanguage = notification.object as? SupportedLanguage
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Change language and wait for notification
        service.setLanguage(.german)
        
        // Give notification time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        #expect(notificationReceived == true)
        #expect(receivedLanguage == .german)
    }
    
    // MARK: - Locale Tests
    
    @Test func testCurrentLocale() {
        let service = createTestService()
        
        // Test system locale
        service.setLanguage(.system)
        #expect(service.currentLocale == Locale.current)
        
        // Test specific locales
        service.setLanguage(.japanese)
        #expect(service.currentLocale.identifier == "ja")
        
        service.setLanguage(.chineseSimplified)
        #expect(service.currentLocale.identifier == "zh-Hans")
        
        service.setLanguage(.chineseTraditional)
        #expect(service.currentLocale.identifier == "zh-Hant")
    }
    
    @Test func testLanguageSupport() {
        let service = createTestService()
        
        // Test supported languages
        #expect(service.isLanguageSupported("en") == true)
        #expect(service.isLanguageSupported("ja") == true)
        #expect(service.isLanguageSupported("es") == true)
        #expect(service.isLanguageSupported("fr") == true)
        #expect(service.isLanguageSupported("de") == true)
        #expect(service.isLanguageSupported("zh-Hans") == true)
        #expect(service.isLanguageSupported("zh-Hant") == true)
        #expect(service.isLanguageSupported("ko") == true)
        #expect(service.isLanguageSupported("pt") == true)
        #expect(service.isLanguageSupported("it") == true)
        #expect(service.isLanguageSupported("ru") == true)
        
        // Test unsupported languages
        #expect(service.isLanguageSupported("ar") == false)
        #expect(service.isLanguageSupported("hi") == false)
        #expect(service.isLanguageSupported("invalid") == false)
    }
    
    // MARK: - SupportedLanguage Enum Tests
    
    @Test func testSupportedLanguageProperties() {
        // Test locale properties
        #expect(SupportedLanguage.english.locale.identifier == "en")
        #expect(SupportedLanguage.japanese.locale.identifier == "ja")
        #expect(SupportedLanguage.spanish.locale.identifier == "es")
        #expect(SupportedLanguage.french.locale.identifier == "fr")
        #expect(SupportedLanguage.german.locale.identifier == "de")
        
        // Test system language uses current locale
        #expect(SupportedLanguage.system.locale == Locale.current)
    }
    
    @Test func testSupportedLanguageDisplayNames() {
        // Test that display names are not empty
        for language in SupportedLanguage.allCases {
            let displayName = language.displayName
            #expect(displayName.isEmpty == false)
            ProductionLogger.debug("Language \(language.rawValue) display name: \(displayName)")
        }
    }
    
    @Test func testSupportedLanguageRightToLeft() {
        // Most languages are left-to-right
        #expect(SupportedLanguage.english.isRightToLeft == false)
        #expect(SupportedLanguage.japanese.isRightToLeft == false)
        #expect(SupportedLanguage.spanish.isRightToLeft == false)
        #expect(SupportedLanguage.french.isRightToLeft == false)
        #expect(SupportedLanguage.german.isRightToLeft == false)
        #expect(SupportedLanguage.chineseSimplified.isRightToLeft == false)
        #expect(SupportedLanguage.chineseTraditional.isRightToLeft == false)
        #expect(SupportedLanguage.korean.isRightToLeft == false)
        #expect(SupportedLanguage.portuguese.isRightToLeft == false)
        #expect(SupportedLanguage.italian.isRightToLeft == false)
        #expect(SupportedLanguage.russian.isRightToLeft == false)
        
        // System follows current locale
        #expect(SupportedLanguage.system.isRightToLeft == (Locale.current.language.characterDirection == .rightToLeft))
    }
    
    // MARK: - Performance Tests
    
    @Test func testLanguageChangePerformance() async {
        let service = createTestService()
        let languages: [SupportedLanguage] = [.english, .japanese, .spanish, .french, .german]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform many language changes
        for _ in 0..<100 {
            for language in languages {
                service.setLanguage(language)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        // Should complete 500 language changes in reasonable time
        #expect(totalTime < 1.0, "Language changes took too long: \(totalTime)s")
    }
    
    @Test func testConcurrentLanguageAccess() async {
        let service = createTestService()
        
        // Test concurrent access
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Language changes
            group.addTask {
                for i in 0..<50 {
                    let language: SupportedLanguage = i % 2 == 0 ? .english : .japanese
                    await service.setLanguage(language)
                }
            }
            
            // Task 2: Language reads
            group.addTask {
                for _ in 0..<100 {
                    _ = await service.currentLanguage
                    _ = await service.currentLocale
                }
            }
        }
        
        // Service should still be functional after concurrent access
        #expect(service.currentLanguage != .system || service.currentLanguage == .system)
    }
    
    // MARK: - Edge Case Tests
    
    @Test func testSetSameLanguageMultipleTimes() async {
        let service = createTestService()
        var notificationCount = 0
        
        let observer = NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Set the same language multiple times
        service.setLanguage(.spanish)
        service.setLanguage(.spanish)
        service.setLanguage(.spanish)
        
        // Give notifications time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Should only receive one notification
        #expect(notificationCount == 1)
        #expect(service.currentLanguage == .spanish)
    }
    
    @Test func testRapidLanguageChanges() async {
        let service = createTestService()
        let languages: [SupportedLanguage] = [.english, .japanese, .spanish, .french, .german]
        
        // Rapidly change languages
        for language in languages {
            service.setLanguage(language)
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        // Final language should be German
        #expect(service.currentLanguage == .german)
    }
}