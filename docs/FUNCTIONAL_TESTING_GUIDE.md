# Swift Photos - Functional Testing Guide

## Repository Pattern Integration Testing

This guide provides comprehensive test scenarios for validating the Repository pattern integration with real photo collections.

## Table of Contents

1. [Test Environment Setup](#test-environment-setup)
2. [Test Scenarios](#test-scenarios)
3. [Expected Behaviors](#expected-behaviors)
4. [Performance Validation](#performance-validation)
5. [Error Handling Tests](#error-handling-tests)
6. [Migration Testing](#migration-testing)

## Test Environment Setup

### Prerequisites

1. **macOS 14.0+** with Swift 6
2. **Test Photo Collections**:
   - Small collection: 10-50 photos
   - Medium collection: 100-500 photos
   - Large collection: 1,000-5,000 photos
   - Massive collection: 10,000+ photos
3. **Various Image Formats**:
   - JPEG/JPG
   - PNG
   - HEIC/HEIF
   - TIFF
   - GIF
   - BMP
   - WebP

### Test Photo Directory Structure

```
~/TestPhotos/
├── Small_Collection/          # 10-50 photos
│   ├── JPEG_Photos/
│   ├── PNG_Photos/
│   └── Mixed_Formats/
├── Medium_Collection/         # 100-500 photos
│   ├── Vacation_2024/
│   ├── Family_Events/
│   └── Nature_Photos/
├── Large_Collection/          # 1,000-5,000 photos
│   ├── Year_2023/
│   ├── Year_2024/
│   └── Professional_Shots/
└── Massive_Collection/        # 10,000+ photos
    ├── Complete_Archive/
    └── All_Photos/
```

## Test Scenarios

### 1. Initial Application Launch

**Test ID**: FUNC-001  
**Priority**: High  
**Pattern**: Both (Repository & Legacy)

**Steps**:
1. Launch Swift Photos application
2. Observe initial UI state
3. Check console logs for Repository pattern initialization

**Expected Results**:
- Application launches successfully
- EnhancedContentView displays initialization screen
- Console shows: "ViewModelFactory: Creating Enhanced ViewModel with Repository pattern"
- No errors or warnings in console

### 2. Small Collection Loading (Repository Pattern)

**Test ID**: FUNC-002  
**Priority**: High  
**Pattern**: Repository

**Steps**:
1. Click "Select Folder" button
2. Navigate to Small_Collection folder (10-50 photos)
3. Select folder and grant access
4. Observe loading behavior

**Expected Results**:
- Repository pattern activates (green indicator in UI)
- Photos load progressively
- All image formats supported
- Loading completes in < 2 seconds
- Memory usage remains under 200MB

### 3. Large Collection Loading (Repository Pattern)

**Test ID**: FUNC-003  
**Priority**: High  
**Pattern**: Repository

**Steps**:
1. Click "Select Folder" button
2. Navigate to Large_Collection folder (1,000-5,000 photos)
3. Select folder and grant access
4. Observe loading and memory behavior

**Expected Results**:
- Repository pattern maintains performance
- Virtual loading activates for large collection
- Initial photos display within 1-2 seconds
- Memory usage stays within configured limits
- Smooth scrolling through photos

### 4. Pattern Switching Test

**Test ID**: FUNC-004  
**Priority**: High  
**Pattern**: Both

**Steps**:
1. Load Medium_Collection with Repository pattern
2. Open Settings > Advanced
3. Toggle "Use Repository Pattern" to OFF
4. Reload the same folder

**Expected Results**:
- System switches to Legacy pattern (orange indicator)
- Photos reload successfully
- Performance characteristics change
- No data loss or corruption

### 5. Mixed Format Support

**Test ID**: FUNC-005  
**Priority**: Medium  
**Pattern**: Repository

**Steps**:
1. Create test folder with one of each format:
   - photo.jpg
   - image.png
   - picture.heic
   - graphic.tiff
   - animation.gif
   - bitmap.bmp
   - modern.webp
2. Load folder with Repository pattern
3. Navigate through all images

**Expected Results**:
- All formats load successfully
- Metadata extracted for each format
- No loading errors
- Proper display of each image type

### 6. Slideshow Playback Test

**Test ID**: FUNC-006  
**Priority**: High  
**Pattern**: Both

**Steps**:
1. Load Medium_Collection
2. Press Space to start slideshow
3. Let it run for 10 transitions
4. Test controls:
   - Pause (Space)
   - Next (Right Arrow)
   - Previous (Left Arrow)
   - Stop (Escape)

**Expected Results**:
- Smooth transitions between photos
- Configured transition effects apply
- No memory leaks during playback
- Controls respond immediately

### 7. Memory Pressure Test

**Test ID**: FUNC-007  
**Priority**: High  
**Pattern**: Repository

**Steps**:
1. Load Massive_Collection (10,000+ photos)
2. Navigate rapidly through photos
3. Monitor memory usage in Activity Monitor
4. Continue for 5 minutes

**Expected Results**:
- Memory usage stays within limits
- Automatic cache cleanup occurs
- No crashes or freezes
- Fallback to Legacy if memory critical

### 8. Error Recovery Test

**Test ID**: FUNC-008  
**Priority**: Medium  
**Pattern**: Repository

**Steps**:
1. Load folder with some corrupted images
2. Include files with wrong extensions
3. Add very large images (>50MB)
4. Observe error handling

**Expected Results**:
- Corrupted images show error placeholder
- System continues loading other images
- Error count displayed in UI
- Can retry failed images

### 9. Search and Filter Test

**Test ID**: FUNC-009  
**Priority**: Medium  
**Pattern**: Repository

**Steps**:
1. Load Large_Collection
2. Use search to filter by:
   - Filename pattern
   - Date range
   - File size
   - File type
3. Combine multiple filters

**Expected Results**:
- Search results appear quickly
- Filters work correctly
- Can clear filters
- Performance remains good

### 10. Metadata Extraction Test

**Test ID**: FUNC-010  
**Priority**: Low  
**Pattern**: Repository

**Steps**:
1. Load photos with rich EXIF data
2. Press 'I' to show info overlay
3. Check displayed metadata:
   - Camera info
   - Date taken
   - GPS location
   - Exposure settings

**Expected Results**:
- Metadata displays correctly
- Missing data handled gracefully
- Performance not impacted
- All standard EXIF fields shown

## Expected Behaviors

### Repository Pattern Indicators

✅ **Healthy Repository Pattern**:
- Green status indicator
- "Repository Mode" label visible
- Fast initial load
- Efficient memory usage
- Advanced features available

⚠️ **Degraded Repository Pattern**:
- Orange status indicator
- Reduced feature set
- May switch to Legacy automatically
- Warning in console logs

❌ **Repository Pattern Failure**:
- Automatic fallback to Legacy
- Error message in UI
- Console shows fallback reason
- Features limited to Legacy set

### Performance Expectations

| Collection Size | Load Time | Memory Usage | Pattern |
|----------------|-----------|--------------|---------|
| 10-50 photos | < 1s | < 200MB | Either |
| 100-500 photos | < 3s | < 500MB | Either |
| 1,000-5,000 photos | < 5s | < 1GB | Repository |
| 10,000+ photos | < 10s | < 2GB | Repository |

## Performance Validation

### Metrics to Monitor

1. **Load Time**: Time from folder selection to first photo display
2. **Memory Usage**: Peak and sustained memory consumption
3. **CPU Usage**: Should remain under 50% during normal operation
4. **Frame Rate**: Smooth 60 FPS during transitions
5. **Cache Hit Rate**: Should exceed 80% after initial load

### Performance Testing Tools

```bash
# Monitor memory usage
sudo fs_usage -w -f filesys Swift\ Photos

# Track system calls
sudo dtruss -p [PID]

# Analyze performance
instruments -t "Time Profiler" Swift\ Photos.app
```

## Error Handling Tests

### Common Error Scenarios

1. **Access Denied**:
   - Select folder without permissions
   - Verify graceful error message
   - Can retry after granting access

2. **Corrupted Images**:
   - Include damaged JPEG files
   - System should skip and continue
   - Error count in UI

3. **Memory Pressure**:
   - Load massive collection on low-memory system
   - Should trigger cache cleanup
   - May fallback to Legacy mode

4. **Network Volumes**:
   - Load photos from network share
   - Should handle latency
   - Timeout handling works

## Migration Testing

### Repository to Legacy Migration

1. Start with Repository pattern
2. Simulate conditions for fallback:
   - High memory pressure
   - Repository errors
   - User preference change
3. Verify seamless transition
4. No data loss during switch

### Legacy to Repository Migration

1. Start with Legacy pattern
2. Enable Repository in settings
3. Reload photo collection
4. Verify enhanced features activate
5. Check performance improvement

## Test Reporting

### Test Report Template

```markdown
Test ID: [FUNC-XXX]
Date: [YYYY-MM-DD]
Tester: [Name]
Build: [Version]

Configuration:
- macOS Version: [XX.X]
- Machine: [Model]
- RAM: [Size]
- Photo Count: [Number]

Results:
- [ ] Passed
- [ ] Failed
- [ ] Partial

Notes:
[Observations and issues]

Screenshots:
[Attach if relevant]
```

## Automated Testing

For continuous validation, use the following test scripts:

### Basic Functional Test

```swift
// SwiftPhotosTests/FunctionalTests.swift
func testRepositoryPatternActivation() async {
    let viewModel = await ViewModelFactory.createSlideshowViewModel(...)
    XCTAssertTrue(viewModel is EnhancedModernSlideshowViewModel)
}

func testLargeColl
ectionPerformance() async {
    // Performance test implementation
}
```

### UI Testing

```swift
// SwiftPhotosUITests/RepositoryPatternUITests.swift
func testRepositoryIndicatorVisible() {
    let app = XCUIApplication()
    app.launch()
    
    // Select folder with photos
    app.buttons["Select Folder"].tap()
    
    // Verify Repository indicator
    XCTAssertTrue(app.staticTexts["Repository Mode"].exists)
}
```

## Troubleshooting

### Common Issues

1. **Repository Pattern Not Activating**:
   - Check console for initialization errors
   - Verify Repository components loaded
   - Check health status in logs

2. **Poor Performance**:
   - Verify performance settings
   - Check for memory pressure
   - Monitor cache effectiveness

3. **Crashes or Freezes**:
   - Collect crash logs
   - Check for memory leaks
   - Verify error handling

### Debug Commands

```bash
# Enable verbose logging
defaults write com.swiftphotos debug.verboseLogging -bool YES

# Force Repository pattern
defaults write com.swiftphotos forceRepositoryPattern -bool YES

# Reset all settings
defaults delete com.swiftphotos
```

## Conclusion

This functional testing guide ensures comprehensive validation of the Repository pattern integration. Regular testing with real photo collections helps maintain quality and performance standards as the application evolves.