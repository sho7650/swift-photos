import Foundation
import AppKit

public final class FileSystemPhotoRepository: SlideshowRepository, @unchecked Sendable {
    private let fileAccess: SecureFileAccess
    private let imageLoader: ImageLoader
    private let sortSettings: SortSettingsManagerProtocol
    private let localizationService: LocalizationService
    
    public init(fileAccess: SecureFileAccess, imageLoader: ImageLoader, sortSettings: SortSettingsManagerProtocol, localizationService: LocalizationService) {
        self.fileAccess = fileAccess
        self.imageLoader = imageLoader
        self.sortSettings = sortSettings
        self.localizationService = localizationService
    }
    
    @MainActor
    public func loadPhotos(from folderURL: URL) async throws -> [Photo] {
        ProductionLogger.debug("FileSystemPhotoRepository: Starting loadPhotos for: \(folderURL.path)")
        ProductionLogger.debug("FileSystemPhotoRepository: Starting loadPhotos")
        
        do {
            ProductionLogger.debug("FileSystemPhotoRepository: Validating file access...")
            ProductionLogger.debug("FileSystemPhotoRepository: About to validate file access")
            try fileAccess.validateFileAccess(for: folderURL)
            ProductionLogger.debug("FileSystemPhotoRepository: File access validation completed")
            
            ProductionLogger.debug("FileSystemPhotoRepository: Enumerating images...")
            ProductionLogger.debug("FileSystemPhotoRepository: About to enumerate images")
            let imageURLs = try fileAccess.enumerateImages(in: folderURL)
            ProductionLogger.debug("FileSystemPhotoRepository: Image enumeration completed with \(imageURLs.count) images")
            
            ProductionLogger.debug("FileSystemPhotoRepository: Creating \(imageURLs.count) photo objects...")
            var photos: [Photo] = []
            var failedCount = 0
            
            for url in imageURLs {
                do {
                    let imageURL = try ImageURL(url)
                    let photo = Photo(imageURL: imageURL)
                    photos.append(photo)
                } catch {
                    ProductionLogger.warning("Failed to create Photo for \(url.lastPathComponent): \(error)")
                    failedCount += 1
                }
            }
            
            ProductionLogger.debug("FileSystemPhotoRepository: Successfully created \(photos.count) photos, failed: \(failedCount)")
            
            // Apply sorting based on current sort settings
            let currentSettings = sortSettings.settings
            let sortedPhotos = await sortPhotos(photos, using: currentSettings)
            ProductionLogger.debug("FileSystemPhotoRepository: Applied sorting: \(currentSettings.order.displayName) \(currentSettings.direction.displayName)")
            
            return sortedPhotos
            
        } catch {
            ProductionLogger.error("FileSystemPhotoRepository: Failed in loadPhotos: \(error)")
            throw error
        }
    }
    
    public func loadImage(for photo: Photo) async throws -> Photo {
        var updatedPhoto = photo
        updatedPhoto.updateLoadState(.loading)
        
        do {
            let image = try await imageLoader.loadImage(from: photo.imageURL)
            updatedPhoto.updateLoadState(.loaded(image))
            return updatedPhoto
        } catch let error as SlideshowError {
            updatedPhoto.updateLoadState(.failed(error))
            throw error
        } catch {
            let slideshowError = SlideshowError.loadingFailed(underlying: error)
            updatedPhoto.updateLoadState(.failed(slideshowError))
            throw slideshowError
        }
    }
    
    public func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata? {
        return try await imageLoader.extractMetadata(from: photo.imageURL.url)
    }
    
    /// Sort photos according to the specified sort settings
    private func sortPhotos(_ photos: [Photo], using sortSettings: SortSettings) async -> [Photo] {
        ProductionLogger.debug("FileSystemPhotoRepository: Sorting \(photos.count) photos by \(sortSettings.order.displayName)")
        
        switch sortSettings.order {
        case .fileName:
            return await sortByFileName(photos, direction: sortSettings.direction)
            
        case .creationDate:
            let direction = sortSettings.direction
            return await sortByCreationDate(photos, direction: direction)
            
        case .modificationDate:
            let direction = sortSettings.direction
            return await sortByModificationDate(photos, direction: direction)
            
        case .fileSize:
            let direction = sortSettings.direction
            return await sortByFileSize(photos, direction: direction)
            
        case .random:
            return sortByRandom(photos, seed: sortSettings.randomSeed)
        }
    }
    
    /// Sort photos by file name using locale-aware comparison
    private func sortByFileName(_ photos: [Photo], direction: SortSettings.SortDirection) async -> [Photo] {
        let locale = await localizationService.currentLocale
        
        let sorted = photos.sorted { photo1, photo2 in
            let name1 = photo1.fileName
            let name2 = photo2.fileName
            
            // Use locale-aware comparison that respects different languages' collation rules
            let comparisonResult = name1.compare(name2, options: .caseInsensitive, range: nil, locale: locale)
            
            switch direction {
            case .ascending:
                return comparisonResult == .orderedAscending
            case .descending:
                return comparisonResult == .orderedDescending
            }
        }
        
        ProductionLogger.debug("FileSystemPhotoRepository: Sorted by file name (\(direction.displayName)) using locale: \(locale.identifier)")
        return sorted
    }
    
    /// Sort photos by creation date
    private func sortByCreationDate(_ photos: [Photo], direction: SortSettings.SortDirection) async -> [Photo] {
        // Load creation dates for all photos
        var photosWithDates: [(Photo, Date?)] = []
        
        for photo in photos {
            let creationDate = await getFileCreationDate(for: photo.imageURL.url)
            photosWithDates.append((photo, creationDate))
        }
        
        let sorted = photosWithDates.sorted { item1, item2 in
            let date1 = item1.1 ?? Date.distantPast
            let date2 = item2.1 ?? Date.distantPast
            return direction == .ascending ? date1 < date2 : date1 > date2
        }.map { $0.0 }
        
        ProductionLogger.debug("FileSystemPhotoRepository: Sorted by creation date (\(direction.displayName))")
        return sorted
    }
    
    /// Sort photos by modification date
    private func sortByModificationDate(_ photos: [Photo], direction: SortSettings.SortDirection) async -> [Photo] {
        // Load modification dates for all photos
        var photosWithDates: [(Photo, Date?)] = []
        
        for photo in photos {
            let modificationDate = await getFileModificationDate(for: photo.imageURL.url)
            photosWithDates.append((photo, modificationDate))
        }
        
        let sorted = photosWithDates.sorted { item1, item2 in
            let date1 = item1.1 ?? Date.distantPast
            let date2 = item2.1 ?? Date.distantPast
            return direction == .ascending ? date1 < date2 : date1 > date2
        }.map { $0.0 }
        
        ProductionLogger.debug("FileSystemPhotoRepository: Sorted by modification date (\(direction.displayName))")
        return sorted
    }
    
    /// Sort photos by file size
    private func sortByFileSize(_ photos: [Photo], direction: SortSettings.SortDirection) async -> [Photo] {
        // Load file sizes for all photos
        var photosWithSizes: [(Photo, Int64)] = []
        
        for photo in photos {
            let fileSize = await getFileSize(for: photo.imageURL.url)
            photosWithSizes.append((photo, fileSize))
        }
        
        let sorted = photosWithSizes.sorted { item1, item2 in
            return direction == .ascending ? item1.1 < item2.1 : item1.1 > item2.1
        }.map { $0.0 }
        
        ProductionLogger.debug("FileSystemPhotoRepository: Sorted by file size (\(direction.displayName))")
        return sorted
    }
    
    /// Sort photos randomly with consistent seed
    private func sortByRandom(_ photos: [Photo], seed: UInt64) -> [Photo] {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let shuffled = photos.shuffled(using: &generator)
        ProductionLogger.debug("FileSystemPhotoRepository: Sorted randomly with seed \(seed)")
        return shuffled
    }
    
    // MARK: - File Attribute Helpers
    
    /// Get file creation date
    private func getFileCreationDate(for url: URL) async -> Date? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            ProductionLogger.warning("Failed to get creation date for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    /// Get file modification date
    private func getFileModificationDate(for url: URL) async -> Date? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
            return resourceValues.contentModificationDate
        } catch {
            ProductionLogger.warning("Failed to get modification date for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    /// Get file size
    private func getFileSize(for url: URL) async -> Int64 {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            ProductionLogger.warning("Failed to get file size for \(url.lastPathComponent): \(error)")
            return 0
        }
    }
}

/// Seeded random number generator for consistent random sorting
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // Linear congruential generator
        state = state &* 1103515245 &+ 12345
        return state
    }
}