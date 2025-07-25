//
//  ModernSlideshowViewModelPerformanceTests.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/25.
//

import Testing
import Foundation
import AppKit
@testable import Swift_Photos

@MainActor
struct ModernSlideshowViewModelPerformanceTests {
    
    // MARK: - Test Configuration
    
    private static let smallCollectionSize = 100
    private static let mediumCollectionSize = 1_000
    private static let largeCollectionSize = 10_000
    private static let massiveCollectionSize = 50_000
    private static let extremeCollectionSize = 100_000
    
    // MARK: - Helper Methods
    
    private func createPerformanceTestViewModel(photoCount: Int) -> (viewModel: ModernSlideshowViewModel, domainService: MockPerformanceDomainService) {
        let domainService = MockPerformanceDomainService()
        let fileAccess = MockPerformanceFileAccess()
        
        // Create test photos
        let photos = (0..<photoCount).map { index in
            Photo(
                id: UUID(),
                imageURL: ImageURL(url: URL(fileURLWithPath: "/test/perf_photo\(index).jpg")),
                fileName: "perf_photo\(index).jpg",
                loadState: .notLoaded,
                metadata: createMockPhotoMetadata()
            )
        }
        
        let testSlideshow = Slideshow(photos: photos, interval: .default, mode: .sequential)
        domainService.mockSlideshow = testSlideshow
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/performance")
        
        let viewModel = ModernSlideshowViewModel(
            domainService: domainService,
            fileAccess: fileAccess,
            performanceSettings: ModernPerformanceSettingsManager(),
            slideshowSettings: ModernSlideshowSettingsManager(),
            sortSettings: ModernSortSettingsManager()
        )
        
        return (viewModel, domainService)
    }
    
    private func createMockPhotoMetadata() -> PhotoMetadata {
        return PhotoMetadata(
            width: 1920,
            height: 1080,
            fileSize: 2_048_000, // 2MB
            creationDate: Date(),
            modificationDate: Date(),
            colorSpace: "sRGB"
        )
    }
    
    private func measureTime<T>(_ block: () async throws -> T) async rethrows -> (result: T, timeInterval: TimeInterval) {
        let startTime = Date()
        let result = try await block()
        let timeInterval = Date().timeIntervalSince(startTime)
        return (result, timeInterval)
    }
    
    // MARK: - Collection Size Performance Tests
    
    @Test func testSmallCollectionPerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: Self.smallCollectionSize)
        
        let (_, loadTime) = await measureTime {
            await viewModel.selectFolder()
        }
        
        // Small collections should load very quickly
        #expect(loadTime < 1.0) // Less than 1 second
        #expect(viewModel.slideshow?.photos.count == Self.smallCollectionSize)
        #expect(viewModel.error == nil)
        
        // Test navigation performance
        let (_, navTime) = await measureTime {
            for _ in 0..<10 {
                viewModel.nextPhoto()
            }
        }
        
        #expect(navTime < 0.1) // Navigation should be instant
    }
    
    @Test func testMediumCollectionPerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: Self.mediumCollectionSize)
        
        let (_, loadTime) = await measureTime {
            await viewModel.selectFolder()
        }
        
        // Medium collections should load reasonably quickly
        #expect(loadTime < 5.0) // Less than 5 seconds
        #expect(viewModel.slideshow?.photos.count == Self.mediumCollectionSize)
        #expect(viewModel.error == nil)
        
        // Test jump navigation performance
        let (_, jumpTime) = await measureTime {
            viewModel.fastGoToPhoto(at: Self.mediumCollectionSize / 2)
        }
        
        #expect(jumpTime < 0.5) // Fast jump should be very quick
    }
    
    @Test func testLargeCollectionPerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: Self.largeCollectionSize)
        
        let (_, loadTime) = await measureTime {
            await viewModel.selectFolder()
        }
        
        // Large collections should still load in reasonable time
        #expect(loadTime < 10.0) // Less than 10 seconds
        #expect(viewModel.slideshow?.photos.count == Self.largeCollectionSize)
        #expect(viewModel.error == nil)
        
        // Verify auto-optimization occurred
        let analysis = viewModel.getPerformanceAnalysis()
        #expect(analysis.currentSettings.memoryWindowSize > 100)
        #expect(analysis.canHandle == true)
        
        // Test random access performance
        let randomIndices = [100, 5000, 9000, 2000, 7500]
        let (_, randomAccessTime) = await measureTime {
            for index in randomIndices {
                viewModel.fastGoToPhoto(at: index)
            }
        }
        
        #expect(randomAccessTime < 2.0) // Random access should be efficient
    }
    
    @Test func testMassiveCollectionPerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: Self.massiveCollectionSize)
        
        let (_, loadTime) = await measureTime {
            await viewModel.selectFolder()
        }
        
        // Massive collections - longer load time acceptable
        #expect(loadTime < 30.0) // Less than 30 seconds
        #expect(viewModel.slideshow?.photos.count == Self.massiveCollectionSize)
        #expect(viewModel.error == nil)
        
        // Should use extreme performance settings
        let analysis = viewModel.getPerformanceAnalysis()
        #expect(analysis.currentSettings.memoryWindowSize >= 1000)
        #expect(analysis.currentSettings.maxMemoryUsageMB >= 8000)
        
        // Test navigation at scale
        let (_, scaleNavTime) = await measureTime {
            viewModel.fastGoToPhoto(at: 25000) // Jump to middle
            viewModel.nextPhoto()
            viewModel.previousPhoto()
            viewModel.fastGoToPhoto(at: 40000) // Jump to different section
        }
        
        #expect(scaleNavTime < 3.0) // Should handle large scale navigation
    }
    
    @Test func testExtremeCollectionPerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: Self.extremeCollectionSize)
        
        let (_, loadTime) = await measureTime {
            await viewModel.selectFolder()
        }
        
        // Extreme collections - generous time limit
        #expect(loadTime < 60.0) // Less than 1 minute
        #expect(viewModel.slideshow?.photos.count == Self.extremeCollectionSize)
        #expect(viewModel.error == nil)
        
        // Should use maximum performance settings
        let analysis = viewModel.getPerformanceAnalysis()
        #expect(analysis.currentSettings.memoryWindowSize >= 2000)
        #expect(analysis.currentSettings.maxMemoryUsageMB >= 16000)
        
        // Test extreme navigation
        let extremeIndices = [0, 25000, 50000, 75000, 99999]
        let (_, extremeNavTime) = await measureTime {
            for index in extremeIndices {
                viewModel.fastGoToPhoto(at: index)
            }
        }
        
        #expect(extremeNavTime < 5.0) // Should handle extreme navigation efficiently
    }
    
    // MARK: - Memory Usage Tests
    
    @Test func testMemoryUsageScaling() async {
        let testSizes = [100, 1000, 10000, 50000]
        
        for size in testSizes {
            let (viewModel, _) = createPerformanceTestViewModel(photoCount: size)
            await viewModel.selectFolder()
            
            let analysis = viewModel.getPerformanceAnalysis()
            let stats = await viewModel.getPerformanceStatistics()
            
            // Memory usage should scale appropriately
            #expect(analysis.estimatedMemoryUsage > 0)
            #expect(analysis.estimatedMemoryUsage < analysis.currentSettings.maxMemoryUsageMB * 1024 * 1024)
            
            // Virtual loader should have reasonable memory footprint
            #expect(stats.virtualLoader.memoryUsageMB < analysis.currentSettings.maxMemoryUsageMB)
            
            print("Collection size: \(size), Memory: \(stats.virtualLoader.memoryUsageMB)MB, Window: \(analysis.currentSettings.memoryWindowSize)")
        }
    }
    
    // MARK: - Cache Performance Tests
    
    @Test func testCacheEfficiency() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: 5000)
        await viewModel.selectFolder()
        
        // Navigate forward and backward to test cache efficiency
        for _ in 0..<50 {
            viewModel.nextPhoto()
        }
        
        for _ in 0..<25 {
            viewModel.previousPhoto()
        }
        
        let stats = await viewModel.getPerformanceStatistics()
        
        // Cache should be reasonably effective
        #expect(stats.virtualLoader.hits > 0)
        #expect(stats.virtualLoader.hitRate > 0.1) // At least 10% hit rate
        #expect(stats.preloader.successRate > 0.5) // At least 50% preload success
    }
    
    @Test func testRandomAccessCachePerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: 10000)
        await viewModel.selectFolder()
        
        // Random access pattern to stress test cache
        let randomIndices = Array(0..<100).map { _ in Int.random(in: 0..<10000) }
        
        let (_, randomTime) = await measureTime {
            for index in randomIndices {
                viewModel.fastGoToPhoto(at: index)
            }
        }
        
        #expect(randomTime < 10.0) // Should handle random access reasonably
        
        let stats = await viewModel.getPerformanceStatistics()
        #expect(stats.virtualLoader.loadedCount > 0)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test func testConcurrentNavigationPerformance() async {
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: 5000)
        await viewModel.selectFolder()
        
        let (_, concurrentTime) = await measureTime {
            // Simulate concurrent navigation
            let tasks = (0..<20).map { index in
                Task {
                    for _ in 0..<10 {
                        if index % 2 == 0 {
                            viewModel.nextPhoto()
                        } else {
                            viewModel.previousPhoto()
                        }
                    }
                }
            }
            
            for task in tasks {
                await task.value
            }
        }
        
        #expect(concurrentTime < 5.0) // Concurrent access should be handled efficiently
        #expect(viewModel.slideshow?.currentIndex != nil)
    }
    
    // MARK: - Performance Regression Tests
    
    @Test func testPerformanceRegressionBenchmark() async {
        // Baseline performance test that can detect regressions
        let (viewModel, _) = createPerformanceTestViewModel(photoCount: 1000)
        
        // Test folder loading
        let (_, loadTime) = await measureTime {
            await viewModel.selectFolder()
        }
        
        // Test sequential navigation
        let (_, seqTime) = await measureTime {
            for _ in 0..<100 {
                viewModel.nextPhoto()
            }
        }
        
        // Test random jumps
        let (_, jumpTime) = await measureTime {
            for i in 0..<20 {
                viewModel.fastGoToPhoto(at: i * 50)
            }
        }
        
        // Performance benchmarks (these values should be adjusted based on actual performance)
        #expect(loadTime < 3.0, "Folder loading regression detected: \(loadTime)s")
        #expect(seqTime < 0.5, "Sequential navigation regression detected: \(seqTime)s")
        #expect(jumpTime < 1.0, "Jump navigation regression detected: \(jumpTime)s")
        
        print("Performance Benchmark - Load: \(String(format: "%.3f", loadTime))s, Sequential: \(String(format: "%.3f", seqTime))s, Jumps: \(String(format: "%.3f", jumpTime))s")
    }
    
    // MARK: - Auto-Optimization Tests
    
    @Test func testAutoOptimizationCorrectness() async {
        let testCases = [
            (size: 50, expectedWindow: 50),
            (size: 500, expectedWindow: 200),
            (size: 5000, expectedWindow: 1000),
            (size: 25000, expectedWindow: 2000),
            (size: 75000, expectedWindow: 5000)
        ]
        
        for testCase in testCases {
            let (viewModel, _) = createPerformanceTestViewModel(photoCount: testCase.size)
            await viewModel.selectFolder()
            
            let analysis = viewModel.getPerformanceAnalysis()
            
            // Window size should be optimized for collection size
            #expect(analysis.currentSettings.memoryWindowSize >= testCase.expectedWindow / 2)
            #expect(analysis.currentSettings.memoryWindowSize <= max(testCase.expectedWindow * 2, testCase.size))
            
            print("Size: \(testCase.size), Window: \(analysis.currentSettings.memoryWindowSize), Expected: ~\(testCase.expectedWindow)")
        }
    }
}

// MARK: - Performance Mock Classes

class MockPerformanceDomainService: SlideshowDomainService {
    var mockSlideshow: Slideshow?
    var createSlideshowCallCount = 0
    
    init() {
        let mockRepository = MockPerformanceRepository()
        let mockCache = MockPerformanceCache()
        super.init(repository: mockRepository, cache: mockCache, maxConcurrentLoads: 10)
    }
    
    override func createSlideshow(from folderURL: URL, interval: SlideshowInterval, mode: Slideshow.SlideshowMode) async throws -> Slideshow {
        createSlideshowCallCount += 1
        
        // Simulate realistic loading time based on collection size
        let photoCount = mockSlideshow?.photos.count ?? 0
        let loadDelay = min(0.001 * Double(photoCount), 5.0) // Max 5 seconds
        
        try await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
        
        return mockSlideshow ?? Slideshow(photos: [], interval: interval, mode: mode)
    }
    
    override func loadImage(for photo: Photo) async throws -> Photo {
        // Simulate image loading time
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        var loadedPhoto = photo
        loadedPhoto.updateLoadState(.loaded(SendableImage(NSImage())))
        return loadedPhoto
    }
}

class MockPerformanceRepository: SlideshowRepository {
    func loadPhotos(from folderURL: URL) async throws -> [Photo] {
        // This will be overridden by the domain service mock
        return []
    }
    
    func loadImage(for photo: Photo) async throws -> Photo {
        // Simulate fast image loading
        try await Task.sleep(nanoseconds: 5_000_000) // 0.005 seconds
        
        var loadedPhoto = photo
        loadedPhoto.updateLoadState(.loaded(SendableImage(NSImage())))
        return loadedPhoto
    }
    
    func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata? {
        return PhotoMetadata(
            width: 1920,
            height: 1080,
            fileSize: 2_048_000,
            creationDate: Date(),
            modificationDate: Date(),
            colorSpace: "sRGB"
        )
    }
}

class MockPerformanceCache: PhotoCache {
    private var cache: [ImageURL: NSImage] = [:]
    private let maxSize = 1000 // Simulate cache size limit
    
    func getCachedImage(for imageURL: ImageURL) async -> NSImage? {
        // Simulate cache lookup time
        try? await Task.sleep(nanoseconds: 1_000_000) // 0.001 seconds
        return cache[imageURL]
    }
    
    func setCachedImage(_ image: NSImage, for imageURL: ImageURL) async {
        // Simulate cache size management
        if cache.count >= maxSize {
            let keyToRemove = cache.keys.first!
            cache.removeValue(forKey: keyToRemove)
        }
        cache[imageURL] = image
    }
    
    func clearCache() async {
        cache.removeAll()
    }
    
    func getCacheStatistics() async -> CacheStatistics {
        return CacheStatistics(
            hitCount: cache.count * 3,
            missCount: cache.count,
            totalCost: cache.count * 150,
            currentCount: cache.count
        )
    }
}

class MockPerformanceFileAccess: SecureFileAccess {
    var mockFolderURL: URL?
    
    init() {
        // Initialize with empty implementation
    }
    
    override func selectFolder() throws -> URL? {
        // Simulate realistic folder selection time
        Thread.sleep(forTimeInterval: 0.1)
        return mockFolderURL
    }
}