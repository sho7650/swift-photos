# Slideshow App Development Guidelines for macOS

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [MVVM Implementation](#mvvm-implementation)
3. [Project Structure](#project-structure)
4. [Coding Standards](#coding-standards)
5. [Recommended Libraries](#recommended-libraries)
6. [Best Practices](#best-practices)

## Architecture Overview

### Recommended Architecture: MVVM (Model-View-ViewModel)

We recommend MVVM architecture for macOS slideshow applications for the following reasons:

- **Balanced Complexity**: Suitable for medium-scale applications without over-engineering
- **Clear Separation of Concerns**: Distinct responsibilities for each layer
- **Testability**: Business logic isolated from UI code
- **SwiftUI Compatibility**: Natural integration with `@Observable` and reactive updates
- **Extensibility**: Easy to add features without major refactoring

### Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│                      View Layer                      │
│              (SwiftUI Views & Modifiers)            │
├─────────────────────────────────────────────────────┤
│                  ViewModel Layer                     │
│            (Business Logic & State Management)       │
├─────────────────────────────────────────────────────┤
│                    Model Layer                       │
│              (Data Structures & DTOs)                │
├─────────────────────────────────────────────────────┤
│                  Service Layer                       │
│            (API, Storage, Image Loading)             │
└─────────────────────────────────────────────────────┘
```

## MVVM Implementation

### Model Layer

```swift
// MARK: - Photo Model
struct Photo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let dateAdded: Date
    var metadata: PhotoMetadata?
    
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
}

// MARK: - Photo Metadata
struct PhotoMetadata: Sendable {
    let width: Int
    let height: Int
    let fileSize: Int64
    let captureDate: Date?
    let location: LocationData?
    let exifData: [String: Any]?
}

// MARK: - Settings Model
struct SlideshowSettings: Codable, Sendable {
    var interval: TimeInterval = 3.0
    var transitionStyle: TransitionStyle = .fade
    var shuffleEnabled: Bool = false
    var repeatEnabled: Bool = true
    var showMetadata: Bool = true
    
    enum TransitionStyle: String, CaseIterable, Codable {
        case fade = "Fade"
        case slide = "Slide"
        case zoom = "Zoom"
        case none = "None"
        
        var animation: Animation {
            switch self {
            case .fade, .zoom:
                return .easeInOut(duration: 0.3)
            case .slide:
                return .spring(response: 0.3, dampingFraction: 0.8)
            case .none:
                return .linear(duration: 0)
            }
        }
    }
}
```

### ViewModel Layer

```swift
// MARK: - Main ViewModel
@MainActor
@Observable
final class SlideshowViewModel {
    // MARK: - State Properties
    private(set) var photos: [Photo] = []
    private(set) var currentIndex = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var loadingProgress: Double = 0
    private(set) var error: Error?
    
    // MARK: - Settings
    var settings = SlideshowSettings() {
        didSet {
            if isPlaying {
                restartTimer()
            }
        }
    }
    
    // MARK: - Dependencies
    private let photoService: PhotoServiceProtocol
    private let settingsService: SettingsServiceProtocol
    private var slideshowTimer: Timer?
    
    // MARK: - Initialization
    init(
        photoService: PhotoServiceProtocol = PhotoService(),
        settingsService: SettingsServiceProtocol = SettingsService()
    ) {
        self.photoService = photoService
        self.settingsService = settingsService
        loadSettings()
    }
    
    deinit {
        slideshowTimer?.invalidate()
    }
    
    // MARK: - Photo Management
    func loadPhotos(from urls: [URL]) async {
        isLoading = true
        loadingProgress = 0
        error = nil
        
        do {
            let loadedPhotos = try await photoService.loadPhotos(
                from: urls,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.loadingProgress = progress
                    }
                }
            )
            
            photos = settings.shuffleEnabled ? loadedPhotos.shuffled() : loadedPhotos
            currentIndex = 0
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Navigation
    func navigate(to index: Int) {
        guard photos.indices.contains(index) else { return }
        currentIndex = index
    }
    
    func navigateNext() {
        guard !photos.isEmpty else { return }
        
        if currentIndex < photos.count - 1 {
            currentIndex += 1
        } else if settings.repeatEnabled {
            currentIndex = 0
        } else {
            pause()
        }
    }
    
    func navigatePrevious() {
        guard !photos.isEmpty else { return }
        
        if currentIndex > 0 {
            currentIndex -= 1
        } else if settings.repeatEnabled {
            currentIndex = photos.count - 1
        }
    }
    
    // MARK: - Playback Control
    func play() {
        guard !photos.isEmpty else { return }
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        isPlaying = false
        stopTimer()
    }
    
    func togglePlayback() {
        isPlaying ? pause() : play()
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        stopTimer()
        slideshowTimer = Timer.scheduledTimer(
            withTimeInterval: settings.interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.navigateNext()
            }
        }
    }
    
    private func stopTimer() {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
    
    private func restartTimer() {
        if isPlaying {
            startTimer()
        }
    }
    
    private func loadSettings() {
        settings = settingsService.loadSettings()
    }
    
    func saveSettings() {
        settingsService.saveSettings(settings)
    }
    
    // MARK: - Computed Properties
    var currentPhoto: Photo? {
        photos.indices.contains(currentIndex) ? photos[currentIndex] : nil
    }
    
    var progress: Double {
        photos.isEmpty ? 0 : Double(currentIndex + 1) / Double(photos.count)
    }
    
    var canNavigateNext: Bool {
        !photos.isEmpty && (currentIndex < photos.count - 1 || settings.repeatEnabled)
    }
    
    var canNavigatePrevious: Bool {
        !photos.isEmpty && (currentIndex > 0 || settings.repeatEnabled)
    }
}
```

### View Layer

```swift
// MARK: - Main Slideshow View
struct SlideshowView: View {
    @State private var viewModel = SlideshowViewModel()
    @State private var showControls = true
    @State private var controlsHideTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    
    private let controlsHideDelay: TimeInterval = 3.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Photo Display
                photoContent
                    .animation(viewModel.settings.transitionStyle.animation, value: viewModel.currentIndex)
                
                // Controls Overlay
                if showControls {
                    ControlsOverlay(viewModel: viewModel)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    LoadingOverlay(progress: viewModel.loadingProgress)
                }
            }
        }
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            showControls = true
            scheduleControlsHide()
        }
        .onHover { hovering in
            if hovering {
                showControls = true
                scheduleControlsHide()
            }
        }
        .onKeyPress(action: handleKeyPress)
        .task {
            await loadInitialPhotos()
        }
    }
    
    @ViewBuilder
    private var photoContent: some View {
        if let photo = viewModel.currentPhoto {
            PhotoDisplayView(photo: photo)
                .id(photo.id)
                .transition(makeTransition())
        } else {
            ContentUnavailableView(
                "No Photos",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Drop photos here to start slideshow")
            )
        }
    }
    
    private func makeTransition() -> AnyTransition {
        switch viewModel.settings.transitionStyle {
        case .fade:
            return .opacity
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .zoom:
            return .scale(scale: 0.8).combined(with: .opacity)
        case .none:
            return .identity
        }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        showControls = true
        scheduleControlsHide()
        
        switch press.key {
        case .space:
            viewModel.togglePlayback()
            return .handled
        case .rightArrow:
            viewModel.navigateNext()
            return .handled
        case .leftArrow:
            viewModel.navigatePrevious()
            return .handled
        case .escape:
            NSApp.keyWindow?.toggleFullScreen(nil)
            return .handled
        default:
            return .ignored
        }
    }
    
    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(controlsHideDelay))
            if !Task.isCancelled {
                withAnimation {
                    showControls = false
                }
            }
        }
    }
    
    private func loadInitialPhotos() async {
        // Implementation depends on your photo source
        // Example: Load from user's Pictures folder
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        await viewModel.loadPhotos(from: [picturesURL])
    }
}
```

### Service Layer

```swift
// MARK: - Photo Service Protocol
protocol PhotoServiceProtocol: Sendable {
    func loadPhotos(from urls: [URL], progress: @Sendable (Double) -> Void) async throws -> [Photo]
    func loadPhoto(from url: URL) async throws -> Photo
    func preloadImages(for photos: [Photo]) async
}

// MARK: - Photo Service Implementation
actor PhotoService: PhotoServiceProtocol {
    // Use unified cache bridge instead of direct NSCache
    private let imageCache = UnifiedImageCacheBridgeFactory.createForSlideshow()
    private let supportedExtensions = ["jpg", "jpeg", "png", "heic", "tiff", "gif"]
    
    init() {
        // Cache configuration handled by factory
    }
    
    func loadPhotos(from urls: [URL], progress: @Sendable (Double) -> Void) async throws -> [Photo] {
        let imageURLs = findImageURLs(in: urls)
        var loadedPhotos: [Photo] = []
        
        for (index, url) in imageURLs.enumerated() {
            let photo = try await loadPhoto(from: url)
            loadedPhotos.append(photo)
            progress(Double(index + 1) / Double(imageURLs.count))
        }
        
        return loadedPhotos
    }
    
    func loadPhoto(from url: URL) async throws -> Photo {
        guard let image = NSImage(contentsOf: url) else {
            throw PhotoError.invalidImage
        }
        
        // Cache the image using unified cache
        let imageURL = try ImageURL(url)
        await imageCache.setCachedImage(SendableImage(image), for: imageURL)
        
        let metadata = try await extractMetadata(from: url)
        
        return Photo(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            dateAdded: Date(),
            metadata: metadata
        )
    }
    
    func preloadImages(for photos: [Photo]) async {
        await withTaskGroup(of: Void.self) { group in
            for photo in photos.prefix(5) { // Preload next 5 images
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    if await self.imageCache.object(forKey: photo.url as NSURL) == nil {
                        _ = try? await self.loadPhoto(from: photo.url)
                    }
                }
            }
        }
    }
    
    private func findImageURLs(in urls: [URL]) -> [URL] {
        var imageURLs: [URL] = []
        
        for url in urls {
            if url.hasDirectoryPath {
                imageURLs.append(contentsOf: findImagesInDirectory(url))
            } else if isImageFile(url) {
                imageURLs.append(url)
            }
        }
        
        return imageURLs
    }
    
    private func findImagesInDirectory(_ directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return enumerator.compactMap { $0 as? URL }.filter(isImageFile)
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func extractMetadata(from url: URL) async throws -> PhotoMetadata {
        // Metadata extraction implementation
        // This is a simplified version
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw PhotoError.metadataExtractionFailed
        }
        
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        return PhotoMetadata(
            width: width,
            height: height,
            fileSize: fileSize,
            captureDate: nil,
            location: nil,
            exifData: properties
        )
    }
}

// MARK: - Error Types
enum PhotoError: LocalizedError {
    case invalidImage
    case metadataExtractionFailed
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The file is not a valid image"
        case .metadataExtractionFailed:
            return "Failed to extract image metadata"
        case .accessDenied:
            return "Access denied to the file"
        }
    }
}
```

## Project Structure

```
SlideshowApp/
├── App/
│   ├── SlideshowApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Photo.swift
│   ├── PhotoMetadata.swift
│   └── SlideshowSettings.swift
├── ViewModels/
│   ├── SlideshowViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Main/
│   │   ├── SlideshowView.swift
│   │   └── PhotoDisplayView.swift
│   ├── Controls/
│   │   ├── ControlsOverlay.swift
│   │   └── PlaybackControls.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── PhotoService.swift
│   ├── SettingsService.swift
│   └── MetadataService.swift
├── Utilities/
│   ├── Extensions/
│   ├── ViewModifiers/
│   └── Helpers/
└── Resources/
    └── Assets.xcassets
```

## Coding Standards

### Swift Version and Platform

- **Swift Version**: 6.0+
- **Platform**: macOS 14.0+
- **UI Framework**: SwiftUI

### Naming Conventions

```swift
// Types: PascalCase
struct PhotoMetadata { }
class SlideshowViewModel { }
protocol PhotoServiceProtocol { }

// Properties and Methods: camelCase
var currentIndex: Int
func loadPhotos() async { }

// Constants: camelCase
let maximumPhotoCount = 1000
let defaultTransitionDuration = 0.3

// Type Aliases: PascalCase
typealias PhotoCompletion = (Result<Photo, Error>) -> Void
```

### Code Organization

```swift
// MARK: - Section Headers
// Use MARK comments to organize code within files

struct ExampleView: View {
    // MARK: - Properties
    @State private var isLoading = false
    
    // MARK: - Body
    var body: some View {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func handleAction() {
        // Implementation
    }
}
```

### Concurrency

```swift
// Use async/await for asynchronous operations
func loadPhotos() async throws -> [Photo] {
    // Implementation
}

// Use @MainActor for UI updates
@MainActor
func updateUI() {
    // UI updates
}

// Use actors for thread-safe services
actor PhotoCache {
    private var cache: [URL: Photo] = [:]
    
    func photo(for url: URL) -> Photo? {
        cache[url]
    }
}
```

### Error Handling

```swift
// Define specific error types
enum SlideshowError: LocalizedError {
    case noPhotosFound
    case loadingFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .noPhotosFound:
            return "No photos found in the selected location"
        case .loadingFailed(let error):
            return "Failed to load photos: \(error.localizedDescription)"
        }
    }
}

// Use Result type for completion handlers
func loadPhoto(completion: @escaping (Result<Photo, Error>) -> Void) {
    // Implementation
}
```

## Recommended Libraries

### Core Dependencies

```swift
// Package.swift
let package = Package(
    name: "SlideshowApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Image Loading & Caching
        .package(url: "https://github.com/kean/Nuke", from: "12.0.0"),
        
        // User Defaults Management
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
        
        // Global Keyboard Shortcuts
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        
        // File Management (Optional)
        .package(url: "https://github.com/JohnSundell/Files", from: "4.0.0"),
        
        // Animations (Optional)
        .package(url: "https://github.com/EmergeTools/Pow", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SlideshowApp",
            dependencies: [
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                "Defaults",
                "KeyboardShortcuts",
                "Files",
                "Pow"
            ]
        ),
        .testTarget(
            name: "SlideshowAppTests",
            dependencies: ["SlideshowApp"]
        )
    ]
)
```

### Library Usage Guidelines

#### Nuke - Image Loading

```swift
import Nuke
import NukeUI

struct OptimizedPhotoView: View {
    let photo: Photo
    
    var body: some View {
        LazyImage(url: photo.url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if state.error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            } else {
                ProgressView()
            }
        }
        .processors([
            .resize(size: CGSize(width: 2000, height: 2000), unit: .pixels),
            .processCoreGraphics { image in
                // Apply custom processing if needed
                return image
            }
        ])
        .priority(.high)
    }
}
```

#### Defaults - Settings Management

```swift
import Defaults

extension Defaults.Keys {
    static let slideshowInterval = Key<TimeInterval>("slideshowInterval", default: 3.0)
    static let transitionStyle = Key<SlideshowSettings.TransitionStyle>("transitionStyle", default: .fade)
    static let shuffleEnabled = Key<Bool>("shuffleEnabled", default: false)
    static let repeatEnabled = Key<Bool>("repeatEnabled", default: true)
}

class SettingsService: SettingsServiceProtocol {
    func loadSettings() -> SlideshowSettings {
        SlideshowSettings(
            interval: Defaults[.slideshowInterval],
            transitionStyle: Defaults[.transitionStyle],
            shuffleEnabled: Defaults[.shuffleEnabled],
            repeatEnabled: Defaults[.repeatEnabled]
        )
    }
    
    func saveSettings(_ settings: SlideshowSettings) {
        Defaults[.slideshowInterval] = settings.interval
        Defaults[.transitionStyle] = settings.transitionStyle
        Defaults[.shuffleEnabled] = settings.shuffleEnabled
        Defaults[.repeatEnabled] = settings.repeatEnabled
    }
}
```

#### KeyboardShortcuts - Global Shortcuts

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSlideshow = Self("toggleSlideshow", default: .init(.space, modifiers: []))
    static let nextPhoto = Self("nextPhoto", default: .init(.rightArrow, modifiers: []))
    static let previousPhoto = Self("previousPhoto", default: .init(.leftArrow, modifiers: []))
    static let toggleFullscreen = Self("toggleFullscreen", default: .init(.f, modifiers: [.command]))
}

@main
struct SlideshowApp: App {
    init() {
        setupKeyboardShortcuts()
    }
    
    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleSlideshow) {
            NotificationCenter.default.post(name: .toggleSlideshow, object: nil)
        }
        
        KeyboardShortcuts.onKeyUp(for: .nextPhoto) {
            NotificationCenter.default.post(name: .nextPhoto, object: nil)
        }
        
        KeyboardShortcuts.onKeyUp(for: .previousPhoto) {
            NotificationCenter.default.post(name: .previousPhoto, object: nil)
        }
    }
}
```

## Best Practices

### 1. Unified Architecture Patterns

```swift
// ✅ DO: Use factory methods for component creation
let cache = UnifiedImageCacheBridgeFactory.createForSlideshow()
let loader = UnifiedImageLoader(settings: performanceSettings)

// ❌ DON'T: Instantiate legacy components directly
let cache = ImageCache() // This class has been removed

// ✅ DO: Provide context for intelligent optimization
let context = LoadingContext(
    collectionSize: photos.count,
    currentIndex: index,
    priority: .normal
)
let image = try await loader.loadImage(from: photo, context: context)

// ❌ DON'T: Load images without context
let image = try await loader.loadImage(from: imageURL) // Missing optimization opportunity

// ✅ DO: Use unified repository interfaces
let repository: UnifiedImageRepository = UnifiedFileSystemImageRepository(...)
let photos = try await repository.loadPhotos(from: .folder(url), options: options)

// ❌ DON'T: Mix legacy and unified patterns in the same component
class MyService {
    let oldRepo: SlideshowRepository // Legacy
    let newCache: UnifiedImageCacheBridge // Unified
    // This creates confusion and maintenance issues
}
```

### 2. Memory Management

```swift
// Use weak references in closures to avoid retain cycles
class PhotoPreloader {
    func preloadNext(photos: [Photo], currentIndex: Int) {
        Task { [weak self] in
            guard let self = self else { return }
            await self.preloadImages(photos, startingAt: currentIndex + 1)
        }
    }
}

// Implement proper cleanup
deinit {
    timer?.invalidate()
    NotificationCenter.default.removeObserver(self)
}
```

### 2. Performance Optimization

```swift
// Lazy loading for large collections
struct PhotoGridView: View {
    let photos: [Photo]
    
    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(photos) { photo in
                PhotoThumbnailView(photo: photo)
                    .task {
                        await preloadIfNeeded(photo)
                    }
            }
        }
    }
}

// Image size optimization
extension NSImage {
    func resized(to targetSize: CGSize) -> NSImage? {
        let frame = NSRect(origin: .zero, size: targetSize)
        guard let representation = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        
        let image = NSImage(size: targetSize)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        representation.draw(in: frame)
        return image
    }
}
```

### 3. Testing

```swift
// ViewModel Testing
class SlideshowViewModelTests: XCTestCase {
    func testPhotoNavigation() async {
        // Given
        let mockService = MockPhotoService()
        let viewModel = await SlideshowViewModel(photoService: mockService)
        let testPhotos = [
            Photo(url: URL(fileURLWithPath: "/photo1.jpg"), name: "Photo 1", dateAdded: Date()),
            Photo(url: URL(fileURLWithPath: "/photo2.jpg"), name: "Photo 2", dateAdded: Date())
        ]
        
        // When
        await viewModel.loadPhotos(from: testPhotos.map { $0.url })
        await viewModel.navigateNext()
        
        // Then
        let currentIndex = await viewModel.currentIndex
        XCTAssertEqual(currentIndex, 1)
    }
}

// Mock Services
class MockPhotoService: PhotoServiceProtocol {
    var mockPhotos: [Photo] = []
    var shouldFail = false
    
    func loadPhotos(from urls: [URL], progress: @Sendable (Double) -> Void) async throws -> [Photo] {
        if shouldFail {
            throw PhotoError.loadingFailed
        }
        return mockPhotos
    }
}
```

### 4. Accessibility

```swift
struct AccessiblePhotoView: View {
    let photo: Photo
    
    var body: some View {
        Image(nsImage: loadImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityLabel(photo.name)
            .accessibilityHint("Double tap to view in full screen")
            .accessibilityAddTraits(.isImage)
    }
}
```

### 5. Localization

```swift
// Use String catalogs for localization
extension String {
    static let playButtonTitle = String(localized: "slideshow.button.play", defaultValue: "Play")
    static let pauseButtonTitle = String(localized: "slideshow.button.pause", defaultValue: "Pause")
    static let noPhotosMessage = String(localized: "slideshow.message.noPhotos", defaultValue: "No photos to display")
}

// Usage
Button(viewModel.isPlaying ? .pauseButtonTitle : .playButtonTitle) {
    viewModel.togglePlayback()
}
```

### 6. SwiftUI View Modifiers

```swift
// Custom view modifiers for consistent styling
struct SlideshowButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
            .shadow(radius: 2)
    }
}

extension View {
    func slideshowButtonStyle() -> some View {
        modifier(SlideshowButtonStyle())
    }
}
```

## Version Control Guidelines

### Git Workflow

- Use feature branches: `feature/photo-metadata`
- Commit message format: `type: description` (e.g., `feat: add EXIF data support`)
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Code Review Checklist

- [ ] Follows MVVM architecture pattern
- [ ] Proper error handling implemented
- [ ] Memory management considered (no retain cycles)
- [ ] UI is responsive and performs well
- [ ] Code is properly documented
- [ ] Unit tests included for business logic
- [ ] Accessibility features implemented
- [ ] Localization keys added

## Conclusion

This guide provides a comprehensive foundation for developing a macOS slideshow application using SwiftUI and the MVVM architecture pattern. The recommended libraries and practices ensure a maintainable, performant, and user-friendly application.


