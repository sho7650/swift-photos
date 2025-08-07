//
//  TestUtilities.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/26.
//

import Foundation
import Testing
import AppKit
@testable import Swift_Photos

// MARK: - Test Utilities

/// Utility functions for testing
struct TestUtilities {
    
    /// Clean up UserDefaults for a fresh test state
    static func cleanUserDefaults() {
        let keys = [
            "SwiftPhotos.SelectedLanguage",
            "SwiftPhotos.PreferredLanguages",
            "SwiftPhotos.UIControlSettings",
            "SwiftPhotos.PerformanceSettings",
            "SwiftPhotos.SlideshowSettings",
            "SwiftPhotos.SortSettings",
            "SwiftPhotos.TransitionSettings"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Create a temporary test directory
    static func createTempTestDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPhotosTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// Create test image files in a directory
    static func createTestImages(in directory: URL, count: Int = 3) throws {
        for i in 1...count {
            let imageURL = directory.appendingPathComponent("test_image_\(i).jpg")
            
            // Create minimal JPEG data
            let jpegData = Data([
                0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
                0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43
            ] + Array(repeating: UInt8(0), count: 100) + [0xFF, 0xD9])
            
            try jpegData.write(to: imageURL)
        }
    }
    
    /// Clean up test directory
    static func cleanupTestDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
    
    /// Wait for async operations to complete
    static func waitForAsync(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}

// MARK: - Mock Objects

/// Mock SecureFileAccess for testing
class TestUtilityMockSecureFileAccess: SecureFileAccess {
    var shouldFailPrepareAccess = false
    var shouldFailEnumerateImages = false
    var prepareAccessCallCount = 0
    var enumerateImagesCallCount = 0
    
    override init() {
        super.init()
    }
    
    override func prepareForAccess(url: URL, bookmarkData: Data? = nil) throws {
        prepareAccessCallCount += 1
        if shouldFailPrepareAccess {
            throw SlideshowError.securityError("Mock prepare access failed")
        }
    }
    
    override func enumerateImages(in folderURL: URL) throws -> [URL] {
        enumerateImagesCallCount += 1
        if shouldFailEnumerateImages {
            throw SlideshowError.folderAccessDenied("Mock enumerate images failed")
        }
        // Return empty array by default
        return []
    }
}

/// Mock ImageLoader for testing - actors don't support inheritance
actor MockImageLoader {
    var shouldFailLoad = false
    var loadCallCount = 0
    var lastLoadedImageURL: ImageURL?
    
    func loadImage(from imageURL: ImageURL) async throws -> SendableImage {
        loadCallCount += 1
        lastLoadedImageURL = imageURL
        
        if shouldFailLoad {
            throw SlideshowError.loadingFailed(underlying: CocoaError(.fileReadNoSuchFile))
        }
        
        // Return a small test image
        let size = CGSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        return SendableImage(image)
    }
    
    func extractMetadata(from url: URL) async throws -> Photo.PhotoMetadata? {
        return Photo.PhotoMetadata(
            fileSize: 1024,
            dimensions: CGSize(width: 100, height: 100),
            creationDate: Date(),
            colorSpace: "sRGB"
        )
    }
}

/// Mock ImageCache for testing - actors don't support inheritance
actor MockImageCache: PhotoCache {
    private var storage: [ImageURL: SendableImage] = [:]
    var cacheHitCount = 0
    var cacheMissCount = 0
    var storeCount = 0
    
    func getCachedImage(for imageURL: ImageURL) async -> SendableImage? {
        if let image = storage[imageURL] {
            cacheHitCount += 1
            return image
        } else {
            cacheMissCount += 1
            return nil
        }
    }
    
    func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) async {
        storage[imageURL] = image
        storeCount += 1
    }
    
    func clearCache() async {
        storage.removeAll()
    }
    
    func getCacheStatistics() async -> CacheStatistics {
        return CacheStatistics(
            hitCount: cacheHitCount,
            missCount: cacheMissCount,
            totalCost: storage.count * 100,
            currentCount: storage.count
        )
    }
    
    func getCacheStats() -> (hits: Int, misses: Int, stores: Int) {
        return (cacheHitCount, cacheMissCount, storeCount)
    }
}

/// Mock LocalizationService for testing UI components - final classes cannot be inherited
@MainActor  
class MockLocalizationService {
    var mockStrings: [String: String] = [:]
    var localizedStringCallCount = 0
    var lastRequestedKey: String?
    var currentLanguage: SupportedLanguage = .english
    
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        localizedStringCallCount += 1
        lastRequestedKey = key
        
        if let mockString = mockStrings[key] {
            if arguments.isEmpty {
                return mockString
            } else {
                return String(format: mockString, arguments: arguments)
            }
        }
        
        // Return the key itself as fallback (mimicking missing translations)
        return key
    }
    
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }
    
    func setMockString(_ string: String, for key: String) {
        mockStrings[key] = string
    }
    
    func clearMockStrings() {
        mockStrings.removeAll()
    }
    
    var effectiveLocale: Locale {
        return Locale(identifier: currentLanguage.rawValue)
    }
}

/// Mock SlideshowViewModel for testing UI components
@MainActor
class MockSlideshowViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentPhoto: Photo?
    @Published var error: Error?
    @Published var windowLevel: WindowLevel = .normal
    
    var playCallCount = 0
    var pauseCallCount = 0
    var stopCallCount = 0
    var nextCallCount = 0
    var previousCallCount = 0
    
    func play() {
        playCallCount += 1
        isPlaying = true
    }
    
    func pause() {
        pauseCallCount += 1
        isPlaying = false
    }
    
    func stop() {
        stopCallCount += 1
        isPlaying = false
    }
    
    func next() {
        nextCallCount += 1
    }
    
    func previous() {
        previousCallCount += 1
    }
    
    func clearError() {
        error = nil
    }
    
    func setMockPhoto(_ photo: Photo?) {
        currentPhoto = photo
    }
    
    func setMockError(_ error: Error?) {
        self.error = error
    }
}

// MARK: - Test Assertions

/// Custom assertions for testing
struct TestAssertions {
    
    /// Assert that two colors are approximately equal (useful for UI testing)
    static func assertColorsEqual(_ color1: NSColor, _ color2: NSColor, tolerance: CGFloat = 0.01) -> Bool {
        guard let rgb1 = color1.usingColorSpace(.deviceRGB),
              let rgb2 = color2.usingColorSpace(.deviceRGB) else {
            return false
        }
        
        return abs(rgb1.redComponent - rgb2.redComponent) < tolerance &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < tolerance &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < tolerance &&
               abs(rgb1.alphaComponent - rgb2.alphaComponent) < tolerance
    }
    
    /// Assert that a point is within a rectangle
    static func assertPointInRect(_ point: CGPoint, _ rect: CGRect) -> Bool {
        return rect.contains(point)
    }
    
    /// Assert that two time intervals are approximately equal
    static func assertTimeIntervalsEqual(_ time1: TimeInterval, _ time2: TimeInterval, tolerance: TimeInterval = 0.1) -> Bool {
        return abs(time1 - time2) < tolerance
    }
}

// MARK: - Performance Testing

/// Utilities for performance testing
struct PerformanceTestUtilities {
    
    /// Measure execution time of a block
    static func measureTime<T>(block: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Measure async execution time
    static func measureAsyncTime<T>(block: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Run a performance test multiple times and get statistics
    static func performanceStatistics(iterations: Int = 10, block: () throws -> Void) rethrows -> (min: TimeInterval, max: TimeInterval, average: TimeInterval) {
        var times: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let (_, time) = try measureTime(block: block)
            times.append(time)
        }
        
        let min = times.min() ?? 0
        let max = times.max() ?? 0
        let average = times.reduce(0, +) / Double(times.count)
        
        return (min, max, average)
    }
}

// MARK: - SwiftUI Testing Helpers

/// Helpers for testing SwiftUI components
@MainActor
struct SwiftUITestHelpers {
    
    /// Create a mock environment for SwiftUI testing
    static func createMockEnvironment() -> (
        localizationService: MockLocalizationService,
        slideshowViewModel: MockSlideshowViewModel
    ) {
        let localizationService = MockLocalizationService()
        let slideshowViewModel = MockSlideshowViewModel()
        
        // Set up common mock strings
        localizationService.setMockString("Play", for: "slideshow.button.play")
        localizationService.setMockString("Pause", for: "slideshow.button.pause")
        localizationService.setMockString("Stop", for: "slideshow.button.stop")
        localizationService.setMockString("Next", for: "slideshow.navigation.next")
        localizationService.setMockString("Previous", for: "slideshow.navigation.previous")
        localizationService.setMockString("Select Folder", for: "button.select_folder")
        
        return (localizationService, slideshowViewModel)
    }
}

// MARK: - Notification Testing

/// Utilities for testing NotificationCenter interactions
struct NotificationTestUtilities {
    
    /// Wait for a notification to be posted
    static func waitForNotification(
        _ name: Notification.Name,
        timeout: TimeInterval = 1.0
    ) async -> Notification? {
        return await withCheckedContinuation { continuation in
            var observer: NSObjectProtocol?
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: nil)
            }
            
            observer = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { notification in
                timeoutTask.cancel()
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: notification)
            }
        }
    }
}

// MARK: - Error Testing

/// Custom errors for testing
enum TestError: Error, LocalizedError {
    case mockError
    case timeoutError
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .mockError:
            return "Mock error for testing"
        case .timeoutError:
            return "Operation timed out"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
}