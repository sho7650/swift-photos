# Unified Architecture Documentation

## Overview

The Swift Photos application has undergone architectural consolidation (Phases 3-5) to create a unified, maintainable codebase. This document details the unified patterns and their usage.

## Architecture Principles

### 1. Single Responsibility with Unified Interfaces

Each unified component consolidates related functionality while maintaining a single, clear purpose:
- **UnifiedImageRepository**: All image-related operations (loading, caching, metadata)
- **UnifiedImageLoader**: All loading strategies (basic, virtual, emergency, preload)
- **UnifiedImageCacheRepository**: All caching strategies (NSCache, LRU, Hybrid)

### 2. Strategy Pattern for Flexibility

Components use strategy patterns to adapt behavior at runtime:
```swift
// Cache strategies selected based on configuration
let cache = UnifiedImageCacheRepository(
    countLimit: 200,
    totalCostLimit: 500_000_000,
    strategy: .hybrid // Can be .nsCache, .lru, or .hybrid
)

// Loading strategies selected based on context
let loader = UnifiedImageLoader(settings: performanceSettings)
// Automatically selects: basic, virtual, emergency, or preload strategy
```

### 3. Bridge Pattern for Migration

Legacy code compatibility through bridge adapters:
```swift
// UnifiedImageCacheBridge makes new cache compatible with old PhotoCache protocol
let bridge: PhotoCache = UnifiedImageCacheBridge(configuration: .default)

// FileSystemPhotoRepositoryAdapter bridges old repository to new interface
let adapter: ImageRepositoryProtocol = FileSystemPhotoRepositoryAdapter(
    legacyRepository: oldRepo,
    cache: unifiedCache
)
```

## Component Details

### UnifiedImageRepository

**Purpose**: Consolidates all image-related repository operations

**Key Interfaces**:
```swift
protocol UnifiedImageRepository: Sendable {
    // Load photos from various sources
    func loadPhotos(from source: ImageSource, options: LoadOptions) async throws -> [Photo]
    
    // Load individual image with quality options
    func loadImage(for photo: Photo, quality: ImageQuality, options: LoadOptions) async throws -> Photo
    
    // Extract metadata
    func loadMetadata(for photo: Photo, options: MetadataOptions) async throws -> ImageMetadata
    
    // Batch operations
    func loadImages(photos: [Photo], quality: ImageQuality, options: LoadOptions) async throws -> [Photo]
}
```

**Image Sources**:
```swift
enum ImageSource {
    case folder(URL)
    case files([URL])
    case photos([Photo])
}
```

**Load Options**:
```swift
struct LoadOptions {
    let includeMetadata: Bool
    let includeHiddenFiles: Bool
    let sortBy: SortCriteria?
    let filterBy: FilterCriteria?
    let maxConcurrentLoads: Int
}
```

### UnifiedImageLoader

**Purpose**: Adaptive image loading with multiple strategies

**Key Features**:
- Automatic strategy selection based on context
- Unified callbacks for UI updates
- Comprehensive statistics tracking
- Memory pressure awareness

**Usage**:
```swift
let loader = UnifiedImageLoader(settings: performanceSettings)

// Set callbacks for UI updates
loader.setImageLoadedCallback { photoId, image in
    // Update UI with loaded image
}

// Load with context for optimization
let context = LoadingContext(
    collectionSize: 10000,
    currentIndex: 500,
    priority: .normal,
    memoryPressure: .normal
)
let image = try await loader.loadImage(from: photo, context: context)
```

**Loading Strategies**:
1. **BasicImageLoadingStrategy**: Direct loading for small collections
2. **VirtualImageLoadingStrategy**: Sliding window for large collections
3. **EmergencyImageLoadingStrategy**: Immediate loading for UI responsiveness
4. **PreloadImageLoadingStrategy**: Background preloading of adjacent images

### UnifiedImageCacheRepository

**Purpose**: Multi-strategy caching with consistent interface

**Cache Strategies**:
1. **NSCacheStrategy**: Apple's NSCache with automatic memory management
2. **LRUCacheStrategy**: Least Recently Used with predictable eviction
3. **HybridCacheStrategy**: Combines NSCache speed with LRU predictability

**Advanced Features**:
```swift
// Priority-based caching
await cache.setPriority(.high, for: cacheKey)

// Thumbnail caching
await cache.cacheThumbnail(image, for: originalKey, size: CGSize(width: 200, height: 200))

// Quality-specific caching
await cache.cacheWithQuality(image, for: key, quality: .compressed)

// Batch preloading
await cache.preload(images)
```

### UnifiedTimerManager

**Purpose**: Consolidated timer management

**Features**:
- Wraps OptimizedTimerPool for performance
- Unified interface for all timer operations
- Automatic cleanup and resource management

**Usage**:
```swift
let timerManager = UnifiedTimerManager()

// Schedule repeating timer
let timerId = await timerManager.scheduleTimer(
    interval: 3.0,
    repeats: true,
    tolerance: 0.1,
    action: { @MainActor in
        // Timer action
    }
)

// Cancel when done
await timerManager.cancelTimer(timerId)
```

## Migration Patterns

### Factory Pattern Usage

Always use factories for common configurations:
```swift
// Cache factories
UnifiedImageCacheBridgeFactory.createDefault()
UnifiedImageCacheBridgeFactory.createForSlideshow()
UnifiedImageCacheBridgeFactory.createMemoryOptimized()
UnifiedImageCacheBridgeFactory.createHighPerformance()

// Repository factories
ImageRepositoryFactory.create(
    type: .unified,
    fileAccess: fileAccess,
    settings: settings
)
```

### Adapter Pattern Usage

For gradual migration:
```swift
// Adapt old repository
let oldRepo = FileSystemPhotoRepository(...)
let adapter = FileSystemPhotoRepositoryAdapter(
    legacyRepository: oldRepo,
    cache: unifiedCache
)

// Use through unified interface
let photos = try await adapter.loadImages(from: folder)
```

## Best Practices

### 1. Always Provide Context

```swift
// ✅ Good: Provides context for optimization
let context = LoadingContext(
    collectionSize: photos.count,
    currentIndex: currentIndex,
    priority: priority
)
let image = try await loader.loadImage(from: photo, context: context)

// ❌ Bad: No context = no optimization
let image = try await loader.loadImage(from: photo.imageURL)
```

### 2. Use Appropriate Cache Configuration

```swift
// For slideshow with many images
let cache = UnifiedImageCacheBridgeFactory.createForSlideshow()

// For limited memory environments
let cache = UnifiedImageCacheBridgeFactory.createMemoryOptimized()

// For maximum performance
let cache = UnifiedImageCacheBridgeFactory.createHighPerformance()
```

### 3. Handle Errors Appropriately

```swift
do {
    let photos = try await repository.loadPhotos(from: .folder(url), options: options)
} catch ImageRepositoryError.accessDenied {
    // Handle permission issues
} catch ImageRepositoryError.unsupportedFormat {
    // Handle format issues
} catch {
    // Handle other errors
}
```

### 4. Clean Up Resources

```swift
// Clean up loader resources
await loader.cleanup()

// Clear cache when needed
await cache.removeAll()

// Cancel timers
await timerManager.cancelAllTimers()
```

## Performance Considerations

### Memory Management

- Unified components automatically adapt to memory pressure
- Cache strategies have different memory characteristics:
  - NSCache: Automatic OS-managed eviction
  - LRU: Predictable memory usage
  - Hybrid: Balance of both

### Concurrency

- All unified components are thread-safe actors
- Concurrent operations are managed internally
- Use `maxConcurrentLoads` in LoadOptions to control parallelism

### Adaptive Behavior

Components adapt based on:
- Collection size
- Available memory
- Current load
- User interaction patterns

## Testing

### Mock Implementations

```swift
// Mock unified loader
class MockUnifiedImageLoader: UnifiedImageLoader {
    var mockDelay: TimeInterval = 0
    var shouldFail = false
    
    override func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        if shouldFail { throw ImageLoadingError.testError }
        try await Task.sleep(for: .seconds(mockDelay))
        return createMockImage()
    }
}

// Mock unified cache
class MockUnifiedCache: UnifiedImageCacheProtocol {
    var storage: [String: SendableImage] = [:]
    
    func get(_ key: ImageCacheKey) async -> SendableImage? {
        storage[key.identifier]
    }
    
    func set(_ value: SendableImage, for key: ImageCacheKey, cost: Int?) async {
        storage[key.identifier] = value
    }
}
```

### Integration Testing

```swift
func testUnifiedImageLoadingFlow() async throws {
    // Setup
    let cache = UnifiedImageCacheBridge(configuration: .memoryOptimized)
    let loader = UnifiedImageLoader(settings: .testSettings)
    let repository = UnifiedFileSystemImageRepository(
        fileAccess: mockFileAccess,
        imageLoader: loader,
        cache: cache
    )
    
    // Test
    let photos = try await repository.loadPhotos(
        from: .folder(testFolder),
        options: .testOptions
    )
    
    // Verify
    XCTAssertFalse(photos.isEmpty)
    XCTAssertNotNil(await cache.getCachedImage(for: photos[0].imageURL))
}
```

## Future Extensibility

The unified architecture supports easy extension:

1. **New Cache Strategies**: Implement `CacheStrategy` protocol
2. **New Loading Strategies**: Implement `ImageLoadingStrategy` protocol  
3. **New Repository Sources**: Extend `ImageSource` enum
4. **New Event Types**: Extend unified event system

Example adding disk cache:
```swift
class DiskCacheStrategy: CacheStrategy {
    func get(_ key: String) async -> NSImage? {
        // Load from disk
    }
    
    func set(_ image: NSImage, for key: String, cost: Int) async {
        // Save to disk
    }
}
```

## Troubleshooting

### Common Issues

1. **"ImageCache not found" compiler error**
   - Solution: Use `UnifiedImageCacheBridge` instead

2. **Performance degradation with unified components**
   - Check context is being provided
   - Verify appropriate strategy is selected
   - Review memory settings

3. **Migration compatibility issues**
   - Use bridge/adapter patterns
   - Migrate incrementally
   - Keep protocols stable

### Debug Logging

Enable detailed logging:
```swift
ProductionLogger.setLevel(.debug)
ProductionLogger.enableCategory(.caching)
ProductionLogger.enableCategory(.imageLoading)
```

## Summary

The unified architecture provides:
- Consistent patterns across the codebase
- Reduced code duplication
- Better performance through adaptive strategies
- Easier testing and maintenance
- Smooth migration path from legacy code

Always prefer unified components for new development and migrate legacy code gradually using the provided bridge and adapter patterns.