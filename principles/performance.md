# SwiftPhotos パフォーマンス最適化とメモリ管理

このドキュメントは、SwiftPhotosアプリケーションのメモリ管理戦略とパフォーマンス最適化アルゴリズムについて詳細に説明します。

## 概要

SwiftPhotosは**100,000枚以上の大量画像**を効率的に処理するため、**3層の多段階メモリ管理システム**を実装しています。これにより、無制限のスケーラビリティを実現しながら、メモリ使用量を適切に制御します。

## メモリ管理アーキテクチャ

### 多層キャッシュシステム
```
┌─────────────────────────────────────────┐
│          VirtualImageLoader             │  スライディングウィンドウ方式
│         (Primary Cache Layer)          │  無制限スケーラビリティ対応
├─────────────────────────────────────────┤
│            LRUImageCache               │  LRU（最近最少使用）アルゴリズム
│        (Secondary Cache Layer)         │  予測可能なメモリ管理
├─────────────────────────────────────────┤
│             ImageCache                 │  NSCache ベースキャッシュ
│         (Tertiary Cache Layer)         │  コストベース退避制御
└─────────────────────────────────────────┘
```

## 1. VirtualImageLoader - メイン制御層

### スライディングウィンドウ方式

**責任**: 現在表示中の画像周辺のみメモリに保持し、不要な画像を自動削除

**ファイル**: `SwiftPhotos/Infrastructure/Services/VirtualImageLoader.swift`

#### 基本アルゴリズム

```swift
/// ウィンドウ外の画像を自動削除
private func cleanupOutOfWindowImages(currentIndex: Int, photos: [Photo]) {
    let bufferSize = windowSize * 2  // 二重バッファで安全性確保
    let bufferStart = max(0, currentIndex - bufferSize)
    let bufferEnd = min(photos.count - 1, currentIndex + bufferSize)
    let photosInBuffer = Set(photos[bufferStart...bufferEnd].map { $0.id })
    
    let beforeCount = loadedImages.count
    // ウィンドウ外の画像をメモリから削除
    loadedImages = loadedImages.filter { photosInBuffer.contains($0.key) }
    let afterCount = loadedImages.count
    
    if beforeCount != afterCount {
        ProductionLogger.debug("VirtualImageLoader: Cleaned up \(beforeCount - afterCount) out-of-window images")
    }
}
```

#### 効果
- **100,000枚**の写真コレクションでも、メモリには**設定されたウィンドウサイズ**のみ保持
- ユーザーが別の画像に移動すると、古い画像は**自動的に削除**
- **リアルタイム削除**: 画像移動時に即座に実行

### 動的ウィンドウサイズ調整

コレクションサイズに応じて最適なウィンドウサイズを自動計算：

```swift
private func calculateEffectiveWindowSize(collectionSize: Int) -> Int {
    switch collectionSize {
    case 0...100:
        return min(windowSize, collectionSize)
    case 101...1000:
        return min(windowSize, max(50, collectionSize / 10))
    case 1001...10000:
        return min(windowSize, max(100, collectionSize / 50))
    default:
        // 大規模コレクション（10k+）用の適応サイズ
        let adaptiveSize = max(200, min(windowSize, collectionSize / 100))
        return adaptiveSize
    }
}
```

### メモリ圧迫検知と緊急開放

**リアルタイム監視**: 画像読み込み完了時に毎回メモリ使用量をチェック

```swift
// メモリ制限を超えた場合の自動クリーンアップ
let currentUsage = getMemoryUsage()
if currentUsage > maxMemoryUsage {
    print("🗄️ VirtualImageLoader: Memory limit exceeded (\(currentUsage)MB > \(maxMemoryUsage)MB), cleaning up")
    await handleMemoryPressure()
}
```

#### 緊急開放アルゴリズム

```swift
private func handleMemoryPressure() async {
    let targetUsage = settings.aggressiveMemoryManagement ? 
        maxMemoryUsage / 2 : // アグレッシブモード: 50%まで削減
        maxMemoryUsage * 3 / 4 // 通常モード: 75%まで削減
    
    // 古い画像から順次削除してメモリ制限内に収める
    let sortedImages = loadedImages.sorted { first, second in
        return first.key.uuidString < second.key.uuidString
    }
    
    var currentUsage = getMemoryUsage()
    var removedCount = 0
    
    for (photoId, _) in sortedImages {
        if currentUsage <= targetUsage { break }
        
        loadedImages.removeValue(forKey: photoId)
        currentUsage = getMemoryUsage()
        removedCount += 1
    }
    
    if removedCount > 0 {
        print("🗄️ VirtualImageLoader: Memory pressure handled - removed \(removedCount) images, usage: \(currentUsage)MB")
    }
}
```

### タスクキャンセレーション

**並行処理の最適化**: ウィンドウ外に移動した画像の読み込みタスクを即座にキャンセル

```swift
/// ウィンドウ外のタスクをキャンセル
private func cancelOutOfWindowTasks(photosInWindow: Set<UUID>) async {
    for (photoId, task) in loadingTasks {
        if !photosInWindow.contains(photoId) {
            task.cancel()
            loadingTasks.removeValue(forKey: photoId)
            ProductionLogger.debug("VirtualImageLoader: Cancelled out-of-window load for \(photoId)")
        }
    }
}
```

## 2. LRUImageCache - 予測可能メモリ管理

### LRU（Least Recently Used）アルゴリズム

**責任**: 使用頻度の低い画像から優先的に削除

**ファイル**: `SwiftPhotos/Infrastructure/Services/LRUImageCache.swift`

#### 双方向リンクリスト実装

```swift
class CacheNode {
    let key: UUID
    let image: NSImage
    let size: Int  // メモリサイズ（バイト）
    var prev: CacheNode?
    var next: CacheNode?
    
    init(key: UUID, image: NSImage) {
        self.key = key
        self.image = image
        // サイズ推定: 幅 × 高さ × 4バイト/画素
        self.size = Int(image.size.width * image.size.height * 4)
    }
}
```

#### メモリ圧迫時の自動削除

```swift
/// メモリ圧迫処理：最近最少使用アイテムを削除
func handleMemoryPressure() {
    // キャッシュの25%を削除
    let targetSize = maxSize * 3 / 4
    
    while currentSize > targetSize && tail != nil {
        // 最も使用頻度の低い画像（tail）から削除
        if let nodeToRemove = tail {
            remove(node: nodeToRemove)
        }
    }
}
```

### 定期メモリ監視

**30秒間隔**でシステムメモリ状況をチェック：

```swift
private func checkMemoryStatus() {
    let memoryInfo = ProcessInfo.processInfo
    let physicalMemory = memoryInfo.physicalMemory
    
    // 物理メモリに対する使用率を計算
    let memoryUsage = Double(currentSize) / Double(physicalMemory)
    
    if memoryUsage > 0.5 { // 物理メモリの50%を超えた場合
        handleMemoryPressure()
    }
}
```

## 3. ImageCache - NSCacheベース基盤層

### コストベース退避制御

**責任**: 基盤的なキャッシュ機能とコストベースの自動削除

**ファイル**: `SwiftPhotos/Infrastructure/Services/ImageCache.swift`

```swift
public actor ImageCache: PhotoCache {
    private let cache = NSCache<NSString, NSImage>()
    
    public init(countLimit: Int = 50, totalCostLimit: Int = 100_000_000) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit  // 100MB デフォルト
        cache.name = "SwiftPhotos.ImageCache"
    }
    
    private func estimateImageCost(_ image: NSImage) -> Int {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 1000
        }
        
        let bytesPerPixel = 4
        let cost = cgImage.width * cgImage.height * bytesPerPixel
        return cost
    }
}
```

## パフォーマンス設定レベル

### スケーラブルな設定プリセット

**ファイル**: `SwiftPhotos/Domain/ValueObjects/PerformanceSettings.swift`

| 設定レベル | メモリウィンドウ | 最大メモリ | 並行読み込み | 対象コレクション |
|------------|------------------|------------|--------------|------------------|
| **Default** | 50枚 | 2GB | 5 | 0-100枚 |
| **High Performance** | 200枚 | 4GB | 10 | 101-1,000枚 |
| **Unlimited** | 1,000枚 | 8GB | 15 | 1,001-10,000枚 |
| **Massive** | 2,000枚 | 16GB | 25 | 10,001-50,000枚 |
| **Extreme** | 5,000枚 | 32GB | 40 | 50,001枚以上 |

### 設定値の制約

```swift
public init(
    memoryWindowSize: Int = 50,
    maxMemoryUsageMB: Int = 2000,
    maxConcurrentLoads: Int = 5,
    largeCollectionThreshold: Int = 100,
    aggressiveMemoryManagement: Bool = true,
    preloadDistance: Int = 10
) {
    // 無制限サポートのため上限なし
    self.memoryWindowSize = max(10, memoryWindowSize) // 10,000+枚も可能
    self.maxMemoryUsageMB = max(500, maxMemoryUsageMB) // 利用可能RAM全体も可能
    self.maxConcurrentLoads = max(1, min(50, maxConcurrentLoads)) // スレッド枯渇防止のため1-50
    self.largeCollectionThreshold = max(50, largeCollectionThreshold) // 上限なし
    self.aggressiveMemoryManagement = aggressiveMemoryManagement
    self.preloadDistance = max(5, preloadDistance) // 数千枚のプリロードも可能
}
```

## 最適化アルゴリズム

### 1. 定期的キャッシュ最適化

**50回読み込みごと**に実行される自動最適化：

```swift
func optimizeCache() async {
    let stats = getCacheStatistics()
    
    // ヒット率が70%未満の場合、ウィンドウサイズを拡大
    if stats.hitRate < 0.7 && windowSize < settings.memoryWindowSize {
        let newWindowSize = min(settings.memoryWindowSize, windowSize + 10)
        print("🗄️ VirtualImageLoader: Low hit rate (\(String(format: "%.1f", stats.hitRate * 100))%), increasing window size to \(newWindowSize)")
        windowSize = newWindowSize
    }
    
    // メモリ使用量が制限の50%未満の場合、より積極的なキャッシュ
    if stats.memoryUsageMB < maxMemoryUsage / 2 && windowSize < settings.memoryWindowSize {
        let newWindowSize = min(settings.memoryWindowSize, windowSize + 20)
        print("🗄️ VirtualImageLoader: Low memory usage, increasing window size to \(newWindowSize)")
        windowSize = newWindowSize
    }
}
```

### 2. 優先度ベース並行読み込み

**距離ベース優先度**: 現在表示中の画像から近い順に優先読み込み

```swift
private func loadImageWindowConcurrently(
    centerIndex: Int,
    startIndex: Int,
    endIndex: Int,
    photos: [Photo]
) async {
    // 中央から外側への距離ベースで優先度を決定
    let photosToLoad = (startIndex...endIndex).map { idx in
        let photo = photos[idx]
        let distance = abs(idx - centerIndex)
        return (photo: photo, distance: distance, index: idx)
    }
    .sorted { $0.distance < $1.distance } // 距離が近い順にソート
    
    // 中央画像（distance = 0）は最優先
    let priority: TaskPriority = distance == 0 ? .userInitiated : .utility
    
    await withTaskGroup(of: Void.self) { group in
        // 並行数制御付きで読み込み実行
    }
}
```

### 3. プログレスジャンプ最適化

**即座に全タスクキャンセル**: プログレスバーでのジャンプ時に不要な読み込みを停止

```swift
func cancelAllForProgressJump() async {
    print("🚫 VirtualImageLoader: Cancelling all tasks for progress bar jump")
    
    for (photoId, task) in loadingTasks {
        task.cancel()
        print("🚫 VirtualImageLoader: Cancelled task for \(photoId)")
    }
    loadingTasks.removeAll()
}
```

## メモリ使用量の計測

### リアルタイム使用量計算

```swift
func getMemoryUsage() -> Int {
    var totalBytes = 0
    for image in loadedImages.values {
        // 推定: 幅 × 高さ × 4バイト/画素（RGBA）
        totalBytes += Int(image.size.width * image.size.height * 4)
    }
    return totalBytes / (1024 * 1024) // MB変換
}
```

### パフォーマンス統計

**リアルタイム監視される指標**:

```swift
func getCacheStatistics() -> (hits: Int, misses: Int, hitRate: Double, loadedCount: Int, memoryUsageMB: Int) {
    let total = cacheHits + cacheMisses
    let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
    return (
        hits: cacheHits,
        misses: cacheMisses,
        hitRate: hitRate,
        loadedCount: loadedImages.count,
        memoryUsageMB: getMemoryUsage()
    )
}
```

## 並行処理の最適化

### Task Groups による制御

**制御可能な並行数**: 1-50の範囲で設定可能

```swift
await withTaskGroup(of: Void.self) { group in
    var semaphore = 0
    
    for (photo, distance, idx) in photosToLoad {
        // セマフォで並行数制御
        while semaphore >= maxConcurrent {
            await group.next()
            semaphore -= 1
        }
        
        group.addTask(priority: priority) { [weak self] in
            await self?.loadImageIfNeeded(photo: photo)
        }
        semaphore += 1
    }
}
```

### Actor による排他制御

**スレッドセーフ**: すべてのキャッシュ操作がActor内で実行

```swift
actor VirtualImageLoader {
    private var loadedImages: [UUID: NSImage] = [:]
    private var loadingTasks: [UUID: Task<NSImage, Error>] = [:]
    
    // Actor内のメソッドは自動的に排他制御される
}
```

## パフォーマンス目標

### スケーラビリティ指標

| コレクションサイズ | 推奨設定 | メモリ使用量 | 読み込み時間 |
|-------------------|----------|--------------|--------------|
| **1-100枚** | Default | ~200MB | < 1秒 |
| **101-1,000枚** | High Performance | ~800MB | < 3秒 |
| **1,001-10,000枚** | Unlimited | ~4GB | < 10秒 |
| **10,001-50,000枚** | Massive | ~8GB | < 30秒 |
| **50,001枚以上** | Extreme | ~16GB | < 60秒 |

### レスポンス目標

- **画像切り替え**: < 100ms
- **ウィンドウ再構成**: < 500ms
- **メモリクリーンアップ**: < 200ms
- **設定変更反映**: < 50ms

## トラブルシューティング

### メモリ不足時の対処

1. **自動縮小**: ウィンドウサイズの自動調整
2. **緊急開放**: アグレッシブモードの有効化
3. **設定変更**: より制約の厳しいプリセットへの切り替え

### デバッグ情報

**ProductionLogger**により詳細なログが記録：

```swift
ProductionLogger.debug("VirtualImageLoader: Cleaned up \(beforeCount - afterCount) out-of-window images")
ProductionLogger.performance("Memory limit exceeded, cleaned up \(removedCount) images")
ProductionLogger.debug("Cache hit rate: \(String(format: "%.1f", hitRate * 100))%")
```

## まとめ

SwiftPhotosのメモリ管理システムは以下の特徴により、**無制限スケーラビリティ**と**効率的なメモリ使用**を両立しています：

### 主要な利点

1. ✅ **スライディングウィンドウ**: 不要な画像の自動削除
2. ✅ **LRU退避**: 使用頻度ベースの賢い削除
3. ✅ **メモリ圧迫検知**: 制限超過時の緊急対応
4. ✅ **動的最適化**: 使用パターンに応じた自動調整
5. ✅ **並行処理制御**: リソース枯渇の防止
6. ✅ **設定可能制限**: ユーザー環境に応じたカスタマイズ

### 実現される効果

- **100,000枚の画像コレクション**でも安定動作
- **メモリ使用量**は設定された制限内に自動制御
- **レスポンシブな操作感**を維持
- **システムリソース**の効率的活用

この高度なメモリ管理により、SwiftPhotosは**プロフェッショナルグレード**の大量画像処理能力を提供します。