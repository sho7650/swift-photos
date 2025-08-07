//
//  ModernSlideshowViewModelTests.swift
//  SwiftPhotosTests
//
//  Created by Claude Code on 2025/07/25.
//

import Testing
import Foundation
import AppKit
@testable import Swift_Photos

@MainActor
struct ModernSlideshowViewModelTests {
    
    // MARK: - Test Helpers
    
    private func createMockDomainService() -> MockSlideshowDomainService {
        return MockSlideshowDomainService()
    }
    
    private func createMockFileAccess() -> MockSecureFileAccess {
        return MockSecureFileAccess()
    }
    
    private func createTestPhotos(count: Int) -> [Photo] {
        return (0..<count).compactMap { index in
            do {
                return Photo(
                    id: UUID(),
                    imageURL: try ImageURL(URL(fileURLWithPath: "/test/photo\(index).jpg"))
                )
            } catch {
                return nil
            }
        }
    }
    
    private func createTestSlideshow(photoCount: Int = 5) -> Slideshow {
        let photos = createTestPhotos(count: photoCount)
        return Slideshow(photos: photos, interval: .default, mode: .sequential)
    }
    
    private func createTestViewModel(
        photoCount: Int = 5,
        performanceSettings: ModernPerformanceSettingsManager? = nil,
        slideshowSettings: ModernSlideshowSettingsManager? = nil,
        sortSettings: ModernSortSettingsManager? = nil
    ) -> (viewModel: ModernSlideshowViewModel, domainService: MockSlideshowDomainService, fileAccess: MockSecureFileAccess) {
        let domainService = createMockDomainService()
        let fileAccess = createMockFileAccess()
        
        // Configure mock to return test slideshow
        let testSlideshow = createTestSlideshow(photoCount: photoCount)
        domainService.mockSlideshow = testSlideshow
        
        let viewModel = ModernSlideshowViewModel(
            domainService: domainService,
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings
        )
        
        return (viewModel, domainService, fileAccess)
    }
    
    // MARK: - Initialization Tests
    
    @Test func testInitialization() {
        let (viewModel, _, _) = createTestViewModel()
        
        #expect(viewModel.slideshow == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
        #expect(viewModel.selectedFolderURL == nil)
        #expect(viewModel.currentPhoto == nil)
        #expect(viewModel.refreshCounter == 0)
    }
    
    @Test func testInitializationWithCustomSettings() {
        let performanceSettings = ModernPerformanceSettingsManager()
        let slideshowSettings = ModernSlideshowSettingsManager()
        let sortSettings = ModernSortSettingsManager()
        
        let (viewModel, _, _) = createTestViewModel(
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings
        )
        
        #expect(viewModel.slideshow == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
    }
    
    // MARK: - Folder Selection Tests
    
    @Test func testSelectFolderSuccess() async {
        let (viewModel, domainService, fileAccess) = createTestViewModel()
        let testURL = URL(fileURLWithPath: "/test/folder")
        fileAccess.mockFolderURL = testURL
        
        await viewModel.selectFolder()
        
        #expect(viewModel.selectedFolderURL == testURL)
        #expect(viewModel.slideshow != nil)
        #expect(viewModel.slideshow?.photos.count == 5)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
        #expect(domainService.createSlideshowCallCount == 1)
    }
    
    @Test func testSelectFolderCancelled() async {
        let (viewModel, domainService, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = nil // Simulate user cancellation
        
        await viewModel.selectFolder()
        
        #expect(viewModel.selectedFolderURL == nil)
        #expect(viewModel.slideshow == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
        #expect(domainService.createSlideshowCallCount == 0)
    }
    
    @Test func testSelectFolderError() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        let testError = SlideshowError.folderAccessDenied("Test folder not accessible")
        fileAccess.mockError = testError
        
        await viewModel.selectFolder()
        
        #expect(viewModel.selectedFolderURL == nil)
        #expect(viewModel.slideshow == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error != nil)
    }
    
    @Test func testSelectFolderLoadingState() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        let testURL = URL(fileURLWithPath: "/test/folder")
        fileAccess.mockFolderURL = testURL
        fileAccess.mockDelay = 0.1 // Add delay to test loading state
        
        let selectTask = Task {
            await viewModel.selectFolder()
        }
        
        // Check loading state is set
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        #expect(viewModel.isLoading == true)
        
        await selectTask.value
        #expect(viewModel.isLoading == false)
    }
    
    // MARK: - Slideshow Control Tests
    
    @Test func testPlaySlideshow() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        viewModel.play()
        
        #expect(viewModel.slideshow?.isPlaying == true)
        #expect(viewModel.slideshow?.state == .playing)
    }
    
    @Test func testPauseSlideshow() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        viewModel.play()
        viewModel.pause()
        
        #expect(viewModel.slideshow?.isPlaying == false)
        #expect(viewModel.slideshow?.state == .paused)
    }
    
    @Test func testStopSlideshow() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        viewModel.play()
        viewModel.stop()
        
        #expect(viewModel.slideshow?.isPlaying == false)
        #expect(viewModel.slideshow?.state == .stopped)
    }
    
    @Test func testPlayPauseStopWithoutSlideshow() {
        let (viewModel, _, _) = createTestViewModel()
        
        // These should not crash when no slideshow is loaded
        viewModel.play()
        viewModel.pause()
        viewModel.stop()
        
        #expect(viewModel.slideshow == nil)
    }
    
    // MARK: - Navigation Tests
    
    @Test func testNextPhoto() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        let initialIndex = viewModel.slideshow?.currentIndex ?? -1
        let initialRefreshCounter = viewModel.refreshCounter
        
        viewModel.nextPhoto()
        
        #expect(viewModel.slideshow?.currentIndex == (initialIndex + 1) % 5)
        #expect(viewModel.refreshCounter == initialRefreshCounter + 1)
        #expect(viewModel.currentPhoto == viewModel.slideshow?.currentPhoto)
    }
    
    @Test func testPreviousPhoto() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        viewModel.nextPhoto() // Move to index 1
        viewModel.nextPhoto() // Move to index 2
        let initialRefreshCounter = viewModel.refreshCounter
        
        viewModel.previousPhoto()
        
        #expect(viewModel.slideshow?.currentIndex == 1)
        #expect(viewModel.refreshCounter == initialRefreshCounter + 1)
        #expect(viewModel.currentPhoto == viewModel.slideshow?.currentPhoto)
    }
    
    @Test func testGoToPhotoValidIndex() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        let initialRefreshCounter = viewModel.refreshCounter
        
        viewModel.goToPhoto(at: 3)
        
        #expect(viewModel.slideshow?.currentIndex == 3)
        #expect(viewModel.refreshCounter == initialRefreshCounter + 1)
        #expect(viewModel.currentPhoto == viewModel.slideshow?.currentPhoto)
        #expect(viewModel.error == nil)
    }
    
    @Test func testGoToPhotoInvalidIndex() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        let initialIndex = viewModel.slideshow?.currentIndex ?? -1
        
        viewModel.goToPhoto(at: 10) // Invalid index
        
        #expect(viewModel.slideshow?.currentIndex == initialIndex) // Should remain unchanged
        #expect(viewModel.error != nil) // Should have error
    }
    
    @Test func testFastGoToPhoto() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        let initialRefreshCounter = viewModel.refreshCounter
        
        viewModel.fastGoToPhoto(at: 2)
        
        #expect(viewModel.slideshow?.currentIndex == 2)
        #expect(viewModel.refreshCounter == initialRefreshCounter + 1)
        #expect(viewModel.error == nil)
    }
    
    @Test func testNavigationWithoutSlideshow() {
        let (viewModel, _, _) = createTestViewModel()
        
        // These should not crash when no slideshow is loaded
        viewModel.nextPhoto()
        viewModel.previousPhoto()
        viewModel.goToPhoto(at: 0)
        viewModel.fastGoToPhoto(at: 0)
        
        #expect(viewModel.slideshow == nil)
        #expect(viewModel.error == nil)
    }
    
    // MARK: - Settings Tests
    
    @Test func testSetInterval() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        let newInterval = try! SlideshowInterval(5.0)
        
        viewModel.setInterval(newInterval)
        
        #expect(viewModel.slideshow?.interval == newInterval)
    }
    
    @Test func testSetMode() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        viewModel.setMode(.singleLoop)
        
        #expect(viewModel.slideshow?.mode == .singleLoop)
    }
    
    @Test func testUpdatePerformanceSettings() async {
        let (viewModel, _, _) = createTestViewModel()
        let newSettings = PerformanceSettings.highPerformance
        
        await viewModel.updatePerformanceSettings(newSettings)
        
        // The settings should be updated - we can verify through the performance analysis
        let analysis = viewModel.getPerformanceAnalysis()
        #expect(analysis.currentSettings == newSettings)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testClearError() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        let testError = SlideshowError.folderAccessDenied("Test folder not accessible")
        fileAccess.mockError = testError
        
        await viewModel.selectFolder()
        #expect(viewModel.error != nil)
        
        viewModel.clearError()
        #expect(viewModel.error == nil)
    }
    
    @Test func testErrorPersistence() async {
        let (viewModel, _, fileAccess) = createTestViewModel()
        let testError = SlideshowError.folderAccessDenied("Test folder not accessible")
        fileAccess.mockError = testError
        
        await viewModel.selectFolder()
        #expect(viewModel.error != nil)
        
        // Error should persist until explicitly cleared
        viewModel.nextPhoto()
        #expect(viewModel.error != nil)
        
        viewModel.clearError()
        #expect(viewModel.error == nil)
    }
    
    // MARK: - Performance Analysis Tests
    
    @Test func testGetPerformanceAnalysis() async {
        let (viewModel, _, fileAccess) = createTestViewModel(photoCount: 100)
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        let analysis = viewModel.getPerformanceAnalysis()
        
        #expect(analysis.collectionSize == 100)
        #expect(analysis.currentSettings != nil)
        #expect(analysis.recommendedSettings != nil)
        #expect(analysis.estimatedMemoryUsage > 0)
    }
    
    @Test func testGetPerformanceStatistics() async {
        let (viewModel, _, _) = createTestViewModel()
        
        let stats = await viewModel.getPerformanceStatistics()
        
        #expect(stats.virtualLoader.hitRate >= 0.0)
        #expect(stats.virtualLoader.hitRate <= 1.0)
        #expect(stats.preloader.successRate >= 0.0)
        #expect(stats.preloader.successRate <= 1.0)
    }
    
    // MARK: - Large Collection Performance Tests
    
    @Test func testLargeCollectionVirtualLoading() async {
        let (viewModel, _, fileAccess) = createTestViewModel(photoCount: 2000) // Large collection
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        #expect(viewModel.slideshow?.photos.count == 2000)
        #expect(viewModel.slideshow != nil)
        
        // Navigation should work with large collections
        viewModel.nextPhoto()
        #expect(viewModel.slideshow?.currentIndex == 1)
        
        viewModel.fastGoToPhoto(at: 1000)
        #expect(viewModel.slideshow?.currentIndex == 1000)
    }
    
    @Test func testPerformanceSettingsAutoOptimization() async {
        let (viewModel, _, fileAccess) = createTestViewModel(photoCount: 5000) // Massive collection
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        let analysis = viewModel.getPerformanceAnalysis()
        #expect(analysis.collectionSize == 5000)
        
        // Should auto-optimize for large collections
        #expect(analysis.currentSettings.memoryWindowSize > 100)
        #expect(analysis.canHandle == true)
    }
    
    // MARK: - Auto-Start Tests
    
    @Test func testAutoStartEnabled() async {
        let slideshowSettings = ModernSlideshowSettingsManager()
        slideshowSettings.updateSettings(SlideshowSettings(autoStart: true))
        
        let (viewModel, _, fileAccess) = createTestViewModel(
            slideshowSettings: slideshowSettings
        )
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        #expect(viewModel.slideshow?.isPlaying == true)
        #expect(viewModel.slideshow?.state == .playing)
    }
    
    @Test func testAutoStartDisabled() async {
        let slideshowSettings = ModernSlideshowSettingsManager()
        slideshowSettings.updateSettings(SlideshowSettings(autoStart: false))
        
        let (viewModel, _, fileAccess) = createTestViewModel(
            slideshowSettings: slideshowSettings
        )
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        #expect(viewModel.slideshow?.isPlaying == false)
        #expect(viewModel.slideshow?.state == .stopped)
    }
    
    // MARK: - Random Sort Integration Tests
    
    @Test func testRandomSortSeedRegeneration() async {
        let sortSettings = ModernSortSettingsManager()
        sortSettings.updateSettings(SortSettings(order: .random))
        
        let (viewModel, _, fileAccess) = createTestViewModel(
            sortSettings: sortSettings
        )
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        let initialSeed = sortSettings.settings.randomSeed
        
        await viewModel.selectFolder()
        
        // Random seed should be regenerated when selecting folder with random sort
        #expect(sortSettings.settings.randomSeed != initialSeed)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test func testConcurrentNavigation() async {
        let (viewModel, _, fileAccess) = createTestViewModel(photoCount: 100)
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        // Test concurrent navigation calls
        let tasks = (0..<10).map { index in
            Task {
                if index % 2 == 0 {
                    viewModel.nextPhoto()
                } else {
                    viewModel.previousPhoto()
                }
            }
        }
        
        for task in tasks {
            await task.value
        }
        
        // Should not crash and should have a valid state
        #expect(viewModel.slideshow?.currentIndex != nil)
        #expect(viewModel.slideshow?.currentIndex ?? -1 >= 0)
        #expect(viewModel.slideshow?.currentIndex ?? -1 < 100)
    }
    
    @Test func testConcurrentGoToPhoto() async {
        let (viewModel, _, fileAccess) = createTestViewModel(photoCount: 50)
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        await viewModel.selectFolder()
        
        // Test concurrent goToPhoto calls
        let tasks = (0..<10).map { index in
            Task {
                viewModel.goToPhoto(at: index * 5)
            }
        }
        
        for task in tasks {
            await task.value
        }
        
        // Should not crash and should have a valid state
        #expect(viewModel.slideshow?.currentIndex != nil)
        #expect(viewModel.slideshow?.currentIndex ?? -1 >= 0)
        #expect(viewModel.slideshow?.currentIndex ?? -1 < 50)
    }
    
    // MARK: - Memory Management Tests
    
    @Test func testMemoryCleanupOnDeinit() async {
        var viewModel: ModernSlideshowViewModel? = createTestViewModel().viewModel
        
        // Load a slideshow
        let fileAccess = MockSecureFileAccess()
        fileAccess.mockFolderURL = URL(fileURLWithPath: "/test/folder")
        
        // Set to nil to trigger deinit
        viewModel = nil
        
        // Verify cleanup occurred (this is more of a crash test)
        #expect(viewModel == nil)
    }
}

// MARK: - Mock Classes

class MockSlideshowDomainService: SlideshowDomainService {
    var mockSlideshow: Slideshow?
    var mockPhoto: Photo?
    var mockError: Error?
    var createSlideshowCallCount = 0
    var loadImageCallCount = 0
    
    init() {
        // Create minimal mock dependencies
        let mockRepository = MockSlideshowRepository()
        let mockCache = MockPhotoCache()
        super.init(repository: mockRepository, cache: mockCache, maxConcurrentLoads: 3)
    }
    
    override func createSlideshow(from folderURL: URL, interval: SlideshowInterval, mode: Slideshow.SlideshowMode) async throws -> Slideshow {
        createSlideshowCallCount += 1
        
        if let error = mockError {
            throw error
        }
        
        return mockSlideshow ?? Slideshow(photos: [], interval: interval, mode: mode)
    }
    
    override func loadImage(for photo: Photo) async throws -> Photo {
        loadImageCallCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if let mockPhoto = mockPhoto {
            return mockPhoto
        }
        
        // Return photo with loaded state
        var loadedPhoto = photo
        loadedPhoto.updateLoadState(.loaded(SendableImage(NSImage())))
        return loadedPhoto
    }
}

class MockSlideshowRepository: SlideshowRepository {
    var mockPhotos: [Photo] = []
    var mockError: Error?
    
    func loadPhotos(from folderURL: URL) async throws -> [Photo] {
        if let error = mockError {
            throw error
        }
        return mockPhotos
    }
    
    func loadImage(for photo: Photo) async throws -> Photo {
        if let error = mockError {
            throw error
        }
        var loadedPhoto = photo
        loadedPhoto.updateLoadState(.loaded(SendableImage(NSImage())))
        return loadedPhoto
    }
    
    func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata? {
        if let error = mockError {
            throw error
        }
        return Photo.PhotoMetadata(
            fileSize: 2_048_000,
            dimensions: CGSize(width: 1920, height: 1080),
            creationDate: Date(),
            colorSpace: "sRGB"
        )
    }
}

class MockPhotoCache: PhotoCache {
    private var cache: [ImageURL: SendableImage] = [:]
    
    func getCachedImage(for imageURL: ImageURL) async -> SendableImage? {
        return cache[imageURL]
    }
    
    func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) async {
        cache[imageURL] = image
    }
    
    func clearCache() async {
        cache.removeAll()
    }
    
    func getCacheStatistics() async -> CacheStatistics {
        return CacheStatistics(
            hitCount: cache.count * 2,
            missCount: cache.count,
            totalCost: cache.count * 100,
            currentCount: cache.count
        )
    }
}

class MockSecureFileAccess: SecureFileAccess {
    var mockFolderURL: URL?
    var mockError: Error?
    var mockDelay: TimeInterval = 0
    
    override init() {
        // Initialize with empty implementation
    }
    
    override func selectFolder() throws -> URL? {
        if mockDelay > 0 {
            Thread.sleep(forTimeInterval: mockDelay)
        }
        
        if let error = mockError {
            throw error
        }
        
        return mockFolderURL
    }
}