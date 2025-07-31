# ViewModel層リファクタリングガイド

## 概要

現在のModernSlideshowViewModelは700行以上のコードを含み、多くの責務を担っています。このドキュメントでは、ViewModelを適切に分割し、単一責任の原則に従った設計にリファクタリングする方法を説明します。

## 現状の問題点

### ModernSlideshowViewModelの責務（現状）

1. **画像管理**: 画像の読み込み、キャッシュ、仮想ローディング
2. **スライドショー制御**: 再生/停止、ナビゲーション、タイマー管理
3. **設定管理**: 各種設定の読み込み、保存、通知処理
4. **UI状態管理**: ローディング状態、エラー表示、ウィンドウレベル
5. **イベント処理**: キーボード、マウス、メニューイベント
6. **統計情報**: キャッシュ統計、パフォーマンスメトリクス

### 問題点

- **責務過多**: 単一のViewModelが多すぎる責任を持っている
- **テスタビリティ**: 大きすぎるクラスはテストが困難
- **保守性**: 変更の影響範囲が広すぎる
- **再利用性**: 機能単位での再利用が困難

## 新しいViewModel構成

### 1. コアViewModels

#### 1.1 ImageGalleryViewModel

```swift
// Application/ViewModels/ImageGalleryViewModel.swift
import Foundation
import SwiftUI
import Observation

/// 画像ギャラリー表示専用のViewModel
@Observable
@MainActor
public final class ImageGalleryViewModel {
    // MARK: - State
    public private(set) var images: [Photo] = []
    public private(set) var selectedImageIDs: Set<Photo.ID> = []
    public private(set) var viewMode: ViewMode = .grid
    public private(set) var sortOrder: SortOrder = .name
    public private(set) var filterCriteria: FilterCriteria?
    
    // MARK: - Computed Properties
    public var displayedImages: [Photo] {
        var result = images
        
        // フィルタリング
        if let filter = filterCriteria {
            result = result.filter { photo in
                filter.matches(photo)
            }
        }
        
        // ソート
        result.sort(by: sortOrder.comparator)
        
        return result
    }
    
    public var hasSelection: Bool {
        !selectedImageIDs.isEmpty
    }
    
    // MARK: - Dependencies
    private let imageRepository: ImageRepositoryProtocol
    private let cacheRepository: ImageCacheRepositoryProtocol
    private let sortSettings: SortSettings
    
    // MARK: - Initialization
    public init(
        imageRepository: ImageRepositoryProtocol,
        cacheRepository: ImageCacheRepositoryProtocol,
        sortSettings: SortSettings
    ) {
        self.imageRepository = imageRepository
        self.cacheRepository = cacheRepository
        self.sortSettings = sortSettings
    }
    
    // MARK: - Public Methods
    public func loadImages(from folder: URL) async throws {
        let imageURLs = try await imageRepository.loadImageURLs(from: folder)
        self.images = imageURLs.map { Photo(imageURL: $0) }
    }
    
    public func selectImage(_ photo: Photo) {
        if selectedImageIDs.contains(photo.id) {
            selectedImageIDs.remove(photo.id)
        } else {
            selectedImageIDs.insert(photo.id)
        }
    }
    
    public func selectAll() {
        selectedImageIDs = Set(images.map { $0.id })
    }
    
    public func deselectAll() {
        selectedImageIDs.removeAll()
    }
    
    public func setViewMode(_ mode: ViewMode) {
        self.viewMode = mode
    }
    
    public func setSortOrder(_ order: SortOrder) {
        self.sortOrder = order
    }
    
    public func setFilter(_ criteria: FilterCriteria?) {
        self.filterCriteria = criteria
    }
}

// MARK: - Supporting Types
public enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    case columns = "Columns"
}

public enum SortOrder: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case type = "Type"
    
    var comparator: (Photo, Photo) -> Bool {
        switch self {
        case .name:
            return { $0.displayName < $1.displayName }
        case .date:
            return { $0.imageURL.creationDate ?? Date() < $1.imageURL.creationDate ?? Date() }
        case .size:
            return { $0.fileSize < $1.fileSize }
        case .type:
            return { $0.imageURL.url.pathExtension < $1.imageURL.url.pathExtension }
        }
    }
}

public struct FilterCriteria {
    public let searchText: String?
    public let dateRange: ClosedRange<Date>?
    public let sizeRange: ClosedRange<Int64>?
    public let fileTypes: Set<String>?
    
    func matches(_ photo: Photo) -> Bool {
        // フィルタリングロジック
        if let searchText = searchText,
           !photo.displayName.localizedCaseInsensitiveContains(searchText) {
            return false
        }
        
        // 他の条件チェック...
        return true
    }
}
```

#### 1.2 ImageViewerViewModel

```swift
// Application/ViewModels/ImageViewerViewModel.swift
import Foundation
import SwiftUI
import Observation

/// 単一画像表示専用のViewModel
@Observable
@MainActor
public final class ImageViewerViewModel {
    // MARK: - State
    public private(set) var currentPhoto: Photo?
    public private(set) var currentImage: SendableImage?
    public private(set) var zoomLevel: CGFloat = 1.0
    public private(set) var rotation: Angle = .zero
    public private(set) var isLoading = false
    public private(set) var loadError: Error?
    public private(set) var metadata: ImageMetadata?
    
    // MARK: - Computed Properties
    public var canZoomIn: Bool {
        zoomLevel < maxZoomLevel
    }
    
    public var canZoomOut: Bool {
        zoomLevel > minZoomLevel
    }
    
    public var isImageLoaded: Bool {
        currentImage != nil
    }
    
    // MARK: - Constants
    private let minZoomLevel: CGFloat = 0.1
    private let maxZoomLevel: CGFloat = 10.0
    private let zoomStep: CGFloat = 0.25
    
    // MARK: - Dependencies
    private let imageRepository: ImageRepositoryProtocol
    private let cacheRepository: ImageCacheRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol
    
    // MARK: - Initialization
    public init(
        imageRepository: ImageRepositoryProtocol,
        cacheRepository: ImageCacheRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.imageRepository = imageRepository
        self.cacheRepository = cacheRepository
        self.metadataRepository = metadataRepository
    }
    
    // MARK: - Public Methods
    public func loadPhoto(_ photo: Photo) async {
        guard photo.id != currentPhoto?.id else { return }
        
        currentPhoto = photo
        isLoading = true
        loadError = nil
        
        do {
            // キャッシュチェック
            let cacheKey = ImageCacheKey(
                url: photo.imageURL.url,
                size: nil,
                quality: .full
            )
            
            if let cachedImage = await cacheRepository.get(cacheKey) {
                currentImage = cachedImage
                isLoading = false
                
                // メタデータを非同期で読み込み
                Task {
                    await loadMetadata(for: photo)
                }
                return
            }
            
            // キャッシュになければ読み込み
            let image = try await imageRepository.loadImage(from: photo.imageURL.url)
            currentImage = image
            
            // キャッシュに保存
            await cacheRepository.set(image, for: cacheKey, cost: nil)
            
            // メタデータ読み込み
            await loadMetadata(for: photo)
            
        } catch {
            loadError = error
            ProductionLogger.error("Failed to load photo: \(error)")
        }
        
        isLoading = false
    }
    
    public func zoomIn() {
        let newZoom = min(zoomLevel + zoomStep, maxZoomLevel)
        setZoom(newZoom)
    }
    
    public func zoomOut() {
        let newZoom = max(zoomLevel - zoomStep, minZoomLevel)
        setZoom(newZoom)
    }
    
    public func setZoom(_ level: CGFloat) {
        zoomLevel = max(minZoomLevel, min(level, maxZoomLevel))
    }
    
    public func resetZoom() {
        zoomLevel = 1.0
    }
    
    public func rotate(by angle: Angle) {
        rotation = rotation + angle
    }
    
    public func resetRotation() {
        rotation = .zero
    }
    
    public func fitToWindow() {
        // ウィンドウサイズに合わせたズームレベルを計算
        zoomLevel = 1.0 // 実際の計算はViewで行う
    }
    
    // MARK: - Private Methods
    private func loadMetadata(for photo: Photo) async {
        do {
            metadata = try await metadataRepository.loadAllMetadata(for: photo.imageURL.url)
        } catch {
            ProductionLogger.warning("Failed to load metadata: \(error)")
        }
    }
}
```

#### 1.3 SlideshowControlViewModel

```swift
// Application/ViewModels/SlideshowControlViewModel.swift
import Foundation
import SwiftUI
import Observation

/// スライドショー制御専用のViewModel
@Observable
@MainActor
public final class SlideshowControlViewModel {
    // MARK: - State
    public private(set) var isPlaying = false
    public private(set) var currentIndex = 0
    public private(set) var playbackSpeed: PlaybackSpeed = .normal
    public private(set) var repeatMode: RepeatMode = .loop
    public private(set) var shuffleEnabled = false
    
    // MARK: - Computed Properties
    public var canGoNext: Bool {
        guard !photos.isEmpty else { return false }
        return currentIndex < photos.count - 1 || repeatMode != .none
    }
    
    public var canGoPrevious: Bool {
        guard !photos.isEmpty else { return false }
        return currentIndex > 0 || repeatMode != .none
    }
    
    public var progress: Double {
        guard !photos.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(photos.count)
    }
    
    public var currentPhoto: Photo? {
        guard photos.indices.contains(currentIndex) else { return nil }
        return photos[currentIndex]
    }
    
    // MARK: - Private State
    private var photos: [Photo] = []
    private var originalOrder: [Photo] = []
    private var timer: Timer?
    
    // MARK: - Dependencies
    private let settings: SlideshowSettings
    private weak var imageViewerViewModel: ImageViewerViewModel?
    
    // MARK: - Initialization
    public init(
        settings: SlideshowSettings,
        imageViewerViewModel: ImageViewerViewModel? = nil
    ) {
        self.settings = settings
        self.imageViewerViewModel = imageViewerViewModel
        
        // 設定から初期値を読み込み
        self.playbackSpeed = settings.playbackSpeed
        self.repeatMode = settings.repeatMode
        self.shuffleEnabled = settings.shuffleEnabled
    }
    
    // MARK: - Public Methods
    public func setPhotos(_ photos: [Photo]) {
        self.originalOrder = photos
        self.photos = shuffleEnabled ? photos.shuffled() : photos
        currentIndex = 0
        
        // 最初の画像を読み込み
        if let firstPhoto = self.photos.first {
            Task {
                await imageViewerViewModel?.loadPhoto(firstPhoto)
            }
        }
    }
    
    public func play() {
        guard !photos.isEmpty else { return }
        isPlaying = true
        startTimer()
    }
    
    public func pause() {
        isPlaying = false
        stopTimer()
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func next() {
        guard canGoNext else { return }
        
        if currentIndex < photos.count - 1 {
            currentIndex += 1
        } else if repeatMode == .loop {
            currentIndex = 0
        }
        
        loadCurrentPhoto()
    }
    
    public func previous() {
        guard canGoPrevious else { return }
        
        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .loop {
            currentIndex = photos.count - 1
        }
        
        loadCurrentPhoto()
    }
    
    public func goToPhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        currentIndex = index
        loadCurrentPhoto()
    }
    
    public func setPlaybackSpeed(_ speed: PlaybackSpeed) {
        self.playbackSpeed = speed
        if isPlaying {
            restartTimer()
        }
    }
    
    public func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
    }
    
    public func toggleShuffle() {
        shuffleEnabled.toggle()
        
        if shuffleEnabled {
            // 現在の写真を保持してシャッフル
            let currentPhoto = photos[currentIndex]
            photos = originalOrder.shuffled()
            
            // 現在の写真の新しいインデックスを見つける
            if let newIndex = photos.firstIndex(where: { $0.id == currentPhoto.id }) {
                currentIndex = newIndex
            }
        } else {
            // 元の順序に戻す
            let currentPhoto = photos[currentIndex]
            photos = originalOrder
            
            if let newIndex = photos.firstIndex(where: { $0.id == currentPhoto.id }) {
                currentIndex = newIndex
            }
        }
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: playbackSpeed.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerTick()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        if isPlaying {
            startTimer()
        }
    }
    
    private func handleTimerTick() {
        if canGoNext {
            next()
        } else {
            pause()
        }
    }
    
    private func loadCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        
        Task {
            await imageViewerViewModel?.loadPhoto(photo)
        }
    }
}

// MARK: - Supporting Types
public enum PlaybackSpeed: String, CaseIterable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"
    case veryFast = "Very Fast"
    
    var interval: TimeInterval {
        switch self {
        case .slow: return 5.0
        case .normal: return 3.0
        case .fast: return 2.0
        case .veryFast: return 1.0
        }
    }
}

public enum RepeatMode: String, CaseIterable {
    case none = "None"
    case loop = "Loop"
    case single = "Single"
}
```

#### 1.4 ImageLoadingViewModel

```swift
// Application/ViewModels/ImageLoadingViewModel.swift
import Foundation
import SwiftUI
import Observation

/// 画像読み込み状態管理専用のViewModel
@Observable
@MainActor
public final class ImageLoadingViewModel {
    // MARK: - State
    public private(set) var loadingState: LoadingState = .idle
    public private(set) var progress: LoadingProgress = LoadingProgress()
    public private(set) var error: Error?
    public private(set) var recentFolders: [RecentFolder] = []
    
    // MARK: - Computed Properties
    public var isLoading: Bool {
        loadingState.isLoading
    }
    
    public var canCancel: Bool {
        loadingState.isCancellable
    }
    
    public var progressPercentage: Double {
        guard progress.total > 0 else { return 0 }
        return Double(progress.completed) / Double(progress.total)
    }
    
    // MARK: - Private State
    private var loadingTask: Task<[Photo], Error>?
    
    // MARK: - Dependencies
    private let imageRepository: ImageRepositoryProtocol
    private let recentFilesService: RecentFilesService
    
    // MARK: - Initialization
    public init(
        imageRepository: ImageRepositoryProtocol,
        recentFilesService: RecentFilesService
    ) {
        self.imageRepository = imageRepository
        self.recentFilesService = recentFilesService
        
        Task {
            await loadRecentFolders()
        }
    }
    
    // MARK: - Public Methods
    public func selectFolder() async -> URL? {
        loadingState = .selectingFolder
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing images"
        
        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
        
        if response == .OK, let url = panel.url {
            await addToRecentFolders(url)
            return url
        }
        
        loadingState = .idle
        return nil
    }
    
    public func loadImages(from folder: URL) async throws -> [Photo] {
        loadingState = .scanning(folder: folder)
        error = nil
        progress = LoadingProgress()
        
        loadingTask = Task {
            do {
                // フォルダスキャン
                let imageURLs = try await imageRepository.loadImageURLs(from: folder)
                progress.total = imageURLs.count
                
                if imageURLs.isEmpty {
                    throw LoadingError.noImagesFound
                }
                
                loadingState = .loadingImages(count: imageURLs.count)
                
                // 画像作成
                var photos: [Photo] = []
                for (index, imageURL) in imageURLs.enumerated() {
                    try Task.checkCancellation()
                    
                    let photo = Photo(imageURL: imageURL)
                    photos.append(photo)
                    
                    progress.completed = index + 1
                    progress.currentFile = imageURL.url.lastPathComponent
                }
                
                loadingState = .completed
                return photos
                
            } catch {
                self.error = error
                loadingState = .failed(error)
                throw error
            }
        }
        
        return try await loadingTask!.value
    }
    
    public func cancel() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingState = .cancelled
    }
    
    public func retry() async throws -> [Photo] {
        guard case .failed = loadingState,
              let lastFolder = recentFolders.first?.url else {
            throw LoadingError.noFolderSelected
        }
        
        return try await loadImages(from: lastFolder)
    }
    
    public func reset() {
        loadingState = .idle
        progress = LoadingProgress()
        error = nil
        loadingTask = nil
    }
    
    // MARK: - Private Methods
    private func loadRecentFolders() async {
        do {
            let items = try await recentFilesService.getRecentFiles()
            self.recentFolders = items.compactMap { item in
                guard item.url.hasDirectoryPath else { return nil }
                return RecentFolder(
                    url: item.url,
                    name: item.url.lastPathComponent,
                    lastAccessed: item.lastAccessed
                )
            }
        } catch {
            ProductionLogger.warning("Failed to load recent folders: \(error)")
        }
    }
    
    private func addToRecentFolders(_ url: URL) async {
        do {
            try await recentFilesService.addRecentFile(url)
            await loadRecentFolders()
        } catch {
            ProductionLogger.warning("Failed to add recent folder: \(error)")
        }
    }
}

// MARK: - Supporting Types
public enum LoadingState: Equatable {
    case idle
    case selectingFolder
    case scanning(folder: URL)
    case loadingImages(count: Int)
    case completed
    case cancelled
    case failed(Error)
    
    var isLoading: Bool {
        switch self {
        case .idle, .completed, .cancelled, .failed:
            return false
        case .selectingFolder, .scanning, .loadingImages:
            return true
        }
    }
    
    var isCancellable: Bool {
        switch self {
        case .scanning, .loadingImages:
            return true
        default:
            return false
        }
    }
    
    public static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.selectingFolder, .selectingFolder),
             (.completed, .completed),
             (.cancelled, .cancelled):
            return true
        case let (.scanning(url1), .scanning(url2)):
            return url1 == url2
        case let (.loadingImages(count1), .loadingImages(count2)):
            return count1 == count2
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

public struct LoadingProgress: Equatable {
    public var total: Int = 0
    public var completed: Int = 0
    public var currentFile: String = ""
}

public struct RecentFolder: Identifiable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let lastAccessed: Date
}

public enum LoadingError: LocalizedError {
    case noImagesFound
    case noFolderSelected
    case accessDenied(URL)
    
    public var errorDescription: String? {
        switch self {
        case .noImagesFound:
            return "No images found in the selected folder"
        case .noFolderSelected:
            return "No folder selected"
        case .accessDenied(let url):
            return "Access denied to folder: \(url.lastPathComponent)"
        }
    }
}
```

### 2. 統合ViewModel

#### 2.1 MainCoordinatorViewModel

```swift
// Application/ViewModels/MainCoordinatorViewModel.swift
import Foundation
import SwiftUI
import Observation

/// アプリケーション全体の調整を行うViewModel
@Observable
@MainActor
public final class MainCoordinatorViewModel {
    // MARK: - Child ViewModels
    public let imageGallery: ImageGalleryViewModel
    public let imageViewer: ImageViewerViewModel
    public let slideshowControl: SlideshowControlViewModel
    public let imageLoading: ImageLoadingViewModel
    
    // MARK: - State
    public private(set) var displayMode: DisplayMode = .welcome
    public private(set) var selectedPhotoID: Photo.ID?
    
    // MARK: - Dependencies
    private let repositories: RepositoryContainer
    
    // MARK: - Initialization
    public init(repositories: RepositoryContainer) {
        self.repositories = repositories
        
        // 子ViewModelの初期化
        self.imageGallery = ImageGalleryViewModel(
            imageRepository: repositories.imageRepository,
            cacheRepository: repositories.memoryCacheRepository,
            sortSettings: SortSettings()
        )
        
        self.imageViewer = ImageViewerViewModel(
            imageRepository: repositories.imageRepository,
            cacheRepository: repositories.memoryCacheRepository,
            metadataRepository: repositories.metadataRepository
        )
        
        self.slideshowControl = SlideshowControlViewModel(
            settings: SlideshowSettings(),
            imageViewerViewModel: imageViewer
        )
        
        self.imageLoading = ImageLoadingViewModel(
            imageRepository: repositories.imageRepository,
            recentFilesService: RecentFilesService()
        )
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    public func openFolder() async {
        guard let folderURL = await imageLoading.selectFolder() else { return }
        
        do {
            let photos = try await imageLoading.loadImages(from: folderURL)
            
            await imageGallery.loadImages(from: folderURL)
            slideshowControl.setPhotos(photos)
            
            displayMode = .gallery
            
        } catch {
            // エラーハンドリングはimageLoadingViewModelで行われる
            ProductionLogger.error("Failed to open folder: \(error)")
        }
    }
    
    public func showPhoto(_ photo: Photo) {
        selectedPhotoID = photo.id
        displayMode = .viewer
        
        Task {
            await imageViewer.loadPhoto(photo)
        }
    }
    
    public func startSlideshow() {
        guard !imageGallery.images.isEmpty else { return }
        
        displayMode = .slideshow
        slideshowControl.play()
    }
    
    public func exitSlideshow() {
        slideshowControl.pause()
        displayMode = .gallery
    }
    
    public func showGallery() {
        displayMode = .gallery
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // ViewModels間の連携設定
        // 例: ギャラリーでの選択がビューアーに反映される等
    }
}

// MARK: - Supporting Types
public enum DisplayMode {
    case welcome
    case gallery
    case viewer
    case slideshow
}
```

### 3. 移行戦略

#### 3.1 段階的移行計画

1. **Phase 1: 新ViewModelの作成**（1週間）
   - 各ViewModelのインターフェース定義
   - 基本機能の実装
   - ユニットテスト作成

2. **Phase 2: 既存機能の移植**（1週間）
   - ModernSlideshowViewModelから機能を移植
   - 動作確認とバグ修正

3. **Phase 3: UI層の更新**（1週間）
   - Viewを新しいViewModelに接続
   - バインディングの更新
   - 統合テスト

#### 3.2 互換性維持

```swift
// 一時的な互換性レイヤー
extension ModernSlideshowViewModel {
    /// 新しいViewModelへの移行用ブリッジ
    var coordinator: MainCoordinatorViewModel {
        // 内部的にMainCoordinatorViewModelを使用
        return internalCoordinator
    }
}
```

### 4. ベストプラクティス

#### 4.1 ViewModelの設計原則

1. **単一責任**: 各ViewModelは特定の画面/機能に対応
2. **テスタブル**: 依存性注入によりモック可能
3. **観察可能**: @Observableで自動的にUI更新
4. **非同期対応**: async/awaitで非同期処理

#### 4.2 状態管理

```swift
// 良い例: 明確な状態定義
public enum LoadingState {
    case idle
    case loading(progress: Double)
    case loaded
    case failed(Error)
}

// 悪い例: 複数のBool値での状態管理
var isLoading: Bool
var isError: Bool
var isCompleted: Bool
```

#### 4.3 エラーハンドリング

```swift
// 各ViewModelで一貫したエラーハンドリング
public protocol ErrorHandling {
    var error: Error? { get }
    func clearError()
}

extension ImageViewerViewModel: ErrorHandling {
    public func clearError() {
        loadError = nil
    }
}
```

### 5. パフォーマンス最適化

#### 5.1 メモリ管理

```swift
// 弱参照による循環参照の防止
class SlideshowControlViewModel {
    private weak var imageViewerViewModel: ImageViewerViewModel?
}
```

#### 5.2 非同期処理

```swift
// タスクのキャンセル処理
private var loadingTask: Task<Void, Never>?

func loadImages() {
    loadingTask?.cancel()
    loadingTask = Task {
        // 処理
    }
}
```

## まとめ

このリファクタリングにより：

1. **保守性の向上**: 各ViewModelが明確な責務を持つ
2. **テスタビリティ**: 小さな単位でのテストが可能
3. **再利用性**: 機能単位での再利用が容易
4. **拡張性**: 新機能の追加が簡単
5. **パフォーマンス**: 必要な部分のみの更新が可能