import XCTest
@testable import Swift_Photos

/// Unit tests for FileSystemPhotoRepositoryAdapter
final class FileSystemPhotoRepositoryAdapterTests: XCTestCase {
    
    private var adapter: FileSystemPhotoRepositoryAdapter!
    private var mockLegacyRepository: MockFileSystemPhotoRepository!
    private var mockMetadataRepository: MockMetadataRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockLegacyRepository = MockFileSystemPhotoRepository()
        mockMetadataRepository = MockMetadataRepository()
        
        adapter = FileSystemPhotoRepositoryAdapter(
            legacyRepository: mockLegacyRepository,
            metadataRepository: mockMetadataRepository
        )
    }
    
    override func tearDown() async throws {
        adapter = nil
        mockLegacyRepository = nil
        mockMetadataRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testLoadImageSuccess() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testImage = NSImage(size: CGSize(width: 100, height: 100))
        mockLegacyRepository.mockImageResult = .success(testImage)
        
        // When
        let result = try await adapter.loadImage(from: testURL)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(mockLegacyRepository.loadImageCallCount, 1)
    }
    
    func testLoadImageFailure() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/nonexistent.jpg")
        let testError = SlideshowError.fileNotFound(testURL)
        mockLegacyRepository.mockImageResult = .failure(testError)
        
        // When & Then
        do {
            _ = try await adapter.loadImage(from: testURL)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    func testLoadImageURLsSuccess() async throws {
        // Given
        let testFolder = URL(fileURLWithPath: "/test/folder")
        let testURLs = [
            URL(fileURLWithPath: "/test/folder/image1.jpg"),
            URL(fileURLWithPath: "/test/folder/image2.png")
        ]
        mockLegacyRepository.mockPhotos = testURLs.compactMap { url in
            try? Photo(imageURL: ImageURL(url))
        }
        
        // When
        let result = try await adapter.loadImageURLs(from: testFolder)
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(mockLegacyRepository.loadPhotosCallCount, 1)
    }
    
    func testLoadMetadataWithLegacyData() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let legacyMetadata = Photo.PhotoMetadata(
            imageSize: CGSize(width: 1920, height: 1080),
            fileSize: 1024000,
            captureDate: Date(),
            gpsLocation: nil,
            cameraInfo: nil,
            colorProfile: nil
        )
        mockLegacyRepository.mockMetadata = legacyMetadata
        
        // When
        let result = try await adapter.loadMetadata(for: testURL)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.basicInfo.width, 1920)
        XCTAssertEqual(result.basicInfo.height, 1080)
        XCTAssertEqual(result.basicInfo.fileSize, 1024000)
        XCTAssertEqual(mockLegacyRepository.loadMetadataCallCount, 1)
    }
    
    func testLoadMetadataFallbackToNewRepository() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        mockLegacyRepository.mockMetadata = nil // No legacy metadata
        
        let newMetadata = ImageMetadata(
            url: testURL,
            basicInfo: ImageBasicInfo(
                width: 2560,
                height: 1440,
                fileSize: 2048000,
                colorSpace: "sRGB",
                bitDepth: 8,
                hasAlpha: false,
                format: "jpg"
            ),
            exifData: [:],
            iptcData: [:],
            xmpData: [:],
            extractionDate: Date(),
            source: .fileSystem
        )
        mockMetadataRepository.mockMetadata = newMetadata
        
        // When
        let result = try await adapter.loadMetadata(for: testURL)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.basicInfo.width, 2560)
        XCTAssertEqual(result.basicInfo.height, 1440)
        XCTAssertEqual(mockLegacyRepository.loadMetadataCallCount, 1)
        XCTAssertEqual(mockMetadataRepository.extractMetadataCallCount, 1)
    }
    
    func testGenerateThumbnail() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testImage = NSImage(size: CGSize(width: 1000, height: 1000))
        mockLegacyRepository.mockImageResult = .success(testImage)
        
        let thumbnailSize = CGSize(width: 200, height: 200)
        
        // When
        let result = try await adapter.generateThumbnail(for: testURL, size: thumbnailSize)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(mockLegacyRepository.loadImageCallCount, 1)
    }
    
    func testSearchImages() async throws {
        // Given
        let testFolder = URL(fileURLWithPath: "/test/folder")
        let allURLs = [
            URL(fileURLWithPath: "/test/folder/photo1.jpg"),
            URL(fileURLWithPath: "/test/folder/document.pdf"),
            URL(fileURLWithPath: "/test/folder/photo2.png")
        ]
        mockLegacyRepository.mockPhotos = allURLs.compactMap { url in
            try? Photo(imageURL: ImageURL(url))
        }
        
        let criteria = SearchCriteria(
            fileExtensions: ["jpg", "png"],
            namePattern: nil,
            dateRange: nil,
            sizeRange: nil
        )
        
        // When
        let result = try await adapter.searchImages(in: testFolder, matching: criteria)
        
        // Then
        XCTAssertEqual(result.count, 3) // All URLs are already photos from legacy repo
        XCTAssertEqual(mockLegacyRepository.loadPhotosCallCount, 1)
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceMetrics() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testImage = NSImage(size: CGSize(width: 100, height: 100))
        mockLegacyRepository.mockImageResult = .success(testImage)
        
        // When - Perform some operations
        _ = try await adapter.loadImage(from: testURL)
        _ = try await adapter.loadImage(from: testURL)
        
        let metrics = await adapter.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(metrics.operationCount, 2)
        XCTAssertEqual(metrics.successCount, 2)
        XCTAssertEqual(metrics.errorCount, 0)
        XCTAssertGreaterThan(metrics.averageResponseTime, 0)
    }
    
    func testPerformanceMetricsWithErrors() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/nonexistent.jpg")
        let testError = SlideshowError.fileNotFound(testURL)
        mockLegacyRepository.mockImageResult = .failure(testError)
        
        // When - Perform operations that will fail
        do {
            _ = try await adapter.loadImage(from: testURL)
        } catch {
            // Expected to fail
        }
        
        let metrics = await adapter.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(metrics.operationCount, 1)
        XCTAssertEqual(metrics.successCount, 0)
        XCTAssertEqual(metrics.errorCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadImageWithInvalidURL() async throws {
        // Given
        let invalidURL = URL(fileURLWithPath: "/invalid/path/image.txt")
        
        // When & Then
        do {
            _ = try await adapter.loadImage(from: invalidURL)
            XCTFail("Expected error to be thrown for invalid URL")
        } catch {
            XCTAssertTrue(error is ImageURLError)
        }
    }
    
    func testLoadMetadataError() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testError = SlideshowError.metadataExtractionFailed
        mockLegacyRepository.mockMetadataError = testError
        mockMetadataRepository.mockError = RepositoryError.metadataNotFound(testURL)
        
        // When & Then
        do {
            _ = try await adapter.loadMetadata(for: testURL)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    // MARK: - Supported Formats Tests
    
    func testSupportedImageFormats() async {
        // When
        let formats = await adapter.supportedImageFormats
        
        // Then
        XCTAssertTrue(formats.contains("jpg"))
        XCTAssertTrue(formats.contains("png"))
        XCTAssertTrue(formats.contains("heic"))
        XCTAssertTrue(formats.contains("tiff"))
        XCTAssertTrue(formats.contains("gif"))
    }
}

// MARK: - Mock Classes

/// Mock implementation of FileSystemPhotoRepository for testing
class MockFileSystemPhotoRepository: FileSystemPhotoRepository {
    
    var loadPhotosCallCount = 0
    var loadImageCallCount = 0
    var loadMetadataCallCount = 0
    
    var mockPhotos: [Photo] = []
    var mockImageResult: Result<NSImage, Error> = .success(NSImage(size: CGSize(width: 100, height: 100)))
    var mockMetadata: Photo.PhotoMetadata?
    var mockMetadataError: Error?
    
    override func loadPhotos(from folderURL: URL) async throws -> [Photo] {
        loadPhotosCallCount += 1
        return mockPhotos
    }
    
    override func loadImage(for photo: Photo) async throws -> Photo {
        loadImageCallCount += 1
        
        var updatedPhoto = photo
        
        switch mockImageResult {
        case .success(let image):
            let sendableImage = SendableImage(image)
            updatedPhoto.updateLoadState(.loaded(sendableImage))
            return updatedPhoto
            
        case .failure(let error):
            if let slideshowError = error as? SlideshowError {
                updatedPhoto.updateLoadState(.failed(slideshowError))
                throw slideshowError
            } else {
                let slideshowError = SlideshowError.loadingFailed(underlying: error)
                updatedPhoto.updateLoadState(.failed(slideshowError))
                throw slideshowError
            }
        }
    }
    
    override func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata? {
        loadMetadataCallCount += 1
        
        if let error = mockMetadataError {
            throw error
        }
        
        return mockMetadata
    }
}

/// Mock implementation of MetadataRepositoryProtocol for testing
class MockMetadataRepository: MetadataRepositoryProtocol {
    
    var extractMetadataCallCount = 0
    var validateMetadataCallCount = 0
    var getPerformanceStatisticsCallCount = 0
    
    var mockMetadata: ImageMetadata?
    var mockError: Error?
    var mockValidationResult = MetadataValidationResult(isValid: true, warnings: [], errors: [])
    var mockPerformanceStats = MetadataPerformanceStatistics(
        totalExtractions: 0,
        successfulExtractions: 0,
        failedExtractions: 0,
        averageExtractionTime: 0,
        cacheHitRate: 0,
        lastExtraction: Date()
    )
    
    func extractMetadata(from url: URL) async throws -> ImageMetadata {
        extractMetadataCallCount += 1
        
        if let error = mockError {
            throw error
        }
        
        guard let metadata = mockMetadata else {
            throw RepositoryError.metadataNotFound(url)
        }
        
        return metadata
    }
    
    func validateMetadata(_ metadata: ImageMetadata) async throws -> MetadataValidationResult {
        validateMetadataCallCount += 1
        return mockValidationResult
    }
    
    func getPerformanceStatistics() async -> MetadataPerformanceStatistics {
        getPerformanceStatisticsCallCount += 1
        return mockPerformanceStats
    }
}