import XCTest
@testable import Swift_Photos
import Foundation

/// Unit tests for Repository implementations
/// Tests individual Repository classes in isolation
final class RepositoryTests: XCTestCase {
    
    // MARK: - Test Properties
    private var tempDirectory: URL!
    private var testImageURLs: [URL] = []
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepositoryTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create test image files
        await createTestImages()
    }
    
    override func tearDown() async throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        testImageURLs = []
        tempDirectory = nil
        
        try await super.tearDown()
    }
    
    // MARK: - LocalImageRepository Tests
    
    func testLocalImageRepository_LoadsImageURLs() async throws {
        // Given: LocalImageRepository
        let repository = LocalImageRepository()
        
        // When: Loading image URLs
        let imageURLs = try await repository.loadImageURLs(from: tempDirectory)
        
        // Then: Should find test images
        XCTAssertEqual(imageURLs.count, testImageURLs.count)
        
        for imageURL in imageURLs {
            XCTAssertTrue(testImageURLs.contains(imageURL.url))
        }
    }
    
    func testLocalImageRepository_LoadsImage() async throws {
        // Given: LocalImageRepository and test image
        let repository = LocalImageRepository()
        let testImageURL = testImageURLs.first!
        
        // When: Loading image
        let image = try await repository.loadImage(from: testImageURL)
        
        // Then: Should load successfully
        XCTAssertNotNil(image.nsImage)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
    
    func testLocalImageRepository_LoadsMetadata() async throws {
        // Given: LocalImageRepository and test image
        let repository = LocalImageRepository()
        let testImageURL = testImageURLs.first!
        
        // When: Loading metadata
        let metadata = try await repository.loadMetadata(for: testImageURL)
        
        // Then: Should have basic metadata
        XCTAssertNotNil(metadata.fileInfo)
        XCTAssertNotNil(metadata.imageInfo)
        XCTAssertGreaterThan(metadata.fileInfo.size, 0)
        XCTAssertGreaterThan(metadata.imageInfo.width, 0)
        XCTAssertGreaterThan(metadata.imageInfo.height, 0)
    }
    
    func testLocalImageRepository_GeneratesThumbnail() async throws {
        // Given: LocalImageRepository and test image
        let repository = LocalImageRepository()
        let testImageURL = testImageURLs.first!
        let targetSize = CGSize(width: 50, height: 50)
        
        // When: Generating thumbnail
        let thumbnail = try await repository.generateThumbnail(for: testImageURL, size: targetSize)
        
        // Then: Should create appropriately sized thumbnail
        XCTAssertNotNil(thumbnail.nsImage)
        let thumbnailSize = thumbnail.size
        XCTAssertLessThanOrEqual(thumbnailSize.width, targetSize.width + 1) // Allow for rounding
        XCTAssertLessThanOrEqual(thumbnailSize.height, targetSize.height + 1)
    }
    
    func testLocalImageRepository_SearchesImages() async throws {
        // Given: LocalImageRepository and search criteria
        let repository = LocalImageRepository()
        let criteria = SearchCriteria(
            fileName: "test_image_1",
            fileTypes: ["jpg"],
            dateRange: nil,
            sizeRange: nil
        )
        
        // When: Searching images
        let matchingImages = try await repository.searchImages(in: tempDirectory, matching: criteria)
        
        // Then: Should find matching image
        XCTAssertEqual(matchingImages.count, 1)
        XCTAssertTrue(matchingImages.first?.url.lastPathComponent.contains("test_image_1") ?? false)
    }
    
    func testLocalImageRepository_SupportedFormats() async throws {
        // Given: LocalImageRepository
        let repository = LocalImageRepository()
        
        // When: Getting supported formats
        let formats = repository.supportedImageFormats
        
        // Then: Should include common formats
        XCTAssertTrue(formats.contains("jpg"))
        XCTAssertTrue(formats.contains("png"))
        XCTAssertTrue(formats.contains("heic"))
        XCTAssertGreaterThan(formats.count, 5)
    }
    
    // MARK: - MemoryCacheRepository Tests
    
    func testMemoryCacheRepository_StoresAndRetrievesImages() async throws {
        // Given: MemoryCacheRepository
        let repository = MemoryCacheRepository()
        let testImageURL = try ImageURL(testImageURLs.first!)
        let testImage = createTestSendableImage()
        
        // When: Storing and retrieving image
        await repository.set(testImage, for: testImageURL, cost: 1000)
        let retrievedImage = await repository.get(testImageURL)
        
        // Then: Should retrieve the same image
        XCTAssertNotNil(retrievedImage)
        XCTAssertEqual(retrievedImage?.size, testImage.size)
    }
    
    func testMemoryCacheRepository_HandlesCapacityLimits() async throws {
        // Given: MemoryCacheRepository with small capacity
        let repository = MemoryCacheRepository(maxCost: 1000, countLimit: 2)
        let imageURL1 = try ImageURL(testImageURLs[0])
        let imageURL2 = try ImageURL(testImageURLs[1])
        let imageURL3 = try ImageURL(testImageURLs[2])
        let testImage = createTestSendableImage()
        
        // When: Adding more images than capacity
        await repository.set(testImage, for: imageURL1, cost: 500)
        await repository.set(testImage, for: imageURL2, cost: 500)
        await repository.set(testImage, for: imageURL3, cost: 500) // Should evict one
        
        // Then: Should respect capacity limits
        let statistics = await repository.getStatistics()
        XCTAssertLessThanOrEqual(statistics.currentCount, 2)
        XCTAssertLessThanOrEqual(statistics.currentCost, 1000)
    }
    
    func testMemoryCacheRepository_PriorityHandling() async throws {
        // Given: MemoryCacheRepository
        let repository = MemoryCacheRepository(maxCost: 1000, countLimit: 10)
        let testImageURL = try ImageURL(testImageURLs.first!)
        let testImage = createTestSendableImage()
        
        // When: Setting with different priorities
        await repository.set(testImage, for: testImageURL, priority: .high, cost: 500)
        
        // Get with different priority
        let retrievedImage = await repository.get(testImageURL, priority: .high)
        
        // Then: Should handle priority operations
        XCTAssertNotNil(retrievedImage)
    }
    
    // MARK: - FileSystemMetadataRepository Tests
    
    func testFileSystemMetadataRepository_ExtractsMetadata() async throws {
        // Given: FileSystemMetadataRepository
        let repository = FileSystemMetadataRepository()
        let testImageURL = testImageURLs.first!
        
        // When: Extracting metadata
        let metadata = try await repository.extractMetadata(from: testImageURL)
        
        // Then: Should extract basic metadata
        XCTAssertNotNil(metadata.basicInfo)
        XCTAssertGreaterThan(metadata.basicInfo.width, 0)
        XCTAssertGreaterThan(metadata.basicInfo.height, 0)
        XCTAssertGreaterThan(metadata.basicInfo.fileSize, 0)
    }
    
    func testFileSystemMetadataRepository_ValidatesMetadata() async throws {
        // Given: FileSystemMetadataRepository
        let repository = FileSystemMetadataRepository()
        let validMetadata = ImageMetadata(
            fileInfo: ImageMetadata.FileInfo(
                size: 1000,
                createdDate: Date(),
                modifiedDate: Date(),
                fileName: "test",
                fileExtension: "jpg"
            ),
            imageInfo: ImageMetadata.ImageInfo(
                width: 100,
                height: 100,
                colorSpace: "RGB",
                bitDepth: 8,
                hasAlpha: false
            ),
            exifData: nil,
            iptcData: nil,
            xmpData: nil,
            colorProfile: nil
        )
        
        // When: Validating metadata
        let validationResult = await repository.validateMetadata(validMetadata)
        
        // Then: Should validate successfully
        XCTAssertTrue(validationResult.isValid)
        XCTAssertTrue(validationResult.warnings.isEmpty)
        XCTAssertTrue(validationResult.errors.isEmpty)
    }
    
    // MARK: - UserDefaultsSettingsRepository Tests
    
    func testUserDefaultsSettingsRepository_StoresAndRetrievesSettings() async throws {
        // Given: UserDefaultsSettingsRepository
        let repository = UserDefaultsSettingsRepository()
        let testSettings = PerformanceSettings(
            memoryWindowSize: 100,
            maxMemoryUsageMB: 512,
            maxConcurrentLoads: 5,
            largeCollectionThreshold: 1000,
            enableSmartCaching: true,
            enableMemoryPressureDetection: true,
            aggressiveMemoryCleanup: false
        )
        
        // When: Storing and retrieving settings
        try await repository.saveSettings(testSettings, category: .performance)
        let retrievedSettings: PerformanceSettings = try await repository.loadSettings(category: .performance)
        
        // Then: Should retrieve the same settings
        XCTAssertEqual(retrievedSettings.memoryWindowSize, testSettings.memoryWindowSize)
        XCTAssertEqual(retrievedSettings.maxMemoryUsageMB, testSettings.maxMemoryUsageMB)
        XCTAssertEqual(retrievedSettings.maxConcurrentLoads, testSettings.maxConcurrentLoads)
    }
    
    func testUserDefaultsSettingsRepository_HandlesInvalidSettings() async throws {
        // Given: UserDefaultsSettingsRepository
        let repository = UserDefaultsSettingsRepository()
        
        // When: Trying to load non-existent settings
        do {
            let _: PerformanceSettings = try await repository.loadSettings(category: .performance)
            // If no settings exist, should use defaults or throw
        } catch {
            // Expected for non-existent settings
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    // MARK: - RepositoryContainer Tests
    
    func testRepositoryContainer_ProvidesRepositories() async throws {
        // Given: RepositoryContainer
        let container = RepositoryContainer.shared
        
        // When: Getting repositories
        let imageRepo = await container.imageRepository()
        let cacheRepo = await container.cacheRepository()
        let metadataRepo = await container.metadataRepository()
        let settingsRepo = await container.settingsRepository()
        
        // Then: Should provide repository instances
        XCTAssertNotNil(imageRepo)
        XCTAssertNotNil(cacheRepo)
        XCTAssertNotNil(metadataRepo)
        XCTAssertNotNil(settingsRepo)
    }
    
    func testRepositoryContainer_PerformsHealthCheck() async throws {
        // Given: RepositoryContainer
        let container = RepositoryContainer.shared
        
        // When: Performing health check
        let healthStatus = await container.performHealthCheck()
        
        // Then: Should return health status
        XCTAssertNotNil(healthStatus)
        // Health status depends on actual repository state
    }
    
    func testRepositoryContainer_ProvidesMetrics() async throws {
        // Given: RepositoryContainer with some operations
        let container = RepositoryContainer.shared
        let imageRepo = await container.imageRepository()
        
        // Perform some operations
        _ = try? await imageRepo.loadImageURLs(from: tempDirectory)
        
        // When: Getting performance metrics
        let metrics = await container.getPerformanceMetrics()
        
        // Then: Should provide metrics
        XCTAssertNotNil(metrics)
        XCTAssertGreaterThanOrEqual(metrics.count, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testLocalImageRepository_HandlesInvalidURL() async throws {
        // Given: LocalImageRepository and invalid URL
        let repository = LocalImageRepository()
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.jpg")
        
        // When: Attempting to load from invalid URL
        do {
            _ = try await repository.loadImage(from: invalidURL)
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should throw appropriate error
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    func testMemoryCacheRepository_HandlesNilValues() async throws {
        // Given: MemoryCacheRepository
        let repository = MemoryCacheRepository()
        let testImageURL = try ImageURL(testImageURLs.first!)
        
        // When: Trying to get non-existent image
        let result = await repository.get(testImageURL)
        
        // Then: Should return nil
        XCTAssertNil(result)
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
            
            // Set different colors for different test images
            switch i {
            case 1: NSColor.red.setFill()
            case 2: NSColor.green.setFill()
            case 3: NSColor.blue.setFill()
            default: NSColor.gray.setFill()
            }
            
            NSRect(x: 0, y: 0, width: 100, height: 100).fill()
            image.unlockFocus()
            
            // Save as JPEG (simplified for testing)
            if let tiffData = image.tiffRepresentation {
                try? tiffData.write(to: imageURL)
                testImageURLs.append(imageURL)
            }
        }
    }
    
    private func createTestSendableImage() -> SendableImage {
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()
        NSColor.yellow.setFill()
        NSRect(x: 0, y: 0, width: 50, height: 50).fill()
        image.unlockFocus()
        return SendableImage(image)
    }
}