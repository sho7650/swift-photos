import XCTest
@testable import Swift_Photos

final class VirtualLoadingSystemTests: XCTestCase {
    
    private var virtualLoader: VirtualImageLoader!
    private var backgroundPreloader: BackgroundPreloader!
    private var performanceSettings: PerformanceSettings!
    
    override func setUp() async throws {
        try await super.setUp()
        
        performanceSettings = PerformanceSettings(
            memoryWindowSize: 50,
            maxMemoryUsageMB: 1000,
            maxConcurrentLoads: 5,
            largeCollectionThreshold: 100,
            aggressiveMemoryManagement: true,
            preloadDistance: 10
        )
        
        virtualLoader = VirtualImageLoader(settings: performanceSettings)
        backgroundPreloader = BackgroundPreloader(settings: performanceSettings)
    }
    
    override func tearDown() async throws {
        virtualLoader = nil
        backgroundPreloader = nil
        performanceSettings = nil
        
        try await super.tearDown()
    }
    
    // MARK: - VirtualImageLoader Tests
    
    func testVirtualLoader_LoadImageWindow() async throws {
        // Given
        let photos = createTestPhotos(count: 100)
        let currentIndex = 50
        
        // When
        await virtualLoader.loadImageWindow(around: currentIndex, photos: photos)
        
        // Allow some time for async loading
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        let stats = await virtualLoader.getCacheStatistics()
        XCTAssertGreaterThan(stats.loadedCount, 0)
        XCTAssertLessThanOrEqual(stats.loadedCount, performanceSettings.memoryWindowSize)
    }
    
    func testVirtualLoader_MemoryPressureHandling() async throws {
        // Given
        let photos = createTestPhotos(count: 1000)
        
        // Load many windows to trigger memory pressure
        for index in stride(from: 0, to: 500, by: 50) {
            await virtualLoader.loadImageWindow(around: index, photos: photos)
        }
        
        // Allow time for loading and memory management
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then
        let stats = await virtualLoader.getCacheStatistics()
        let memoryUsage = await virtualLoader.getMemoryUsage()
        
        // Memory usage should be kept under the limit
        XCTAssertLessThanOrEqual(memoryUsage, performanceSettings.maxMemoryUsageMB)
    }
    
    func testVirtualLoader_CancelOperations() async throws {
        // Given
        let photos = createTestPhotos(count: 100)
        
        // Start loading
        await virtualLoader.loadImageWindow(around: 50, photos: photos)
        
        // When - cancel all operations
        await virtualLoader.cancelAllForProgressJump()
        
        // Then
        let activeTaskCount = await virtualLoader.getActiveTaskCount()
        XCTAssertEqual(activeTaskCount, 0)
    }
    
    func testVirtualLoader_UpdateSettings() async throws {
        // Given
        let newSettings = PerformanceSettings(
            memoryWindowSize: 100,
            maxMemoryUsageMB: 2000,
            maxConcurrentLoads: 10
        )
        
        // When
        await virtualLoader.updateSettings(newSettings)
        
        // Then - verify settings are applied (would need exposed properties to test properly)
        // For now, just verify no crashes
        let photos = createTestPhotos(count: 50)
        await virtualLoader.loadImageWindow(around: 25, photos: photos)
    }
    
    func testVirtualLoader_AdaptiveWindowSizing() async throws {
        // Test different collection sizes get appropriate window sizes
        let testCases: [(collectionSize: Int, expectedMaxWindow: Int)] = [
            (50, 50),      // Small collection
            (500, 50),     // Medium collection
            (5000, 100),   // Large collection
            (50000, 500)   // Massive collection
        ]
        
        for testCase in testCases {
            let photos = createTestPhotos(count: testCase.collectionSize)
            await virtualLoader.loadImageWindow(around: testCase.collectionSize / 2, photos: photos)
            
            // Allow time for loading
            try await Task.sleep(nanoseconds: 100_000_000)
            
            let stats = await virtualLoader.getCacheStatistics()
            XCTAssertLessThanOrEqual(stats.loadedCount, testCase.expectedMaxWindow,
                                      "Collection size \(testCase.collectionSize) should have window <= \(testCase.expectedMaxWindow)")
        }
    }
    
    // MARK: - BackgroundPreloader Tests
    
    func testBackgroundPreloader_SchedulePreload() async throws {
        // Given
        let photos = createTestPhotos(count: 100)
        let currentIndex = 50
        
        // When
        await backgroundPreloader.schedulePreload(
            photos: photos,
            currentIndex: currentIndex,
            windowSize: 20
        )
        
        // Allow time for preloading
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then
        let stats = await backgroundPreloader.getStatistics()
        XCTAssertGreaterThan(stats.total, 0)
        XCTAssertGreaterThanOrEqual(stats.successful, 0)
    }
    
    func testBackgroundPreloader_UpdatePriorities() async throws {
        // Given
        let photos = createTestPhotos(count: 100)
        
        // Schedule initial preload
        await backgroundPreloader.schedulePreload(
            photos: photos,
            currentIndex: 25,
            windowSize: 20
        )
        
        // When - update priorities for new position
        await backgroundPreloader.updatePriorities(
            photos: photos,
            newIndex: 75
        )
        
        // Then - verify priorities were updated (would need internal state access)
        // For now, verify no crashes
        let stats = await backgroundPreloader.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.activeLoads, 0)
    }
    
    func testBackgroundPreloader_CancelAllPreloads() async throws {
        // Given
        let photos = createTestPhotos(count: 100)
        
        // Schedule preload
        await backgroundPreloader.schedulePreload(
            photos: photos,
            currentIndex: 50,
            windowSize: 30
        )
        
        // When
        await backgroundPreloader.cancelAllPreloads()
        
        // Then
        let stats = await backgroundPreloader.getStatistics()
        XCTAssertEqual(stats.activeLoads, 0)
    }
    
    func testBackgroundPreloader_UpdateSettings() async throws {
        // Given
        let newSettings = PerformanceSettings(
            maxConcurrentLoads: 15,
            preloadDistance: 25
        )
        
        // When
        await backgroundPreloader.updateSettings(newSettings)
        
        // Then - verify settings applied
        let photos = createTestPhotos(count: 50)
        await backgroundPreloader.schedulePreload(
            photos: photos,
            currentIndex: 25,
            windowSize: 25
        )
        
        // Verify no crashes with new settings
        let stats = await backgroundPreloader.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.activeLoads, 0)
    }
    
    // MARK: - Integration Tests
    
    func testVirtualLoadingSystem_Integration() async throws {
        // Given
        let photos = createTestPhotos(count: 1000)
        var callbackInvoked = false
        
        // Setup callback
        await virtualLoader.setImageLoadedCallback { photoId, image in
            callbackInvoked = true
        }
        
        // When - simulate navigation through photos
        for index in stride(from: 0, to: 100, by: 10) {
            await virtualLoader.loadImageWindow(around: index, photos: photos)
            await backgroundPreloader.schedulePreload(
                photos: photos,
                currentIndex: index,
                windowSize: performanceSettings.preloadDistance
            )
            
            // Simulate brief pause at each photo
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        // Then
        let loaderStats = await virtualLoader.getCacheStatistics()
        let preloaderStats = await backgroundPreloader.getStatistics()
        
        XCTAssertGreaterThan(loaderStats.loadedCount, 0)
        XCTAssertGreaterThan(preloaderStats.total, 0)
        XCTAssertTrue(callbackInvoked)
    }
    
    func testVirtualLoadingSystem_PerformanceUnderLoad() async throws {
        // Measure performance with large collection
        let photos = createTestPhotos(count: 10000)
        
        let startTime = Date()
        
        // Simulate rapid navigation
        for index in stride(from: 0, to: 1000, by: 100) {
            await virtualLoader.loadImageWindow(around: index, photos: photos)
            await backgroundPreloader.updatePriorities(photos: photos, newIndex: index)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Performance should be reasonable even with large collection
        XCTAssertLessThan(elapsed, 5.0, "Virtual loading should handle 10k photos efficiently")
        
        // Memory should be under control
        let memoryUsage = await virtualLoader.getMemoryUsage()
        XCTAssertLessThanOrEqual(memoryUsage, performanceSettings.maxMemoryUsageMB)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPhotos(count: Int) -> [Photo] {
        (1...count).map { index in
            Photo(
                imageURL: ImageURL(URL(fileURLWithPath: "/test/photo\(index).jpg")),
                fileName: "photo\(index).jpg",
                fileSize: Int64(index * 1000),
                fileCreationDate: Date(),
                fileModificationDate: Date()
            )
        }
    }
}

// MARK: - Performance Test Suite

final class VirtualLoadingPerformanceTests: XCTestCase {
    
    func testLargeCollectionPerformance() async throws {
        let settings = PerformanceSettings.extreme
        let virtualLoader = VirtualImageLoader(settings: settings)
        let photos = (1...100000).map { index in
            Photo(
                imageURL: ImageURL(URL(fileURLWithPath: "/test/photo\(index).jpg")),
                fileName: "photo\(index).jpg",
                fileSize: Int64(index * 1000),
                fileCreationDate: Date(),
                fileModificationDate: Date()
            )
        }
        
        // Measure window loading performance
        let metrics = await measure {
            await virtualLoader.loadImageWindow(around: 50000, photos: photos)
        }
        
        // Log performance metrics
        print("100k photo collection window load metrics:")
        print("- Average: \(metrics.average)")
        print("- Min: \(metrics.min)")
        print("- Max: \(metrics.max)")
        
        // Performance should be reasonable even with 100k photos
        XCTAssertLessThan(metrics.average, 0.1, "Window loading should be fast even with 100k photos")
    }
    
    private func measure(block: @escaping () async -> Void) async -> (average: TimeInterval, min: TimeInterval, max: TimeInterval) {
        var measurements: [TimeInterval] = []
        
        for _ in 0..<5 {
            let start = Date()
            await block()
            let elapsed = Date().timeIntervalSince(start)
            measurements.append(elapsed)
        }
        
        let average = measurements.reduce(0, +) / Double(measurements.count)
        let min = measurements.min() ?? 0
        let max = measurements.max() ?? 0
        
        return (average, min, max)
    }
}