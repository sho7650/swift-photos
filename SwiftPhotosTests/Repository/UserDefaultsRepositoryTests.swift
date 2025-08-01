import XCTest
@testable import Swift_Photos

/// UserDefaultsSettingsRepository のユニットテスト
final class UserDefaultsSettingsRepositoryTests: XCTestCase {
    
    private var repository: UserDefaultsSettingsRepository!
    private var testUserDefaults: UserDefaults!
    private let testSuiteName = "UserDefaultsSettingsRepositoryTest"
    
    override func setUp() async throws {
        try await super.setUp()
        
        // テスト用のUserDefaultsを作成
        testUserDefaults = UserDefaults(suiteName: testSuiteName)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        
        // テスト用のRepositoryを初期化
        repository = UserDefaultsSettingsRepository(
            userDefaults: testUserDefaults,
            keyPrefix: "TestSwiftPhotos"
        )
    }
    
    override func tearDown() async throws {
        // テストデータをクリーンアップ
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        repository = nil
        testUserDefaults = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Save/Load Tests
    
    func testSaveAndLoadStringSetting() async throws {
        // Given
        let key = "testString"
        let value = "Hello, World!"
        let category = RepositorySettingsCategory.other
        
        // When
        try await repository.saveSetting(value, for: key, category: category)
        let loadedValue = try await repository.loadSetting(for: key, type: String.self, category: category)
        
        // Then
        XCTAssertEqual(loadedValue, value)
    }
    
    func testSaveAndLoadIntSetting() async throws {
        // Given
        let key = "testInt"
        let value = 42
        let category = RepositorySettingsCategory.core
        
        // When
        try await repository.saveSetting(value, for: key, category: category)
        let loadedValue = try await repository.loadSetting(for: key, type: Int.self, category: category)
        
        // Then
        XCTAssertEqual(loadedValue, value)
    }
    
    func testSaveAndLoadDoubleSetting() async throws {
        // Given
        let key = "testDouble"
        let value = 3.14159
        let category = RepositorySettingsCategory.core
        
        // When
        try await repository.saveSetting(value, for: key, category: category)
        let loadedValue = try await repository.loadSetting(for: key, type: Double.self, category: category)
        
        // Then
        XCTAssertEqual(loadedValue, value, accuracy: 0.00001)
    }
    
    func testSaveAndLoadBoolSetting() async throws {
        // Given
        let key = "testBool"
        let value = true
        let category = RepositorySettingsCategory.userInterface
        
        // When
        try await repository.saveSetting(value, for: key, category: category)
        let loadedValue = try await repository.loadSetting(for: key, type: Bool.self, category: category)
        
        // Then
        XCTAssertEqual(loadedValue, value)
    }
    
    func testLoadNonExistentSetting() async throws {
        // Given
        let key = "nonExistent"
        let category = RepositorySettingsCategory.other
        
        // When
        let loadedValue = try await repository.loadSetting(for: key, type: String.self, category: category)
        
        // Then
        XCTAssertNil(loadedValue)
    }
    
    // MARK: - Complex Object Tests
    
    func testSaveAndLoadComplexObject() async throws {
        // Given
        struct TestSettings: Codable, Equatable {
            let name: String
            let version: Int
            let enabled: Bool
            let values: [Double]
        }
        
        let key = "complexObject"
        let value = TestSettings(
            name: "Test Configuration",
            version: 2,
            enabled: true,
            values: [1.0, 2.5, 3.14, 4.7]
        )
        let category = RepositorySettingsCategory.other
        
        // When
        try await repository.saveSetting(value, for: key, category: category)
        let loadedValue = try await repository.loadSetting(for: key, type: TestSettings.self, category: category)
        
        // Then
        XCTAssertEqual(loadedValue, value)
    }
    
    // MARK: - Category Tests
    
    func testSeparateCategoriesDoNotInterfere() async throws {
        // Given
        let key = "sameKey"
        let value1 = "Performance Value"
        let value2 = "UI Value"
        let category1 = RepositorySettingsCategory.core
        let category2 = RepositorySettingsCategory.userInterface
        
        // When
        try await repository.saveSetting(value1, for: key, category: category1)
        try await repository.saveSetting(value2, for: key, category: category2)
        
        let loadedValue1 = try await repository.loadSetting(for: key, type: String.self, category: category1)
        let loadedValue2 = try await repository.loadSetting(for: key, type: String.self, category: category2)
        
        // Then
        XCTAssertEqual(loadedValue1, value1)
        XCTAssertEqual(loadedValue2, value2)
        XCTAssertNotEqual(loadedValue1, loadedValue2)
    }
    
    func testLoadAllSettingsFromCategory() async throws {
        // Given
        let category = RepositorySettingsCategory.core
        try await repository.saveSetting(3.0, for: "interval", category: category)
        try await repository.saveSetting(true, for: "autoStart", category: category)
        try await repository.saveSetting("fade", for: "transition", category: category)
        
        // When
        let allSettings = try await repository.loadAllSettings(for: category)
        
        // Then
        XCTAssertEqual(allSettings.count, 3)
        XCTAssertEqual(allSettings["interval"] as? Double, 3.0)
        XCTAssertEqual(allSettings["autoStart"] as? Bool, true)
        XCTAssertEqual(allSettings["transition"] as? String, "fade")
    }
    
    // MARK: - Delete Tests
    
    func testDeleteSetting() async throws {
        // Given
        let key = "toBeDeleted"
        let value = "Temporary Value"
        let category = RepositorySettingsCategory.other
        
        try await repository.saveSetting(value, for: key, category: category)
        XCTAssertTrue(await repository.hasSetting(for: key, category: category))
        
        // When
        try await repository.deleteSetting(for: key, category: category)
        
        // Then
        XCTAssertFalse(await repository.hasSetting(for: key, category: category))
        let loadedValue = try await repository.loadSetting(for: key, type: String.self, category: category)
        XCTAssertNil(loadedValue)
    }
    
    func testDeleteAllSettingsFromCategory() async throws {
        // Given
        let category = RepositorySettingsCategory.core
        try await repository.saveSetting(1024, for: "memoryLimit", category: category)
        try await repository.saveSetting(5, for: "maxConcurrentLoads", category: category)
        try await repository.saveSetting(true, for: "enableOptimization", category: category)
        
        // Verify settings exist
        XCTAssertTrue(await repository.hasSetting(for: "memoryLimit", category: category))
        XCTAssertTrue(await repository.hasSetting(for: "maxConcurrentLoads", category: category))
        XCTAssertTrue(await repository.hasSetting(for: "enableOptimization", category: category))
        
        // When
        try await repository.deleteAllSettings(for: category)
        
        // Then
        XCTAssertFalse(await repository.hasSetting(for: "memoryLimit", category: category))
        XCTAssertFalse(await repository.hasSetting(for: "maxConcurrentLoads", category: category))
        XCTAssertFalse(await repository.hasSetting(for: "enableOptimization", category: category))
        
        let allSettings = try await repository.loadAllSettings(for: category)
        XCTAssertTrue(allSettings.isEmpty)
    }
    
    // MARK: - Batch Operations Tests
    
    func testSaveMultipleSettings() async throws {
        // Given
        let settings = [
            (key: "setting1", value: "value1", category: RepositorySettingsCategory.other),
            (key: "setting2", value: 42, category: RepositorySettingsCategory.core),
            (key: "setting3", value: true, category: RepositorySettingsCategory.userInterface)
        ]
        
        // When
        try await repository.saveMultipleSettings(settings)
        
        // Then
        let loadedValue1 = try await repository.loadSetting(for: "setting1", type: String.self, category: .other)
        let loadedValue2 = try await repository.loadSetting(for: "setting2", type: Int.self, category: .core)
        let loadedValue3 = try await repository.loadSetting(for: "setting3", type: Bool.self, category: .userInterface)
        
        XCTAssertEqual(loadedValue1, "value1")
        XCTAssertEqual(loadedValue2, 42)
        XCTAssertEqual(loadedValue3, true)
    }
    
    // MARK: - Export/Import Tests
    
    func testExportAndImportSettings() async throws {
        // Given - Setup initial settings
        let categories: [RepositorySettingsCategory] = [.core, .userInterface]
        
        try await repository.saveSetting(1024, for: "memoryLimit", category: .core)
        try await repository.saveSetting(5, for: "maxLoads", category: .core)
        try await repository.saveSetting(3.0, for: "interval", category: .core)
        try await repository.saveSetting(true, for: "autoStart", category: .core)
        
        // When - Export settings
        let exportedSettings = try await repository.exportSettings(for: categories)
        
        // Clear original settings
        try await repository.deleteAllSettings(for: .core)
        try await repository.deleteAllSettings(for: .userInterface)
        
        // Import settings back
        try await repository.importData(exportedSettings, for: categories, overwriteExisting: true)
        
        // Then - Verify restored settings
        let memoryLimit = try await repository.loadSetting(for: "memoryLimit", type: Int.self, category: .core)
        let maxLoads = try await repository.loadSetting(for: "maxLoads", type: Int.self, category: .core)
        let interval = try await repository.loadSetting(for: "interval", type: Double.self, category: .core)
        let autoStart = try await repository.loadSetting(for: "autoStart", type: Bool.self, category: .core)
        
        XCTAssertEqual(memoryLimit, 1024)
        XCTAssertEqual(maxLoads, 5)
        XCTAssertEqual(interval, 3.0)
        XCTAssertEqual(autoStart, true)
    }
    
    func testImportWithoutOverwrite() async throws {
        // Given - Existing setting
        let key = "existingSetting"
        let originalValue = "original"
        let newValue = "new"
        let category = RepositorySettingsCategory.other
        
        try await repository.saveSetting(originalValue, for: key, category: category)
        
        let importData = [
            category.rawValue: [key: newValue]
        ]
        
        // When - Import without overwrite
        try await repository.importData(importData, for: [category], overwriteExisting: false)
        
        // Then - Original value should remain
        let loadedValue = try await repository.loadSetting(for: key, type: String.self, category: category)
        XCTAssertEqual(loadedValue, originalValue)
    }
    
    // MARK: - Caching Tests
    
    func testCacheHitAndMiss() async throws {
        // Given
        let key = "cachedSetting"
        let value = "cached value"
        let category = RepositorySettingsCategory.other
        
        // When - First save (cache miss)
        try await repository.saveSetting(value, for: key, category: category)
        
        // First load (cache miss)
        _ = try await repository.loadSetting(for: key, type: String.self, category: category)
        
        // Second load (cache hit)
        let cachedValue = try await repository.loadSetting(for: key, type: String.self, category: category)
        
        // Then
        XCTAssertEqual(cachedValue, value)
        
        let metrics = await repository.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics.cacheHitCount, 0)
    }
    
    func testClearCache() async throws {
        // Given
        let key = "cachedSetting"
        let value = "test value"
        let category = RepositorySettingsCategory.other
        
        try await repository.saveSetting(value, for: key, category: category)
        _ = try await repository.loadSetting(for: key, type: String.self, category: category) // Load to cache
        
        // When
        await repository.clearCache()
        
        // Then - Next load should be cache miss but still work
        let loadedValue = try await repository.loadSetting(for: key, type: String.self, category: category)
        XCTAssertEqual(loadedValue, value)
    }
    
    // MARK: - Utility Tests
    
    func testHasSetting() async throws {
        // Given
        let key = "testKey"
        let value = "test value"
        let category = RepositorySettingsCategory.other
        
        // Initially should not exist
        XCTAssertFalse(await repository.hasSetting(for: key, category: category))
        
        // When
        try await repository.saveSetting(value, for: key, category: category)
        
        // Then
        XCTAssertTrue(await repository.hasSetting(for: key, category: category))
    }
    
    func testGetSettingKeys() async throws {
        // Given
        let category = RepositorySettingsCategory.userInterface
        try await repository.saveSetting("name", for: "sortMethod", category: category)
        try await repository.saveSetting(true, for: "ascending", category: category)
        try await repository.saveSetting(false, for: "caseSensitive", category: category)
        
        // When
        let keys = await repository.getSettingKeys(for: category)
        
        // Then
        XCTAssertEqual(Set(keys), Set(["sortMethod", "ascending", "caseSensitive"]))
    }
    
    func testSupportedCategories() {
        // When
        let supportedCategories = repository.supportedCategories
        
        // Then
        XCTAssertEqual(supportedCategories.count, RepositorySettingsCategory.allCases.count)
        XCTAssertTrue(supportedCategories.contains(.core))
        XCTAssertTrue(supportedCategories.contains(.userInterface))
        XCTAssertTrue(supportedCategories.contains(.system))
        XCTAssertTrue(supportedCategories.contains(.integration))
        XCTAssertTrue(supportedCategories.contains(.development))
        XCTAssertTrue(supportedCategories.contains(.other))
    }
    
    // MARK: - Default Settings Tests
    
    func testInitializeDefaultSettings() async throws {
        // When
        try await repository.initializeDefaultSettings()
        
        // Then - Check some default values
        let memoryLimit = try await repository.loadSetting(for: "memoryLimit", type: Int.self, category: .performance)
        let interval = try await repository.loadSetting(for: "interval", type: Double.self, category: .slideshow)
        let sortMethod = try await repository.loadSetting(for: "sortMethod", type: String.self, category: .sort)
        let effectType = try await repository.loadSetting(for: "effectType", type: String.self, category: .transition)
        
        XCTAssertEqual(memoryLimit, 1024 * 1024 * 1024) // 1GB
        XCTAssertEqual(interval, 3.0)
        XCTAssertEqual(sortMethod, "name")
        XCTAssertEqual(effectType, "fade")
    }
    
    // MARK: - Backup/Restore Tests
    
    func testCreateAndRestoreBackup() async throws {
        // Given - Setup test data
        try await repository.saveSetting("test app", for: "appName", category: .other)
        try await repository.saveSetting(1024, for: "memoryLimit", category: .core)
        try await repository.saveSetting(true, for: "autoStart", category: .core)
        
        // When - Create backup
        let backupData = try await repository.createBackup()
        
        // Clear all settings
        for category in RepositorySettingsCategory.allCases {
            try await repository.deleteAllSettings(for: category)
        }
        
        // Restore from backup
        try await repository.restoreFromBackup(backupData, overwriteExisting: true)
        
        // Then - Verify restored data
        let appName = try await repository.loadSetting(for: "appName", type: String.self, category: .other)
        let memoryLimit = try await repository.loadSetting(for: "memoryLimit", type: Int.self, category: .core)
        let autoStart = try await repository.loadSetting(for: "autoStart", type: Bool.self, category: .core)
        
        XCTAssertEqual(appName, "test app")
        XCTAssertEqual(memoryLimit, 1024)
        XCTAssertEqual(autoStart, true)
    }
    
    // MARK: - Validation Tests
    
    func testValidatePerformanceSetting() async throws {
        // Valid memory limit
        let validMemoryLimit = 1024 * 1024 * 1024 // 1GB
        let isValidMemory = try await repository.validateSetting(validMemoryLimit, for: "memoryLimit", category: .core)
        XCTAssertTrue(isValidMemory)
        
        // Invalid memory limit (too large)
        let invalidMemoryLimit = 32 * 1024 * 1024 * 1024 // 32GB
        let isInvalidMemory = try await repository.validateSetting(invalidMemoryLimit, for: "memoryLimit", category: .core)
        XCTAssertFalse(isInvalidMemory)
        
        // Valid concurrent loads
        let validConcurrentLoads = 5
        let isValidLoads = try await repository.validateSetting(validConcurrentLoads, for: "maxConcurrentLoads", category: .core)
        XCTAssertTrue(isValidLoads)
        
        // Invalid concurrent loads (too many)
        let invalidConcurrentLoads = 50
        let isInvalidLoads = try await repository.validateSetting(invalidConcurrentLoads, for: "maxConcurrentLoads", category: .core)
        XCTAssertFalse(isInvalidLoads)
    }
    
    func testValidateSlideshowSetting() async throws {
        // Valid interval
        let validInterval = 2.5
        let isValidInterval = try await repository.validateSetting(validInterval, for: "interval", category: .core)
        XCTAssertTrue(isValidInterval)
        
        // Invalid interval (too short)
        let invalidInterval = 0.05
        let isInvalidInterval = try await repository.validateSetting(invalidInterval, for: "interval", category: .core)
        XCTAssertFalse(isInvalidInterval)
        
        // Valid boolean setting
        let validBool = true
        let isValidBool = try await repository.validateSetting(validBool, for: "autoStart", category: .core)
        XCTAssertTrue(isValidBool)
    }
}