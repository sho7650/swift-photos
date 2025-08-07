# Swift Photos アーキテクチャ移行計画書

## 概要

現行のSwift Photosアプリケーションを、新しいアーキテクチャ仕様（MVVM + Repository パターン）へ段階的に移行する計画です。現在の機能を維持しながら、アーキテクチャの改善と新機能の追加を行います。

## 現状分析

### 現行アーキテクチャの強み

1. **Clean Architecture原則の採用済み**
   - 明確なレイヤー分離（Domain, Application, Infrastructure, Presentation）
   - 依存性の方向が適切に制御されている

2. **Swift 6準拠**
   - `@Observable`パターンの採用済み（ModernSlideshowViewModel）
   - Actor-basedの並行処理（VirtualImageLoader, ImageCache）

3. **高度なパフォーマンス最適化**
   - 100k+画像対応の仮想ローディングシステム
   - 多層キャッシュシステム（ImageCache, LRUImageCache）
   - 動的メモリ管理

### 改善が必要な領域

1. **Repository層の抽象化**
   - 現在は`SlideshowRepository`のみ定義
   - キャッシュ、メタデータ用のRepositoryインターフェース未定義

2. **ViewModelの責務整理**
   - 一部のViewModelが大きすぎる（ModernSlideshowViewModel: 700行以上）
   - ビジネスロジックとプレゼンテーションロジックの混在

3. **エラーハンドリング**
   - エラータイプの統一化が不完全
   - ユーザーフィードバックの一貫性

4. **テスト戦略**
   - ユニットテストが不足
   - 統合テスト・UIテストの未実装

## 移行フェーズ

### フェーズ1: Repository層の強化（2週間）

#### 1.1 Repository抽象化
```swift
// Domain/Repositories/
- ImageRepositoryProtocol.swift  # 新規
- CacheRepositoryProtocol.swift  # 新規
- MetadataRepositoryProtocol.swift  # 新規
- SettingsRepositoryProtocol.swift  # 新規
```

#### 1.2 具体実装
```swift
// Infrastructure/Repositories/
- LocalImageRepository.swift  # FileSystemPhotoRepositoryを分割
- MemoryCacheRepository.swift  # ImageCacheの抽象化
- DiskCacheRepository.swift  # 新規：永続キャッシュ
- ImageMetadataRepository.swift  # メタデータ専用
```

#### 1.3 既存コードのリファクタリング
- `FileSystemPhotoRepository`を新しいRepository構造に分割
- 依存性注入の改善

### フェーズ2: ViewModel層のリファクタリング（3週間）

#### 2.1 ViewModelの分割
```swift
// Application/ViewModels/
- ImageGalleryViewModel.swift  # グリッド/リスト表示専用
- ImageViewerViewModel.swift  # 単一画像表示専用
- SlideshowControlViewModel.swift  # スライドショー制御
- ImageLoadingViewModel.swift  # 画像読み込み状態管理
```

#### 2.2 ビジネスロジックの移動
- ViewModelからDomain層のUseCaseへ移動
- プレゼンテーションロジックとビジネスロジックの分離

#### 2.3 状態管理の改善
- グローバル状態用のEnvironment Object定義
- ViewModelの責務明確化

### フェーズ3: エラーハンドリングとフィードバック（1週間）

#### 3.1 統一エラータイプ定義
```swift
// Domain/Errors/
- AppError.swift  # 統一エラータイプ
- ErrorMapper.swift  # エラー変換ユーティリティ
```

#### 3.2 ユーザーフィードバック改善
- 非侵入的アラートシステム
- リトライ機能の実装
- エラーログの強化

### フェーズ4: パフォーマンス最適化（2週間）

#### 4.1 キャッシュシステムの改善
- ディスクキャッシュの追加
- キャッシュ戦略の最適化
- メモリ圧迫時の動作改善

#### 4.2 画像読み込みの最適化
- プログレッシブローディングの実装
- サムネイル事前生成
- ダウンサンプリングの改善

### フェーズ5: テスト基盤の構築（3週間）

#### 5.1 ユニットテスト
```swift
// SwiftPhotosTests/
- ViewModels/
- Repositories/
- Services/
- UseCases/
```

#### 5.2 統合テスト
- 画像読み込みフロー
- キャッシュ動作
- 設定の永続化

#### 5.3 UIテスト
- 主要ユーザーフロー
- ジェスチャー操作
- キーボードショートカット

### フェーズ6: 新機能実装（4週間）

#### 6.1 基本編集機能
- 回転/反転
- クロップ
- 基本的な画像調整

#### 6.2 整理機能
- フォルダー管理
- タグ付け
- お気に入り
- 検索/フィルタリング

#### 6.3 共有機能
- システム共有シート統合
- エクスポート機能
- メタデータ保持

### フェーズ7: アクセシビリティとローカライゼーション（2週間）

#### 7.1 VoiceOver対応
- 適切なラベル付け
- 画像説明の提供
- カスタムアクション

#### 7.2 キーボード完全対応
- すべての機能へのアクセス
- フォーカス管理
- ショートカット一覧

#### 7.3 ローカライゼーション拡充
- 追加言語サポート
- 地域別フォーマット

### フェーズ8: プラグインアーキテクチャ（3週間）

#### 8.1 プラグインインターフェース定義
```swift
// Domain/Plugins/
- PluginProtocol.swift
- FilterPlugin.swift
- ExportPlugin.swift
- MetadataPlugin.swift
```

#### 8.2 プラグインマネージャー
- プラグインの検出と読み込み
- ライフサイクル管理
- 設定管理

## 実装詳細

### Repository層の実装例

```swift
// Domain/Repositories/ImageRepositoryProtocol.swift
public protocol ImageRepositoryProtocol {
    func loadImage(from url: URL) async throws -> SendableImage
    func loadImages(from folder: URL) async throws -> [ImageURL]
    func loadMetadata(for url: URL) async throws -> ImageMetadata
}

// Infrastructure/Repositories/LocalImageRepository.swift
public actor LocalImageRepository: ImageRepositoryProtocol {
    private let fileAccess: SecureFileAccess
    private let imageLoader: ImageLoader
    
    public func loadImage(from url: URL) async throws -> SendableImage {
        // 実装
    }
}
```

### ViewModelの分割例

```swift
// Application/ViewModels/ImageGalleryViewModel.swift
@Observable
@MainActor
public final class ImageGalleryViewModel {
    // グリッド表示専用のプロパティとメソッド
    public var images: [Photo] = []
    public var selectedImages: Set<Photo.ID> = []
    public var viewMode: ViewMode = .grid
    
    private let imageRepository: ImageRepositoryProtocol
    private let cacheRepository: CacheRepositoryProtocol
    
    public func loadImages(from folder: URL) async throws {
        // 実装
    }
}
```

### エラーハンドリングの統一

```swift
// Domain/Errors/AppError.swift
public enum AppError: LocalizedError {
    case fileAccess(underlying: Error)
    case imageLoading(url: URL, reason: String)
    case cacheFailure(reason: String)
    case networkError(underlying: Error)
    case unsupportedFormat(format: String)
    
    public var errorDescription: String? {
        // ローカライズされたエラーメッセージ
    }
    
    public var recoverySuggestion: String? {
        // リカバリー提案
    }
}
```

## リスク管理

### 技術的リスク

1. **後方互換性**
   - 既存の設定ファイルとの互換性維持
   - 移行スクリプトの提供

2. **パフォーマンス**
   - リファクタリング中のパフォーマンス低下防止
   - 段階的な最適化

3. **メモリ管理**
   - 新しいキャッシュシステムのメモリ使用量監視
   - メモリリークの防止

### 軽減策

1. **段階的移行**
   - 機能単位での移行
   - フィーチャーフラグの使用

2. **徹底的なテスト**
   - 各フェーズでの回帰テスト
   - パフォーマンステスト

3. **ロールバック計画**
   - 各フェーズでのロールバック手順
   - バックアップとリストア

## 成果指標

### パフォーマンス指標

- 起動時間: 現状維持または改善
- 画像読み込み速度: 20%向上
- メモリ使用量: 現状維持
- キャッシュヒット率: 90%以上

### コード品質指標

- テストカバレッジ: 80%以上
- 循環的複雑度: 10以下
- コード重複: 5%以下

### ユーザビリティ指標

- アクセシビリティスコア: 100%
- キーボード操作可能機能: 100%
- エラーからの復旧成功率: 95%以上

## 実装スケジュール

| フェーズ | 期間 | 開始日 | 終了日 |
|---------|------|--------|--------|
| フェーズ1: Repository層 | 2週間 | 2025/02/01 | 2025/02/14 |
| フェーズ2: ViewModel層 | 3週間 | 2025/02/15 | 2025/03/07 |
| フェーズ3: エラーハンドリング | 1週間 | 2025/03/08 | 2025/03/14 |
| フェーズ4: パフォーマンス | 2週間 | 2025/03/15 | 2025/03/28 |
| フェーズ5: テスト基盤 | 3週間 | 2025/03/29 | 2025/04/18 |
| フェーズ6: 新機能 | 4週間 | 2025/04/19 | 2025/05/16 |
| フェーズ7: アクセシビリティ | 2週間 | 2025/05/17 | 2025/05/30 |
| フェーズ8: プラグイン | 3週間 | 2025/05/31 | 2025/06/20 |

## 移行チェックリスト

### 事前準備
- [ ] 現在のコードベースの完全バックアップ
- [ ] 既存機能の詳細ドキュメント作成
- [ ] パフォーマンスベースラインの測定
- [ ] 移行用ブランチの作成

### 各フェーズ共通
- [ ] 設計レビューの実施
- [ ] 実装レビューの実施
- [ ] ユニットテストの作成
- [ ] 統合テストの実行
- [ ] パフォーマンステスト
- [ ] ドキュメントの更新

### 完了条件
- [ ] すべてのテストが成功
- [ ] パフォーマンス指標の達成
- [ ] コード品質指標の達成
- [ ] ユーザビリティ指標の達成
- [ ] ドキュメントの完成

## 結論

この移行計画により、Swift Photosは現在の機能を維持しながら、より保守性が高く、拡張可能で、パフォーマンスに優れたアーキテクチャへと進化します。段階的な移行アプローチにより、リスクを最小限に抑えながら、継続的な改善を実現します。