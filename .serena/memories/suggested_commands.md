# Development Commands for Swift Photos

## Build Commands
```bash
# Standard build
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" build

# Clean build
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" clean build

# Release build
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" -configuration Release build
```

## Testing Commands
```bash
# Run all tests
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" test -destination 'platform=macOS'

# Run UI tests only
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" -only-testing:SwiftPhotosUITests test

# Run unit tests only
xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" -only-testing:SwiftPhotosTests/SwiftPhotosTests test
```

## File Operations (macOS)
```bash
# List files
ls -la

# Find files
find . -name "*.swift" -type f

# Search content
grep -r "pattern" --include="*.swift" .

# Git operations
git status
git add .
git commit -m "message"
```

## Xcode Integration
- Open project: `open "Swift Photos.xcodeproj"`
- Build from command line for faster CI/CD
- Use scheme "Swift Photos" for all operations