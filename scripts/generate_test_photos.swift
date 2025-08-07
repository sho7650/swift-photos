#!/usr/bin/env swift

import Foundation
import AppKit
import CoreImage

// Test Photo Generator for Swift Photos Functional Testing
// This script generates test photo collections of various sizes

print("🎨 Swift Photos Test Data Generator")
print("==================================\n")

// Configuration
struct TestConfig {
    let basePath: String
    let collections: [(name: String, count: Int, sizeRange: ClosedRange<Int>)]
    
    static let standard = TestConfig(
        basePath: NSHomeDirectory() + "/TestPhotos",
        collections: [
            ("Small_Collection", 25, 100...500),      // 25 photos, 100-500 KB each
            ("Medium_Collection", 250, 200...1000),   // 250 photos, 200KB-1MB each
            ("Large_Collection", 2500, 500...2000),   // 2,500 photos, 500KB-2MB each
            ("Massive_Collection", 10000, 100...500)  // 10,000 photos, 100-500KB each
        ]
    )
}

// Image generation utilities
class TestImageGenerator {
    
    static func generateTestImage(
        width: Int,
        height: Int,
        text: String,
        backgroundColor: NSColor,
        format: String = "jpg"
    ) -> Data? {
        
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        
        // Fill background
        backgroundColor.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        
        // Add some visual interest
        let circleCount = Int.random(in: 3...8)
        for _ in 0..<circleCount {
            let color = NSColor(
                red: CGFloat.random(in: 0...1),
                green: CGFloat.random(in: 0...1),
                blue: CGFloat.random(in: 0...1),
                alpha: 0.5
            )
            color.setFill()
            
            let radius = CGFloat.random(in: 50...200)
            let x = CGFloat.random(in: 0...CGFloat(width))
            let y = CGFloat.random(in: 0...CGFloat(height))
            
            let circle = NSBezierPath(
                ovalIn: NSRect(
                    x: x - radius/2,
                    y: y - radius/2,
                    width: radius,
                    height: radius
                )
            )
            circle.fill()
        }
        
        // Add text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -2.0
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (CGFloat(width) - textSize.width) / 2,
            y: (CGFloat(height) - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        
        // Convert to data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        switch format.lowercased() {
        case "jpg", "jpeg":
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        case "png":
            return bitmap.representation(using: .png, properties: [:])
        case "tiff":
            return bitmap.representation(using: .tiff, properties: [:])
        case "gif":
            return bitmap.representation(using: .gif, properties: [:])
        case "bmp":
            return bitmap.representation(using: .bmp, properties: [:])
        default:
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        }
    }
    
    static func generateSizeAdjustedImage(
        targetSizeKB: Int,
        text: String,
        format: String = "jpg"
    ) -> Data? {
        
        // Start with reasonable dimensions
        var width = 1920
        var height = 1080
        var quality: Float = 0.8
        
        // Generate initial image
        var imageData = generateTestImage(
            width: width,
            height: height,
            text: text,
            backgroundColor: randomColor(),
            format: format
        )
        
        // Adjust quality to reach target size
        let targetBytes = targetSizeKB * 1024
        let tolerance = 0.1 // 10% tolerance
        
        var attempts = 0
        while let data = imageData, attempts < 10 {
            let currentSize = data.count
            let ratio = Double(targetBytes) / Double(currentSize)
            
            if ratio > (1 - tolerance) && ratio < (1 + tolerance) {
                // Within tolerance
                return data
            }
            
            if ratio > 1 {
                // Image too small, increase dimensions
                width = Int(Double(width) * sqrt(ratio))
                height = Int(Double(height) * sqrt(ratio))
            } else {
                // Image too large, decrease quality or dimensions
                if quality > 0.3 {
                    quality *= Float(ratio)
                } else {
                    width = Int(Double(width) * sqrt(ratio))
                    height = Int(Double(height) * sqrt(ratio))
                }
            }
            
            // Regenerate with new parameters
            imageData = generateTestImage(
                width: min(max(width, 100), 4000),
                height: min(max(height, 100), 3000),
                text: text,
                backgroundColor: randomColor(),
                format: format
            )
            
            attempts += 1
        }
        
        return imageData
    }
    
    static func randomColor() -> NSColor {
        return NSColor(
            red: CGFloat.random(in: 0.2...0.8),
            green: CGFloat.random(in: 0.2...0.8),
            blue: CGFloat.random(in: 0.2...0.8),
            alpha: 1.0
        )
    }
}

// File system utilities
class TestDataManager {
    
    static func createDirectoryStructure(at basePath: String) throws {
        let fileManager = FileManager.default
        
        // Create base directory
        try fileManager.createDirectory(
            atPath: basePath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        print("📁 Created base directory: \(basePath)")
    }
    
    static func generateCollection(
        name: String,
        count: Int,
        sizeRange: ClosedRange<Int>,
        basePath: String
    ) throws {
        
        let collectionPath = basePath + "/" + name
        let fileManager = FileManager.default
        
        // Create collection directory
        try fileManager.createDirectory(
            atPath: collectionPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        print("\n📸 Generating \(name) (\(count) photos)...")
        
        // Variety of formats
        let formats = ["jpg", "jpg", "jpg", "png", "png", "tiff", "gif", "bmp"] // More JPGs
        
        // Progress tracking
        let progressInterval = max(1, count / 10)
        
        for i in 0..<count {
            // Show progress
            if i % progressInterval == 0 {
                let percent = Int((Double(i) / Double(count)) * 100)
                print("   Progress: \(percent)%", terminator: "\r")
                fflush(stdout)
            }
            
            let format = formats.randomElement() ?? "jpg"
            let targetSize = Int.random(in: sizeRange)
            let fileName = String(format: "IMG_%04d.\(format)", i + 1)
            let filePath = collectionPath + "/" + fileName
            
            // Generate image with metadata text
            let metadata = """
            Photo \(i + 1)
            Collection: \(name)
            Size: ~\(targetSize)KB
            Format: \(format.uppercased())
            """
            
            if let imageData = TestImageGenerator.generateSizeAdjustedImage(
                targetSizeKB: targetSize,
                text: metadata,
                format: format
            ) {
                try imageData.write(to: URL(fileURLWithPath: filePath))
            }
        }
        
        print("   ✅ Generated \(count) photos")
        
        // Create subdirectories for organization
        if count > 100 {
            try organizeIntoSubfolders(collectionPath: collectionPath)
        }
    }
    
    static func organizeIntoSubfolders(collectionPath: String) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(atPath: collectionPath)
            .filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") || $0.hasSuffix(".tiff") }
        
        let subfolders = ["Favorites", "Recent", "Archive"]
        
        for subfolder in subfolders {
            let subfolderPath = collectionPath + "/" + subfolder
            try fileManager.createDirectory(
                atPath: subfolderPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Move some files to subfolder
            let filesToMove = files.shuffled().prefix(files.count / 4)
            for file in filesToMove {
                let sourcePath = collectionPath + "/" + file
                let destPath = subfolderPath + "/" + file
                try? fileManager.moveItem(atPath: sourcePath, toPath: destPath)
            }
        }
        
        print("   📂 Organized into subfolders")
    }
    
    static func generateCorruptedFiles(basePath: String) throws {
        let corruptedPath = basePath + "/Corrupted_Files"
        let fileManager = FileManager.default
        
        try fileManager.createDirectory(
            atPath: corruptedPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        print("\n⚠️  Generating corrupted test files...")
        
        // 1. File with wrong extension
        let wrongExtData = "This is not an image".data(using: .utf8)!
        try wrongExtData.write(to: URL(fileURLWithPath: corruptedPath + "/not_an_image.jpg"))
        
        // 2. Truncated JPEG
        if let validImage = TestImageGenerator.generateTestImage(
            width: 1000,
            height: 1000,
            text: "Truncated",
            backgroundColor: .red
        ) {
            let truncated = validImage.prefix(validImage.count / 3)
            try truncated.write(to: URL(fileURLWithPath: corruptedPath + "/truncated.jpg"))
        }
        
        // 3. Empty file
        try Data().write(to: URL(fileURLWithPath: corruptedPath + "/empty.png"))
        
        // 4. Very large file name
        let longName = String(repeating: "long_filename_", count: 20) + ".jpg"
        if let largeNameImage = TestImageGenerator.generateTestImage(
            width: 500,
            height: 500,
            text: "Long Name",
            backgroundColor: .blue
        ) {
            try largeNameImage.write(to: URL(fileURLWithPath: corruptedPath + "/" + longName))
        }
        
        print("   ✅ Generated corrupted test files")
    }
    
    static func createSummaryReport(basePath: String, config: TestConfig) throws {
        var report = """
        # Swift Photos Test Data Summary
        
        Generated on: \(Date())
        Base Path: \(basePath)
        
        ## Collections Generated:
        
        """
        
        for collection in config.collections {
            report += "- **\(collection.name)**: \(collection.count) photos (\(collection.sizeRange)KB each)\n"
        }
        
        report += """
        
        ## Additional Test Data:
        
        - Corrupted files for error handling tests
        - Various image formats (JPEG, PNG, TIFF, GIF, BMP)
        - Organized subfolders for large collections
        
        ## Usage:
        
        1. Launch Swift Photos
        2. Select any collection folder
        3. Run through test scenarios in FUNCTIONAL_TESTING_GUIDE.md
        
        ## Cleanup:
        
        To remove test data:
        ```bash
        rm -rf ~/TestPhotos
        ```
        """
        
        let reportPath = basePath + "/README.md"
        try report.write(to: URL(fileURLWithPath: reportPath), atomically: true, encoding: .utf8)
        print("\n📄 Generated summary report: \(reportPath)")
    }
}

// Main execution
func main() {
    let config = TestConfig.standard
    
    do {
        // Create directory structure
        try TestDataManager.createDirectoryStructure(at: config.basePath)
        
        // Generate each collection
        for collection in config.collections {
            try TestDataManager.generateCollection(
                name: collection.name,
                count: collection.count,
                sizeRange: collection.sizeRange,
                basePath: config.basePath
            )
        }
        
        // Generate corrupted files for testing
        try TestDataManager.generateCorruptedFiles(basePath: config.basePath)
        
        // Create summary report
        try TestDataManager.createSummaryReport(basePath: config.basePath, config: config)
        
        print("\n✅ Test data generation complete!")
        print("📍 Location: \(config.basePath)")
        print("🚀 Ready for functional testing")
        
    } catch {
        print("\n❌ Error: \(error.localizedDescription)")
        exit(1)
    }
}

// Run the generator
main()