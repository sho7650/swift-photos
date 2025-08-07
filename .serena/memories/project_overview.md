# Swift Photos Project Overview

## Purpose
SwiftUI-based macOS photo slideshow application with sophisticated features for managing large photo collections (tested up to 100k+ photos).

## Tech Stack
- **Platform**: macOS 14.0+
- **Language**: Swift 6.0+
- **Framework**: SwiftUI
- **Architecture**: Clean Architecture with MVVM pattern
- **Build System**: Xcode project (Swift Photos.xcodeproj)

## Key Features
- Large photo collection handling with virtual loading
- Multiple caching tiers (ImageCache, LRUImageCache, VirtualImageLoader)
- Advanced UI control system with auto-hiding
- Transition effects system
- Settings management with Modern* managers
- Performance optimization for different collection sizes

## Project Structure
- `SwiftPhotos/`: Main source code
  - `Application/`: ViewModels and Services
  - `Domain/`: Entities, Value Objects, Repositories
  - `Infrastructure/`: File System, Image Loading, Caching
  - `Presentation/`: SwiftUI Views and Extensions
- `SwiftPhotosTests/`: Unit tests
- `SwiftPhotosUITests/`: UI tests
- `principles/`: Development guidelines
- `docs/`: Documentation

## Current Status
- Using Swift 6 with @Observable pattern
- Modern* settings managers replacing legacy implementations
- Unified components consolidating redundant implementations