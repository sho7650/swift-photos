import XCTest
@testable import Swift_Photos

/// Unit tests for ImageRepositoryFactory
final class ImageRepositoryFactoryTests: XCTestCase {
    
    private var factory: ImageRepositoryFactory!
    private var mockRepositoryContainer: MockRepositoryContainer!
    private var mockLegacyRepository: MockFileSystemPhotoRepository!
    private var mockMetadataRepository: MockMetadataRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockRepositoryContainer = MockRepositoryContainer()
        mockLegacyRepository = MockFileSystemPhotoRepository()
        mockMetadataRepository = MockMetadataRepository()
    }
    
    override func tearDown() async throws {
        factory = nil
        mockRepositoryContainer = nil
        mockLegacyRepository = nil
        mockMetadataRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - Factory Configuration Tests
    
    func testCreateLegacyRepository() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(repositoryType: .legacy)
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: mockLegacyRepository,
            metadataRepository: mockMetadataRepository
        )
        
        // When
        let repository = try await factory.createImageRepository()
        
        // Then
        XCTAssertTrue(repository is FileSystemPhotoRepositoryAdapter)
    }
    
    func testCreateModernRepository() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(repositoryType: .modern)
        let mockModernRepo = MockLocalImageRepository()
        mockRepositoryContainer.mockImageRepository = mockModernRepo
        
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer
        )
        
        // When
        let repository = try await factory.createImageRepository()
        
        // Then
        XCTAssertTrue(repository is MockLocalImageRepository)
        XCTAssertEqual(mockRepositoryContainer.imageRepositoryCallCount, 1)
    }
    
    func testCreateAutomaticRepositoryPrefersModern() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(repositoryType: .automatic)
        let mockModernRepo = MockLocalImageRepository()
        mockRepositoryContainer.mockImageRepository = mockModernRepo
        
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: mockLegacyRepository,
            metadataRepository: mockMetadataRepository
        )
        
        // When
        let repository = try await factory.createImageRepository()
        
        // Then
        XCTAssertTrue(repository is MockLocalImageRepository)
        XCTAssertEqual(mockRepositoryContainer.imageRepositoryCallCount, 1)
    }
    
    func testCreateAutomaticRepositoryFallbackToLegacy() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(repositoryType: .automatic)
        mockRepositoryContainer.shouldThrowError = true // Modern repo will fail
        
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: mockLegacyRepository,
            metadataRepository: mockMetadataRepository
        )
        
        // When
        let repository = try await factory.createImageRepository()
        
        // Then
        XCTAssertTrue(repository is FileSystemPhotoRepositoryAdapter)
    }
    
    func testCreateLegacyRepositoryNotAvailable() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(
            repositoryType: .legacy,
            fallbackToLegacy: false
        )
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: nil, // No legacy repository
            metadataRepository: mockMetadataRepository
        )
        
        // When & Then
        do {
            _ = try await factory.createImageRepository()
            XCTFail("Expected FactoryError.legacyRepositoryNotAvailable")
        } catch FactoryError.legacyRepositoryNotAvailable {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateLegacyRepositoryNotAvailableWithFallback() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(
            repositoryType: .legacy,
            fallbackToLegacy: true
        )
        let mockModernRepo = MockLocalImageRepository()
        mockRepositoryContainer.mockImageRepository = mockModernRepo
        
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: nil, // No legacy repository
            metadataRepository: mockMetadataRepository
        )
        
        // When
        let repository = try await factory.createImageRepository()
        
        // Then
        XCTAssertTrue(repository is MockLocalImageRepository) // Should fallback to modern
    }
    
    // MARK: - Repository Information Tests
    
    func testGetAvailableRepositoryTypes() async throws {
        // Given
        factory = ImageRepositoryFactory(
            legacyRepository: mockLegacyRepository,
            metadataRepository: mockMetadataRepository
        )
        
        // When
        let availableTypes = await factory.getAvailableRepositoryTypes()
        
        // Then
        XCTAssertTrue(availableTypes.contains(.modern))
        XCTAssertTrue(availableTypes.contains(.legacy))
        XCTAssertTrue(availableTypes.contains(.automatic))
    }
    
    func testGetAvailableRepositoryTypesNoLegacy() async throws {
        // Given
        factory = ImageRepositoryFactory(
            legacyRepository: nil,
            metadataRepository: mockMetadataRepository
        )
        
        // When
        let availableTypes = await factory.getAvailableRepositoryTypes()
        
        // Then
        XCTAssertTrue(availableTypes.contains(.modern))
        XCTAssertFalse(availableTypes.contains(.legacy))
        XCTAssertTrue(availableTypes.contains(.automatic))
    }
    
    func testGetRepositoryCapabilities() async throws {
        // Given
        factory = ImageRepositoryFactory()
        
        // When
        let legacyCapabilities = await factory.getRepositoryCapabilities(for: .legacy)
        let modernCapabilities = await factory.getRepositoryCapabilities(for: .modern)
        let automaticCapabilities = await factory.getRepositoryCapabilities(for: .automatic)
        
        // Then
        XCTAssertTrue(legacyCapabilities.supportsAdvancedSorting)
        XCTAssertEqual(legacyCapabilities.performanceLevel, .good)
        
        XCTAssertFalse(modernCapabilities.supportsAdvancedSorting)
        XCTAssertEqual(modernCapabilities.performanceLevel, .excellent)
        
        XCTAssertTrue(automaticCapabilities.supportsAdvancedSorting)
        XCTAssertEqual(automaticCapabilities.performanceLevel, .excellent)
    }
    
    // MARK: - Migration Support Tests
    
    func testShouldMigrateToModernFromLegacy() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(repositoryType: .legacy)
        let mockModernRepo = MockLocalImageRepository()
        mockRepositoryContainer.mockImageRepository = mockModernRepo
        
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer
        )
        
        // When
        let shouldMigrate = await factory.shouldMigrateToModern()
        
        // Then
        XCTAssertTrue(shouldMigrate)
    }
    
    func testShouldMigrateToModernFromModern() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(repositoryType: .modern)
        factory = ImageRepositoryFactory(configuration: config)
        
        // When
        let shouldMigrate = await factory.shouldMigrateToModern()
        
        // Then
        XCTAssertFalse(shouldMigrate) // Already using modern
    }
    
    func testValidateMigrationSuccess() async throws {
        // Given
        let mockModernRepo = MockLocalImageRepository()
        mockRepositoryContainer.mockImageRepository = mockModernRepo
        
        factory = ImageRepositoryFactory(
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: mockLegacyRepository
        )
        
        // When
        let result = await factory.validateMigration()
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
    }
    
    func testValidateMigrationWithIssues() async throws {
        // Given
        mockRepositoryContainer.shouldThrowError = true // Modern repo will fail
        
        factory = ImageRepositoryFactory(
            repositoryContainer: mockRepositoryContainer,
            legacyRepository: nil // No legacy repo either
        )
        
        // When
        let result = await factory.validateMigration()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.issues.isEmpty)
    }
    
    func testValidateMigrationWithWarnings() async throws {
        // Given
        let config = ImageRepositoryFactory.FactoryConfiguration(enablePerformanceMonitoring: false)
        let mockModernRepo = MockLocalImageRepository()
        mockRepositoryContainer.mockImageRepository = mockModernRepo
        
        factory = ImageRepositoryFactory(
            configuration: config,
            repositoryContainer: mockRepositoryContainer
        )
        
        // When
        let result = await factory.validateMigration()
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertFalse(result.warnings.isEmpty)
    }
    
    // MARK: - Convenience Factory Methods Tests
    
    func testCreateWithLegacySupport() async throws {
        // Given
        let mockFileAccess = MockSecureFileAccess()
        let mockImageLoader = MockImageLoader()
        let mockSortSettings = MockModernSortSettingsManager()
        let mockLocalizationService = MockLocalizationService()
        
        // When
        let factory = await ImageRepositoryFactory.createWithLegacySupport(
            fileAccess: mockFileAccess,
            imageLoader: mockImageLoader,
            sortSettings: mockSortSettings,
            localizationService: mockLocalizationService
        )
        
        // Then
        let availableTypes = await factory.getAvailableRepositoryTypes()
        XCTAssertTrue(availableTypes.contains(.legacy))
        XCTAssertTrue(availableTypes.contains(.modern))
    }
    
    func testCreateModernOnly() async throws {
        // Given & When
        let factory = ImageRepositoryFactory.createModernOnly()
        
        // Then
        let availableTypes = await factory.getAvailableRepositoryTypes()
        XCTAssertTrue(availableTypes.contains(.modern))
        XCTAssertFalse(availableTypes.contains(.legacy))
        XCTAssertTrue(availableTypes.contains(.automatic))
    }
}

// MARK: - Mock Classes

/// Mock implementation of RepositoryContainer for testing
class MockRepositoryContainer: RepositoryContainer {
    
    var imageRepositoryCallCount = 0
    var shouldThrowError = false
    var mockImageRepository: (any ImageRepositoryProtocol)?
    
    override func imageRepository() async -> any ImageRepositoryProtocol {
        imageRepositoryCallCount += 1
        
        if shouldThrowError {
            fatalError("Mock error for testing")
        }
        
        return mockImageRepository ?? MockLocalImageRepository()
    }
}

/// Mock implementation of LocalImageRepository for testing
class MockLocalImageRepository: ImageRepositoryProtocol {
    
    let supportedImageFormats: Set<String> = ["jpg", "png", "heic"]
    
    func loadImage(from url: URL) async throws -> SendableImage {
        let image = NSImage(size: CGSize(width: 100, height: 100))
        return SendableImage(image)
    }
    
    func loadImageURLs(from folder: URL) async throws -> [ImageURL] {
        return []
    }
    
    func loadMetadata(for url: URL) async throws -> ImageMetadata {
        return ImageMetadata(
            url: url,
            basicInfo: ImageBasicInfo(
                width: 100,
                height: 100,
                fileSize: 1000,
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
    }
    
    func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage {
        let image = NSImage(size: size)
        return SendableImage(image)
    }
    
    func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL] {
        return []
    }
}

/// Mock implementations of dependencies
class MockSecureFileAccess: SecureFileAccess {
    // Mock implementation would go here
}

class MockImageLoader: ImageLoader {
    // Mock implementation would go here
}

class MockModernSortSettingsManager: ModernSortSettingsManager {
    // Mock implementation would go here
}

class MockLocalizationService: LocalizationService {
    // Mock implementation would go here
}