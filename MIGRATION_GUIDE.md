# Swift Photos Architecture Migration Guide

This guide helps developers migrate from legacy components to the new unified architecture introduced in Phases 3-5.

## Overview

The Swift Photos codebase has undergone significant architectural consolidation to:
- Reduce code duplication
- Improve maintainability
- Standardize patterns across layers
- Enable better testability

## Migration Checklist

### 1. Cache Layer Migration

#### From ImageCache to UnifiedImageCacheBridge

**Legacy Pattern:**
```swift
let imageCache = ImageCache(countLimit: 50, totalCostLimit: 100_000_000)
await imageCache.setCachedImage(image, for: imageURL)
let cached = await imageCache.getCachedImage(for: imageURL)
```

**Unified Pattern:**
```swift
// Use factory for common configurations
let cache = UnifiedImageCacheBridgeFactory.createForSlideshow()

// Or create with custom configuration
let cache = UnifiedImageCacheBridge(
    configuration: UnifiedImageCacheConfiguration(
        countLimit: 200,
        totalCostLimit: 500_000_000,
        strategy: .hybrid
    )
)

// Same API through PhotoCache protocol
await cache.setCachedImage(image, for: imageURL)
let cached = await cache.getCachedImage(for: imageURL)
```

#### Available Factory Methods
- `UnifiedImageCacheBridgeFactory.createDefault()` - Standard configuration
- `UnifiedImageCacheBridgeFactory.createForSlideshow()` - Optimized for slideshow (200 items, 500MB)
- `UnifiedImageCacheBridgeFactory.createMemoryOptimized()` - Low memory usage (25 items, 50MB)
- `UnifiedImageCacheBridgeFactory.createHighPerformance()` - High performance (500 items, 1GB)

### 2. Image Loading Migration

#### From Direct ImageLoader to UnifiedImageLoader

**Legacy Pattern:**
```swift
let loader = ImageLoader(maxConcurrentOperations: 5)
let image = try await loader.loadImage(from: imageURL)
```

**Unified Pattern:**
```swift
let loader = UnifiedImageLoader(settings: performanceSettings)

// Single image loading with context
let context = LoadingContext(
    collectionSize: photos.count,
    currentIndex: currentIndex,
    priority: .normal
)
let image = try await loader.loadImage(from: photo, context: context)

// Window-based loading for collections
let images = await loader.loadImageWindow(
    around: centerIndex,
    photos: photos,
    windowSize: 50
)

// Emergency loading for immediate UI response
loader.loadImageEmergency(photo: photo) { result in
    // Handle result
}
```

### 3. Repository Layer Migration

#### From SlideshowRepository to UnifiedImageRepository

**Legacy Pattern:**
```swift
let repository: SlideshowRepository = FileSystemPhotoRepository(
    fileAccess: fileAccess,
    imageLoader: imageLoader,
    sortSettings: sortSettings,
    localizationService: localizationService
)
let photos = try await repository.loadPhotos(from: folderURL)
```

**Unified Pattern:**
```swift
// Option 1: Use UnifiedFileSystemImageRepository directly
let repository = UnifiedFileSystemImageRepository(
    fileAccess: fileAccess,
    imageLoader: unifiedLoader,
    cache: unifiedCache,
    metadataExtractor: metadataExtractor
)

let options = LoadOptions(
    includeMetadata: true,
    sortBy: .creationDate,
    filterBy: .supportedFormats
)
let photos = try await repository.loadPhotos(
    from: .folder(folderURL),
    options: options
)

// Option 2: Use adapter for gradual migration
let legacyRepo = FileSystemPhotoRepository(...)
let adapter = FileSystemPhotoRepositoryAdapter(
    legacyRepository: legacyRepo,
    cache: unifiedCache
)
```

### 4. Timer Management Migration

#### From OptimizedTimerPool to UnifiedTimerManager

**Legacy Pattern:**
```swift
let timerId = OptimizedTimerPool.shared.scheduleTimer(
    withInterval: 3.0,
    repeats: true
) {
    // Timer action
}
OptimizedTimerPool.shared.cancelTimer(timerId)
```

**Unified Pattern:**
```swift
let timerManager = UnifiedTimerManager()
let timerId = await timerManager.scheduleTimer(
    interval: 3.0,
    repeats: true,
    action: {
        // Timer action
    }
)
await timerManager.cancelTimer(timerId)
```

## Component Mapping

| Legacy Component | Unified Component | Migration Strategy |
|-----------------|-------------------|-------------------|
| ImageCache | UnifiedImageCacheBridge | Direct replacement via factory |
| LRUImageCache | UnifiedImageCacheRepository (LRU strategy) | Use configuration |
| ImageLoader | UnifiedImageLoader | Add context parameter |
| VirtualImageLoader | UnifiedImageLoader (virtual strategy) | Automatic selection |
| FileSystemPhotoRepository | UnifiedFileSystemImageRepository | Use adapter or rewrite |
| OptimizedTimerPool | UnifiedTimerManager | Wrap existing pool |

## Testing Considerations

### Update Test Dependencies

```swift
// Before
let mockCache = MockImageCache()

// After
let mockCache = MockPhotoCache() // Implements PhotoCache protocol
// Or use the real bridge with test configuration
let testCache = UnifiedImageCacheBridge(
    configuration: .memoryOptimized
)
```

### Mock Unified Components

```swift
// Mock UnifiedImageLoader
class MockUnifiedImageLoader: UnifiedImageLoader {
    var mockImages: [UUID: SendableImage] = [:]
    
    override func loadImage(from photo: Photo, context: LoadingContext) async throws -> SendableImage {
        if let image = mockImages[photo.id] {
            return image
        }
        throw ImageLoadingError.notFound
    }
}
```

## Common Pitfalls

1. **Don't mix legacy and unified caching** - Use one consistent approach
2. **Always provide context for UnifiedImageLoader** - It optimizes based on context
3. **Use factories for standard configurations** - Avoid hardcoding cache limits
4. **Check for actor isolation** - Many unified components are actors requiring await
5. **Handle new error types** - Unified components may throw different errors

## Gradual Migration Strategy

1. **Phase 1**: Replace cache instantiation with factories (no code changes needed)
2. **Phase 2**: Migrate image loading to UnifiedImageLoader (add context)
3. **Phase 3**: Update repositories using adapters (minimal changes)
4. **Phase 4**: Fully migrate to unified repositories (larger refactor)
5. **Phase 5**: Update tests to use unified mocks

## Performance Benefits

After migration, you should see:
- Reduced memory usage through intelligent caching strategies
- Better performance with adaptive loading
- Improved maintainability with consistent patterns
- Easier testing with standardized interfaces

## Getting Help

- Check `CLAUDE.md` for architectural overview
- Review unit tests for usage examples
- Use Xcode's Find/Replace for bulk updates
- Run tests frequently during migration