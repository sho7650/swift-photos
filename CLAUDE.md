# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Please refer to define for Architecture principles: @principles/architecture.md
Please refer to this for coding best practices: https://developer.apple.com/documentation/xcode/improving-build-efficiency-with-good-coding-practices.

## Build & Development Commands

### Build Commands

```bash
# Build the project
xcodebuild -project PhotoSlideshow.xcodeproj -scheme PhotoSlideshow build

# Clean build
xcodebuild -project PhotoSlideshow.xcodeproj -scheme PhotoSlideshow clean build

# Build for release
xcodebuild -project PhotoSlideshow.xcodeproj -scheme PhotoSlideshow -configuration Release build
```

### Testing Commands

```bash
# Run unit tests
xcodebuild -project PhotoSlideshow.xcodeproj -scheme PhotoSlideshow test -destination 'platform=macOS'

# Run UI tests only
xcodebuild -project PhotoSlideshow.xcodeproj -scheme PhotoSlideshow -only-testing:PhotoSlideshowUITests test

# Run specific test class
xcodebuild -project PhotoSlideshow.xcodeproj -scheme PhotoSlideshow -only-testing:PhotoSlideshowTests/PhotoSlideshowTests test
```

## Architecture Overview

PhotoSlideshow is a macOS application built using **Clean Architecture** principles with SwiftUI. The architecture is designed to handle unlimited photo collections (tested up to 100k+ photos) with sophisticated image loading, caching, and transition systems.

### Layer Structure

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │  SwiftUI Views, Settings UI
├─────────────────────────────────────────┤
│           Application Layer             │  ViewModels, Services, Coordinators
├─────────────────────────────────────────┤
│           Infrastructure Layer          │  File System, Image Loading, Caching
├─────────────────────────────────────────┤
│              Domain Layer               │  Entities, Value Objects, Repositories
└─────────────────────────────────────────┘
```

## Core Domain

### Key Entities

- **Photo**: Core entity with state management (`notLoaded`, `loading`, `loaded`, `failed`)
- **Slideshow**: Manages photo collections, playback state, and navigation
- **PhotoMetadata**: File information (size, dimensions, dates, color space)

### Value Objects

- **ImageURL**: Type-safe URL wrapper for image file paths
- **SlideshowInterval**: Configurable timing for automatic slideshow progression
- **Settings Objects**: Performance, Slideshow, Sort, and Transition configurations

### Repository Pattern

- **SlideshowRepository**: Abstract interface for photo loading
- **FileSystemPhotoRepository**: Concrete implementation with security and sorting

## Settings Management Architecture

The application uses a sophisticated multi-layered settings system with real-time updates:

### Settings Types

1. **PerformanceSettings**: Memory management, concurrent loading, cache sizes
2. **SlideshowSettings**: Timing, auto-start, looping, random order
3. **SortSettings**: File ordering (name, date, size, random with fixed seed)
4. **TransitionSettings**: Animation effects, duration, easing, intensity

### Settings Managers

Each settings type has a dedicated `@MainActor` manager class that:

- Persists settings to UserDefaults using JSON encoding
- Publishes changes via `@Published` properties
- Sends NotificationCenter updates for cross-component communication
- Provides preset configurations and validation

### Notification Pattern

```swift
// Settings changes trigger notifications
extension Notification.Name {
    static let sortSettingsChanged = Notification.Name("sortSettingsChanged")
    static let transitionSettingsChanged = Notification.Name("transitionSettingsChanged")
}
```

## Image Loading & Caching Architecture

### Multi-Tier Caching System

1. **ImageCache**: NSCache-based primary cache with cost-based eviction
2. **LRUImageCache**: Least-recently-used cache for predictable memory management
3. **VirtualImageLoader**: Actor-based sliding window loader for massive collections
4. **BackgroundPreloader**: Priority queue system for adjacent image preloading

### Performance Scaling

The system automatically adapts to collection sizes:

- **0-100 photos**: Standard caching (50 image window)
- **101-1,000 photos**: High performance mode (200 image window)
- **1,001-10,000 photos**: Unlimited mode (1,000 image window)
- **10,001-50,000 photos**: Massive mode (2,000 image window, 16GB memory)
- **50,001+ photos**: Extreme mode (5,000 image window, 32GB memory, dynamic scaling)

### Virtual Loading Strategy

For large collections, the `VirtualImageLoader` maintains a sliding window around the current image:

```swift
// Smart window sizing based on collection size
private func calculateEffectiveWindowSize(collectionSize: Int) -> Int {
    switch collectionSize {
    case 0...100: return min(windowSize, collectionSize)
    case 101...1000: return min(windowSize, max(50, collectionSize / 10))
    case 1001...10000: return min(windowSize, max(100, collectionSize / 50))
    default: return max(200, min(windowSize, collectionSize / 100))
    }
}
```

## Transition System

### Animation Architecture

- **TransitionSettings**: Configuration for 13 different effect types
- **ImageTransitionManager**: Handles SwiftUI AnyTransition creation and timing
- **Real-time Updates**: Settings changes immediately reflected in slideshow display

### Effect Types

```swift
public enum TransitionEffectType {
    case none, fade, slideLeft, slideRight, slideUp, slideDown,
         zoomIn, zoomOut, rotateClockwise, rotateCounterClockwise,
         pushLeft, pushRight, crossfade
}
```

### Integration Pattern

Views listen for transition setting changes and recreate transition managers:

```swift
NotificationCenter.default.addObserver(forName: .transitionSettingsChanged) { _ in
    self.transitionManager = ImageTransitionManager(transitionSettings: settings)
    // Trigger visual feedback for immediate effect preview
}
```

## Key Design Patterns

### Repository Pattern

- Abstract `SlideshowRepository` interface in Domain layer
- Concrete `FileSystemPhotoRepository` in Infrastructure layer
- Dependency injection through initializers

### Observer Pattern

- Settings managers use `@Published` properties for SwiftUI reactivity
- NotificationCenter for cross-component communication
- Virtual loader callbacks for UI integration

### Actor Pattern

- `VirtualImageLoader` and `ImageCache` use Swift actors for thread-safe access
- Concurrent image loading with Task groups and cancellation support

### Strategy Pattern

- Sorting algorithms implemented as enum cases with associated behavior
- Performance presets as static configurations
- Transition effects as pluggable implementations

## Performance Considerations

### Memory Management

- Automatic memory pressure detection and cache cleanup
- Configurable memory limits with aggressive/normal cleanup modes
- Window-based loading prevents memory explosion with large collections

### Concurrency

- Maximum concurrent loads configurable (1-50 range)
- Background preloading with priority queues
- Task cancellation for images outside current window

### Statistics & Monitoring

- Cache hit/miss ratios tracked for optimization
- Memory usage estimation and reporting
- Adaptive window sizing based on performance metrics

## File Organization

### Domain Layer (`PhotoSlideshow/Domain/`)

- `Entities/`: Core business objects (Photo, Slideshow)
- `ValueObjects/`: Immutable value types (Settings, ImageURL, etc.)
- `Repositories/`: Abstract data access interfaces
- `Services/`: Domain logic and business rules

### Infrastructure Layer (`PhotoSlideshow/Infrastructure/`)

- `Repositories/`: Concrete data access implementations
- `Services/`: Technical services (file access, image loading, caching)
- `Utils/`: Cross-cutting utilities (logging, window access)

### Application Layer (`PhotoSlideshow/Application/`)

- `ViewModels/`: Presentation logic coordinators
- `Services/`: Application services (keyboard handling, settings management)

### Presentation Layer (`PhotoSlideshow/Presentation/`)

- `Views/`: SwiftUI view implementations
- `Extensions/`: UI-specific extensions

## UI Control System Architecture

PhotoSlideshow features a sophisticated auto-hiding UI control system with excellent code separation and extensibility.

### Enhanced UI Control Components

#### 1. UIControlSettings & Manager

- **UIControlSettings**: Value object with comprehensive configuration options
- **UIControlSettingsManager**: Persistent settings with presets (default, minimal, always-visible, subtle)
- Auto-hide timing: 5s default, 2s when playing, 10s when paused
- Configurable blur effects and opacity levels

#### 2. State Management

- **UIControlStateManager**: Centralized state management with smart auto-hide logic
- Mouse interaction tracking with window boundary detection
- Keyboard interaction callbacks for seamless integration
- Progressive disclosure system (hover reveals details, tap toggles info)

#### 3. View Components

- **MinimalControlsView**: Clean bottom-center overlay with blur effects
- **DetailedInfoOverlay**: Expandable information panel with photo metadata
- **Enhanced KeyboardHandler**: Added shortcuts (I=info toggle, H=hide/show controls)

### Keyboard Shortcuts

- **Space**: Play/Pause slideshow
- **Arrow Keys**: Navigate photos (left/right, up/down)
- **I**: Toggle detailed info overlay
- **H**: Toggle controls visibility
- **Escape**: Stop/Pause slideshow
- **Cmd+,**: Open settings window

### Integration Pattern

```swift
// UI control state manager integrates with existing components
let uiControlStateManager = UIControlStateManager(
    uiControlSettings: uiControlSettings,
    slideshowViewModel: viewModel
)

// Keyboard handler callbacks notify UI state changes
keyboardHandler.onKeyboardInteraction = {
    uiControlStateManager.handleKeyboardInteraction()
}
```

## Development Notes

- **Security**: App uses sandboxing with secure file access bookmarks
- **Logging**: Comprehensive logging with both NSLog and os.log for debugging
- **Error Handling**: Custom SlideshowError types with detailed error contexts
- **State Management**: Careful @MainActor usage for UI thread safety
- **Testing**: Separate test targets for unit tests and UI tests

## Pending Minor Tasks

The following enhancement tasks remain for future development:

### Code Quality Improvements

1. **Fix SwiftUI Warnings**: Address onChange deprecations and actor isolation warnings
2. **Add Unit Tests**: Comprehensive testing for UIControlStateManager logic
3. **Performance Optimization**: Reduce timer overhead when controls are hidden
4. **Accessibility Support**: VoiceOver integration and keyboard navigation

### Enhanced Interaction Components

1. **InteractionZoneView.swift**: Invisible interaction areas for advanced gesture handling
2. **MouseTracker.swift**: Enhanced global mouse tracking with sensitivity controls
3. **InteractionDetector.swift**: Unified interaction detection system combining mouse, keyboard, and gestures
4. **AdaptiveTimer.swift**: Smart timer with context-aware delays and dynamic adjustment
5. **OverlayPositionManager.swift**: Precise positioning calculations for different screen sizes and resolutions
6. **BlurEffectManager.swift**: Advanced visual effects system with customizable blur styles

## Future Extension Roadmap

### Phase 1: Advanced Interaction Features

- **Gesture Support**: Pinch-to-zoom, two-finger scroll, swipe navigation
- **Touch Bar Integration**: MacBook Pro Touch Bar controls for slideshow navigation
- **Apple Remote Support**: Wireless remote control for presentation mode
- **Multi-Touch Trackpad**: Advanced gestures for photo manipulation

### Phase 2: Enhanced UI Customization

- **Theme System**: Dark/light/custom color schemes with user-defined palettes
- **Layout Presets**: Minimal, compact, full-featured control arrangements
- **User-Customizable Controls**: Drag-and-drop control arrangement editor
- **Adaptive UI**: Automatic layout adjustments based on screen size and orientation

### Phase 3: Smart Content Features

- **AI-Powered Categorization**: Automatic photo tagging and organization
- **Smart Collections**: Face recognition, location grouping, date-based collections
- **Intelligent Slideshow Pacing**: Automatic timing based on photo complexity and content
- **Content-Aware Transitions**: Transition effects that adapt to photo characteristics

### Phase 4: Professional Presentation Features

- **Multi-Monitor Support**: Presenter notes on secondary display
- **Audio Synchronization**: Slide transitions synchronized to background music
- **Video Export**: Export slideshows as video files with custom timings
- **Presentation Templates**: Pre-configured settings for different presentation types

### Phase 5: Integration & Sharing

- **iCloud Photo Library**: Seamless integration with Apple's photo ecosystem
- **Social Media Sharing**: Batch processing and direct sharing to social platforms
- **AirPlay Support**: Wireless presentation to Apple TV and compatible devices
- **Cloud Storage Integration**: Support for Dropbox, Google Drive, OneDrive

### Phase 6: Advanced Photography Features

- **RAW Image Support**: Professional photography workflow integration
- **Color Space Management**: Professional color accuracy for print and web
- **Metadata Preservation**: EXIF data viewing and editing capabilities
- **Batch Processing**: Mass photo operations and adjustments

### Extension Architecture Benefits

The current plugin-ready architecture supports:

- **Modular Components**: Each feature can be developed independently
- **Configuration-Driven Behavior**: Changes without code modifications
- **Protocol-Oriented Design**: Easy addition of new control types and interactions
- **Dependency Injection**: All components are testable and replaceable
- **Settings-Based Customization**: User preferences drive functionality

### Implementation Priority

**High Priority** (Core functionality improvements):

- Code quality improvements and warning fixes
- Unit test coverage for new UI components
- Performance optimization for large photo collections

**Medium Priority** (Enhanced user experience):

- Advanced interaction components (gesture support, adaptive timers)
- Theme system and UI customization options
- Multi-monitor and presentation features

**Low Priority** (Advanced features):

- AI-powered content organization
- Professional photography workflow integration
- Third-party service integrations

This roadmap ensures the PhotoSlideshow application remains maintainable, extensible, and aligned with modern macOS application development best practices.
