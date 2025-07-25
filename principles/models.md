# SwiftPhotos プロジェクト構造とモデル詳細

このドキュメントは、SwiftPhotosプロジェクトの完全な構造、クラス、機能を詳細に記述したものです。

## プロジェクト概要

SwiftPhotosは**Clean Architecture**原則に基づいて構築されたmacOSスライドショーアプリケーションです。Swift 6の`@Observable`パターンを使用し、100,000枚以上の写真コレクションを効率的に処理できる高性能アーキテクチャを実装しています。

## アーキテクチャ層構造

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │  SwiftUI Views, MenuBar, Settings UI
├─────────────────────────────────────────┤
│           Application Layer             │  ViewModels, Modern Settings Managers
├─────────────────────────────────────────┤
│           Infrastructure Layer          │  File System, Image Loading, Caching
├─────────────────────────────────────────┤
│              Domain Layer               │  Entities, Value Objects, Repositories
└─────────────────────────────────────────┘
```

## 1. Domain Layer（ドメイン層）

**ディレクトリ**: `SwiftPhotos/Domain/`

### 1.1 Entities（エンティティ）

#### Photo.swift
- **責任**: 写真の状態管理とメタデータ保持
- **主要構造**:
  ```swift
  public struct Photo: Identifiable, Equatable, Sendable {
      public let id: UUID
      public let imageURL: ImageURL
      public private(set) var loadState: LoadState
      public private(set) var metadata: PhotoMetadata?
  }
  ```
- **LoadState列挙型**:
  - `notLoaded`: 未読み込み状態
  - `loading`: 読み込み中
  - `loaded(SendableImage)`: 読み込み完了（画像データ付き）
  - `failed(SlideshowError)`: 読み込み失敗
- **PhotoMetadata構造体**: ファイルサイズ、寸法、作成日、色空間情報

#### Slideshow.swift
- **責任**: スライドショーの中核的な状態とナビゲーション管理
- **主要構造**:
  ```swift
  public struct Slideshow: Equatable {
      public private(set) var photos: [Photo]
      public private(set) var currentIndex: Int
      public private(set) var interval: SlideshowInterval
      public private(set) var mode: SlideshowMode
      public private(set) var state: SlideshowState
  }
  ```
- **SlideshowMode列挙型**:
  - `sequential`: 順次再生
  - `singleLoop`: 単一ループ
- **SlideshowState列挙型**:
  - `stopped`: 停止状態
  - `playing`: 再生中
  - `paused`: 一時停止

### 1.2 Value Objects（バリューオブジェクト）

#### ImageURL.swift
- **責任**: 型安全なURL wrapper with 画像形式バリデーション
- **サポート形式**: jpg, jpeg, png, gif, bmp, tiff, tif, webp, heic, heif
- **バリデーション**: 初期化時に画像形式を検証

#### SlideshowSettings.swift
- **責任**: スライドショー動作の設定管理
- **主要プロパティ**:
  - `slideDuration: Double`: スライド表示時間（1秒〜30分）
  - `autoStart: Bool`: フォルダ選択時の自動開始
  - `randomOrder: Bool`: ランダム順序
  - `loopSlideshow: Bool`: ループ再生
- **プリセット設定**: default, quick, slow, random

#### PerformanceSettings.swift
- **責任**: パフォーマンス設定とメモリ管理
- **スケーラビリティレベル**:
  - **Default**: 0-100枚（メモリウィンドウ: 50）
  - **High Performance**: 101-1,000枚（メモリウィンドウ: 200）
  - **Unlimited**: 1,001-10,000枚（メモリウィンドウ: 1,000）
  - **Massive**: 10,001-50,000枚（メモリウィンドウ: 2,000, 16GB）
  - **Extreme**: 50,001枚以上（メモリウィンドウ: 5,000, 32GB）

#### TransitionSettings.swift
- **責任**: アニメーション効果の設定
- **エフェクトタイプ**: 13種類の効果（fade, slide系, zoom系, rotate系, push系, crossfade）
- **設定項目**: 持続時間、イージング、強度

#### SortSettings.swift
- **責任**: ファイルソート設定
- **ソート順序**: fileName, creationDate, modificationDate, fileSize, random
- **ソート方向**: ascending, descending
- **ランダムシード**: 固定シードによる再現可能なランダム

#### UIControlSettings.swift
- **責任**: UI制御設定
- **自動非表示タイミング**: 再生時2秒、停止時10秒
- **ブラー効果**: 設定可能な透明度とスタイル

### 1.3 Repositories（リポジトリ）

#### SlideshowRepository.swift
- **責任**: データアクセスの抽象インターフェース
- **主要メソッド**:
  - `loadPhotos(from: URL) async throws -> [Photo]`
  - `loadImage(for: Photo) async throws -> Photo`
  - `loadMetadata(for: Photo) async throws -> PhotoMetadata?`

### 1.4 Domain Services

#### SlideshowDomainService.swift
- **責任**: スライドショー作成とプリロード機能
- **主要機能**:
  - スライドショー作成
  - 隣接画像のプリロード（半径2画像）
  - キャッシュ統計取得
  - メタデータ読み込み

## 2. Application Layer（アプリケーション層）

**ディレクトリ**: `SwiftPhotos/Application/`

### 2.1 ViewModels

#### ModernSlideshowViewModel.swift
- **責任**: メインアプリケーション状態の管理
- **パターン**: Swift 6 `@Observable` compliant
- **主要プロパティ**:
  ```swift
  @Observable
  @MainActor
  public final class ModernSlideshowViewModel {
      public private(set) var slideshow: Slideshow?
      public private(set) var currentPhoto: Photo?
      public private(set) var isPlaying: Bool = false
      public private(set) var loadingState: LoadingState = .notLoading
      public var windowLevel: WindowLevel = .normal
  }
  ```
- **特徴**:
  - 100,000枚以上の写真をサポート
  - VirtualImageLoader統合による仮想ローディング
  - BackgroundPreloader統合による高速プリロード
  - `@MainActor`によるスレッドセーフ操作

### 2.2 Modern Settings Managers

#### ModernSettingsManagers.swift
包括的な設定管理システム：

##### ModernPerformanceSettingsManager
- **責任**: メモリ管理とパフォーマンス設定
- **機能**: コレクションサイズに応じた推奨設定、メモリ使用量推定
- **永続化**: UserDefaults with JSON encoding

##### ModernSlideshowSettingsManager
- **責任**: タイミングと再生設定
- **通知**: 設定変更時のNotificationCenter通知
- **プリセット**: デフォルト設定へのリセット機能

##### ModernSortSettingsManager
- **責任**: ファイルソート設定
- **ランダム機能**: シード再生成による新しいランダム順序
- **通知**: ソート設定変更の通知

##### ModernTransitionSettingsManager
- **責任**: アニメーション効果設定
- **リアルタイム更新**: 設定変更時の即座な効果反映
- **プリセット**: 複数の事前定義済み効果設定

##### ModernUIControlSettingsManager
- **責任**: UI制御設定
- **プリセット**: default, minimal, always-visible, subtle
- **カスタマイズ**: ブラー効果、透明度、自動非表示タイミング

### 2.3 Services

#### UIControlStateManager.swift
- **責任**: UI制御の状態管理
- **機能**:
  - 自動非表示ロジック
  - マウス境界検出
  - キーボード操作コールバック
  - 詳細情報表示制御

#### KeyboardHandler.swift
- **責任**: キーボードショートカット処理
- **サポートショートカット**:
  - Space: 再生/一時停止
  - 矢印キー: ナビゲーション
  - I: 詳細情報切り替え
  - H: コントロール表示切り替え
  - Cmd+,: 設定ウィンドウ
  - Escape: フルスクリーン切り替え

#### RecentFilesManager.swift
- **責任**: 最近使用したファイル管理
- **セキュリティ**: Security bookmark integration
- **永続化**: SecureRecentFilesRepository使用

## 3. Infrastructure Layer（インフラストラクチャ層）

**ディレクトリ**: `SwiftPhotos/Infrastructure/`

### 3.1 Repositories

#### FileSystemPhotoRepository.swift
- **責任**: ファイルシステムからの写真読み込み
- **依存関係**: SecureFileAccess, ImageLoader, ModernSortSettingsManager
- **ソート機能**: 
  - ファイル名順（自然順序比較）
  - 作成日時順
  - 変更日時順
  - ファイルサイズ順
  - ランダム（固定シード）

#### SecureRecentFilesRepository.swift
- **責任**: セキュアな最近使用ファイル管理
- **セキュリティ**: Security-scoped resource management
- **永続化**: UserDefaults with security bookmark

### 3.2 Core Services

#### ImageLoader.swift
- **パターン**: Actor-based concurrent loading
- **最適化**:
  - CGImageSource thumbnail generation
  - Configurable concurrent operations (1-50)
  - Memory-efficient loading with size limits

#### SecureFileAccess.swift
- **責任**: macOS sandboxing対応のファイルアクセス
- **機能**:
  - Security-scoped resource management
  - Bookmark data persistence
  - NSOpenPanel統合
  - Permission validation

### 3.3 高性能キャッシュシステム

#### VirtualImageLoader.swift
- **パターン**: Sliding window loading for unlimited scalability
- **アルゴリズム**:
  - Distance-based priority loading
  - Dynamic window sizing based on collection size
  - Task groups with cancellation support
- **パフォーマンス指標**:
  ```swift
  // スライディングウィンドウサイズの計算
  private func calculateEffectiveWindowSize(collectionSize: Int) -> Int {
      switch collectionSize {
      case 0...100: return min(windowSize, collectionSize)
      case 101...1000: return min(windowSize, max(50, collectionSize / 10))
      case 1001...10000: return min(windowSize, max(100, collectionSize / 50))
      default: return max(200, min(windowSize, collectionSize / 100))
      }
  }
  ```

#### ImageCache.swift
- **実装**: NSCache-based primary cache
- **機能**: Cost-based eviction, hit/miss statistics
- **制限**: Configurable count and memory limits

#### LRUImageCache.swift
- **実装**: Least-recently-used cache
- **特徴**: Predictable memory management, thread-safe operations

#### BackgroundPreloader.swift
- **責任**: Priority queue based preloading
- **最適化**: Adjacent image preloading with distance-based priority
- **並行処理**: Configurable concurrent preload operations

### 3.4 Utils

#### SendableImage.swift
- **責任**: Thread-safe NSImage wrapper
- **実装**: `@unchecked Sendable` conformance for cross-actor usage
- **プロパティ**: NSImage reference, size information

#### ProductionLogger.swift
- **責任**: Production-ready logging system
- **レベル**: lifecycle, debug, info, warning, error, userAction, performance
- **実装**: os.log integration with categorized subsystems

#### WindowAccessor.swift
- **責任**: NSWindow access utilities
- **機能**: Window level control, fullscreen management

## 4. Presentation Layer（プレゼンテーション層）

**ディレクトリ**: `SwiftPhotos/Presentation/`

### 4.1 Main Views

#### ContentView.swift
- **責任**: アプリケーションのメインUI統合
- **初期化フロー**:
  1. 非同期コンポーネント初期化
  2. 依存関係注入
  3. UI状態管理セットアップ
- **統合コンポーネント**:
  - ModernSlideshowViewModel
  - すべてのModern*Settings managers
  - UIControlStateManager
  - KeyboardHandler

#### MinimalControlsView.swift
- **デザイン**: Bottom-center minimal controls with blur background
- **機能**:
  - 再生/一時停止制御
  - 前/次ナビゲーション
  - プログレスバー表示
  - Hover reveal interaction
- **自動非表示**: 設定可能なタイムアウト

#### DetailedInfoOverlay.swift
- **責任**: 詳細情報表示
- **情報項目**:
  - ファイル名
  - ファイルサイズ
  - 画像寸法
  - 作成日時
  - EXIF データ（可能な場合）

#### SimpleImageDisplayView.swift
- **責任**: 画像表示とカーソル制御
- **機能**:
  - AspectRatio保持の画像表示
  - ホバー時のカーソル制御
  - Transition effects integration

### 4.2 Settings Views

**ディレクトリ**: `SwiftPhotos/Presentation/Views/Settings/`

#### PerformanceSettingsView.swift
- **設定項目**:
  - メモリウィンドウサイズ
  - 最大並行読み込み数
  - キャッシュサイズ制限
  - メモリ使用量制限
- **プリセット**: Default, High Performance, Unlimited, Massive, Extreme

#### SlideshowSettingsView.swift
- **設定項目**:
  - スライド持続時間（カスタムスライダー）
  - 自動開始オプション
  - ランダム順序切り替え
  - ループ再生設定
- **プリセット**: Default, Quick, Slow, Random

#### SortSettingsView.swift
- **設定項目**:
  - ソート順序選択
  - ソート方向（昇順/降順）
  - ランダムシード管理
- **プリセット**: Alphabetical, Chronological, Newest First, Largest First, Randomized

#### TransitionSettingsView.swift
- **設定項目**:
  - エフェクトタイプ（13種類）
  - 持続時間設定
  - イージング方式
  - 効果強度
- **プリセット**: Instant, Quick, Smooth, Dramatic

### 4.3 Menu Integration

#### SwiftPhotosMenuBar.swift
- **責任**: SwiftUI Commands integration
- **メニュー構造**:
  - **File Menu**: Open Folder, Add Photos, Recent Files
  - **View Menu**: Fullscreen Toggle, Window Level Control
  - **Window Menu**: Settings, Minimize, Zoom
- **Recent Files**: セキュリティブックマーク管理付き
- **Window Level**: Normal, Floating, Modal Panel, Dock, Desktop Background

### 4.4 Extensions

#### CursorControlModifiers.swift
- **責任**: SwiftUI View modifiers for cursor control
- **機能**:
  - ホバー時のカーソル表示/非表示
  - カスタムカーソル設定
  - 画像境界内でのカーソル制御

## 主要設計パターン

### 1. Repository Pattern
```swift
// Domain layer: Abstract interface
public protocol SlideshowRepository {
    func loadPhotos(from folderURL: URL) async throws -> [Photo]
}

// Infrastructure layer: Concrete implementation
public class FileSystemPhotoRepository: SlideshowRepository {
    // Implementation details
}
```

### 2. Observer Pattern
- Settings managers use `@Published` properties for SwiftUI reactivity
- NotificationCenter for cross-component communication
- Virtual loader callbacks for UI integration

### 3. Actor Pattern
```swift
// Thread-safe concurrent operations
actor VirtualImageLoader {
    // Sliding window management
}

actor ImageLoader {
    // Concurrent image loading
}
```

### 4. Dependency Injection
```swift
// Constructor injection pattern
public init(
    domainService: SlideshowDomainService,
    fileAccess: SecureFileAccess,
    performanceSettings: ModernPerformanceSettingsManager,
    slideshowSettings: ModernSlideshowSettingsManager,
    sortSettings: ModernSortSettingsManager
) {
    // Dependency setup
}
```

## パフォーマンス最適化

### メモリ管理戦略
1. **Multi-tier Caching System**:
   - ImageCache (NSCache-based)
   - LRUImageCache (predictable eviction)
   - VirtualImageLoader (sliding window)

2. **Adaptive Window Sizing**:
   - コレクションサイズに応じた動的ウィンドウサイズ
   - メモリ圧迫時の自動クリーンアップ
   - Distance-based priority loading

### 並行処理最適化
- **Configurable Concurrency**: 1-50 concurrent operations
- **Task Cancellation**: ウィンドウ外画像の読み込みキャンセル
- **Priority Queues**: 中心から外側への優先度ベース読み込み

### メモリ使用量推定
```swift
public func estimatedMemoryUsage(for collectionSize: Int) -> Int {
    let bytesPerPixel = 4 // RGBA
    let bytesPerImage = Int(averageImageSize.width * averageImageSize.height) * bytesPerPixel
    let effectiveWindowSize = min(settings.memoryWindowSize, collectionSize)
    return (effectiveWindowSize * bytesPerImage) / (1024 * 1024) // MB
}
```

## Swift 6対応

### Modern Architecture
- **@Observable Pattern**: `@ObservableObject`からの移行
- **@MainActor Isolation**: UI操作のスレッドセーフ保証
- **@unchecked Sendable**: Actor間でのデータ転送

### Sendable Compliance
```swift
public struct SendableImage: @unchecked Sendable {
    public let nsImage: NSImage
    public let size: CGSize
}

extension ModernSlideshowViewModel: @unchecked Sendable {}
```

## セキュリティ機能

### macOS Sandboxing
- **Security-scoped Resource Access**: フォルダへのアクセス権限管理
- **Bookmark Data Persistence**: アクセス権限の永続化
- **Permission Validation**: ファイルアクセス前の権限確認

### Recent Files Security
```swift
// Security bookmark creation
let bookmarkData = try url.bookmarkData(
    options: [.withSecurityScope],
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)
```

## エラーハンドリング

### カスタムエラータイプ
```swift
public enum SlideshowError: Error, LocalizedError, Equatable, Sendable {
    case invalidImageFormat(String)
    case fileNotFound(URL)
    case loadingFailed(underlying: Error)
    case invalidInterval(Double)
    case invalidIndex(Int)
    case securityError(String)
    case noPhotosFound
    case accessDenied(URL)
    case invalidSettings(reason: String)
    case memoryWarning
}
```

## ファイル構成総覧

### Domain Layer
```
Domain/
├── Entities/
│   ├── Photo.swift                 # 写真エンティティと状態管理
│   └── Slideshow.swift            # スライドショーエンティティ
├── Repositories/
│   └── SlideshowRepository.swift  # データアクセス抽象インターフェース
├── Services/
│   ├── InteractionProtocols.swift  # インタラクションプロトコル
│   ├── RecentFilesService.swift    # 最近使用ファイルサービス
│   ├── SettingsCategoryService.swift # 設定カテゴリサービス
│   └── SlideshowDomainService.swift  # スライドショードメインサービス
└── ValueObjects/
    ├── ImageURL.swift              # 型安全URL wrapper
    ├── InteractionTypes.swift      # インタラクションタイプ定義
    ├── MenuConfiguration.swift     # メニュー設定
    ├── PerformanceSettings.swift   # パフォーマンス設定
    ├── PhotoZoomState.swift        # 写真ズーム状態
    ├── RecentFileItem.swift        # 最近使用ファイル項目
    ├── SettingsCategory.swift      # 設定カテゴリ
    ├── SettingsSection.swift       # 設定セクション
    ├── SlideshowInterval.swift     # スライドショー間隔
    ├── SlideshowSettings.swift     # スライドショー設定
    ├── SortSettings.swift          # ソート設定
    ├── TransitionSettings.swift    # トランジション設定
    ├── UIControlSettings.swift     # UI制御設定
    └── WindowLevel.swift           # ウィンドウレベル
```

### Application Layer
```
Application/
├── Services/
│   ├── AdvancedGestureManager.swift     # 高度なジェスチャー管理
│   ├── AppSettingsCoordinator.swift     # アプリ設定統合
│   ├── BlurEffectIntegration.swift      # ブラー効果統合
│   ├── BlurEffectManager.swift          # ブラー効果管理
│   ├── GestureAnimationController.swift # ジェスチャーアニメーション
│   ├── GestureCoordinator.swift         # ジェスチャー統合
│   ├── ImageTransitionManager.swift     # 画像トランジション管理
│   ├── InteractionZoneManager.swift     # インタラクションゾーン管理
│   ├── KeyboardHandler.swift            # キーボード処理
│   ├── MenuBarCoordinator.swift         # メニューバー統合
│   ├── ModernSettingsManagers.swift     # モダン設定管理
│   ├── OverlayPositionManager.swift     # オーバーレイ位置管理
│   ├── PositionUtilities.swift          # 位置計算ユーティリティ
│   ├── PositioningStrategies.swift      # 位置決め戦略
│   ├── RecentFilesManager.swift         # 最近使用ファイル管理
│   ├── SettingsWindowManager.swift      # 設定ウィンドウ管理
│   └── UIControlStateManager.swift      # UI制御状態管理
└── ViewModels/
    ├── ModernSlideshowViewModel.swift   # メインViewModel（Swift 6対応）
    └── SlideshowViewModel.swift         # レガシーViewModel（非推奨）
```

### Infrastructure Layer
```
Infrastructure/
├── Repositories/
│   ├── FileSystemPhotoRepository.swift      # ファイルシステムリポジトリ
│   └── SecureRecentFilesRepository.swift    # セキュア最近ファイルリポジトリ
├── Services/
│   ├── AdaptiveTimer.swift              # 適応タイマー
│   ├── BackgroundPreloader.swift       # バックグラウンドプリローダー
│   ├── CursorManager.swift              # カーソル管理
│   ├── ImageCache.swift                 # 画像キャッシュ
│   ├── ImageLoader.swift                # 画像ローダー
│   ├── InteractionDetector.swift        # インタラクション検出
│   ├── LRUImageCache.swift              # LRU画像キャッシュ
│   ├── MouseTracker.swift               # マウストラッカー
│   ├── SecureFileAccess.swift           # セキュアファイルアクセス
│   ├── TargetImageLoader.swift          # ターゲット画像ローダー
│   └── VirtualImageLoader.swift         # 仮想画像ローダー
└── Utils/
    ├── ProductionLogger.swift           # プロダクションログ
    ├── SendableImage.swift              # Sendable画像wrapper
    ├── SwiftPhotosLogger.swift          # アプリ専用ログ
    └── WindowAccessor.swift             # ウィンドウアクセサー
```

### Presentation Layer
```
Presentation/
├── Extensions/
│   ├── CursorControlModifiers.swift     # カーソル制御モディファイア
│   └── TrackingAreaView.swift           # トラッキングエリアView
├── MenuBar/
│   └── SwiftPhotosMenuBar.swift         # メニューバー統合
└── Views/
    ├── BlurEffectViews.swift            # ブラー効果Views
    ├── ControlsView.swift               # コントロールView
    ├── DetailedInfoOverlay.swift        # 詳細情報オーバーレイ
    ├── ImageDisplayView.swift           # 画像表示View
    ├── ImageDisplayViewWithObserver.swift # オブザーバー付き画像表示
    ├── MinimalControlsView.swift        # ミニマルコントロール
    ├── OverlayPositionCoordinator.swift # オーバーレイ位置統合
    ├── Settings/
    │   ├── AdvancedSettingsView.swift       # 高度設定View
    │   ├── FileManagementSettingsView.swift # ファイル管理設定
    │   ├── InterfaceSettingsView.swift      # インターフェース設定
    │   ├── KeyboardShortcutsView.swift      # キーボードショートカット
    │   ├── PerformanceSettingsView.swift    # パフォーマンス設定
    │   ├── SlideshowSettingsView.swift      # スライドショー設定
    │   ├── SortSettingsView.swift           # ソート設定
    │   └── TransitionSettingsView.swift     # トランジション設定
    ├── SidebarSettingsWindow.swift     # サイドバー設定ウィンドウ
    ├── SimpleImageDisplayView.swift     # シンプル画像表示
    ├── SimpleInteractionZoneView.swift  # シンプルインタラクションゾーン
    └── TooltipView.swift                # ツールチップView
```

## まとめ

SwiftPhotosは、真のClean Architectureを実装した現代的なmacOSアプリケーションです。以下の特徴により、スケーラブルで保守可能な高性能アプリケーションを実現しています：

### 主要特徴
1. **無制限スケーラビリティ**: 100,000枚以上の写真コレクション対応
2. **高性能キャッシュ**: Multi-tier caching + virtual loading
3. **モダンSwift**: Swift 6完全対応、@Observableパターン
4. **セキュリティ**: macOS sandboxing完全対応
5. **拡張性**: Plugin-ready architecture
6. **保守性**: Clear separation of concerns

### アーキテクチャの利点
- **テスタビリティ**: 各層が独立してテスト可能
- **拡張性**: 新機能の追加が既存コードに影響しない
- **保守性**: 責任の明確な分離により変更の影響範囲が限定される
- **パフォーマンス**: 最適化された並行処理とメモリ管理
- **再利用性**: 各コンポーネントが独立して再利用可能

このアーキテクチャにより、大規模な写真コレクションでも高性能を維持しながら、モダンなmacOSアプリケーションとしての要件を満たす、プロフェッショナルグレードのスライドショーアプリケーションを実現しています。