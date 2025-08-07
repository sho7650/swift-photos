import Foundation
import AppKit
import ImageIO

public actor ImageLoader {
    private var activeOperations: Set<String> = []
    private let maxConcurrentOperations: Int
    private let maxImageSize: CGFloat
    
    public init(maxConcurrentOperations: Int = 3, maxImageSize: CGFloat = 2048) {
        self.maxConcurrentOperations = maxConcurrentOperations
        self.maxImageSize = maxImageSize
    }
    
    public func loadImage(from imageURL: ImageURL) async throws -> SendableImage {
        let key = imageURL.url.absoluteString
        
        guard !activeOperations.contains(key) else {
            while activeOperations.contains(key) {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            return try await loadImage(from: imageURL)
        }
        
        while activeOperations.count >= maxConcurrentOperations {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        
        activeOperations.insert(key)
        
        defer {
            activeOperations.remove(key)
        }
        
        do {
            let image = try await loadAndOptimizeImage(from: imageURL.url)
            return SendableImage(image)
        } catch {
            throw SlideshowError.loadingFailed(underlying: error)
        }
    }
    
    private func loadAndOptimizeImage(from url: URL) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                        continuation.resume(throwing: SlideshowError.loadingFailed(underlying: CocoaError(.fileReadCorruptFile)))
                        return
                    }
                    
                    let options: [CFString: Any] = [
                        kCGImageSourceThumbnailMaxPixelSize: self.maxImageSize,
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true
                    ]
                    
                    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                        continuation.resume(throwing: SlideshowError.loadingFailed(underlying: CocoaError(.fileReadCorruptFile)))
                        return
                    }
                    
                    let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: nsImage)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func extractMetadata(from url: URL) async throws -> Photo.PhotoMetadata? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    let creationDate = resourceValues.creationDate
                    
                    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
                        let metadata = Photo.PhotoMetadata(
                            fileSize: fileSize,
                            dimensions: CGSize.zero,
                            creationDate: creationDate,
                            colorSpace: nil
                        )
                        continuation.resume(returning: metadata)
                        return
                    }
                    
                    let width = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
                    let height = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
                    let dimensions = CGSize(width: width, height: height)
                    
                    let colorSpace = properties[kCGImagePropertyColorModel] as? String
                    
                    let metadata = Photo.PhotoMetadata(
                        fileSize: fileSize,
                        dimensions: dimensions,
                        creationDate: creationDate,
                        colorSpace: colorSpace
                    )
                    
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}