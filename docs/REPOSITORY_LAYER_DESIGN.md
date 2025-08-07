# Repository層 詳細設計書

## 概要

Swift PhotosのRepository層を新アーキテクチャ仕様に基づいて再設計します。この文書では、Repository層の抽象化、プロトコル定義、および具体的な実装方針について詳述します。

## 設計原則

1. **単一責任の原則**: 各Repositoryは特定のデータアクセスに関する責任のみを持つ
2. **依存性逆転の原則**: 上位層は抽象（プロトコル）に依存し、具体実装に依存しない
3. **インターフェース分離の原則**: クライアントが必要としないメソッドへの依存を強制しない
4. **テスタビリティ**: モックやスタブによる容易なテスト実装

## Repository層の構成

### 1. プロトコル定義（Domain層）

#### 1.1 ImageRepositoryProtocol

```swift
// Domain/Repositories/ImageRepositoryProtocol.swift
import Foundation

/// 画像データへのアクセスを抽象化するプロトコル
public protocol ImageRepositoryProtocol: Sendable {
    /// 指定されたURLから画像を読み込む
    func loadImage(from url: URL) async throws -> SendableImage
    
    /// 指定されたフォルダから画像URLのリストを取得
    func loadImageURLs(from folder: URL) async throws -> [ImageURL]
    
    /// 画像のメタデータを読み込む
    func loadMetadata(for url: URL) async throws -> ImageMetadata
    
    /// 画像のサムネイルを生成
    func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage
    
    /// 指定された条件で画像を検索
    func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL]
}

/// 画像検索条件
public struct SearchCriteria: Sendable {
    public let fileName: String?
    public let dateRange: DateRange?
    public let sizeRange: SizeRange?
    public let metadata: [String: Any]?
    
    public struct DateRange: Sendable {
        public let start: Date
        public let end: Date
    }
    
    public struct SizeRange: Sendable {
        public let minSize: Int64
        public let maxSize: Int64
    }
}
```

#### 1.2 CacheRepositoryProtocol

```swift
// Domain/Repositories/CacheRepositoryProtocol.swift
import Foundation

/// キャッシュ操作を抽象化するプロトコル
public protocol CacheRepositoryProtocol: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    /// キャッシュから値を取得
    func get(_ key: Key) async -> Value?
    
    /// キャッシュに値を保存
    func set(_ value: Value, for key: Key, cost: Int?) async
    
    /// キャッシュから値を削除
    func remove(_ key: Key) async
    
    /// すべてのキャッシュをクリア
    func removeAll() async
    
    /// キャッシュ統計情報を取得
    func statistics() async -> CacheStatistics
    
    /// キャッシュサイズの制限を設定
    func setLimits(countLimit: Int?, totalCostLimit: Int?) async
}

/// 画像専用のキャッシュプロトコル
public protocol ImageCacheRepositoryProtocol: CacheRepositoryProtocol where Key == ImageCacheKey, Value == SendableImage {
    /// プリロード用の特別なメソッド
    func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async
}

public struct ImageCacheKey: Hashable, Sendable {
    public let url: URL
    public let size: CGSize?
    public let quality: ImageQuality
    
    public enum ImageQuality: Sendable {
        case thumbnail
        case preview
        case full
    }
}
```

#### 1.3 MetadataRepositoryProtocol

```swift
// Domain/Repositories/MetadataRepositoryProtocol.swift
import Foundation

/// 画像メタデータへのアクセスを抽象化するプロトコル
public protocol MetadataRepositoryProtocol: Sendable {
    /// EXIFデータを読み込む
    func loadEXIFData(for url: URL) async throws -> EXIFData
    
    /// IPTCデータを読み込む
    func loadIPTCData(for url: URL) async throws -> IPTCData
    
    /// XMPデータを読み込む
    func loadXMPData(for url: URL) async throws -> XMPData
    
    /// すべてのメタデータを統合して読み込む
    func loadAllMetadata(for url: URL) async throws -> ImageMetadata
    
    /// メタデータを更新（非破壊的）
    func updateMetadata(_ metadata: ImageMetadata, for url: URL) async throws
    
    /// メタデータをキャッシュ
    func cacheMetadata(_ metadata: ImageMetadata, for url: URL) async
}

/// 統合メタデータ構造体
public struct ImageMetadata: Sendable, Codable {
    public let fileInfo: FileInfo
    public let imageInfo: ImageInfo
    public let exifData: EXIFData?
    public let iptcData: IPTCData?
    public let xmpData: XMPData?
    public let colorProfile: ColorProfile?
    
    public struct FileInfo: Sendable, Codable {
        public let size: Int64
        public let createdDate: Date
        public let modifiedDate: Date
        public let fileName: String
        public let fileExtension: String
    }
    
    public struct ImageInfo: Sendable, Codable {
        public let width: Int
        public let height: Int
        public let colorSpace: String?
        public let bitDepth: Int?
        public let hasAlpha: Bool
    }
}
```

#### 1.4 SettingsRepositoryProtocol

```swift
// Domain/Repositories/SettingsRepositoryProtocol.swift
import Foundation

/// アプリケーション設定へのアクセスを抽象化するプロトコル
public protocol SettingsRepositoryProtocol: Sendable {
    /// 設定を読み込む
    func load<T: Codable>(_ type: T.Type, for key: SettingsKey) async -> T?
    
    /// 設定を保存
    func save<T: Codable>(_ value: T, for key: SettingsKey) async throws
    
    /// 設定を削除
    func remove(for key: SettingsKey) async
    
    /// すべての設定をリセット
    func resetAll() async
    
    /// 設定をエクスポート
    func export() async throws -> Data
    
    /// 設定をインポート
    func importSettings(from data: Data) async throws
}

public struct SettingsKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    // 定義済みキー
    public static let performance = SettingsKey(rawValue: "performance")
    public static let slideshow = SettingsKey(rawValue: "slideshow")
    public static let sort = SettingsKey(rawValue: "sort")
    public static let transition = SettingsKey(rawValue: "transition")
    public static let uiControl = SettingsKey(rawValue: "uiControl")
}
```

### 2. 具体実装（Infrastructure層）

#### 2.1 LocalImageRepository

```swift
// Infrastructure/Repositories/LocalImageRepository.swift
import Foundation
import AppKit

/// ローカルファイルシステムから画像を読み込むRepository
public actor LocalImageRepository: ImageRepositoryProtocol {
    private let fileAccess: SecureFileAccess
    private let imageLoader: ImageLoader
    private let metadataExtractor: MetadataExtractor
    private let thumbnailGenerator: ThumbnailGenerator
    
    public init(
        fileAccess: SecureFileAccess,
        imageLoader: ImageLoader,
        metadataExtractor: MetadataExtractor,
        thumbnailGenerator: ThumbnailGenerator
    ) {
        self.fileAccess = fileAccess
        self.imageLoader = imageLoader
        self.metadataExtractor = metadataExtractor
        self.thumbnailGenerator = thumbnailGenerator
    }
    
    public func loadImage(from url: URL) async throws -> SendableImage {
        try fileAccess.validateFileAccess(for: url)
        return try await imageLoader.loadImage(from: url)
    }
    
    public func loadImageURLs(from folder: URL) async throws -> [ImageURL] {
        try fileAccess.validateFileAccess(for: folder)
        let urls = try fileAccess.enumerateImages(in: folder)
        return try urls.map { try ImageURL($0) }
    }
    
    public func loadMetadata(for url: URL) async throws -> ImageMetadata {
        try fileAccess.validateFileAccess(for: url)
        return try await metadataExtractor.extract(from: url)
    }
    
    public func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage {
        try fileAccess.validateFileAccess(for: url)
        return try await thumbnailGenerator.generate(from: url, targetSize: size)
    }
    
    public func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL] {
        let allURLs = try await loadImageURLs(from: folder)
        
        return try await withThrowingTaskGroup(of: (ImageURL, Bool).self) { group in
            for imageURL in allURLs {
                group.addTask {
                    let matches = try await self.matchesCriteria(imageURL.url, criteria)
                    return (imageURL, matches)
                }
            }
            
            var matchingURLs: [ImageURL] = []
            for try await (url, matches) in group {
                if matches {
                    matchingURLs.append(url)
                }
            }
            return matchingURLs
        }
    }
    
    private func matchesCriteria(_ url: URL, _ criteria: SearchCriteria) async throws -> Bool {
        // 検索条件のマッチング実装
        if let fileName = criteria.fileName {
            guard url.lastPathComponent.localizedCaseInsensitiveContains(fileName) else {
                return false
            }
        }
        
        // 他の条件チェック...
        return true
    }
}
```

#### 2.2 MemoryCacheRepository

```swift
// Infrastructure/Repositories/MemoryCacheRepository.swift
import Foundation
import AppKit

/// メモリベースのキャッシュRepository
public actor MemoryCacheRepository: ImageCacheRepositoryProtocol {
    private let cache: NSCache<NSString, CacheEntry>
    private var statistics = CacheStatistics(
        hitCount: 0,
        missCount: 0,
        totalCost: 0,
        currentCount: 0
    )
    
    private class CacheEntry: NSObject {
        let value: SendableImage
        let cost: Int
        let timestamp: Date
        
        init(value: SendableImage, cost: Int) {
            self.value = value
            self.cost = cost
            self.timestamp = Date()
        }
    }
    
    public init(countLimit: Int = 100, totalCostLimit: Int = 500_000_000) {
        self.cache = NSCache<NSString, CacheEntry>()
        self.cache.countLimit = countLimit
        self.cache.totalCostLimit = totalCostLimit
    }
    
    public func get(_ key: ImageCacheKey) async -> SendableImage? {
        let cacheKey = key.cacheKey
        if let entry = cache.object(forKey: cacheKey as NSString) {
            statistics.hitCount += 1
            return entry.value
        } else {
            statistics.missCount += 1
            return nil
        }
    }
    
    public func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        let cacheKey = key.cacheKey
        let imageCost = cost ?? calculateCost(for: value)
        let entry = CacheEntry(value: value, cost: imageCost)
        
        cache.setObject(entry, forKey: cacheKey as NSString, cost: imageCost)
        statistics.totalCost += imageCost
        statistics.currentCount = cache.countLimit
    }
    
    public func remove(_ key: ImageCacheKey) async {
        let cacheKey = key.cacheKey
        if let entry = cache.object(forKey: cacheKey as NSString) {
            statistics.totalCost -= entry.cost
            statistics.currentCount -= 1
        }
        cache.removeObject(forKey: cacheKey as NSString)
    }
    
    public func removeAll() async {
        cache.removeAllObjects()
        statistics = CacheStatistics(
            hitCount: 0,
            missCount: 0,
            totalCost: 0,
            currentCount: 0
        )
    }
    
    public func statistics() async -> CacheStatistics {
        return statistics
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        if let countLimit = countLimit {
            cache.countLimit = countLimit
        }
        if let totalCostLimit = totalCostLimit {
            cache.totalCostLimit = totalCostLimit
        }
    }
    
    public func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async {
        for (key, value) in images {
            await set(value, for: key, cost: nil)
        }
    }
    
    private func calculateCost(for image: SendableImage) -> Int {
        // 画像のメモリコストを計算
        let pixelCount = Int(image.size.width * image.size.height)
        let bytesPerPixel = 4 // RGBA
        return pixelCount * bytesPerPixel
    }
}

extension ImageCacheKey {
    var cacheKey: String {
        var key = url.absoluteString
        if let size = size {
            key += "_\(Int(size.width))x\(Int(size.height))"
        }
        key += "_\(quality)"
        return key
    }
}
```

#### 2.3 DiskCacheRepository

```swift
// Infrastructure/Repositories/DiskCacheRepository.swift
import Foundation

/// ディスクベースのキャッシュRepository
public actor DiskCacheRepository: ImageCacheRepositoryProtocol {
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let maxDiskSize: Int64
    private var currentDiskUsage: Int64 = 0
    
    public init(cacheDirectory: URL, maxDiskSize: Int64 = 1_073_741_824) { // 1GB default
        self.cacheDirectory = cacheDirectory
        self.maxDiskSize = maxDiskSize
        
        Task {
            await createCacheDirectoryIfNeeded()
            await calculateDiskUsage()
        }
    }
    
    public func get(_ key: ImageCacheKey) async -> SendableImage? {
        let fileURL = cacheFileURL(for: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            await updateAccessTime(for: fileURL)
            
            guard let nsImage = NSImage(data: data) else {
                return nil
            }
            
            return SendableImage(nsImage)
        } catch {
            ProductionLogger.error("Failed to load cached image: \(error)")
            return nil
        }
    }
    
    public func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        let fileURL = cacheFileURL(for: key)
        
        do {
            // PNG形式で保存
            guard let data = value.pngData() else {
                return
            }
            
            // ディスク容量チェック
            let fileSize = Int64(data.count)
            if currentDiskUsage + fileSize > maxDiskSize {
                await performCleanup(requiredSpace: fileSize)
            }
            
            try data.write(to: fileURL)
            currentDiskUsage += fileSize
            
            // メタデータを保存
            await saveCacheMetadata(for: key, size: fileSize)
            
        } catch {
            ProductionLogger.error("Failed to save image to disk cache: \(error)")
        }
    }
    
    public func remove(_ key: ImageCacheKey) async {
        let fileURL = cacheFileURL(for: key)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            try fileManager.removeItem(at: fileURL)
            currentDiskUsage -= fileSize
            
            await removeCacheMetadata(for: key)
        } catch {
            // ファイルが存在しない場合は無視
        }
    }
    
    public func removeAll() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
            
            currentDiskUsage = 0
        } catch {
            ProductionLogger.error("Failed to clear disk cache: \(error)")
        }
    }
    
    public func statistics() async -> CacheStatistics {
        let fileCount = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil).count) ?? 0
        
        return CacheStatistics(
            hitCount: 0, // ディスクキャッシュではトラッキングしない
            missCount: 0,
            totalCost: Int(currentDiskUsage),
            currentCount: fileCount
        )
    }
    
    public func setLimits(countLimit: Int?, totalCostLimit: Int?) async {
        // ディスクキャッシュでは totalCostLimit のみ使用
        if let totalCostLimit = totalCostLimit {
            self.maxDiskSize = Int64(totalCostLimit)
        }
    }
    
    public func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async {
        for (key, value) in images {
            await set(value, for: key, cost: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func cacheFileURL(for key: ImageCacheKey) -> URL {
        let fileName = key.cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key.cacheKey
        return cacheDirectory.appendingPathComponent(fileName).appendingPathExtension("png")
    }
    
    private func createCacheDirectoryIfNeeded() async {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            ProductionLogger.error("Failed to create cache directory: \(error)")
        }
    }
    
    private func calculateDiskUsage() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            currentDiskUsage = contents.reduce(0) { total, fileURL in
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + Int64(size)
            }
        } catch {
            ProductionLogger.error("Failed to calculate disk usage: \(error)")
        }
    }
    
    private func performCleanup(requiredSpace: Int64) async {
        // LRU方式でファイルを削除
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey]
            )
            
            // アクセス日時でソート
            let sortedFiles = contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                return date1 < date2
            }
            
            var freedSpace: Int64 = 0
            for fileURL in sortedFiles {
                if freedSpace >= requiredSpace {
                    break
                }
                
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                try fileManager.removeItem(at: fileURL)
                freedSpace += Int64(size)
                currentDiskUsage -= Int64(size)
            }
        } catch {
            ProductionLogger.error("Failed to perform cleanup: \(error)")
        }
    }
    
    private func updateAccessTime(for url: URL) async {
        do {
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } catch {
            // アクセス時刻の更新に失敗しても続行
        }
    }
    
    private func saveCacheMetadata(for key: ImageCacheKey, size: Int64) async {
        // メタデータ管理の実装（必要に応じて）
    }
    
    private func removeCacheMetadata(for key: ImageCacheKey) async {
        // メタデータ削除の実装（必要に応じて）
    }
}
```

#### 2.4 UserDefaultsSettingsRepository

```swift
// Infrastructure/Repositories/UserDefaultsSettingsRepository.swift
import Foundation

/// UserDefaultsを使用した設定Repository
public actor UserDefaultsSettingsRepository: SettingsRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func load<T: Codable>(_ type: T.Type, for key: SettingsKey) async -> T? {
        guard let data = userDefaults.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            ProductionLogger.error("Failed to decode settings for key \(key.rawValue): \(error)")
            return nil
        }
    }
    
    public func save<T: Codable>(_ value: T, for key: SettingsKey) async throws {
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: key.rawValue)
    }
    
    public func remove(for key: SettingsKey) async {
        userDefaults.removeObject(forKey: key.rawValue)
    }
    
    public func resetAll() async {
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        userDefaults.synchronize()
    }
    
    public func export() async throws -> Data {
        let allSettings = userDefaults.dictionaryRepresentation()
        return try JSONSerialization.data(withJSONObject: allSettings, options: .prettyPrinted)
    }
    
    public func importSettings(from data: Data) async throws {
        let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        for (key, value) in settings {
            userDefaults.set(value, forKey: key)
        }
        
        userDefaults.synchronize()
    }
}
```

### 3. Repository統合とDI（Dependency Injection）

#### 3.1 RepositoryContainer

```swift
// Application/DI/RepositoryContainer.swift
import Foundation

/// Repositoryのコンテナ（依存性注入用）
@MainActor
public final class RepositoryContainer {
    public let imageRepository: ImageRepositoryProtocol
    public let memoryCacheRepository: ImageCacheRepositoryProtocol
    public let diskCacheRepository: ImageCacheRepositoryProtocol
    public let metadataRepository: MetadataRepositoryProtocol
    public let settingsRepository: SettingsRepositoryProtocol
    
    private init(
        imageRepository: ImageRepositoryProtocol,
        memoryCacheRepository: ImageCacheRepositoryProtocol,
        diskCacheRepository: ImageCacheRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.imageRepository = imageRepository
        self.memoryCacheRepository = memoryCacheRepository
        self.diskCacheRepository = diskCacheRepository
        self.metadataRepository = metadataRepository
        self.settingsRepository = settingsRepository
    }
    
    /// プロダクション用のコンテナを作成
    public static func createProduction() -> RepositoryContainer {
        let fileAccess = SecureFileAccess()
        let imageLoader = ImageLoader()
        let metadataExtractor = MetadataExtractor()
        let thumbnailGenerator = ThumbnailGenerator()
        
        let imageRepository = LocalImageRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            metadataExtractor: metadataExtractor,
            thumbnailGenerator: thumbnailGenerator
        )
        
        let memoryCacheRepository = MemoryCacheRepository()
        
        let cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SwiftPhotos")
            .appendingPathComponent("ImageCache")
        
        let diskCacheRepository = DiskCacheRepository(cacheDirectory: cacheDirectory)
        
        let metadataRepository = FileSystemMetadataRepository(
            metadataExtractor: metadataExtractor
        )
        
        let settingsRepository = UserDefaultsSettingsRepository()
        
        return RepositoryContainer(
            imageRepository: imageRepository,
            memoryCacheRepository: memoryCacheRepository,
            diskCacheRepository: diskCacheRepository,
            metadataRepository: metadataRepository,
            settingsRepository: settingsRepository
        )
    }
    
    /// テスト用のコンテナを作成
    public static func createForTesting(
        imageRepository: ImageRepositoryProtocol? = nil,
        memoryCacheRepository: ImageCacheRepositoryProtocol? = nil,
        diskCacheRepository: ImageCacheRepositoryProtocol? = nil,
        metadataRepository: MetadataRepositoryProtocol? = nil,
        settingsRepository: SettingsRepositoryProtocol? = nil
    ) -> RepositoryContainer {
        return RepositoryContainer(
            imageRepository: imageRepository ?? MockImageRepository(),
            memoryCacheRepository: memoryCacheRepository ?? MockCacheRepository(),
            diskCacheRepository: diskCacheRepository ?? MockCacheRepository(),
            metadataRepository: metadataRepository ?? MockMetadataRepository(),
            settingsRepository: settingsRepository ?? MockSettingsRepository()
        )
    }
}
```

### 4. 移行戦略

#### 4.1 段階的移行

1. **Phase 1**: プロトコル定義とテスト実装
   - すべてのRepositoryプロトコルを定義
   - モック実装を作成
   - ユニットテストを実装

2. **Phase 2**: 既存コードのラップ
   - 既存の実装をRepositoryパターンでラップ
   - ViewModelからの直接アクセスを排除

3. **Phase 3**: 新実装への置き換え
   - 新しいRepository実装を作成
   - パフォーマンステストとチューニング
   - 本番環境への段階的デプロイ

#### 4.2 互換性維持

```swift
// 既存コードとの互換性レイヤー
extension FileSystemPhotoRepository {
    /// 既存のloadPhotosメソッドをRepository経由で実装
    public func loadPhotos(from folderURL: URL) async throws -> [Photo] {
        let imageURLs = try await imageRepository.loadImageURLs(from: folderURL)
        
        // 既存のソート処理
        let sortedURLs = await sortSettings.sort(imageURLs)
        
        // Photo オブジェクトの作成
        return sortedURLs.map { Photo(imageURL: $0) }
    }
}
```

### 5. テスト戦略

#### 5.1 モック実装

```swift
// Tests/Mocks/MockImageRepository.swift
final class MockImageRepository: ImageRepositoryProtocol {
    var loadImageCalled = false
    var loadImageResult: Result<SendableImage, Error> = .failure(TestError.notImplemented)
    
    func loadImage(from url: URL) async throws -> SendableImage {
        loadImageCalled = true
        return try loadImageResult.get()
    }
    
    // 他のメソッドも同様に実装
}
```

#### 5.2 ユニットテスト例

```swift
// Tests/Repositories/ImageRepositoryTests.swift
final class ImageRepositoryTests: XCTestCase {
    func testLoadImage() async throws {
        // Given
        let mockRepository = MockImageRepository()
        let testImage = SendableImage(NSImage())
        mockRepository.loadImageResult = .success(testImage)
        
        // When
        let result = try await mockRepository.loadImage(from: URL(fileURLWithPath: "/test.jpg"))
        
        // Then
        XCTAssertTrue(mockRepository.loadImageCalled)
        XCTAssertEqual(result.id, testImage.id)
    }
}
```

## まとめ

このRepository層の設計により、以下の利点が得られます：

1. **テスタビリティの向上**: プロトコルベースの設計により、モックやスタブが容易
2. **保守性の向上**: 責務が明確に分離され、変更の影響範囲が限定的
3. **拡張性**: 新しいデータソースの追加が容易（クラウドストレージ等）
4. **パフォーマンス**: キャッシュ層の抽象化により、最適化が容易
5. **型安全性**: Swift の型システムを活用した安全な実装