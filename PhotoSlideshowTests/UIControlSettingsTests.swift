//
//  UIControlSettingsTests.swift
//  PhotoSlideshowTests
//
//  Created by Claude Code on 2025/07/24.
//

import Testing
import Foundation
@testable import PhotoSlideshow

@MainActor
struct UIControlSettingsTests {
    
    // MARK: - Initialization Tests
    
    @Test func testDefaultInitialization() {
        let settings = UIControlSettings()
        
        #expect(settings.autoHideDelay == 5.0)
        #expect(settings.playingAutoHideDelay == 2.0)
        #expect(settings.pausedAutoHideDelay == 10.0)
        #expect(settings.fadeAnimationDuration == 0.3)
        #expect(settings.backgroundBlurIntensity == 0.8)
        #expect(settings.backgroundOpacity == 0.15)
        #expect(settings.showDetailedInfoByDefault == false)
        #expect(settings.hideOnPlay == true)
        #expect(settings.minimumVisibilityDuration == 1.0)
        #expect(settings.showOnMouseMovement == true)
        #expect(settings.mouseSensitivity == 10.0)
        #expect(settings.bottomOffset == 50.0)
    }
    
    @Test func testCustomInitialization() {
        let settings = UIControlSettings(
            autoHideDelay: 3.0,
            playingAutoHideDelay: 1.5,
            pausedAutoHideDelay: 8.0,
            fadeAnimationDuration: 0.5,
            backgroundBlurIntensity: 0.6,
            backgroundOpacity: 0.2,
            showDetailedInfoByDefault: true,
            hideOnPlay: false,
            minimumVisibilityDuration: 2.0,
            showOnMouseMovement: false,
            mouseSensitivity: 20.0,
            bottomOffset: 75.0
        )
        
        #expect(settings.autoHideDelay == 3.0)
        #expect(settings.playingAutoHideDelay == 1.5)
        #expect(settings.pausedAutoHideDelay == 8.0)
        #expect(settings.fadeAnimationDuration == 0.5)
        #expect(settings.backgroundBlurIntensity == 0.6)
        #expect(settings.backgroundOpacity == 0.2)
        #expect(settings.showDetailedInfoByDefault == true)
        #expect(settings.hideOnPlay == false)
        #expect(settings.minimumVisibilityDuration == 2.0)
        #expect(settings.showOnMouseMovement == false)
        #expect(settings.mouseSensitivity == 20.0)
        #expect(settings.bottomOffset == 75.0)
    }
    
    // MARK: - Validation Tests
    
    @Test func testAutoHideDelayValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(autoHideDelay: 0.5)
        #expect(minSettings.autoHideDelay == 1.0) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(autoHideDelay: 50.0)
        #expect(maxSettings.autoHideDelay == 30.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(autoHideDelay: 7.0)
        #expect(validSettings.autoHideDelay == 7.0)
    }
    
    @Test func testPlayingAutoHideDelayValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(playingAutoHideDelay: 0.1)
        #expect(minSettings.playingAutoHideDelay == 0.5) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(playingAutoHideDelay: 15.0)
        #expect(maxSettings.playingAutoHideDelay == 10.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(playingAutoHideDelay: 3.0)
        #expect(validSettings.playingAutoHideDelay == 3.0)
    }
    
    @Test func testPausedAutoHideDelayValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(pausedAutoHideDelay: 0.5)
        #expect(minSettings.pausedAutoHideDelay == 1.0) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(pausedAutoHideDelay: 100.0)
        #expect(maxSettings.pausedAutoHideDelay == 60.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(pausedAutoHideDelay: 15.0)
        #expect(validSettings.pausedAutoHideDelay == 15.0)
    }
    
    @Test func testFadeAnimationDurationValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(fadeAnimationDuration: 0.05)
        #expect(minSettings.fadeAnimationDuration == 0.1) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(fadeAnimationDuration: 5.0)
        #expect(maxSettings.fadeAnimationDuration == 2.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(fadeAnimationDuration: 0.8)
        #expect(validSettings.fadeAnimationDuration == 0.8)
    }
    
    @Test func testBlurIntensityValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(backgroundBlurIntensity: -0.5)
        #expect(minSettings.backgroundBlurIntensity == 0.0) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(backgroundBlurIntensity: 1.5)
        #expect(maxSettings.backgroundBlurIntensity == 1.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(backgroundBlurIntensity: 0.7)
        #expect(validSettings.backgroundBlurIntensity == 0.7)
    }
    
    @Test func testBackgroundOpacityValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(backgroundOpacity: -0.2)
        #expect(minSettings.backgroundOpacity == 0.0) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(backgroundOpacity: 1.2)
        #expect(maxSettings.backgroundOpacity == 1.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(backgroundOpacity: 0.3)
        #expect(validSettings.backgroundOpacity == 0.3)
    }
    
    @Test func testMinimumVisibilityDurationValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(minimumVisibilityDuration: 0.05)
        #expect(minSettings.minimumVisibilityDuration == 0.1) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(minimumVisibilityDuration: 10.0)
        #expect(maxSettings.minimumVisibilityDuration == 5.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(minimumVisibilityDuration: 2.5)
        #expect(validSettings.minimumVisibilityDuration == 2.5)
    }
    
    @Test func testMouseSensitivityValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(mouseSensitivity: 0.5)
        #expect(minSettings.mouseSensitivity == 1.0) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(mouseSensitivity: 150.0)
        #expect(maxSettings.mouseSensitivity == 100.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(mouseSensitivity: 25.0)
        #expect(validSettings.mouseSensitivity == 25.0)
    }
    
    @Test func testBottomOffsetValidation() {
        // Test minimum constraint
        let minSettings = UIControlSettings(bottomOffset: 10.0)
        #expect(minSettings.bottomOffset == 20.0) // Should be clamped to minimum
        
        // Test maximum constraint
        let maxSettings = UIControlSettings(bottomOffset: 300.0)
        #expect(maxSettings.bottomOffset == 200.0) // Should be clamped to maximum
        
        // Test valid range
        let validSettings = UIControlSettings(bottomOffset: 80.0)
        #expect(validSettings.bottomOffset == 80.0)
    }
    
    // MARK: - Preset Tests
    
    @Test func testDefaultPreset() {
        let preset = UIControlSettings.default
        let regular = UIControlSettings()
        
        #expect(preset.autoHideDelay == regular.autoHideDelay)
        #expect(preset.playingAutoHideDelay == regular.playingAutoHideDelay)
        #expect(preset.pausedAutoHideDelay == regular.pausedAutoHideDelay)
        #expect(preset.fadeAnimationDuration == regular.fadeAnimationDuration)
        #expect(preset.backgroundBlurIntensity == regular.backgroundBlurIntensity)
        #expect(preset.backgroundOpacity == regular.backgroundOpacity)
        #expect(preset.showDetailedInfoByDefault == regular.showDetailedInfoByDefault)
        #expect(preset.hideOnPlay == regular.hideOnPlay)
        #expect(preset.minimumVisibilityDuration == regular.minimumVisibilityDuration)
        #expect(preset.showOnMouseMovement == regular.showOnMouseMovement)
        #expect(preset.mouseSensitivity == regular.mouseSensitivity)
        #expect(preset.bottomOffset == regular.bottomOffset)
    }
    
    @Test func testMinimalPreset() {
        let preset = UIControlSettings.minimal
        
        #expect(preset.autoHideDelay == 3.0)
        #expect(preset.playingAutoHideDelay == 1.0)
        #expect(preset.pausedAutoHideDelay == 5.0)
        #expect(preset.fadeAnimationDuration == 0.2)
        #expect(preset.backgroundBlurIntensity == 0.6)
        #expect(preset.backgroundOpacity == 0.1)
        #expect(preset.showDetailedInfoByDefault == false)
        #expect(preset.hideOnPlay == true)
        #expect(preset.minimumVisibilityDuration == 0.5)
        #expect(preset.showOnMouseMovement == true)
        #expect(preset.mouseSensitivity == 15.0)
        #expect(preset.bottomOffset == 30.0)
    }
    
    @Test func testAlwaysVisiblePreset() {
        let preset = UIControlSettings.alwaysVisible
        
        // These values will be clamped by validation
        #expect(preset.autoHideDelay == 30.0) // Clamped from 999.0 to max 30.0
        #expect(preset.playingAutoHideDelay == 10.0) // Clamped from 999.0 to max 10.0
        #expect(preset.pausedAutoHideDelay == 60.0) // Clamped from 999.0 to max 60.0
        #expect(preset.fadeAnimationDuration == 0.3)
        #expect(preset.backgroundBlurIntensity == 0.9)
        #expect(preset.backgroundOpacity == 0.2)
        #expect(preset.showDetailedInfoByDefault == true)
        #expect(preset.hideOnPlay == false)
        #expect(preset.minimumVisibilityDuration == 1.0)
        #expect(preset.showOnMouseMovement == true)
        #expect(preset.mouseSensitivity == 5.0)
        #expect(preset.bottomOffset == 60.0)
    }
    
    @Test func testSubtlePreset() {
        let preset = UIControlSettings.subtle
        
        #expect(preset.autoHideDelay == 7.0)
        #expect(preset.playingAutoHideDelay == 3.0)
        #expect(preset.pausedAutoHideDelay == 15.0)
        #expect(preset.fadeAnimationDuration == 0.5)
        #expect(preset.backgroundBlurIntensity == 0.5)
        #expect(preset.backgroundOpacity == 0.05)
        #expect(preset.showDetailedInfoByDefault == false)
        #expect(preset.hideOnPlay == true)
        #expect(preset.minimumVisibilityDuration == 1.5)
        #expect(preset.showOnMouseMovement == true)
        #expect(preset.mouseSensitivity == 20.0)
        #expect(preset.bottomOffset == 40.0)
    }
    
    // MARK: - Equality Tests
    
    @Test func testEquality() {
        let settings1 = UIControlSettings(
            autoHideDelay: 5.0,
            playingAutoHideDelay: 2.0,
            backgroundBlurIntensity: 0.8
        )
        
        let settings2 = UIControlSettings(
            autoHideDelay: 5.0,
            playingAutoHideDelay: 2.0,
            backgroundBlurIntensity: 0.8
        )
        
        let settings3 = UIControlSettings(
            autoHideDelay: 4.0, // Different value
            playingAutoHideDelay: 2.0,
            backgroundBlurIntensity: 0.8
        )
        
        #expect(settings1 == settings2)
        #expect(settings1 != settings3)
    }
    
    // MARK: - Codable Tests
    
    @Test func testCodable() throws {
        let originalSettings = UIControlSettings(
            autoHideDelay: 3.5,
            playingAutoHideDelay: 1.5,
            pausedAutoHideDelay: 8.0,
            fadeAnimationDuration: 0.4,
            backgroundBlurIntensity: 0.7,
            backgroundOpacity: 0.25,
            showDetailedInfoByDefault: true,
            hideOnPlay: false,
            minimumVisibilityDuration: 2.0,
            showOnMouseMovement: false,
            mouseSensitivity: 15.0,
            bottomOffset: 80.0
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSettings)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(UIControlSettings.self, from: data)
        
        // Verify
        #expect(decodedSettings == originalSettings)
        #expect(decodedSettings.autoHideDelay == 3.5)
        #expect(decodedSettings.playingAutoHideDelay == 1.5)
        #expect(decodedSettings.pausedAutoHideDelay == 8.0)
        #expect(decodedSettings.fadeAnimationDuration == 0.4)
        #expect(decodedSettings.backgroundBlurIntensity == 0.7)
        #expect(decodedSettings.backgroundOpacity == 0.25)
        #expect(decodedSettings.showDetailedInfoByDefault == true)
        #expect(decodedSettings.hideOnPlay == false)
        #expect(decodedSettings.minimumVisibilityDuration == 2.0)
        #expect(decodedSettings.showOnMouseMovement == false)
        #expect(decodedSettings.mouseSensitivity == 15.0)
        #expect(decodedSettings.bottomOffset == 80.0)
    }
}

// MARK: - UIControlSettingsManager Tests

@MainActor
struct UIControlSettingsManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func testManagerInitialization() {
        let manager = UIControlSettingsManager()
        
        // Should initialize with default settings (values should match even if not same instance)
        let defaultSettings = UIControlSettings.default
        #expect(manager.settings.autoHideDelay == defaultSettings.autoHideDelay)
        #expect(manager.settings.playingAutoHideDelay == defaultSettings.playingAutoHideDelay)
        #expect(manager.settings.pausedAutoHideDelay == defaultSettings.pausedAutoHideDelay)
        #expect(manager.settings.showDetailedInfoByDefault == defaultSettings.showDetailedInfoByDefault)
        #expect(manager.settings.hideOnPlay == defaultSettings.hideOnPlay)
    }
    
    // MARK: - Settings Update Tests
    
    @Test func testUpdateSettings() {
        let manager = UIControlSettingsManager()
        let customSettings = UIControlSettings(
            autoHideDelay: 8.0,
            playingAutoHideDelay: 3.0,
            showDetailedInfoByDefault: true
        )
        
        manager.updateSettings(customSettings)
        
        #expect(manager.settings == customSettings)
        #expect(manager.settings.autoHideDelay == 8.0)
        #expect(manager.settings.playingAutoHideDelay == 3.0)
        #expect(manager.settings.showDetailedInfoByDefault == true)
    }
    
    @Test func testResetToDefault() {
        let manager = UIControlSettingsManager()
        let customSettings = UIControlSettings(
            autoHideDelay: 8.0,
            showDetailedInfoByDefault: true
        )
        
        // Apply custom settings
        manager.updateSettings(customSettings)
        #expect(manager.settings != UIControlSettings.default)
        
        // Reset to default
        manager.resetToDefault()
        #expect(manager.settings == UIControlSettings.default)
    }
    
    @Test func testApplyPreset() {
        let manager = UIControlSettingsManager()
        
        // Apply minimal preset
        manager.applyPreset(.minimal)
        #expect(manager.settings == UIControlSettings.minimal)
        
        // Apply always visible preset
        manager.applyPreset(.alwaysVisible)
        #expect(manager.settings == UIControlSettings.alwaysVisible)
        
        // Apply subtle preset
        manager.applyPreset(.subtle)
        #expect(manager.settings == UIControlSettings.subtle)
    }
    
    // MARK: - Notification Tests
    
    @Test func testSettingsChangeNotification() async {
        let manager = UIControlSettingsManager()
        var notificationReceived = false
        var receivedSettings: UIControlSettings?
        
        // Set up notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: .uiControlSettingsChanged,
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            receivedSettings = notification.object as? UIControlSettings
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Update settings
        let newSettings = UIControlSettings(autoHideDelay: 7.0)
        manager.updateSettings(newSettings)
        
        // Give notification time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        #expect(notificationReceived == true)
        if let received = receivedSettings {
            #expect(received.autoHideDelay == 7.0)
        }
    }
}