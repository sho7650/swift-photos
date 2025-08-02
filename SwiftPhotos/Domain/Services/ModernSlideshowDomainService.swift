import Foundation
import AppKit

/// Modern SlideshowDomainService using the new Repository pattern
/// This replaces the old SlideshowDomainService with integrated Repository layer support
@MainActor
public class ModernSlideshowDomainService: ObservableObject {
    
    // MARK: - Dependencies
    private let imageRepository: any ImageRepositoryProtocol
    private let cacheRepository: any ImageCacheRepositoryProtocol
    private let metadataRepository: any MetadataRepositoryProtocol
    private let settingsRepository: any SettingsRepositoryProtocol
    private var repositoryContainer: RepositoryContainer
    
    // MARK: - Configuration
    private let maxConcurrentLoads: Int
    private let performanceMonitoring: Bool
    
    // MARK: - Performance Tracking
    private var operationCount = 0
    private var successCount = 0
    private var errorCount = 0
    private var lastOperationTime = Date()
    
    // MARK: - Initialization
    
    /// Initialize with specific repositories (for testing or custom configuration)
    public init(
        imageRepository: any ImageRepositoryProtocol,
        cacheRepository: any ImageCacheRepositoryProtocol,
        metadataRepository: any MetadataRepositoryProtocol,
        settingsRepository: any SettingsRepositoryProtocol,
        maxConcurrentLoads: Int = 5,
        performanceMonitoring: Bool = true
    ) {
        self.imageRepository = imageRepository
        self.cacheRepository = cacheRepository
        self.metadataRepository = metadataRepository
        self.settingsRepository = settingsRepository
        self.repositoryContainer = RepositoryContainer.shared
        self.maxConcurrentLoads = maxConcurrentLoads
        self.performanceMonitoring = performanceMonitoring
        
        ProductionLogger.info("ModernSlideshowDomainService: Initialized with custom repositories")
    }
    
    /// Initialize with RepositoryContainer (recommended for production)
    public convenience init(
        repositoryContainer: RepositoryContainer = RepositoryContainer.shared,
        maxConcurrentLoads: Int = 5,
        performanceMonitoring: Bool = true
    ) async {
        let imageRepo = await repositoryContainer.imageRepository()
        let cacheRepo = await repositoryContainer.cacheRepository()
        let metadataRepo = await repositoryContainer.metadataRepository()
        let settingsRepo = await repositoryContainer.settingsRepository()
        
        self.init(
            imageRepository: imageRepo,
            cacheRepository: cacheRepo,
            metadataRepository: metadataRepo,
            settingsRepository: settingsRepo,
            maxConcurrentLoads: maxConcurrentLoads,
            performanceMonitoring: performanceMonitoring
        )
        
        self.repositoryContainer = repositoryContainer
        ProductionLogger.info("ModernSlideshowDomainService: Initialized with RepositoryContainer")
    }
    
    // MARK: - Slideshow Creation
    
    /// Create a slideshow from a folder URL using the new Repository pattern
    public func createSlideshow(
        from folderURL: URL,
        interval: SlideshowInterval,
        mode: Slideshow.SlideshowMode
    ) async throws -> Slideshow {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("ModernSlideshowDomainService: Creating slideshow from \(folderURL.path)")
        
        do {
            // Load image URLs from the repository
            let imageURLs = try await imageRepository.loadImageURLs(from: folderURL)
            ProductionLogger.debug("ModernSlideshowDomainService: Found \(imageURLs.count) image URLs")
            
            // Convert ImageURLs to Photos
            let photos = imageURLs.map { imageURL in
                Photo(imageURL: imageURL)
            }
            
            // Create slideshow
            let slideshow = Slideshow(photos: photos, interval: interval, mode: mode)
            
            // Update performance metrics
            successCount += 1
            lastOperationTime = Date()
            
            if performanceMonitoring {
                let duration = Date().timeIntervalSince(startTime)
                ProductionLogger.performance("ModernSlideshowDomainService: Created slideshow with \(photos.count) photos in \(String(format: "%.2f", duration))s")
            }
            
            ProductionLogger.debug("ModernSlideshowDomainService: Successfully created slideshow with \(slideshow.photos.count) photos")
            return slideshow
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("ModernSlideshowDomainService: Error creating slideshow: \(error)")
            throw SlideshowError.loadingFailed(underlying: error)
        }
    }
    
    // MARK: - Image Loading
    
    /// Load an image for a photo using the new Repository pattern with caching
    public func loadImage(for photo: Photo) async throws -> Photo {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("ModernSlideshowDomainService: Loading image for \(photo.fileName)")
        
        do {
            // Create cache key from ImageURL
            let cacheKey = ImageCacheKey(url: photo.imageURL.url)
            
            // Check cache first
            if let cachedImage = await cacheRepository.get(cacheKey) {
                ProductionLogger.debug("ModernSlideshowDomainService: Cache hit for \(photo.fileName)")
                var updatedPhoto = photo
                updatedPhoto.updateLoadState(.loaded(cachedImage))
                successCount += 1
                return updatedPhoto
            }
            
            // Load from repository
            let sendableImage = try await imageRepository.loadImage(from: photo.imageURL.url)
            
            // Cache the loaded image
            await cacheRepository.set(sendableImage, for: cacheKey, cost: estimateImageCost(sendableImage))
            
            // Update photo state
            var updatedPhoto = photo
            updatedPhoto.updateLoadState(.loaded(sendableImage))
            
            // Update performance metrics
            successCount += 1
            lastOperationTime = Date()
            
            if performanceMonitoring {
                let duration = Date().timeIntervalSince(startTime)
                ProductionLogger.performance("ModernSlideshowDomainService: Loaded image \(photo.fileName) in \(String(format: "%.2f", duration))s")
            }
            
            ProductionLogger.debug("ModernSlideshowDomainService: Successfully loaded image for \(photo.fileName)")
            return updatedPhoto
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.error("ModernSlideshowDomainService: Error loading image for \(photo.fileName): \(error)")
            
            // Update photo with error state
            var updatedPhoto = photo
            let slideshowError = SlideshowError.loadingFailed(underlying: error)
            updatedPhoto.updateLoadState(.failed(slideshowError))
            throw slideshowError
        }
    }
    
    // MARK: - Metadata Loading
    
    /// Load metadata for a photo using the new Repository pattern
    public func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata? {
        let startTime = Date()
        operationCount += 1
        
        ProductionLogger.debug("ModernSlideshowDomainService: Loading metadata for \(photo.fileName)")
        
        do {
            let imageMetadata = try await metadataRepository.loadAllMetadata(for: photo.imageURL.url)
            
            // Convert ImageMetadata to Photo.PhotoMetadata
            let photoMetadata = convertToPhotoMetadata(imageMetadata)
            
            successCount += 1
            lastOperationTime = Date()
            
            if performanceMonitoring {
                let duration = Date().timeIntervalSince(startTime)
                ProductionLogger.performance("ModernSlideshowDomainService: Loaded metadata for \(photo.fileName) in \(String(format: "%.2f", duration))s")
            }
            
            ProductionLogger.debug("ModernSlideshowDomainService: Successfully loaded metadata for \(photo.fileName)")
            return photoMetadata
            
        } catch {
            errorCount += 1
            lastOperationTime = Date()
            ProductionLogger.warning("ModernSlideshowDomainService: Failed to load metadata for \(photo.fileName): \(error)")
            return nil // Metadata loading is optional
        }
    }
    
    // MARK: - Batch Operations
    
    /// Preload multiple images concurrently
    public func preloadImages(for photos: [Photo], priority: TaskPriority = .utility) async {
        ProductionLogger.debug("ModernSlideshowDomainService: Preloading \(photos.count) images")
        
        await withTaskGroup(of: Bool.self) { group in
            let maxConcurrent = min(maxConcurrentLoads, photos.count)
            
            for photo in photos.prefix(maxConcurrent) {
                group.addTask(priority: priority) { @Sendable [weak self] in
                    do {
                        _ = try await self?.loadImage(for: photo)
                        return true
                    } catch {
                        ProductionLogger.warning("ModernSlideshowDomainService: Failed to preload \(photo.fileName): \(error)")
                        return false
                    }
                }
            }
            
            var loadedCount = 0
            for await success in group {
                if success { loadedCount += 1 }
            }
        }
        
        ProductionLogger.debug("ModernSlideshowDomainService: Completed preloading batch")
    }
    
    /// Search for images in a folder using specific criteria
    public func searchImages(
        in folderURL: URL,
        matching criteria: SearchCriteria
    ) async throws -> [Photo] {
        ProductionLogger.debug("ModernSlideshowDomainService: Searching images in \(folderURL.path)")
        
        let imageURLs = try await imageRepository.searchImages(in: folderURL, matching: criteria)
        let photos = imageURLs.map { Photo(imageURL: $0) }
        
        ProductionLogger.debug("ModernSlideshowDomainService: Found \(photos.count) images matching criteria")
        return photos
    }
    
    // MARK: - Health and Performance
    
    /// Get performance metrics for the domain service
    public func getPerformanceMetrics() -> DomainServiceMetrics {
        return DomainServiceMetrics(
            operationCount: operationCount,
            successCount: successCount,
            errorCount: errorCount,
            successRate: operationCount > 0 ? Double(successCount) / Double(operationCount) : 0.0,
            lastOperation: lastOperationTime
        )
    }
    
    /// Perform health check on all repositories
    public func performHealthCheck() async -> RepositoryHealthStatus {
        return await repositoryContainer.performHealthCheck()
    }
    
    /// Clear all caches
    public func clearAllCaches() async {
        await cacheRepository.removeAll()
        ProductionLogger.info("ModernSlideshowDomainService: Cleared all caches")
    }
    
    // MARK: - Private Helper Methods
    
    /// Estimate the cost of an image for caching purposes
    private func estimateImageCost(_ image: SendableImage) -> Int {
        let size = image.nsImage.size
        // Rough estimate: width * height * 4 bytes per pixel (RGBA)
        return Int(size.width * size.height * 4)
    }
    
    /// Convert ImageMetadata to Photo.PhotoMetadata
    private func convertToPhotoMetadata(_ imageMetadata: ImageMetadata) -> Photo.PhotoMetadata {
        // Parse capture date from EXIF data
        let captureDate = imageMetadata.exifData?.dateTaken
        
        // Extract color space from image info
        let colorSpace = imageMetadata.imageInfo.colorSpace
        
        return Photo.PhotoMetadata(
            fileSize: imageMetadata.fileInfo.size,
            dimensions: CGSize(
                width: CGFloat(imageMetadata.imageInfo.width),
                height: CGFloat(imageMetadata.imageInfo.height)
            ),
            creationDate: captureDate,
            colorSpace: colorSpace
        )
    }
}

// MARK: - Supporting Types

/// Performance metrics for the domain service
public struct DomainServiceMetrics: Sendable {
    public let operationCount: Int
    public let successCount: Int
    public let errorCount: Int
    public let successRate: Double
    public let lastOperation: Date
    
    public init(
        operationCount: Int,
        successCount: Int,
        errorCount: Int,
        successRate: Double,
        lastOperation: Date
    ) {
        self.operationCount = operationCount
        self.successCount = successCount
        self.errorCount = errorCount
        self.successRate = successRate
        self.lastOperation = lastOperation
    }
}

// MARK: - Factory Methods

extension ModernSlideshowDomainService {
    
    /// Create a domain service with legacy repository support
    public static func createWithLegacySupport(
        fileAccess: SecureFileAccess,
        imageLoader: ImageLoader,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService
    ) async -> ModernSlideshowDomainService {
        
        let factory = await ImageRepositoryFactory.createWithLegacySupport(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        
        do {
            let imageRepo = try await factory.createImageRepository()
            let container = RepositoryContainer.shared
            let cacheRepo = await container.cacheRepository()
            let metadataRepo = await container.metadataRepository()
            let settingsRepo = await container.settingsRepository()
            
            return ModernSlideshowDomainService(
                imageRepository: imageRepo,
                cacheRepository: cacheRepo,
                metadataRepository: metadataRepo,
                settingsRepository: settingsRepo
            )
            
        } catch {
            ProductionLogger.error("ModernSlideshowDomainService: Failed to create with legacy support: \(error)")
            // Fallback to modern-only implementation
            return await ModernSlideshowDomainService()
        }
    }
    
    /// Create a domain service with modern repositories only
    public static func createModernOnly() async -> ModernSlideshowDomainService {
        return await ModernSlideshowDomainService()
    }
}