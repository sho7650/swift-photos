# Task Completion Checklist for Swift Photos

## After Code Changes
1. **Build Verification**
   ```bash
   xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" build
   ```

2. **Run Tests**
   ```bash
   # Unit tests
   xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" -only-testing:SwiftPhotosTests test
   
   # UI tests (if UI changes made)
   xcodebuild -project "Swift Photos.xcodeproj" -scheme "Swift Photos" -only-testing:SwiftPhotosUITests test
   ```

3. **Code Quality Checks**
   - Ensure Swift 6 compliance (no concurrency warnings)
   - Verify @MainActor isolation for UI code
   - Check for retain cycles in closures
   - Validate Modern* manager usage over legacy

4. **Architecture Compliance**
   - Follow Clean Architecture layers
   - Use proper dependency injection
   - Implement error handling
   - Add MARK: comments for organization

5. **Performance Considerations**
   - Memory management for large collections
   - Proper image caching
   - Actor usage for thread safety

## Before Commit
- Clean build passes
- Tests pass
- No compiler warnings
- Code follows style conventions