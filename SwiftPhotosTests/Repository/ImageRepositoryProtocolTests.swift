import XCTest
@testable import Swift_Photos

/// ImageRepositoryProtocol のユニットテスト
final class ImageRepositoryProtocolTests: XCTestCase {
    
    private var mockRepository: MockImageRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockImageRepository()
    }
    
    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - loadImage Tests
    
    func testLoadImageSuccess() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let expectedImage = SendableImage(NSImage())
        mockRepository.loadImageResult = .success(expectedImage)
        
        // When
        let result = try await mockRepository.loadImage(from: testURL)
        
        // Then
        XCTAssertTrue(mockRepository.loadImageCalled)
        XCTAssertEqual(mockRepository.lastLoadImageURL, testURL)
        XCTAssertEqual(result.id, expectedImage.id)
    }
    
    func testLoadImageFailure() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/nonexistent.jpg")
        let expectedError = RepositoryError.notFound("image.jpg")
        mockRepository.loadImageResult = .failure(expectedError)
        
        // When & Then
        do {
            _ = try await mockRepository.loadImage(from: testURL)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(mockRepository.loadImageCalled)
            XCTAssertEqual(mockRepository.lastLoadImageURL, testURL)
        }
    }
    
    // MARK: - loadImageURLs Tests
    
    func testLoadImageURLsSuccess() async throws {
        // Given
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        let expectedURLs = [
            try ImageURL(URL(fileURLWithPath: "/test/folder/image1.jpg")),
            try ImageURL(URL(fileURLWithPath: "/test/folder/image2.png"))
        ]
        mockRepository.loadImageURLsResult = .success(expectedURLs)
        
        // When
        let result = try await mockRepository.loadImageURLs(from: testFolderURL)
        
        // Then
        XCTAssertTrue(mockRepository.loadImageURLsCalled)
        XCTAssertEqual(mockRepository.lastLoadImageURLsFolder, testFolderURL)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].url.lastPathComponent, "image1.jpg")
        XCTAssertEqual(result[1].url.lastPathComponent, "image2.png")
    }
    
    func testLoadImageURLsEmptyFolder() async throws {
        // Given
        let testFolderURL = URL(fileURLWithPath: "/test/empty")
        mockRepository.loadImageURLsResult = .success([])
        
        // When
        let result = try await mockRepository.loadImageURLs(from: testFolderURL)
        
        // Then
        XCTAssertTrue(mockRepository.loadImageURLsCalled)
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - loadMetadata Tests
    
    func testLoadMetadataSuccess() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let expectedMetadata = ImageMetadata(
            fileInfo: ImageMetadata.FileInfo(
                size: 1024,
                createdDate: Date(),
                modifiedDate: Date(),
                fileName: "image.jpg",
                fileExtension: "jpg"
            ),
            imageInfo: ImageMetadata.ImageInfo(
                width: 800,
                height: 600,
                colorSpace: "sRGB",
                bitDepth: 8,
                hasAlpha: false
            )
        )
        mockRepository.loadMetadataResult = .success(expectedMetadata)
        
        // When
        let result = try await mockRepository.loadMetadata(for: testURL)
        
        // Then
        XCTAssertTrue(mockRepository.loadMetadataCalled)
        XCTAssertEqual(mockRepository.lastLoadMetadataURL, testURL)
        XCTAssertEqual(result.fileInfo.fileName, "image.jpg")
        XCTAssertEqual(result.imageInfo.width, 800)
        XCTAssertEqual(result.imageInfo.height, 600)
    }
    
    // MARK: - generateThumbnail Tests
    
    func testGenerateThumbnailSuccess() async throws {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testSize = CGSize(width: 150, height: 150)
        let expectedThumbnail = SendableImage(NSImage())
        mockRepository.generateThumbnailResult = .success(expectedThumbnail)
        
        // When
        let result = try await mockRepository.generateThumbnail(for: testURL, size: testSize)
        
        // Then
        XCTAssertTrue(mockRepository.generateThumbnailCalled)
        XCTAssertEqual(mockRepository.lastGenerateThumbnailURL, testURL)
        XCTAssertEqual(mockRepository.lastGenerateThumbnailSize, testSize)
        XCTAssertEqual(result.id, expectedThumbnail.id)
    }
    
    // MARK: - searchImages Tests
    
    func testSearchImagesWithFileName() async throws {
        // Given
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        let searchCriteria = SearchCriteria(fileName: "sunset")
        let expectedURLs = [
            try ImageURL(URL(fileURLWithPath: "/test/folder/sunset1.jpg")),
            try ImageURL(URL(fileURLWithPath: "/test/folder/sunset2.png"))
        ]
        mockRepository.searchImagesResult = .success(expectedURLs)
        
        // When
        let result = try await mockRepository.searchImages(in: testFolderURL, matching: searchCriteria)
        
        // Then
        XCTAssertTrue(mockRepository.searchImagesCalled)
        XCTAssertEqual(mockRepository.lastSearchImagesFolder, testFolderURL)
        XCTAssertEqual(mockRepository.lastSearchImagesCriteria?.fileName, "sunset")
        XCTAssertEqual(result.count, 2)
    }
    
    func testSearchImagesWithDateRange() async throws {
        // Given
        let testFolderURL = URL(fileURLWithPath: "/test/folder")
        let startDate = Date().addingTimeInterval(-86400) // 1日前
        let endDate = Date()
        let dateRange = SearchCriteria.DateRange(start: startDate, end: endDate)
        let searchCriteria = SearchCriteria(dateRange: dateRange)
        let expectedURLs = [try ImageURL(URL(fileURLWithPath: "/test/folder/recent.jpg"))]
        mockRepository.searchImagesResult = .success(expectedURLs)
        
        // When
        let result = try await mockRepository.searchImages(in: testFolderURL, matching: searchCriteria)
        
        // Then
        XCTAssertTrue(mockRepository.searchImagesCalled)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(mockRepository.lastSearchImagesCriteria?.dateRange?.start, startDate)
        XCTAssertEqual(mockRepository.lastSearchImagesCriteria?.dateRange?.end, endDate)
    }
    
    // MARK: - supportedImageFormats Tests
    
    func testSupportedImageFormats() {
        // Given & When
        let formats = mockRepository.supportedImageFormats
        
        // Then
        XCTAssertTrue(formats.contains("jpg"))
        XCTAssertTrue(formats.contains("png"))
        XCTAssertTrue(formats.contains("gif"))
        XCTAssertTrue(formats.contains("heic"))
        XCTAssertFalse(formats.contains("txt"))
    }
}

// MARK: - Mock Implementation

final class MockImageRepository: ImageRepositoryProtocol {
    // MARK: - Call Tracking
    var loadImageCalled = false
    var loadImageURLsCalled = false  
    var loadMetadataCalled = false
    var generateThumbnailCalled = false
    var searchImagesCalled = false
    
    // MARK: - Parameter Tracking
    var lastLoadImageURL: URL?
    var lastLoadImageURLsFolder: URL?
    var lastLoadMetadataURL: URL?
    var lastGenerateThumbnailURL: URL?
    var lastGenerateThumbnailSize: CGSize?
    var lastSearchImagesFolder: URL?
    var lastSearchImagesCriteria: SearchCriteria?
    
    // MARK: - Result Configuration
    var loadImageResult: Result<SendableImage, Error> = .failure(TestError.notConfigured)
    var loadImageURLsResult: Result<[ImageURL], Error> = .failure(TestError.notConfigured)
    var loadMetadataResult: Result<ImageMetadata, Error> = .failure(TestError.notConfigured)
    var generateThumbnailResult: Result<SendableImage, Error> = .failure(TestError.notConfigured)
    var searchImagesResult: Result<[ImageURL], Error> = .failure(TestError.notConfigured)
    
    // MARK: - Protocol Implementation
    
    func loadImage(from url: URL) async throws -> SendableImage {
        loadImageCalled = true
        lastLoadImageURL = url
        return try loadImageResult.get()
    }
    
    func loadImageURLs(from folder: URL) async throws -> [ImageURL] {
        loadImageURLsCalled = true
        lastLoadImageURLsFolder = folder
        return try loadImageURLsResult.get()
    }
    
    func loadMetadata(for url: URL) async throws -> ImageMetadata {
        loadMetadataCalled = true
        lastLoadMetadataURL = url
        return try loadMetadataResult.get()
    }
    
    func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage {
        generateThumbnailCalled = true
        lastGenerateThumbnailURL = url
        lastGenerateThumbnailSize = size
        return try generateThumbnailResult.get()
    }
    
    func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL] {
        searchImagesCalled = true
        lastSearchImagesFolder = folder
        lastSearchImagesCriteria = criteria
        return try searchImagesResult.get()
    }
    
    var supportedImageFormats: Set<String> {
        return ["jpg", "jpeg", "png", "gif", "heic", "tiff"]
    }
    
    // MARK: - Test Utilities
    
    func reset() {
        loadImageCalled = false
        loadImageURLsCalled = false
        loadMetadataCalled = false
        generateThumbnailCalled = false
        searchImagesCalled = false
        
        lastLoadImageURL = nil
        lastLoadImageURLsFolder = nil
        lastLoadMetadataURL = nil
        lastGenerateThumbnailURL = nil
        lastGenerateThumbnailSize = nil
        lastSearchImagesFolder = nil
        lastSearchImagesCriteria = nil
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case notConfigured
    case mockError(String)
}

// MARK: - Test Extensions

extension SearchCriteria: Equatable {
    public static func == (lhs: SearchCriteria, rhs: SearchCriteria) -> Bool {
        return lhs.fileName == rhs.fileName &&
               lhs.dateRange == rhs.dateRange &&
               lhs.sizeRange == rhs.sizeRange &&
               lhs.fileTypes == rhs.fileTypes
    }
}

extension SearchCriteria.DateRange: Equatable {
    public static func == (lhs: SearchCriteria.DateRange, rhs: SearchCriteria.DateRange) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }
}

extension SearchCriteria.SizeRange: Equatable {
    public static func == (lhs: SearchCriteria.SizeRange, rhs: SearchCriteria.SizeRange) -> Bool {
        return lhs.minSize == rhs.minSize && lhs.maxSize == rhs.maxSize
    }
}