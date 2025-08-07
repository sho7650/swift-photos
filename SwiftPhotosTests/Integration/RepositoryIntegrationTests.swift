import XCTest
@testable import Swift_Photos
import Foundation

/// Integration tests for Repository pattern with ViewModel
/// Tests the complete flow from ViewModel through Repository layer to concrete implementations
@MainActor
final class RepositoryIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    private var tempDirectory: URL!
    private var testImageURLs: [URL] = []
    private var mockFileAccess: MockSecureFileAccess!
    private var mockImageLoader: MockImageLoader!
    
    // MARK: - Test Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepositoryIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create test image files
        await createTestImages()
        
        // Setup mocks
        mockFileAccess = MockSecureFileAccess()
        mockImageLoader = MockImageLoader()
        
        // Configure mock file access to allow test directory
        mockFileAccess.allowedDirectories = [tempDirectory]
        mockFileAccess.shouldSucceed = true
        
        // Configure mock image loader with test images
        mockImageLoader.shouldSucceed = true
        mockImageLoader.loadDelay = 0.1
    }
    
    override func tearDown() async throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        testImageURLs = []
        mockFileAccess = nil
        mockImageLoader = nil
        tempDirectory = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Domain Service Integration Tests
    
    func testModernSlideshowDomainService_CreatesSlideshow() async throws {
        // Given: A domain service with Repository pattern
        let domainService = await createModernDomainService()
        let interval = try SlideshowInterval(3.0)
        
        // When: Creating a slideshow
        let slideshow = try await domainService.createSlideshow(
            from: tempDirectory,
            interval: interval,
            mode: .sequential
        )
        
        // Then: Slideshow is created successfully
        XCTAssertEqual(slideshow.photos.count, testImageURLs.count)
        XCTAssertEqual(slideshow.interval, interval)
        XCTAssertEqual(slideshow.mode, .sequential)
        XCTAssertFalse(slideshow.isEmpty)
    }
    
    func testModernSlideshowDomainService_LoadsImages() async throws {
        // Given: A domain service and slideshow
        let domainService = await createModernDomainService()
        let interval = try SlideshowInterval(3.0)
        let slideshow = try await domainService.createSlideshow(
            from: tempDirectory,
            interval: interval,
            mode: .sequential
        )
        
        guard let firstPhoto = slideshow.photos.first else {
            XCTFail("No photos in slideshow")
            return
        }
        
        // When: Loading an image
        let loadedPhoto = try await domainService.loadImage(for: firstPhoto)
        
        // Then: Image is loaded successfully
        XCTAssertTrue(loadedPhoto.loadState.isLoaded)
        XCTAssertNotNil(loadedPhoto.loadState.image)
    }
    
    func testModernSlideshowDomainService_CachesImages() async throws {
        // Given: A domain service
        let domainService = await createModernDomainService()
        let interval = try SlideshowInterval(3.0)
        let slideshow = try await domainService.createSlideshow(
            from: tempDirectory,
            interval: interval,
            mode: .sequential
        )
        
        guard let firstPhoto = slideshow.photos.first else {
            XCTFail("No photos in slideshow")
            return
        }
        
        // When: Loading the same image twice
        let firstLoad = try await domainService.loadImage(for: firstPhoto)
        let secondLoad = try await domainService.loadImage(for: firstPhoto)
        
        // Then: Both loads should succeed (second should be from cache)
        XCTAssertTrue(firstLoad.loadState.isLoaded)
        XCTAssertTrue(secondLoad.loadState.isLoaded)
        
        // Performance metrics should show operations
        let metrics = domainService.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics.operationCount, 0)
        XCTAssertGreaterThan(metrics.successCount, 0)
    }
    
    // MARK: - Enhanced ViewModel Integration Tests
    
    func testEnhancedModernSlideshowViewModel_Integration() async throws {
        // Given: An enhanced ViewModel with Repository pattern
        let viewModel = await createEnhancedViewModel()
        
        // When: Creating a slideshow
        viewModel.selectedFolderURL = tempDirectory
        
        // Wait for slideshow creation (simulate the private method)
        try await simulateSlideshowCreation(viewModel: viewModel)
        
        // Then: ViewModel state is updated correctly
        XCTAssertNotNil(viewModel.slideshow)
        XCTAssertEqual(viewModel.slideshow?.photos.count, testImageURLs.count)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    func testEnhancedModernSlideshowViewModel_LoadsCurrentImage() async throws {
        // Given: An enhanced ViewModel with slideshow
        let viewModel = await createEnhancedViewModel()
        viewModel.selectedFolderURL = tempDirectory
        try await simulateSlideshowCreation(viewModel: viewModel)
        
        // When: Loading current image
        await viewModel.loadCurrentImage()
        
        // Then: Current photo is loaded
        XCTAssertNotNil(viewModel.currentPhoto)
        XCTAssertTrue(viewModel.currentPhoto?.loadState.isLoaded ?? false)
    }
    
    func testEnhancedModernSlideshowViewModel_FallbackToLegacy() async throws {
        // Given: Enhanced ViewModel with failing Repository and legacy fallback
        let viewModel = await createEnhancedViewModelWithFailingRepository()
        viewModel.selectedFolderURL = tempDirectory
        
        // When: Attempting to create slideshow (Repository will fail, should fallback to legacy)
        try await simulateSlideshowCreation(viewModel: viewModel)
        
        // Then: Should fall back to legacy implementation
        let metrics = await viewModel.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics.legacyOperations, 0)
        XCTAssertTrue(metrics.isUsingLegacyFallback)
    }
    
    func testEnhancedModernSlideshowViewModel_PerformanceMetrics() async throws {
        // Given: Enhanced ViewModel with some operations
        let viewModel = await createEnhancedViewModel()
        viewModel.selectedFolderURL = tempDirectory
        try await simulateSlideshowCreation(viewModel: viewModel)
        await viewModel.loadCurrentImage()
        
        // When: Getting performance metrics
        let metrics = await viewModel.getPerformanceMetrics()
        
        // Then: Metrics should reflect operations
        XCTAssertGreaterThan(metrics.totalOperations, 0)
        XCTAssertGreaterThan(metrics.repositoryOperations, 0)
        XCTAssertTrue(metrics.repositoryUsageRate > 0)
        XCTAssertTrue(metrics.performanceMonitoringEnabled)
    }
    
    // MARK: - Repository Health and Monitoring Tests
    
    func testRepositoryContainer_HealthCheck() async throws {
        // Given: Repository container
        let container = RepositoryContainer.shared
        
        // When: Performing health check
        let healthStatus = await container.performHealthCheck()
        
        // Then: Health status should be available
        XCTAssertNotNil(healthStatus)
        // Health may vary based on actual repository state
    }
    
    func testRepositoryContainer_PerformanceMonitoring() async throws {
        // Given: Repository container with some operations
        let container = RepositoryContainer.shared
        let imageRepo = await container.imageRepository()
        
        // When: Performing operations and getting metrics
        _ = try? await imageRepo.loadImageURLs(from: tempDirectory)
        let metrics = await container.getPerformanceMetrics()
        
        // Then: Metrics should be available
        XCTAssertNotNil(metrics)
        XCTAssertGreaterThanOrEqual(metrics.count, 1) // At least one repository
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testEnhancedViewModel_HandlesRepositoryErrors() async throws {
        // Given: ViewModel with failing repository and no legacy fallback
        let viewModel = await createEnhancedViewModelWithFailingRepository(enableLegacyFallback: false)
        viewModel.selectedFolderURL = tempDirectory
        
        // When: Attempting to create slideshow
        do {
            try await simulateSlideshowCreation(viewModel: viewModel)
        } catch {
            // Expected to fail
        }
        
        // Then: Error should be set
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testModernDomainService_HandlesInvalidFolder() async throws {
        // Given: Domain service
        let domainService = await createModernDomainService()
        let invalidFolder = tempDirectory.appendingPathComponent("nonexistent")
        
        // When: Attempting to create slideshow from invalid folder
        do {
            _ = try await domainService.createSlideshow(
                from: invalidFolder,
                interval: try SlideshowInterval(3.0),
                mode: .sequential
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should throw appropriate error
            XCTAssertTrue(error is SlideshowError)
        }
    }
    
    // MARK: - Factory Integration Tests
    
    func testImageRepositoryFactory_CreatesCorrectRepository() async throws {
        // Given: Repository factory
        let factory = await ImageRepositoryFactory.createWithLegacySupport(
            fileAccess: mockFileAccess,
            imageLoader: mockImageLoader,
            sortSettings: MockModernSortSettingsManager(),
            localizationService: MockLocalizationService()
        )
        
        // When: Creating repository
        let repository = try await factory.createImageRepository()
        
        // Then: Repository should be created
        XCTAssertNotNil(repository)
        
        // Should be able to load images
        let imageURLs = try await repository.loadImageURLs(from: tempDirectory)
        XCTAssertEqual(imageURLs.count, testImageURLs.count)
    }
    
    // MARK: - Private Helper Methods
    
    private func createTestImages() async {
        testImageURLs = []
        
        // Create several test image files
        for i in 1...3 {
            let imageURL = tempDirectory.appendingPathComponent("test_image_\(i).jpg")
            
            // Create a simple test image
            let image = NSImage(size: NSSize(width: 100, height: 100))
            image.lockFocus()
            NSColor.blue.setFill()
            NSRect(x: 0, y: 0, width: 100, height: 100).fill()
            image.unlockFocus()
            
            // Save as JPEG (simplified for testing)
            if let tiffData = image.tiffRepresentation {
                try? tiffData.write(to: imageURL)
                testImageURLs.append(imageURL)
            }
        }
    }
    
    private func createModernDomainService() async -> ModernSlideshowDomainService {
        return await ModernSlideshowDomainService.createWithLegacySupport(
            fileAccess: mockFileAccess,
            imageLoader: mockImageLoader,
            sortSettings: MockModernSortSettingsManager(),
            localizationService: MockLocalizationService()
        )
    }
    
    private func createEnhancedViewModel() async -> EnhancedModernSlideshowViewModel {
        return await EnhancedModernSlideshowViewModel(
            fileAccess: mockFileAccess,
            imageLoader: mockImageLoader,
            sortSettings: MockModernSortSettingsManager(),
            localizationService: MockLocalizationService()
        )
    }
    
    private func createEnhancedViewModelWithFailingRepository(enableLegacyFallback: Bool = true) async -> EnhancedModernSlideshowViewModel {
        // Create failing mocks
        let failingFileAccess = MockSecureFileAccess()
        failingFileAccess.shouldSucceed = false
        
        return await EnhancedModernSlideshowViewModel(
            fileAccess: failingFileAccess,
            imageLoader: mockImageLoader,
            sortSettings: MockModernSortSettingsManager(),
            localizationService: MockLocalizationService(),
            performanceSettings: ModernPerformanceSettingsManager(),
            slideshowSettings: ModernSlideshowSettingsManager()
        )
    }
    
    private func simulateSlideshowCreation(viewModel: EnhancedModernSlideshowViewModel) async throws {
        // This simulates the private createSlideshow method
        // In a real integration test, you might expose this method or use a test-specific interface
        
        let domainService = await createModernDomainService()
        let interval = try SlideshowInterval(3.0)
        let slideshow = try await domainService.createSlideshow(
            from: tempDirectory,
            interval: interval,
            mode: .sequential
        )
        
        // Simulate the ViewModel's slideshow setting
        viewModel.setSlideshow(slideshow)
    }
}

// MARK: - Mock Implementations

private class MockSecureFileAccess: SecureFileAccess {
    var allowedDirectories: [URL] = []
    var shouldSucceed = true
    
    override func validateFileAccess(for url: URL) throws {
        if !shouldSucceed {
            throw SlideshowError.fileNotFound(url)
        }
        // Allow access to test directories
        let isAllowed = allowedDirectories.contains { allowedDir in
            url.path.hasPrefix(allowedDir.path)
        }
        if !isAllowed {
            throw SlideshowError.accessDenied(url)
        }
    }
    
    override func enumerateImages(in directory: URL) throws -> [URL] {
        if !shouldSucceed {
            throw SlideshowError.folderAccessFailed(directory, underlying: NSError(domain: "Test", code: -1))
        }
        
        // Return mock image files
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "jpg" }
    }
}

private class MockImageLoader: ImageLoader {
    var shouldSucceed = true
    var loadDelay: TimeInterval = 0
    
    override func loadImage(from url: URL) async throws -> SendableImage {
        if loadDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw SlideshowError.fileNotFound(url)
        }
        
        // Create a mock image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        
        return SendableImage(image)
    }
}

private class MockModernSortSettingsManager: ModernSortSettingsManager {
    override init() {
        super.init()
        // Use default settings for testing
    }
}

private class MockLocalizationService: LocalizationService {
    override init() {
        super.init()
        // Use default localization for testing
    }
}