# Swift Photos 実装ロードマップ

## エグゼクティブサマリー

このドキュメントは、Swift Photosを新しいアーキテクチャ仕様に移行するための実践的な実装ロードマップです。現在の機能を維持しながら、段階的にアーキテクチャを改善していきます。

## 現在の状況

### 完了済みタスク ✅

1. **アーキテクチャ差分分析**
   - 現状と目標の明確化
   - 移行に必要な変更点の特定

2. **Repository層設計**
   - プロトコル定義完了
   - 実装方針の策定

3. **ViewModel層設計**
   - 責務分割の設計完了
   - リファクタリング手順の文書化

### 実装優先順位

優先度に基づいて、以下の順序で実装を進めます：

## Phase 1: 基盤整備（2週間）

### Week 1: Repository層の実装

#### Day 1-2: プロトコル定義
```bash
# 新しいファイルを作成
touch SwiftPhotos/Domain/Repositories/ImageRepositoryProtocol.swift
touch SwiftPhotos/Domain/Repositories/CacheRepositoryProtocol.swift
touch SwiftPhotos/Domain/Repositories/MetadataRepositoryProtocol.swift
touch SwiftPhotos/Domain/Repositories/SettingsRepositoryProtocol.swift
```

**実装内容:**
- `ImageRepositoryProtocol`: 画像読み込みの抽象化
- `CacheRepositoryProtocol`: キャッシュ操作の抽象化
- `MetadataRepositoryProtocol`: メタデータアクセスの抽象化
- `SettingsRepositoryProtocol`: 設定管理の抽象化

#### Day 3-4: 具体実装（メモリキャッシュ）
```swift
// Infrastructure/Repositories/MemoryCacheRepository.swift
public actor MemoryCacheRepository: ImageCacheRepositoryProtocol {
    // 既存のImageCacheをラップ
    private let imageCache: ImageCache
    
    public init(imageCache: ImageCache) {
        self.imageCache = imageCache
    }
}
```

#### Day 5: 既存コードの適応
```swift
// FileSystemPhotoRepositoryを新しいプロトコルに適応
extension FileSystemPhotoRepository: ImageRepositoryProtocol {
    // 既存メソッドをプロトコルに合わせて調整
}
```

### Week 2: ViewModelリファクタリング準備

#### Day 1-2: 新ViewModelの骨組み作成
```bash
# ViewModelファイルの作成
touch SwiftPhotos/Application/ViewModels/ImageGalleryViewModel.swift
touch SwiftPhotos/Application/ViewModels/ImageViewerViewModel.swift
touch SwiftPhotos/Application/ViewModels/SlideshowControlViewModel.swift
touch SwiftPhotos/Application/ViewModels/ImageLoadingViewModel.swift
```

#### Day 3-5: MainCoordinatorViewModel実装
```swift
// 既存のModernSlideshowViewModelと並行して動作
@Observable
@MainActor
public final class MainCoordinatorViewModel {
    // 段階的に機能を移行
}
```

## Phase 2: コア機能の移行（3週間）

### Week 3: 画像読み込み機能の移行

#### タスク:
1. `ImageLoadingViewModel`の完全実装
2. フォルダ選択UIの更新
3. 読み込み進捗表示の改善

#### 成功基準:
- [ ] 既存の読み込み機能が新ViewModelで動作
- [ ] パフォーマンスの劣化なし
- [ ] エラーハンドリングの改善

### Week 4: ギャラリー機能の移行

#### タスク:
1. `ImageGalleryViewModel`の実装
2. グリッド/リスト表示の移行
3. 選択機能の実装

#### 成功基準:
- [ ] 既存のギャラリー機能が維持される
- [ ] 新しいソート/フィルター機能が追加可能

### Week 5: スライドショー機能の移行

#### タスク:
1. `SlideshowControlViewModel`の実装
2. タイマー管理の改善
3. トランジション効果の維持

#### 成功基準:
- [ ] スライドショー機能が正常動作
- [ ] 設定変更が即座に反映

## Phase 3: 高度な機能実装（4週間）

### Week 6-7: キャッシュシステムの強化

#### 実装項目:
1. **DiskCacheRepository**
   ```swift
   // ディスクキャッシュの追加
   public actor DiskCacheRepository: ImageCacheRepositoryProtocol {
       private let cacheDirectory: URL
       private let maxDiskSize: Int64
   }
   ```

2. **キャッシュ戦略の最適化**
   - LRU + サイズベースの削除
   - 非同期プリロード
   - メモリ圧迫時の自動クリーンアップ

### Week 8-9: エラーハンドリングとフィードバック

#### 実装項目:
1. **統一エラータイプ**
   ```swift
   public enum AppError: LocalizedError {
       case imageLoading(ImageLoadingError)
       case fileAccess(FileAccessError)
       case cache(CacheError)
   }
   ```

2. **ユーザーフィードバック改善**
   - 非侵入的なトースト通知
   - リトライ可能なエラーダイアログ
   - 詳細なエラーログ

## Phase 4: テストとドキュメント（2週間）

### Week 10: テスト実装

#### ユニットテスト
```swift
// Tests/ViewModels/ImageGalleryViewModelTests.swift
class ImageGalleryViewModelTests: XCTestCase {
    func testImageLoading() async {
        // Repository のモックを使用
        let mockRepo = MockImageRepository()
        let viewModel = ImageGalleryViewModel(imageRepository: mockRepo)
        
        // テスト実行
    }
}
```

#### 統合テスト
- 画像読み込みフロー全体
- キャッシュ動作
- 設定の永続化

### Week 11: ドキュメント整備

1. **開発者向けドキュメント**
   - アーキテクチャ概要の更新
   - APIリファレンス
   - 移行ガイド

2. **ユーザー向けドキュメント**
   - 新機能の説明
   - トラブルシューティングガイド

## 実装チェックリスト

### 必須タスク 🔴

- [ ] Repository層のプロトコル定義
- [ ] 基本的なRepository実装
- [ ] ViewModelの分割
- [ ] 既存機能の動作確認
- [ ] 基本的なユニットテスト

### 重要タスク 🟡

- [ ] ディスクキャッシュ実装
- [ ] エラーハンドリング統一
- [ ] パフォーマンス最適化
- [ ] 統合テスト
- [ ] ドキュメント更新

### 追加機能 🟢

- [ ] プラグインシステム
- [ ] 高度な編集機能
- [ ] クラウド同期
- [ ] AI機能統合

## リスク管理

### 技術的リスク

1. **パフォーマンス劣化**
   - 対策: 各フェーズでベンチマークテスト実施
   - 基準: 現行版と同等以上のパフォーマンス

2. **メモリリーク**
   - 対策: Instrumentsでの定期的なチェック
   - 弱参照の適切な使用

3. **後方互換性**
   - 対策: 設定ファイルのマイグレーション機能
   - 旧バージョンからのアップグレードテスト

### 対応策

```swift
// 設定マイグレーション例
struct SettingsMigrator {
    static func migrate(from oldVersion: String, to newVersion: String) throws {
        // バージョン別の移行処理
    }
}
```

## 次のステップ

### 今週のタスク

1. **月曜日-火曜日**
   - Repository プロトコルファイルの作成
   - 基本的なプロトコル定義の実装

2. **水曜日-木曜日**
   - MemoryCacheRepository の実装
   - 既存 ImageCache のラップ

3. **金曜日**
   - テストの作成
   - 動作確認

### 来週のタスク

1. **ViewModel骨組みの作成**
2. **依存性注入の設定**
3. **最初の機能移行**

## コマンドリファレンス

### ビルドとテスト

```bash
# プロジェクトのビルド
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" build

# ユニットテストの実行
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" test

# 特定のテストクラスのみ実行
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" \
  -only-testing:SwiftPhotosTests/ImageGalleryViewModelTests test
```

### コード品質チェック

```bash
# SwiftLintでのコードチェック（設定が必要）
swiftlint

# コードカバレッジの確認
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" \
  -enableCodeCoverage YES test
```

## 成功の定義

### 短期目標（3ヶ月）

- ✅ 新アーキテクチャへの移行完了
- ✅ 既存機能の完全な動作保証
- ✅ テストカバレッジ 70%以上
- ✅ パフォーマンスの維持または向上

### 中期目標（6ヶ月）

- 🎯 新機能（編集、整理）の実装
- 🎯 プラグインシステムの基盤
- 🎯 テストカバレッジ 85%以上
- 🎯 ユーザーフィードバックの反映

### 長期目標（1年）

- 🚀 AI機能の統合
- 🚀 クラウド同期機能
- 🚀 プラグインエコシステム
- 🚀 エンタープライズ機能

## まとめ

この実装ロードマップに従うことで、Swift Photosは段階的に新しいアーキテクチャへ移行できます。各フェーズで動作確認とテストを行い、品質を保ちながら進めることが重要です。

定期的な進捗確認と計画の見直しを行い、必要に応じて調整してください。