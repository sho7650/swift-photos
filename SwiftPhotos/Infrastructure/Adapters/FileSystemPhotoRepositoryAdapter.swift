import Foundation
import AppKit

/// Adapter that bridges the existing FileSystemPhotoRepository with the new ImageRepositoryProtocol
/// This enables backward compatibility while migrating to the new Repository pattern
public actor FileSystemPhotoRepositoryAdapter: ImageRepositoryProtocol {
    
    // MARK: - Properties
    private let legacyRepository: FileSystemPhotoRepository
    private let metadataRepository: any MetadataRepositoryProtocol
    
    // MARK: - Performance Tracking
    private var operationCount = 0
    private var successCount = 0
    private var errorCount = 0
    private var totalResponseTime: TimeInterval = 0
    private var lastOperationTime = Date()
    
    // MARK: - Supported Formats
    public let supportedImageFormats: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"
    ]
    
    // MARK: - Initialization
    public init(
        legacyRepository: FileSystemPhotoRepository,
        metadataRepository: any MetadataRepositoryProtocol
    ) {
        self.legacyRepository = legacyRepository
        self.metadataRepository = metadataRepository
        ProductionLogger.info("FileSystemPhotoRepositoryAdapter: Initialized with legacy repository bridge")
    }
    
    // MARK: - ImageRepositoryProtocol Implementation
    
    public func loadImage(from url: URL) async throws -> SendableImage {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Loading image from \(url.lastPathComponent)")
        
        do {
            // Create a Photo object for the legacy repository
            let imageURL = try ImageURL(url)
            let photo = Photo(imageURL: imageURL)
            
            // Use the legacy repository to load the image
            let loadedPhoto = try await legacyRepository.loadImage(for: photo)
            
            // Extract the loaded image from the photo
            switch loadedPhoto.loadState {
            case .loaded(let image):
                let sendableImage = SendableImage(image)
                
                // Update performance metrics
                successCount += 1
                totalResponseTime += Date().timeIntervalSince(startTime)
                lastOperationTime = Date()
                
                ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Successfully loaded image \(url.lastPathComponent)")
                return sendableImage
                
            case .failed(let error):
                errorCount += 1
                lastOperationTime = Date()
                ProductionLogger.error("FileSystemPhotoRepositoryAdapter: Failed to load image \(url.lastPathComponent): \(error)")
                throw error
                
            case .loading, .notLoaded:
                let error = RepositoryError.loadingFailed(url: url, reason: "Image loading incomplete")
                errorCount += 1
                lastOperationTime = Date()
                throw error
            }
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("FileSystemPhotoRepositoryAdapter: Error loading image from \(url.lastPathComponent): \(error)")
            throw RepositoryError.loadingFailed(url: url, reason: error.localizedDescription)
        }
    }
    
    public func loadImageURLs(from folder: URL) async throws -> [ImageURL] {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Loading image URLs from \(folder.path)")
        
        do {
            // Use the legacy repository to load photos
            let photos = try await legacyRepository.loadPhotos(from: folder)
            
            // Extract image URLs from the photos
            let imageURLs = photos.map { $0.imageURL }
            
            // Update performance metrics
            successCount += 1
            totalResponseTime += Date().timeIntervalSince(startTime)
            lastOperationTime = Date()
            
            ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Successfully loaded \(imageURLs.count) image URLs")
            return imageURLs
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("FileSystemPhotoRepositoryAdapter: Failed to load image URLs from \(folder.path): \(error)")
            throw RepositoryError.loadingFailed(url: folder, reason: error.localizedDescription)
        }
    }
    
    public func loadMetadata(for url: URL) async throws -> ImageMetadata {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Loading metadata for \(url.lastPathComponent)")
        
        do {
            // Create a Photo object for the legacy repository
            let imageURL = try ImageURL(url)
            let photo = Photo(imageURL: imageURL)
            
            // Try to get metadata from the legacy repository first
            if let legacyMetadata = try await legacyRepository.loadMetadata(for: photo) {
                // Convert legacy metadata to new format
                let imageMetadata = convertLegacyMetadata(legacyMetadata, for: url)
                
                successCount += 1
                totalResponseTime += Date().timeIntervalSince(startTime)
                lastOperationTime = Date()
                
                return imageMetadata
            }
            
            // Fallback to new metadata repository
            let metadata = try await metadataRepository.extractMetadata(from: url)
            
            successCount += 1
            totalResponseTime += Date().timeIntervalSince(startTime)
            lastOperationTime = Date()
            
            ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Successfully loaded metadata for \(url.lastPathComponent)")
            return metadata
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("FileSystemPhotoRepositoryAdapter: Failed to load metadata for \(url.lastPathComponent): \(error)")
            throw RepositoryError.metadataExtractionFailed(url: url, reason: error.localizedDescription)
        }
    }
    
    public func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Generating thumbnail for \(url.lastPathComponent)")
        
        do {
            // Load the full image first
            let fullImage = try await loadImage(from: url)
            
            // Generate thumbnail from the full image
            let thumbnailImage = try await generateThumbnailFromImage(fullImage.nsImage, targetSize: size)
            let sendableThumbnail = SendableImage(thumbnailImage)
            
            successCount += 1
            totalResponseTime += Date().timeIntervalSince(startTime)
            lastOperationTime = Date()
            
            ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Successfully generated thumbnail for \(url.lastPathComponent)")
            return sendableThumbnail
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("FileSystemPhotoRepositoryAdapter: Failed to generate thumbnail for \(url.lastPathComponent): \(error)")
            throw error
        }
    }
    
    public func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL] {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Searching images in \(folder.path)")
        
        do {
            // Load all image URLs from the folder
            let allImageURLs = try await loadImageURLs(from: folder)
            
            // Apply search criteria
            let filteredURLs = try await filterImageURLs(allImageURLs, using: criteria)
            
            successCount += 1
            totalResponseTime += Date().timeIntervalSince(startTime)
            lastOperationTime = Date()
            
            ProductionLogger.debug("FileSystemPhotoRepositoryAdapter: Found \(filteredURLs.count) images matching criteria")
            return filteredURLs
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("FileSystemPhotoRepositoryAdapter: Search failed in \(folder.path): \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Convert legacy Photo.PhotoMetadata to new ImageMetadata format
    private func convertLegacyMetadata(_ legacyMetadata: Photo.PhotoMetadata, for url: URL) -> ImageMetadata {
        var exifData: [String: String] = [:]
        var iptcData: [String: String] = [:]
        var xmpData: [String: String] = [:]
        
        // Convert legacy metadata if available
        if let captureDate = legacyMetadata.captureDate {
            exifData["DateTimeOriginal"] = ISO8601DateFormatter().string(from: captureDate)
        }
        
        if let gpsLocation = legacyMetadata.gpsLocation {
            exifData["GPSLatitude"] = String(gpsLocation.latitude)
            exifData["GPSLongitude"] = String(gpsLocation.longitude)
        }
        
        if let cameraInfo = legacyMetadata.cameraInfo {
            exifData["Make"] = cameraInfo.make
            exifData["Model"] = cameraInfo.model
            if let focalLength = cameraInfo.focalLength {
                exifData["FocalLength"] = String(focalLength)
            }
            if let aperture = cameraInfo.aperture {
                exifData["FNumber"] = String(aperture)
            }
            if let shutterSpeed = cameraInfo.shutterSpeed {
                exifData["ExposureTime"] = String(shutterSpeed)
            }
            if let iso = cameraInfo.iso {
                exifData["ISOSpeedRatings"] = String(iso)
            }
        }
        
        let basicInfo = ImageBasicInfo(
            width: legacyMetadata.imageSize?.width ?? 0,
            height: legacyMetadata.imageSize?.height ?? 0,
            fileSize: legacyMetadata.fileSize,
            colorSpace: legacyMetadata.colorProfile?.colorSpace,
            bitDepth: legacyMetadata.colorProfile?.bitsPerChannel ?? 8,
            hasAlpha: legacyMetadata.colorProfile?.hasAlpha ?? false,
            format: url.pathExtension.lowercased()
        )
        
        return ImageMetadata(
            url: url,
            basicInfo: basicInfo,
            exifData: exifData,
            iptcData: iptcData,
            xmpData: xmpData,
            extractionDate: Date(),
            source: .fileSystem
        )
    }
    
    /// Generate thumbnail from full image
    private func generateThumbnailFromImage(_ image: NSImage, targetSize: CGSize) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnailImage = NSImage(size: targetSize)
                thumbnailImage.lockFocus()
                
                let sourceRect = NSRect(origin: .zero, size: image.size)
                let targetRect = NSRect(origin: .zero, size: targetSize)
                
                image.draw(in: targetRect, from: sourceRect, operation: .copy, fraction: 1.0)
                thumbnailImage.unlockFocus()
                
                continuation.resume(returning: thumbnailImage)
            }
        }
    }
    
    /// Filter image URLs using search criteria
    private func filterImageURLs(_ urls: [ImageURL], using criteria: SearchCriteria) async throws -> [ImageURL] {
        var filteredURLs: [ImageURL] = []
        
        for imageURL in urls {
            let url = imageURL.url
            var matchesCriteria = true
            
            // Filter by file extension
            if !criteria.fileExtensions.isEmpty {
                let fileExtension = url.pathExtension.lowercased()
                if !criteria.fileExtensions.contains(fileExtension) {
                    matchesCriteria = false
                }
            }
            
            // Filter by filename pattern
            if let namePattern = criteria.namePattern {
                let fileName = url.deletingPathExtension().lastPathComponent
                if !fileName.localizedCaseInsensitiveContains(namePattern) {
                    matchesCriteria = false
                }
            }
            
            // Filter by date range (requires file attributes)
            if let dateRange = criteria.dateRange {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let creationDate = resourceValues.creationDate ?? Date.distantPast
                    let modificationDate = resourceValues.contentModificationDate ?? Date.distantPast
                    let relevantDate = max(creationDate, modificationDate)
                    
                    if relevantDate < dateRange.lowerBound || relevantDate > dateRange.upperBound {
                        matchesCriteria = false
                    }
                } catch {
                    // If we can't get dates, exclude from date-based searches
                    matchesCriteria = false
                }
            }
            
            // Filter by file size range
            if let sizeRange = criteria.sizeRange {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    
                    if fileSize < sizeRange.lowerBound || fileSize > sizeRange.upperBound {
                        matchesCriteria = false
                    }
                } catch {
                    // If we can't get size, exclude from size-based searches
                    matchesCriteria = false
                }
            }
            
            if matchesCriteria {
                filteredURLs.append(imageURL)
            }
        }
        
        return filteredURLs
    }
    
    // MARK: - Performance Monitoring
    
    public func getPerformanceMetrics() async -> RepositoryMetrics {
        let averageResponseTime = operationCount > 0 ? totalResponseTime / Double(operationCount) : 0.0
        
        return RepositoryMetrics(
            operationCount: operationCount,
            successCount: successCount,
            errorCount: errorCount,
            averageResponseTime: averageResponseTime,
            cacheHitRate: 0.0, // Legacy repository doesn't provide cache info
            totalDataTransferred: 0, // Not tracked in legacy repository
            lastOperation: lastOperationTime
        )
    }
    
    // MARK: - Configuration
    
    /// Update the adapter configuration
    public func updateConfiguration(_ configuration: AdapterConfiguration) async {
        ProductionLogger.info("FileSystemPhotoRepositoryAdapter: Configuration updated")
        // Configuration updates would be applied here if needed
    }
}

// MARK: - Supporting Types

/// Configuration for the adapter
public struct AdapterConfiguration: Sendable {
    public let enableThumbnailGeneration: Bool
    public let defaultThumbnailSize: CGSize
    public let enableMetadataCaching: Bool
    public let searchTimeout: TimeInterval
    
    public init(
        enableThumbnailGeneration: Bool = true,
        defaultThumbnailSize: CGSize = CGSize(width: 200, height: 200),
        enableMetadataCaching: Bool = true,
        searchTimeout: TimeInterval = 30.0
    ) {
        self.enableThumbnailGeneration = enableThumbnailGeneration
        self.defaultThumbnailSize = defaultThumbnailSize
        self.enableMetadataCaching = enableMetadataCaching
        self.searchTimeout = searchTimeout
    }
    
    public static let `default` = AdapterConfiguration()
}

// MARK: - Repository Error Extension

extension RepositoryError {
    static func loadingFailed(url: URL, reason: String) -> RepositoryError {
        return .operationFailed(operation: "loadImage", details: "Failed to load \(url.lastPathComponent): \(reason)")
    }
    
    static func metadataExtractionFailed(url: URL, reason: String) -> RepositoryError {
        return .operationFailed(operation: "extractMetadata", details: "Failed to extract metadata for \(url.lastPathComponent): \(reason)")
    }
}