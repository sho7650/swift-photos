//
//  UnifiedFileSystemImageRepository.swift
//  Swift Photos
//
//  Unified file system image repository implementation
//  Consolidates FileSystemPhotoRepository and LocalImageRepository functionality
//  Phase 4.1b: Repository Layer Consolidation - Implementation Consolidation
//

import Foundation
import AppKit
import ImageIO

/// Unified file system implementation for image repository operations
public final class UnifiedFileSystemImageRepository: UnifiedImageRepository, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let fileAccess: SecureFileAccess
    private let imageLoader: ImageLoader
    private let cache: ImageCacheRepository?
    private let localizationService: LocalizationService?
    
    // MARK: - Configuration
    
    private let supportedImageFormats: Set<String>
    private let maxConcurrentLoads: Int
    
    // MARK: - Statistics
    
    private let metricsTracker: RepositoryMetricsTracker
    
    // MARK: - Initialization
    
    public init(
        fileAccess: SecureFileAccess,
        imageLoader: ImageLoader,
        cache: ImageCacheRepository? = nil,
        localizationService: LocalizationService? = nil,
        supportedImageFormats: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "webp"],
        maxConcurrentLoads: Int = 10
    ) {
        self.fileAccess = fileAccess
        self.imageLoader = imageLoader
        self.cache = cache
        self.localizationService = localizationService
        self.supportedImageFormats = supportedImageFormats
        self.maxConcurrentLoads = maxConcurrentLoads
        self.metricsTracker = RepositoryMetricsTracker()
    }
    
    // MARK: - Supported Formats
    
    public var supportedFormats: Set<String> {
        return supportedImageFormats
    }
    
    // MARK: - Core Image Operations
    
    public func loadPhotos(from source: ImageSource, options: LoadOptions) async throws -> [Photo] {
        let startTime = Date()
        
        do {
            let urls = try await resolveImageURLs(from: source)
            
            // Create Photo objects
            var photos: [Photo] = []
            var failedCount = 0
            
            for url in urls {
                do {
                    let imageURL = try ImageURL(url)
                    let photo = Photo(imageURL: imageURL)
                    photos.append(photo)
                } catch {
                    ProductionLogger.warning("Failed to create Photo for \(url.lastPathComponent): \(error)")
                    failedCount += 1
                }
            }
            
            // Apply sorting if specified
            let sortedPhotos = applySorting(photos, sortOrder: options.sortOrder)
            
            // Update metrics
            await metricsTracker.recordSuccess(responseTime: Date().timeIntervalSince(startTime))
            
            ProductionLogger.debug("UnifiedFileSystemImageRepository: Loaded \(sortedPhotos.count) photos, failed: \(failedCount)")
            return sortedPhotos
            
        } catch {
            await metricsTracker.recordError()
            throw UnifiedRepositoryError.sourceNotFound(source)
        }
    }
    
    public func loadImage(for photo: Photo, quality: ImageQuality, options: LoadOptions) async throws -> Photo {
        let startTime = Date()
        
        // Check cache first if available
        if let cache = cache, options.cachePolicy != CachePolicy.never && options.cachePolicy != CachePolicy.reloadIgnoringCache {
            let cacheKey = ImageCacheKey(url: photo.imageURL.url, quality: quality)
            
            if let cachedImage = await cache.getWithQuality(cacheKey, quality: quality) {
                var updatedPhoto = photo
                updatedPhoto.updateLoadState(.loaded(cachedImage))
                await metricsTracker.recordSuccess(responseTime: Date().timeIntervalSince(startTime))
                return updatedPhoto
            }
        }
        
        // Load from file system
        do {
            var updatedPhoto = photo
            updatedPhoto.updateLoadState(.loading)
            
            let image = try await loadImageFromFileSystem(url: photo.imageURL.url, quality: quality)
            updatedPhoto.updateLoadState(.loaded(image))
            
            // Cache the result if caching is enabled
            if let cache = cache, options.cachePolicy != CachePolicy.never {
                let cacheKey = ImageCacheKey(url: photo.imageURL.url, quality: quality)
                await cache.cacheWithQuality(image, for: cacheKey, quality: quality)
            }
            
            await metricsTracker.recordSuccess(responseTime: Date().timeIntervalSince(startTime))
            return updatedPhoto
            
        } catch {
            await metricsTracker.recordError()
            
            var failedPhoto = photo
            let repositoryError = UnifiedRepositoryError.loadingFailed(photo, underlying: error)
            failedPhoto.updateLoadState(.failed(SlideshowError.loadingFailed(underlying: error)))
            
            throw repositoryError
        }
    }
    
    public func loadMetadata(for photo: Photo, options: MetadataOptions) async throws -> ImageMetadata {
        let startTime = Date()
        
        do {
            let metadata = try await extractImageMetadata(from: photo.imageURL.url, options: options)
            await metricsTracker.recordSuccess(responseTime: Date().timeIntervalSince(startTime))
            return metadata
            
        } catch {
            await metricsTracker.recordError()
            throw UnifiedRepositoryError.metadataExtractionFailed(photo.imageURL.url, underlying: error)
        }
    }
    
    // MARK: - Bulk Operations
    
    public func loadImages(for photos: [Photo], quality: ImageQuality, options: LoadOptions) async throws -> [Photo] {
        guard !photos.isEmpty else { return [] }
        
        let maxConcurrency = options.maxConcurrency ?? maxConcurrentLoads
        let concurrent = options.concurrent && maxConcurrency > 1
        
        if concurrent {
            return try await withThrowingTaskGroup(of: Photo.self) { group in
                var results: [Photo] = []
                var activeTaskCount = 0
                
                for photo in photos {
                    if activeTaskCount < maxConcurrency {
                        group.addTask {
                            try await self.loadImage(for: photo, quality: quality, options: options)
                        }
                        activeTaskCount += 1
                    }
                    
                    // Process completed tasks
                    if activeTaskCount >= maxConcurrency {
                        if let result = try await group.next() {
                            results.append(result)
                            activeTaskCount -= 1
                        }
                    }
                }
                
                // Process remaining tasks
                while let result = try await group.next() {
                    results.append(result)
                }
                
                return results
            }
        } else {
            // Sequential loading
            var results: [Photo] = []
            for photo in photos {
                let loadedPhoto = try await loadImage(for: photo, quality: quality, options: options)
                results.append(loadedPhoto)
            }
            return results
        }
    }
    
    public func loadMetadata(for photos: [Photo], options: MetadataOptions) async throws -> [URL: ImageMetadata] {
        var results: [URL: ImageMetadata] = [:]
        
        // Load metadata concurrently with limited concurrency
        try await withThrowingTaskGroup(of: (URL, ImageMetadata).self) { group in
            var activeTaskCount = 0
            let maxConcurrency = 5 // Metadata extraction can be CPU intensive
            
            for photo in photos {
                if activeTaskCount < maxConcurrency {
                    group.addTask {
                        let metadata = try await self.loadMetadata(for: photo, options: options)
                        return (photo.imageURL.url, metadata)
                    }
                    activeTaskCount += 1
                }
                
                // Process completed tasks
                if activeTaskCount >= maxConcurrency {
                    if let (url, metadata) = try await group.next() {
                        results[url] = metadata
                        activeTaskCount -= 1
                    }
                }
            }
            
            // Process remaining tasks
            while let (url, metadata) = try await group.next() {
                results[url] = metadata
            }
        }
        
        return results
    }
    
    // MARK: - Search and Discovery
    
    public func searchImages(in source: ImageSource, criteria: SearchCriteria, options: LoadOptions) async throws -> [Photo] {
        let startTime = Date()
        
        do {
            let urls = try await resolveImageURLs(from: source)
            let matchingURLs = try await filterURLsByCriteria(urls, criteria: criteria)
            
            var photos: [Photo] = []
            for url in matchingURLs {
                if let imageURL = try? ImageURL(url) {
                    photos.append(Photo(imageURL: imageURL))
                }
            }
            
            let sortedPhotos = applySorting(photos, sortOrder: options.sortOrder)
            await metricsTracker.recordSuccess(responseTime: Date().timeIntervalSince(startTime))
            
            return sortedPhotos
            
        } catch {
            await metricsTracker.recordError()
            throw UnifiedRepositoryError.searchFailed(criteria, underlying: error)
        }
    }
    
    // MARK: - Performance and Statistics
    
    public func getMetrics() async -> RepositoryMetrics {
        return await metricsTracker.getMetrics()
    }
    
    public func clearCache() async {
        await cache?.removeAll()
        await metricsTracker.reset()
    }
    
    // MARK: - Private Implementation
    
    private func resolveImageURLs(from source: ImageSource) async throws -> [URL] {
        switch source {
        case .directory(let url):
            try await fileAccess.validateFileAccess(for: url)
            return try await fileAccess.enumerateImages(in: url)
            
        case .urls(let urls):
            return urls.filter { url in
                supportedImageFormats.contains(url.pathExtension.lowercased())
            }
            
        case .photos(let photos):
            return photos.map { $0.imageURL.url }
            
        case .search(let url, let criteria):
            try await fileAccess.validateFileAccess(for: url)
            let allURLs = try await fileAccess.enumerateImages(in: url)
            return try await filterURLsByCriteria(allURLs, criteria: criteria)
        }
    }
    
    private func loadImageFromFileSystem(url: URL, quality: ImageQuality) async throws -> SendableImage {
        // Use the existing image loader with quality adjustment
        let originalImage = try await imageLoader.loadImage(from: ImageURL(url))
        
        // Apply quality scaling if needed
        switch quality {
        case .original, .full:
            return originalImage
        case .preview, .thumbnail:
            return try await scaleImageForQuality(originalImage, quality: quality)
        }
    }
    
    private func scaleImageForQuality(_ image: SendableImage, quality: ImageQuality) async throws -> SendableImage {
        let maxDimension = quality.maxDimension
        let originalSize = image.size
        
        // Calculate target size maintaining aspect ratio
        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        
        if scale >= 1.0 {
            return image // No scaling needed
        }
        
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        // Create scaled image
        // Create scaled NSImage
        let scaledNSImage = NSImage(size: targetSize)
        scaledNSImage.lockFocus()
        image.nsImage.draw(in: NSRect(origin: .zero, size: targetSize))
        scaledNSImage.unlockFocus()
        
        return SendableImage(scaledNSImage)
    }
    
    private func extractImageMetadata(from url: URL, options: MetadataOptions) async throws -> ImageMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw UnifiedRepositoryError.unsupportedFormat(url.pathExtension)
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw UnifiedRepositoryError.metadataExtractionFailed(url, underlying: NSError(domain: "MetadataExtraction", code: -1))
        }
        
        // Extract file information
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileInfo = ImageMetadata.FileInfo(
            size: fileAttributes[.size] as? Int64 ?? 0,
            createdDate: fileAttributes[.creationDate] as? Date ?? Date(),
            modifiedDate: fileAttributes[.modificationDate] as? Date ?? Date(),
            fileName: url.deletingPathExtension().lastPathComponent,
            fileExtension: url.pathExtension
        )
        
        // Extract image information
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        let colorSpace = properties[kCGImagePropertyColorModel as String] as? String
        let bitDepth = properties[kCGImagePropertyDepth as String] as? Int
        let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool ?? false
        
        let imageInfo = ImageMetadata.ImageInfo(
            width: width,
            height: height,
            colorSpace: colorSpace,
            bitDepth: bitDepth,
            hasAlpha: hasAlpha
        )
        
        // Extract EXIF data if requested
        var exifData: EXIFData?
        if options.includeEXIF, let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifData = extractEXIFData(from: exifDict, tiffDict: properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any])
        }
        
        // TODO: Extract IPTC and XMP data if requested (currently not implemented)
        let iptcData: IPTCData? = nil
        let xmpData: XMPData? = nil
        
        // Extract color profile if requested
        var colorProfile: ColorProfile?
        if options.includeColorProfile {
            colorProfile = extractColorProfile(from: properties)
        }
        
        return ImageMetadata(
            fileInfo: fileInfo,
            imageInfo: imageInfo,
            exifData: exifData,
            iptcData: iptcData,
            xmpData: xmpData,
            colorProfile: colorProfile
        )
    }
    
    private func extractEXIFData(from exifDict: [String: Any], tiffDict: [String: Any]?) -> EXIFData {
        let cameraModel = tiffDict?[kCGImagePropertyTIFFModel as String] as? String
        
        // Parse date taken
        var dateTaken: Date?
        if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            dateTaken = formatter.date(from: dateString)
        }
        
        // Extract GPS location
        var gpsLocation: EXIFData.GPSLocation?
        if let gpsDict = exifDict[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            gpsLocation = extractGPSLocation(from: gpsDict)
        }
        
        // Extract exposure settings
        let exposureSettings = EXIFData.ExposureSettings(
            aperture: exifDict[kCGImagePropertyExifFNumber as String] as? String,
            shutterSpeed: exifDict[kCGImagePropertyExifExposureTime as String] as? String,
            iso: exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? Int,
            focalLength: exifDict[kCGImagePropertyExifFocalLength as String] as? String
        )
        
        // Convert dictionary to string representation for raw data
        let rawData = exifDict.compactMapValues { "\($0)" }
        
        return EXIFData(
            cameraModel: cameraModel,
            dateTaken: dateTaken,
            gpsLocation: gpsLocation,
            exposureSettings: exposureSettings,
            rawData: rawData
        )
    }
    
    private func extractGPSLocation(from gpsDict: [String: Any]) -> EXIFData.GPSLocation? {
        guard let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }
        
        // Adjust for hemisphere
        let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String
        let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String
        
        let finalLatitude = (latitudeRef == "S") ? -latitude : latitude
        let finalLongitude = (longitudeRef == "W") ? -longitude : longitude
        
        let altitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double
        
        return EXIFData.GPSLocation(
            latitude: finalLatitude,
            longitude: finalLongitude,
            altitude: altitude
        )
    }
    
    private func extractColorProfile(from properties: [String: Any]) -> ColorProfile? {
        guard let colorSpace = properties[kCGImagePropertyColorModel as String] as? String else {
            return nil
        }
        
        let profileType: ColorProfile.ColorProfileType
        switch colorSpace.lowercased() {
        case "rgb":
            profileType = .sRGB
        case "cmyk":
            profileType = .other
        default:
            profileType = .other
        }
        
        return ColorProfile(
            name: colorSpace,
            type: profileType,
            description: "Color profile: \(colorSpace)"
        )
    }
    
    private func filterURLsByCriteria(_ urls: [URL], criteria: SearchCriteria) async throws -> [URL] {
        var matchingURLs: [URL] = []
        
        for url in urls {
            var matches = true
            
            // File name filtering
            if let fileName = criteria.fileName {
                matches = matches && url.lastPathComponent.localizedCaseInsensitiveContains(fileName)
            }
            
            // File type filtering
            if let fileTypes = criteria.fileTypes {
                matches = matches && fileTypes.contains(url.pathExtension.lowercased())
            }
            
            // Date range filtering
            if let dateRange = criteria.dateRange {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let modifiedDate = attributes[.modificationDate] as? Date {
                        matches = matches && (dateRange.start...dateRange.end).contains(modifiedDate)
                    }
                } catch {
                    // Skip files we can't read attributes for
                    matches = false
                }
            }
            
            // Size range filtering
            if let sizeRange = criteria.sizeRange {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        matches = matches && (sizeRange.minSize...sizeRange.maxSize).contains(fileSize)
                    }
                } catch {
                    // Skip files we can't read attributes for
                    matches = false
                }
            }
            
            if matches {
                matchingURLs.append(url)
            }
        }
        
        return matchingURLs
    }
    
    private func applySorting(_ photos: [Photo], sortOrder: SortOrder?) -> [Photo] {
        guard let sortOrder = sortOrder else {
            return photos
        }
        
        switch sortOrder {
        case .fileName(let ascending):
            return photos.sorted { photo1, photo2 in
                let name1 = photo1.imageURL.url.lastPathComponent
                let name2 = photo2.imageURL.url.lastPathComponent
                return ascending ? name1 < name2 : name1 > name2
            }
            
        case .creationDate(let ascending):
            return photos.sorted { photo1, photo2 in
                let date1 = getCreationDate(for: photo1) ?? Date.distantPast
                let date2 = getCreationDate(for: photo2) ?? Date.distantPast
                return ascending ? date1 < date2 : date1 > date2
            }
            
        case .modificationDate(let ascending):
            return photos.sorted { photo1, photo2 in
                let date1 = getModificationDate(for: photo1) ?? Date.distantPast
                let date2 = getModificationDate(for: photo2) ?? Date.distantPast
                return ascending ? date1 < date2 : date1 > date2
            }
            
        case .fileSize(let ascending):
            return photos.sorted { photo1, photo2 in
                let size1 = getFileSize(for: photo1) ?? 0
                let size2 = getFileSize(for: photo2) ?? 0
                return ascending ? size1 < size2 : size1 > size2
            }
            
        case .random(let seed):
            if let seed = seed {
                var generator = UnifiedSeededRandomNumberGenerator(seed: seed)
                return photos.shuffled(using: &generator)
            } else {
                return photos.shuffled()
            }
        }
    }
    
    private func getCreationDate(for photo: Photo) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: photo.imageURL.url.path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
    
    private func getModificationDate(for photo: Photo) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: photo.imageURL.url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    private func getFileSize(for photo: Photo) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: photo.imageURL.url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
}

// MARK: - Supporting Types

/// Seeded random number generator for consistent random sorting
private struct UnifiedSeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

/// Repository metrics tracker
private actor RepositoryMetricsTracker {
    private var operationCount = 0
    private var successCount = 0
    private var errorCount = 0
    private var totalResponseTime: TimeInterval = 0
    private var lastOperation: Date?
    
    func recordSuccess(responseTime: TimeInterval) {
        operationCount += 1
        successCount += 1
        totalResponseTime += responseTime
        lastOperation = Date()
    }
    
    func recordError() {
        operationCount += 1
        errorCount += 1
        lastOperation = Date()
    }
    
    func getMetrics() -> RepositoryMetrics {
        let averageResponseTime = operationCount > 0 ? totalResponseTime / TimeInterval(operationCount) : 0
        
        return RepositoryMetrics(
            operationCount: operationCount,
            successCount: successCount,
            errorCount: errorCount,
            averageResponseTime: averageResponseTime,
            cacheHitRate: 0, // Will be provided by cache if available
            lastOperation: lastOperation
        )
    }
    
    func reset() {
        operationCount = 0
        successCount = 0
        errorCount = 0
        totalResponseTime = 0
        lastOperation = nil
    }
}

// MARK: - NSImage Extension

private extension NSImage {
    func resized(to targetSize: CGSize) -> NSImage? {
        let frame = NSRect(origin: .zero, size: targetSize)
        guard let representation = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        
        let image = NSImage(size: targetSize)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        representation.draw(in: frame)
        return image
    }
}