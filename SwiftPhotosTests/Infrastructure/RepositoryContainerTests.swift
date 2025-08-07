import XCTest
@testable import Swift_Photos

/// RepositoryContainer のユニットテスト
final class RepositoryContainerTests: XCTestCase {
    
    private var container: RepositoryContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        container = RepositoryContainer.shared
        await container.resetAll() // テスト前にクリーンアップ
    }
    
    override func tearDown() async throws {
        await container.resetAll() // テスト後にクリーンアップ
        container = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Repository Creation Tests
    
    func testCreateImageRepository() async throws {
        // When
        let repository = await container.imageRepository()
        
        // Then
        XCTAssertNotNil(repository)
        XCTAssertTrue(repository is LocalImageRepository)
        
        // 同じインスタンスが返されることを確認
        let repository2 = await container.imageRepository()
        XCTAssertIdentical(repository as AnyObject, repository2 as AnyObject)
    }
    
    func testCreateCacheRepository() async throws {
        // When
        let repository = await container.cacheRepository()
        
        // Then
        XCTAssertNotNil(repository)
        XCTAssertTrue(repository is MemoryCacheRepository)
        
        // 同じインスタンスが返されることを確認
        let repository2 = await container.cacheRepository()
        XCTAssertIdentical(repository as AnyObject, repository2 as AnyObject)
    }
    
    func testCreateMetadataRepository() async throws {
        // When
        let repository = await container.metadataRepository()
        
        // Then
        XCTAssertNotNil(repository)
        XCTAssertTrue(repository is FileSystemMetadataRepository)
        
        // 同じインスタンスが返されることを確認
        let repository2 = await container.metadataRepository()
        XCTAssertIdentical(repository as AnyObject, repository2 as AnyObject)
    }
    
    func testCreateSettingsRepository() async throws {
        // When
        let repository = await container.settingsRepository()
        
        // Then
        XCTAssertNotNil(repository)
        XCTAssertTrue(repository is UserDefaultsSettingsRepository)
        
        // 同じインスタンスが返されることを確認
        let repository2 = await container.settingsRepository()
        XCTAssertIdentical(repository as AnyObject, repository2 as AnyObject)
    }
    
    // MARK: - Repository Reset Tests
    
    func testResetImageRepository() async throws {
        // Given
        let repository1 = await container.imageRepository()
        
        // When
        await container.resetImageRepository()
        let repository2 = await container.imageRepository()
        
        // Then
        XCTAssertNotIdentical(repository1 as AnyObject, repository2 as AnyObject)
    }
    
    func testResetAllRepositories() async throws {
        // Given
        let imageRepo1 = await container.imageRepository()
        let cacheRepo1 = await container.cacheRepository()
        let metadataRepo1 = await container.metadataRepository()
        let settingsRepo1 = await container.settingsRepository()
        
        // When
        await container.resetAll()
        
        // Then - 新しいインスタンスが作成される
        let imageRepo2 = await container.imageRepository()
        let cacheRepo2 = await container.cacheRepository()
        let metadataRepo2 = await container.metadataRepository()
        let settingsRepo2 = await container.settingsRepository()
        
        XCTAssertNotIdentical(imageRepo1 as AnyObject, imageRepo2 as AnyObject)
        XCTAssertNotIdentical(cacheRepo1 as AnyObject, cacheRepo2 as AnyObject)
        XCTAssertNotIdentical(metadataRepo1 as AnyObject, metadataRepo2 as AnyObject)
        XCTAssertNotIdentical(settingsRepo1 as AnyObject, settingsRepo2 as AnyObject)
    }
    
    // MARK: - Health Check Tests
    
    func testPerformHealthCheck() async throws {
        // When
        let healthStatus = await container.performHealthCheck()
        
        // Then
        XCTAssertNotNil(healthStatus)
        XCTAssertEqual(healthStatus.totalRepositoryCount, 4) // 4つのRepository
        XCTAssertGreaterThanOrEqual(healthStatus.healthyRepositoryCount, 0)
        XCTAssertLessThanOrEqual(healthStatus.healthyRepositoryCount, 4)
        XCTAssertGreaterThanOrEqual(healthStatus.healthRate, 0.0)
        XCTAssertLessThanOrEqual(healthStatus.healthRate, 1.0)
        
        // チェック時刻が妥当
        let now = Date()
        XCTAssertLessThanOrEqual(healthStatus.checkedAt.timeIntervalSince(now), 1.0)
    }
    
    func testHealthCheckRepositoryStatuses() async throws {
        // When
        let healthStatus = await container.performHealthCheck()
        
        // Then
        XCTAssertTrue(healthStatus.repositoryStatuses.keys.contains("ImageRepository"))
        XCTAssertTrue(healthStatus.repositoryStatuses.keys.contains("CacheRepository"))
        XCTAssertTrue(healthStatus.repositoryStatuses.keys.contains("MetadataRepository"))
        XCTAssertTrue(healthStatus.repositoryStatuses.keys.contains("SettingsRepository"))
    }
    
    // MARK: - Statistics Tests
    
    func testGetAllStatistics() async throws {
        // Given - いくつかのRepositoryを作成してアクティブにする
        let _ = await container.imageRepository()
        let _ = await container.cacheRepository()
        let _ = await container.metadataRepository()
        let _ = await container.settingsRepository()
        
        // When
        let statistics = await container.getAllStatistics()
        
        // Then
        XCTAssertEqual(statistics.configuration, "Default")
        XCTAssertNotNil(statistics.collectedAt)
        
        // 作成されたRepositoryの統計が含まれているかチェック
        // 注意: 実際にoperationが実行されていないため、統計は空の可能性がある
        let hasImageRepoStats = statistics.repositoryStatistics.keys.contains { $0.hasPrefix("ImageRepository") }
        let hasCacheRepoStats = statistics.repositoryStatistics.keys.contains { $0.hasPrefix("CacheRepository") }
        let hasMetadataRepoStats = statistics.repositoryStatistics.keys.contains { $0.hasPrefix("MetadataRepository") }
        
        XCTAssertTrue(hasImageRepoStats || hasCacheRepoStats || hasMetadataRepoStats)
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() {
        // Given
        let config = ContainerConfiguration.default
        
        // Then
        XCTAssertEqual(config.name, "Default")
        XCTAssertEqual(config.imageRepositoryType, .local)
        XCTAssertEqual(config.cacheRepositoryType, .memory)
        XCTAssertEqual(config.metadataRepositoryType, .fileSystem)
        XCTAssertEqual(config.settingsRepositoryType, .userDefaults)
        XCTAssertEqual(config.settingsKeyPrefix, "SwiftPhotos")
    }
    
    func testPerformanceOptimizedConfiguration() {
        // Given
        let config = ContainerConfiguration.performanceOptimized
        
        // Then
        XCTAssertEqual(config.name, "Performance")
        XCTAssertEqual(config.cacheCountLimit, 500)
        XCTAssertEqual(config.cacheTotalCostLimit, 1_000_000_000)
        XCTAssertEqual(config.metadataCacheCountLimit, 5000)
        XCTAssertEqual(config.metadataCacheTotalCostLimit, 100_000_000)
    }
    
    func testMemoryOptimizedConfiguration() {
        // Given
        let config = ContainerConfiguration.memoryOptimized
        
        // Then
        XCTAssertEqual(config.name, "Memory Optimized")
        XCTAssertEqual(config.cacheCountLimit, 50)
        XCTAssertEqual(config.cacheTotalCostLimit, 100_000_000)
        XCTAssertEqual(config.metadataCacheCountLimit, 200)
        XCTAssertEqual(config.metadataCacheTotalCostLimit, 10_000_000)
    }
    
    func testTestingConfiguration() {
        // Given
        let config = ContainerConfiguration.testing
        
        // Then
        XCTAssertEqual(config.name, "Testing")
        XCTAssertEqual(config.settingsKeyPrefix, "TestSwiftPhotos")
        XCTAssertEqual(config.cacheCountLimit, 10)
        XCTAssertEqual(config.cacheTotalCostLimit, 10_000_000)
    }
    
    // MARK: - Repository Health Status Tests
    
    func testRepositoryHealthStatusProperties() {
        // Given
        let repositoryStatuses = [
            "Repository1": true,
            "Repository2": false,
            "Repository3": true,
            "Repository4": true
        ]
        let issues = ["Repository2 failed to initialize"]
        let healthStatus = RepositoryHealthStatus(
            isHealthy: false,
            repositoryStatuses: repositoryStatuses,
            issues: issues,
            checkedAt: Date()
        )
        
        // When & Then
        XCTAssertFalse(healthStatus.isHealthy)
        XCTAssertEqual(healthStatus.healthyRepositoryCount, 3)
        XCTAssertEqual(healthStatus.totalRepositoryCount, 4)
        XCTAssertEqual(healthStatus.healthRate, 0.75, accuracy: 0.01)
        XCTAssertEqual(healthStatus.issues.count, 1)
        XCTAssertEqual(healthStatus.issues.first, "Repository2 failed to initialize")
    }
    
    func testRepositoryHealthStatusAllHealthy() {
        // Given
        let repositoryStatuses = [
            "Repository1": true,
            "Repository2": true,
            "Repository3": true
        ]
        let healthStatus = RepositoryHealthStatus(
            isHealthy: true,
            repositoryStatuses: repositoryStatuses,
            issues: [],
            checkedAt: Date()
        )
        
        // When & Then
        XCTAssertTrue(healthStatus.isHealthy)
        XCTAssertEqual(healthStatus.healthyRepositoryCount, 3)
        XCTAssertEqual(healthStatus.totalRepositoryCount, 3)
        XCTAssertEqual(healthStatus.healthRate, 1.0)
        XCTAssertTrue(healthStatus.issues.isEmpty)
    }
    
    func testRepositoryHealthStatusEmptyRepositories() {
        // Given
        let healthStatus = RepositoryHealthStatus(
            isHealthy: true,
            repositoryStatuses: [:],
            issues: [],
            checkedAt: Date()
        )
        
        // When & Then
        XCTAssertEqual(healthStatus.healthyRepositoryCount, 0)
        XCTAssertEqual(healthStatus.totalRepositoryCount, 0)
        XCTAssertEqual(healthStatus.healthRate, 1.0) // 空の場合は1.0を返す
    }
    
    // MARK: - Repository Container Statistics Tests
    
    func testRepositoryContainerStatistics() {
        // Given
        let statistics: [String: String] = [
            "ImageRepository.operationCount": "10",
            "ImageRepository.successCount": "9",
            "ImageRepository.errorCount": "1",
            "CacheRepository.hitCount": "50",
            "CacheRepository.missCount": "10"
        ]
        let containerStats = RepositoryContainerStatistics(
            configuration: "Test",
            repositoryStatistics: statistics,
            collectedAt: Date()
        )
        
        // When & Then
        XCTAssertEqual(containerStats.configuration, "Test")
        XCTAssertEqual(containerStats.repositoryStatistics.count, 5)
        XCTAssertTrue(containerStats.repositoryStatistics.keys.contains("ImageRepository.operationCount"))
        XCTAssertTrue(containerStats.repositoryStatistics.keys.contains("CacheRepository.hitCount"))
        XCTAssertEqual(containerStats.repositoryStatistics["ImageRepository.operationCount"], "10")
        XCTAssertEqual(containerStats.repositoryStatistics["CacheRepository.hitCount"], "50")
    }
}