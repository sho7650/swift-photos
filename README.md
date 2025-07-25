# Swift Photos

A modern, high-performance photo slideshow application for macOS built with Swift and SwiftUI. Designed to handle massive photo collections (100k+ images) with sophisticated caching and virtual loading systems.

![Swift Photos Banner](docs/images/banner.png)

## ✨ Features

### 🖼️ Advanced Photo Management
- **Massive Collection Support**: Handle up to 100,000+ photos with ease
- **Smart Virtual Loading**: Efficient memory management with sliding window caching
- **Instant First Image Display**: Priority loading for immediate visual feedback
- **Multiple Sorting Options**: Name, date, size, or random with fixed seed

### 🎬 Rich Slideshow Experience
- **13 Transition Effects**: Fade, slide, zoom, rotate, push, and crossfade transitions
- **Adaptive Performance**: Automatic settings optimization based on collection size
- **Background Preloading**: Smart image caching with priority queues
- **Auto-Hide UI**: Cursor and controls automatically hide during playback

### 🎨 Modern Interface
- **Clean Design**: Minimalist interface that focuses on your photos
- **Detailed Info Overlay**: Photo metadata, dimensions, and file information
- **Progressive Disclosure**: Hover reveals details, tap toggles info
- **Customizable Controls**: Configurable auto-hide timing and visual effects

### ⚡ Performance Optimized
- **Clean Architecture**: Domain-driven design with proper separation of concerns
- **Swift 6 Compliance**: Modern `@Observable` pattern for better performance
- **Actor-Based Concurrency**: Thread-safe image loading and caching
- **Memory Pressure Handling**: Automatic cache cleanup and adaptive sizing

## 📱 Screenshots

| Main Interface | Transition Effects | Settings Panel |
|----------------|-------------------|----------------|
| ![Main](docs/images/main.png) | ![Transitions](docs/images/transitions.png) | ![Settings](docs/images/settings.png) |

## 🚀 Installation

### Requirements
- macOS 12.0 or later
- Xcode 15.0 or later (for building from source)

### Download
1. Download the latest release from [Releases](https://github.com/username/swift-photos/releases)
2. Mount the DMG file
3. Drag "Swift Photos.app" to your Applications folder

### Build from Source
```bash
git clone https://github.com/username/swift-photos.git
cd swift-photos
open "Swift Photos.xcodeproj"
```

Build and run using Xcode (⌘+R) or command line:
```bash
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" build
```

## 🎯 Usage

### Getting Started
1. **Open a Folder**: Use ⌘+O or File → Open Folder to select a directory containing images
2. **Navigate Photos**: Use arrow keys (←/→ or ↑/↓) or click controls
3. **Start Slideshow**: Press Space to begin automatic playback
4. **Toggle Info**: Press I to show/hide detailed photo information
5. **Configure Settings**: Press ⌘+, to open the settings window

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause slideshow |
| `←/→` | Previous/Next photo |
| `↑/↓` | Previous/Next photo |
| `I` | Toggle detailed info overlay |
| `H` | Toggle controls visibility |
| `Esc` | Stop/Pause slideshow |
| `⌘+O` | Open folder |
| `⌘+,` | Open settings |

### Performance Recommendations

| Collection Size | Recommended Settings | Expected Performance |
|----------------|---------------------|---------------------|
| 0-100 photos | Standard (50 image window) | Instant loading |
| 101-1,000 photos | High performance (200 image window) | < 2s initial load |
| 1,001-10,000 photos | Unlimited (1,000 image window, 16GB) | < 5s initial load |
| 10,001+ photos | Extreme (5,000 image window, 32GB) | < 10s initial load |

## 🏗️ Architecture

Swift Photos is built using **Clean Architecture** principles with clear separation between layers:

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

### Key Components

#### Domain Layer
- **Photo**: Core entity with state management (`notLoaded`, `loading`, `loaded`, `failed`)
- **Slideshow**: Manages photo collections, playback state, and navigation
- **PhotoMetadata**: File information (size, dimensions, dates, color space)

#### Application Layer
- **ModernSlideshowViewModel**: Main application state with `@Observable` pattern
- **Settings Managers**: Performance, Slideshow, Sort, Transition, and UI Control settings
- **UIControlStateManager**: Sophisticated auto-hiding UI with mouse cursor control

#### Infrastructure Layer
- **VirtualImageLoader**: Actor-based sliding window loader for massive collections
- **BackgroundPreloader**: Priority queue system for adjacent image preloading
- **ImageCache & LRUImageCache**: Multi-tier caching with cost-based eviction
- **SecureFileAccess**: Sandboxed file access with security bookmarks

## 🛠️ Development

### Tech Stack
- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Architecture**: Clean Architecture + Domain-Driven Design
- **Concurrency**: Swift Actors and async/await
- **State Management**: `@Observable` (Swift 6)
- **Persistence**: UserDefaults with JSON encoding

### Project Structure
```
SwiftPhotos/
├── Domain/              # Business logic and entities
│   ├── Entities/        # Core business objects
│   ├── ValueObjects/    # Immutable value types
│   ├── Repositories/    # Data access interfaces
│   └── Services/        # Domain services
├── Application/         # Application coordination
│   ├── ViewModels/      # Presentation logic
│   └── Services/        # Application services
├── Infrastructure/     # External concerns
│   ├── Repositories/    # Data access implementations
│   └── Services/        # Technical services
└── Presentation/       # UI layer
    ├── Views/          # SwiftUI views
    └── Extensions/     # UI extensions
```

### Building and Testing
```bash
# Build
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" build

# Run tests
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" test -destination 'platform=macOS'

# Clean build
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" clean build
```

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📊 Performance Metrics

Swift Photos is optimized for performance across different collection sizes:

- **Memory Usage**: Adaptive based on collection size (2GB-32GB range)
- **Load Times**: < 10 seconds for 50,000+ photos
- **Cache Hit Rate**: 90%+ for typical navigation patterns
- **CPU Usage**: < 20% during slideshow playback

## 🔒 Security & Privacy

- **Sandboxed Application**: Full macOS App Sandbox compliance
- **Security-Scoped Bookmarks**: Secure access to user-selected folders
- **No Network Access**: All processing happens locally
- **No Data Collection**: No analytics or telemetry

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with Apple's modern development frameworks
- Inspired by the need for professional photo presentation tools
- Thanks to the Swift community for excellent tooling and resources

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/username/swift-photos/issues)
- **Discussions**: [GitHub Discussions](https://github.com/username/swift-photos/discussions)
- **Documentation**: [Wiki](https://github.com/username/swift-photos/wiki)

---

Made with ❤️ by [Sho Kisaragi](https://github.com/username)