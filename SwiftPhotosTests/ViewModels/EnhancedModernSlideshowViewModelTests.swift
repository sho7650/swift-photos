import XCTest
@testable import Swift_Photos

@MainActor
final class EnhancedModernSlideshowViewModelTests: XCTestCase {
    
    private var sut: EnhancedModernSlideshowViewModel!
    private var mockFileAccess: MockSecureFileAccess!
    private var mockModernDomainService: MockModernSlideshowDomainService!
    private var mockLegacyDomainService: MockSlideshowDomainService!
    private var performanceSettings: ModernPerformanceSettingsManager!
    private var slideshowSettings: ModernSlideshowSettingsManager!
    private var sortSettings: ModernSortSettingsManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockFileAccess = MockSecureFileAccess()
        mockModernDomainService = MockModernSlideshowDomainService()
        mockLegacyDomainService = MockSlideshowDomainService()
        performanceSettings = ModernPerformanceSettingsManager()
        slideshowSettings = ModernSlideshowSettingsManager()
        sortSettings = ModernSortSettingsManager()
        
        sut = EnhancedModernSlideshowViewModel(
            modernDomainService: mockModernDomainService,
            legacyDomainService: mockLegacyDomainService,
            fileAccess: mockFileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings,
            enableLegacyFallback: true,
            performanceMonitoring: true
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockFileAccess = nil
        mockModernDomainService = nil
        mockLegacyDomainService = nil
        performanceSettings = nil
        slideshowSettings = nil
        sortSettings = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() async throws {
        XCTAssertNil(sut.slideshow)
        XCTAssertNil(sut.currentPhoto)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertEqual(sut.windowLevel, .normal)
    }
    
    // MARK: - Folder Selection Tests
    
    func testSelectFolderAndLoadPhotos_Success() async throws {
        // Given
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        mockFileAccess.folderToReturn = testFolderURL
        
        let testPhotos = createTestPhotos(count: 5)
        let expectedSlideshow = Slideshow(photos: testPhotos)
        mockModernDomainService.slideshowToReturn = expectedSlideshow
        
        // When
        await sut.selectFolderAndLoadPhotos()
        
        // Then
        XCTAssertNotNil(sut.slideshow)
        XCTAssertEqual(sut.slideshow?.photos.count, 5)
        XCTAssertEqual(sut.selectedFolderURL, testFolderURL)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }
    
    func testSelectFolderAndLoadPhotos_Cancelled() async throws {
        // Given
        mockFileAccess.folderToReturn = nil // User cancelled
        
        // When
        await sut.selectFolderAndLoadPhotos()
        
        // Then
        XCTAssertNil(sut.slideshow)
        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSelectFolderAndLoadPhotos_RepositoryFailure_FallbackToLegacy() async throws {
        // Given
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        mockFileAccess.folderToReturn = testFolderURL
        
        // Repository pattern fails
        mockModernDomainService.shouldThrowError = true
        mockModernDomainService.errorToThrow = SlideshowError.loadingFailed(underlying: NSError(domain: "Test", code: 1))
        
        // Legacy fallback succeeds
        let testPhotos = createTestPhotos(count: 3)
        let expectedSlideshow = Slideshow(photos: testPhotos)
        mockLegacyDomainService.slideshowToReturn = expectedSlideshow
        
        // When
        await sut.selectFolderAndLoadPhotos()
        
        // Then
        XCTAssertNotNil(sut.slideshow)
        XCTAssertEqual(sut.slideshow?.photos.count, 3)
        XCTAssertNil(sut.error)
        
        // Verify legacy fallback was used
        let metrics = await sut.getPerformanceMetrics()
        XCTAssertTrue(metrics.isUsingLegacyFallback)
        XCTAssertEqual(metrics.legacyOperations, 1)
    }
    
    // MARK: - Navigation Tests
    
    func testNextPhoto() async throws {
        // Given
        let testPhotos = createTestPhotos(count: 3)
        var slideshow = Slideshow(photos: testPhotos)
        try slideshow.setCurrentIndex(0)
        sut.setSlideshow(slideshow)
        
        // When
        await sut.nextPhoto()
        
        // Then
        XCTAssertEqual(sut.slideshow?.currentIndex, 1)
        XCTAssertEqual(sut.currentPhoto?.id, testPhotos[1].id)
    }
    
    func testPreviousPhoto() async throws {
        // Given
        let testPhotos = createTestPhotos(count: 3)
        var slideshow = Slideshow(photos: testPhotos)
        try slideshow.setCurrentIndex(2)
        sut.setSlideshow(slideshow)
        
        // When
        await sut.previousPhoto()
        
        // Then
        XCTAssertEqual(sut.slideshow?.currentIndex, 1)
        XCTAssertEqual(sut.currentPhoto?.id, testPhotos[1].id)
    }
    
    // MARK: - Slideshow Control Tests
    
    func testStartSlideshow() async throws {
        // Given
        let testPhotos = createTestPhotos(count: 3)
        let slideshow = Slideshow(photos: testPhotos)
        sut.setSlideshow(slideshow)
        
        // When
        sut.startSlideshow()
        
        // Then
        XCTAssertTrue(sut.slideshow?.isPlaying ?? false)
    }
    
    func testStopSlideshow() async throws {
        // Given
        let testPhotos = createTestPhotos(count: 3)
        var slideshow = Slideshow(photos: testPhotos)
        slideshow.play()
        sut.setSlideshow(slideshow)
        
        // When
        sut.stopSlideshow()
        
        // Then
        XCTAssertFalse(sut.slideshow?.isPlaying ?? true)
    }
    
    // MARK: - Image Loading Tests
    
    func testLoadCurrentImage_Success() async throws {
        // Given
        let testPhotos = createTestPhotos(count: 1)
        let slideshow = Slideshow(photos: testPhotos)
        sut.setSlideshow(slideshow)
        
        let loadedPhoto = createLoadedPhoto(from: testPhotos[0])
        mockModernDomainService.photoToReturn = loadedPhoto
        
        // When
        await sut.loadCurrentImage()
        
        // Then
        XCTAssertEqual(sut.currentPhoto?.loadState, loadedPhoto.loadState)
    }
    
    func testLoadCurrentImage_RepositoryFailure_FallbackToLegacy() async throws {
        // Given
        let testPhotos = createTestPhotos(count: 1)
        let slideshow = Slideshow(photos: testPhotos)
        sut.setSlideshow(slideshow)
        
        // Repository fails
        mockModernDomainService.shouldThrowError = true
        mockModernDomainService.errorToThrow = SlideshowError.imageNotFound
        
        // Legacy succeeds
        let loadedPhoto = createLoadedPhoto(from: testPhotos[0])
        mockLegacyDomainService.photoToReturn = loadedPhoto
        
        // When
        await sut.loadCurrentImage()
        
        // Then
        XCTAssertEqual(sut.currentPhoto?.loadState, loadedPhoto.loadState)
    }
    
    // MARK: - Virtual Loading Tests
    
    func testVirtualLoadingSetup_LargeCollection() async throws {
        // Given
        performanceSettings.updateSettings(PerformanceSettings(
            largeCollectionThreshold: 50
        ))
        
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        mockFileAccess.folderToReturn = testFolderURL
        
        let testPhotos = createTestPhotos(count: 100) // Large collection
        let expectedSlideshow = Slideshow(photos: testPhotos)
        mockModernDomainService.slideshowToReturn = expectedSlideshow
        
        // When
        await sut.selectFolderAndLoadPhotos()
        
        // Then
        XCTAssertNotNil(sut.slideshow)
        XCTAssertEqual(sut.slideshow?.photos.count, 100)
        
        // Virtual loading should be configured for large collections
        // (Would need to expose internal state or use dependency injection for virtual loader to test this properly)
    }
    
    func testVirtualLoadingSetup_SmallCollection() async throws {
        // Given
        performanceSettings.updateSettings(PerformanceSettings(
            largeCollectionThreshold: 50
        ))
        
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        mockFileAccess.folderToReturn = testFolderURL
        
        let testPhotos = createTestPhotos(count: 10) // Small collection
        let expectedSlideshow = Slideshow(photos: testPhotos)
        mockModernDomainService.slideshowToReturn = expectedSlideshow
        
        // When
        await sut.selectFolderAndLoadPhotos()
        
        // Then
        XCTAssertNotNil(sut.slideshow)
        XCTAssertEqual(sut.slideshow?.photos.count, 10)
        
        // Standard loading should be used for small collections
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetrics() async throws {
        // Given - perform some operations
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        mockFileAccess.folderToReturn = testFolderURL
        
        let testPhotos = createTestPhotos(count: 5)
        let expectedSlideshow = Slideshow(photos: testPhotos)
        mockModernDomainService.slideshowToReturn = expectedSlideshow
        
        await sut.selectFolderAndLoadPhotos()
        
        // When
        let metrics = await sut.getPerformanceMetrics()
        
        // Then
        XCTAssertGreaterThan(metrics.totalOperations, 0)
        XCTAssertEqual(metrics.repositoryOperations, 1)
        XCTAssertEqual(metrics.legacyOperations, 0)
        XCTAssertFalse(metrics.isUsingLegacyFallback)
        XCTAssertTrue(metrics.performanceMonitoringEnabled)
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
    
    private func createLoadedPhoto(from photo: Photo) -> Photo {
        var loadedPhoto = photo
        let testImage = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
        loadedPhoto.updateLoadState(.loaded(SendableImage(testImage)))
        return loadedPhoto
    }
}

// MARK: - Mock Classes

class MockSecureFileAccess: SecureFileAccess {
    var folderToReturn: URL?
    
    override func selectFolder() throws -> URL? {
        return folderToReturn
    }
}

class MockModernSlideshowDomainService: ModernSlideshowDomainService {
    var slideshowToReturn: Slideshow?
    var photoToReturn: Photo?
    var shouldThrowError = false
    var errorToThrow: Error?
    
    override func createSlideshow(from folderURL: URL, interval: SlideshowInterval, mode: Slideshow.SlideshowMode) async throws -> Slideshow {
        if shouldThrowError {
            throw errorToThrow ?? SlideshowError.loadingFailed(underlying: NSError(domain: "Test", code: 1))
        }
        return slideshowToReturn ?? Slideshow(photos: [])
    }
    
    override func loadImage(for photo: Photo) async throws -> Photo {
        if shouldThrowError {
            throw errorToThrow ?? SlideshowError.imageNotFound
        }
        return photoToReturn ?? photo
    }
}

class MockSlideshowDomainService: SlideshowDomainService {
    var slideshowToReturn: Slideshow?
    var photoToReturn: Photo?
    var shouldThrowError = false
    var errorToThrow: Error?
    
    override func createSlideshow(from folderURL: URL, interval: SlideshowInterval, mode: Slideshow.SlideshowMode) async throws -> Slideshow {
        if shouldThrowError {
            throw errorToThrow ?? SlideshowError.loadingFailed(underlying: NSError(domain: "Test", code: 1))
        }
        return slideshowToReturn ?? Slideshow(photos: [])
    }
    
    override func loadImage(for photo: Photo) async throws -> Photo {
        if shouldThrowError {
            throw errorToThrow ?? SlideshowError.imageNotFound
        }
        return photoToReturn ?? photo
    }
}