import XCTest
@testable import Swift_Photos

/// CacheRepositoryProtocol のユニットテスト
final class CacheRepositoryProtocolTests: XCTestCase {
    
    private var mockCache: MockImageCacheRepository!
    
    override func setUp() {
        super.setUp()
        mockCache = MockImageCacheRepository()
    }
    
    override func tearDown() {
        mockCache = nil
        super.tearDown()
    }
    
    // MARK: - Basic Cache Operations Tests
    
    func testGetAndSetOperation() async {
        // Given
        let testKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/image.jpg"),
            quality: .full
        )
        let testImage = SendableImage(NSImage())
        
        // When
        await mockCache.set(testImage, for: testKey, cost: 1000)
        let retrievedImage = await mockCache.get(testKey)
        
        // Then
        XCTAssertTrue(mockCache.setCalled)
        XCTAssertTrue(mockCache.getCalled)
        XCTAssertNotNil(retrievedImage)
        XCTAssertEqual(retrievedImage?.id, testImage.id)
        XCTAssertEqual(mockCache.lastSetKey, testKey)
        XCTAssertEqual(mockCache.lastSetCost, 1000)
    }
    
    func testGetNonExistentItem() async {
        // Given
        let testKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/nonexistent.jpg"),
            quality: .full
        )
        
        // When
        let result = await mockCache.get(testKey)
        
        // Then
        XCTAssertTrue(mockCache.getCalled)
        XCTAssertNil(result)
        XCTAssertEqual(mockCache.lastGetKey, testKey)
    }
    
    func testRemoveOperation() async {
        // Given
        let testKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/image.jpg"),
            quality: .full
        )
        let testImage = SendableImage(NSImage())
        
        // When
        await mockCache.set(testImage, for: testKey, cost: 1000)
        await mockCache.remove(testKey)
        let retrievedImage = await mockCache.get(testKey)
        
        // Then
        XCTAssertTrue(mockCache.removeCalled)
        XCTAssertNil(retrievedImage)
        XCTAssertEqual(mockCache.lastRemoveKey, testKey)
    }
    
    // MARK: - Batch Operations Tests
    
    func testGetMultiple() async {
        // Given
        let keys = [
            ImageCacheKey(url: URL(fileURLWithPath: "/test/image1.jpg"), quality: .full),
            ImageCacheKey(url: URL(fileURLWithPath: "/test/image2.jpg"), quality: .full)
        ]
        let image1 = SendableImage(NSImage())
        let image2 = SendableImage(NSImage())
        
        mockCache.getMultipleResult = [
            keys[0]: image1,
            keys[1]: image2
        ]
        
        // When
        let result = await mockCache.getMultiple(keys)
        
        // Then
        XCTAssertTrue(mockCache.getMultipleCalled)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[keys[0]]?.id, image1.id)
        XCTAssertEqual(result[keys[1]]?.id, image2.id)
    }
    
    func testSetMultiple() async {
        // Given
        let items = [
            (key: ImageCacheKey(url: URL(fileURLWithPath: "/test/image1.jpg"), quality: .full),
             value: SendableImage(NSImage()),
             cost: 1000 as Int?),
            (key: ImageCacheKey(url: URL(fileURLWithPath: "/test/image2.jpg"), quality: .full),
             value: SendableImage(NSImage()),
             cost: 1500 as Int?)
        ]
        
        // When
        await mockCache.setMultiple(items)
        
        // Then
        XCTAssertTrue(mockCache.setMultipleCalled)
        XCTAssertEqual(mockCache.lastSetMultipleItems.count, 2)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testStatistics() async {
        // Given
        let expectedStats = CacheStatistics(
            hitCount: 10,
            missCount: 5,
            totalCost: 50000,
            currentCount: 15
        )
        mockCache.statisticsResult = expectedStats
        
        // When
        let stats = await mockCache.statistics()
        
        // Then
        XCTAssertTrue(mockCache.statisticsCalled)
        XCTAssertEqual(stats.hitCount, 10)
        XCTAssertEqual(stats.missCount, 5)
        XCTAssertEqual(stats.totalCost, 50000)
        XCTAssertEqual(stats.currentCount, 15)
        XCTAssertEqual(stats.hitRate, 2.0/3.0, accuracy: 0.01)
    }
    
    // MARK: - Image-Specific Operations Tests
    
    func testPreload() async {
        // Given
        let images = [
            (key: ImageCacheKey(url: URL(fileURLWithPath: "/test/image1.jpg"), quality: .preview),
             value: SendableImage(NSImage())),
            (key: ImageCacheKey(url: URL(fileURLWithPath: "/test/image2.jpg"), quality: .preview),
             value: SendableImage(NSImage()))
        ]
        
        // When
        await mockCache.preload(images)
        
        // Then
        XCTAssertTrue(mockCache.preloadCalled)
        XCTAssertEqual(mockCache.lastPreloadImages.count, 2)
    }
    
    func testSetPriority() async {
        // Given
        let testKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/important.jpg"),
            quality: .full
        )
        let priority = CachePriority.high
        
        // When
        await mockCache.setPriority(priority, for: testKey)
        
        // Then
        XCTAssertTrue(mockCache.setPriorityCalled)
        XCTAssertEqual(mockCache.lastSetPriorityKey, testKey)
        XCTAssertEqual(mockCache.lastSetPriority, priority)
    }
    
    func testCacheThumbnail() async {
        // Given
        let originalKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/image.jpg"),
            quality: .full
        )
        let thumbnail = SendableImage(NSImage())
        let size = CGSize(width: 150, height: 150)
        
        // When
        await mockCache.cacheThumbnail(thumbnail, for: originalKey, size: size)
        
        // Then
        XCTAssertTrue(mockCache.cacheThumbnailCalled)
        XCTAssertEqual(mockCache.lastCacheThumbnailOriginalKey, originalKey)
        XCTAssertEqual(mockCache.lastCacheThumbnailSize, size)
    }
    
    func testGetThumbnail() async {
        // Given
        let originalKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/image.jpg"),
            quality: .full
        )
        let size = CGSize(width: 150, height: 150)
        let expectedThumbnail = SendableImage(NSImage())
        mockCache.getThumbnailResult = expectedThumbnail
        
        // When
        let result = await mockCache.getThumbnail(for: originalKey, size: size)
        
        // Then
        XCTAssertTrue(mockCache.getThumbnailCalled)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, expectedThumbnail.id)
        XCTAssertEqual(mockCache.lastGetThumbnailKey, originalKey)
        XCTAssertEqual(mockCache.lastGetThumbnailSize, size)
    }
    
    // MARK: - Quality-Based Caching Tests
    
    func testCacheWithQuality() async {
        // Given
        let testKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/image.jpg"),
            quality: .preview
        )
        let testImage = SendableImage(NSImage())
        let quality = ImageQuality.preview
        
        // When
        await mockCache.cacheWithQuality(testImage, for: testKey, quality: quality)
        
        // Then
        XCTAssertTrue(mockCache.cacheWithQualityCalled)
        XCTAssertEqual(mockCache.lastCacheWithQualityKey, testKey)
        XCTAssertEqual(mockCache.lastCacheWithQuality, quality)
    }
    
    func testGetWithQuality() async {
        // Given
        let testKey = ImageCacheKey(
            url: URL(fileURLWithPath: "/test/image.jpg"),
            quality: .thumbnail
        )
        let quality = ImageQuality.thumbnail
        let expectedImage = SendableImage(NSImage())
        mockCache.getWithQualityResult = expectedImage
        
        // When
        let result = await mockCache.getWithQuality(testKey, quality: quality)
        
        // Then
        XCTAssertTrue(mockCache.getWithQualityCalled)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, expectedImage.id)
        XCTAssertEqual(mockCache.lastGetWithQualityKey, testKey)
        XCTAssertEqual(mockCache.lastGetWithQualityQuality, quality)
    }
    
    // MARK: - Cache Key Tests
    
    func testImageCacheKeyIdentifier() {
        // Given
        let url = URL(fileURLWithPath: "/test/my image.jpg")
        let size = CGSize(width: 800, height: 600)
        let transformations = [
            ImageTransformation.rotation(degrees: 90),
            ImageTransformation.scale(factor: 2.0)
        ]
        let key = ImageCacheKey(
            url: url,
            size: size,
            quality: .preview,
            transformations: transformations
        )
        
        // When
        let identifier = key.cacheIdentifier
        
        // Then
        XCTAssertTrue(identifier.contains("800x600"))
        XCTAssertTrue(identifier.contains("preview"))
        XCTAssertTrue(identifier.contains("rot90"))
        XCTAssertTrue(identifier.contains("scale200"))
    }
    
    // MARK: - Image Quality Tests
    
    func testImageQualityProperties() {
        // Test maxDimension
        XCTAssertEqual(ImageQuality.thumbnail.maxDimension, 150)
        XCTAssertEqual(ImageQuality.preview.maxDimension, 512)
        XCTAssertEqual(ImageQuality.full.maxDimension, 2048)
        XCTAssertEqual(ImageQuality.original.maxDimension, .infinity)
        
        // Test compressionQuality
        XCTAssertEqual(ImageQuality.thumbnail.compressionQuality, 0.6)
        XCTAssertEqual(ImageQuality.preview.compressionQuality, 0.8)
        XCTAssertEqual(ImageQuality.full.compressionQuality, 0.9)
        XCTAssertEqual(ImageQuality.original.compressionQuality, 1.0)
    }
    
    // MARK: - Cache Priority Tests
    
    func testCachePriorityComparison() {
        XCTAssertTrue(CachePriority.low < CachePriority.normal)
        XCTAssertTrue(CachePriority.normal < CachePriority.high)
        XCTAssertTrue(CachePriority.high < CachePriority.critical)
        XCTAssertFalse(CachePriority.critical < CachePriority.low)
    }
}

// MARK: - Mock Implementation

final class MockImageCacheRepository: ImageCacheRepositoryProtocol {
    typealias Key = ImageCacheKey
    typealias Value = SendableImage
    
    // MARK: - Call Tracking
    var getCalled = false
    var setCalled = false
    var removeCalled = false
    var getMultipleCalled = false
    var setMultipleCalled = false
    var removeMultipleCalled = false
    var removeAllCalled = false
    var statisticsCalled = false
    var setLimitsCalled = false
    var containsCalled = false
    var allKeysCalled = false
    var performCleanupCalled = false
    var preloadCalled = false
    var setPriorityCalled = false
    var cacheThumbnailCalled = false
    var getThumbnailCalled = false
    var cacheWithQualityCalled = false
    var getWithQualityCalled = false
    
    // MARK: - Parameter Tracking
    var lastGetKey: ImageCacheKey?
    var lastSetKey: ImageCacheKey?
    var lastSetCost: Int?
    var lastRemoveKey: ImageCacheKey?
    var lastGetMultipleKeys: [ImageCacheKey] = []
    var lastSetMultipleItems: [(key: ImageCacheKey, value: SendableImage, cost: Int?)] = []
    var lastRemoveMultipleKeys: [ImageCacheKey] = []
    var lastSetLimitsCountLimit: Int?
    var lastSetLimitsTotalCostLimit: Int?
    var lastContainsKey: ImageCacheKey?
    var lastPerformCleanupTarget: Double?
    var lastPreloadImages: [(key: ImageCacheKey, value: SendableImage)] = []
    var lastSetPriorityKey: ImageCacheKey?
    var lastSetPriority: CachePriority?
    var lastCacheThumbnailOriginalKey: ImageCacheKey?
    var lastCacheThumbnailSize: CGSize?
    var lastGetThumbnailKey: ImageCacheKey?
    var lastGetThumbnailSize: CGSize?
    var lastCacheWithQualityKey: ImageCacheKey?
    var lastCacheWithQuality: ImageQuality?
    var lastGetWithQualityKey: ImageCacheKey?
    var lastGetWithQualityQuality: ImageQuality?
    
    // MARK: - Result Configuration
    var getResult: SendableImage?
    var getMultipleResult: [ImageCacheKey: SendableImage] = [:]
    var containsResult = false
    var allKeysResult: [ImageCacheKey] = []
    var statisticsResult = CacheStatistics(hitCount: 0, missCount: 0, totalCost: 0, currentCount: 0)
    var getThumbnailResult: SendableImage?
    var getWithQualityResult: SendableImage?
    
    // MARK: - Internal Storage
    private var storage: [ImageCacheKey: SendableImage] = [:]
    
    // MARK: - Protocol Implementation
    
    func get(_ key: ImageCacheKey) async -> SendableImage? {
        getCalled = true
        lastGetKey = key
        return getResult ?? storage[key]
    }
    
    func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        setCalled = true
        lastSetKey = key
        lastSetCost = cost
        storage[key] = value
    }
    
    func remove(_ key: ImageCacheKey) async {
        removeCalled = true
        lastRemoveKey = key
        storage.removeValue(forKey: key)
    }
    
    func getMultiple(_ keys: [ImageCacheKey]) async -> [ImageCacheKey: SendableImage] {
        getMultipleCalled = true
        lastGetMultipleKeys = keys
        return getMultipleResult
    }
    
    func setMultiple(_ items: [(key: ImageCacheKey, value: SendableImage, cost: Int?)]) async {
        setMultipleCalled = true
        lastSetMultipleItems = items
        for item in items {
            storage[item.key] = item.value
        }
    }
    
    func removeMultiple(_ keys: [ImageCacheKey]) async {
        removeMultipleCalled = true
        lastRemoveMultipleKeys = keys
        for key in keys {
            storage.removeValue(forKey: key)
        }
    }
    
    func removeAll() async {
        removeAllCalled = true
        storage.removeAll()
    }
    
    func statistics() async -> CacheStatistics {
        statisticsCalled = true
        return statisticsResult
    }
    
    func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        setLimitsCalled = true
        lastSetLimitsCountLimit = countLimit
        lastSetLimitsTotalCostLimit = totalCostLimit
    }
    
    func contains(_ key: ImageCacheKey) async -> Bool {
        containsCalled = true
        lastContainsKey = key
        return containsResult || storage.keys.contains(key)
    }
    
    func allKeys() async -> [ImageCacheKey] {
        allKeysCalled = true
        return allKeysResult.isEmpty ? Array(storage.keys) : allKeysResult
    }
    
    func performCleanup(targetReduction: Double) async {
        performCleanupCalled = true
        lastPerformCleanupTarget = targetReduction
    }
    
    func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async {
        preloadCalled = true
        lastPreloadImages = images
        for item in images {
            storage[item.key] = item.value
        }
    }
    
    func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async {
        setPriorityCalled = true
        lastSetPriorityKey = key
        lastSetPriority = priority
    }
    
    func cacheThumbnail(_ image: SendableImage, for originalKey: ImageCacheKey, size: CGSize) async {
        cacheThumbnailCalled = true
        lastCacheThumbnailOriginalKey = originalKey
        lastCacheThumbnailSize = size
    }
    
    func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage? {
        getThumbnailCalled = true
        lastGetThumbnailKey = key
        lastGetThumbnailSize = size
        return getThumbnailResult
    }
    
    func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async {
        cacheWithQualityCalled = true
        lastCacheWithQualityKey = key
        lastCacheWithQuality = quality
    }
    
    func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage? {
        getWithQualityCalled = true
        lastGetWithQualityKey = key
        lastGetWithQualityQuality = quality
        return getWithQualityResult
    }
    
    // MARK: - Test Utilities
    
    func reset() {
        // Reset call tracking
        getCalled = false
        setCalled = false
        removeCalled = false
        getMultipleCalled = false
        setMultipleCalled = false
        removeMultipleCalled = false
        removeAllCalled = false
        statisticsCalled = false
        setLimitsCalled = false
        containsCalled = false
        allKeysCalled = false
        performCleanupCalled = false
        preloadCalled = false
        setPriorityCalled = false
        cacheThumbnailCalled = false
        getThumbnailCalled = false
        cacheWithQualityCalled = false
        getWithQualityCalled = false
        
        // Reset parameters
        lastGetKey = nil
        lastSetKey = nil
        lastSetCost = nil
        lastRemoveKey = nil
        lastGetMultipleKeys = []
        lastSetMultipleItems = []
        lastRemoveMultipleKeys = []
        lastSetLimitsCountLimit = nil
        lastSetLimitsTotalCostLimit = nil
        lastContainsKey = nil
        lastPerformCleanupTarget = nil
        lastPreloadImages = []
        lastSetPriorityKey = nil
        lastSetPriority = nil
        lastCacheThumbnailOriginalKey = nil
        lastCacheThumbnailSize = nil
        lastGetThumbnailKey = nil
        lastGetThumbnailSize = nil
        lastCacheWithQualityKey = nil
        lastCacheWithQuality = nil
        lastGetWithQualityKey = nil
        lastGetWithQualityQuality = nil
        
        // Reset results
        getResult = nil
        getMultipleResult = [:]
        containsResult = false
        allKeysResult = []
        statisticsResult = CacheStatistics(hitCount: 0, missCount: 0, totalCost: 0, currentCount: 0)
        getThumbnailResult = nil
        getWithQualityResult = nil
        
        // Reset storage
        storage.removeAll()
    }
}