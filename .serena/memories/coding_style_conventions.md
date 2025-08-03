# Swift Photos Coding Style & Conventions

## Architecture
- **Clean Architecture** with MVVM pattern
- Clear separation of concerns across layers
- Repository pattern for data access
- Observer pattern with @Observable

## Swift 6 Standards
- Use `@Observable` instead of `@ObservableObject`
- Proper `@MainActor` isolation for UI
- Actor pattern for thread-safe services
- Async/await for asynchronous operations

## Naming Conventions
- Types: PascalCase (PhotoMetadata, SlideshowViewModel)
- Properties/Methods: camelCase (currentIndex, loadPhotos)
- Constants: camelCase (maximumPhotoCount)
- Protocols: PascalCase with Protocol suffix (PhotoServiceProtocol)

## Code Organization
- Use MARK: comments for section headers
- Group properties before methods
- Private methods at bottom
- Extensions in separate files when possible

## Modern Components
- Prefer Modern* managers over legacy implementations:
  - ModernPerformanceSettingsManager
  - ModernSlideshowSettingsManager  
  - ModernSortSettingsManager
  - ModernTransitionSettingsManager
  - ModernUIControlSettingsManager

## Memory Management
- Use weak references in closures
- Implement proper cleanup in deinit
- Be mindful of retain cycles