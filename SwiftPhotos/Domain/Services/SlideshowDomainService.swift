import Foundation
import AppKit

@MainActor
public class SlideshowDomainService: ObservableObject {
    private let repository: SlideshowRepository
    private let cache: PhotoCache
    private let maxConcurrentLoads: Int
    
    public init(repository: SlideshowRepository, cache: PhotoCache, maxConcurrentLoads: Int = 3) {
        self.repository = repository
        self.cache = cache
        self.maxConcurrentLoads = maxConcurrentLoads
    }
    
    public func createSlideshow(from folderURL: URL, interval: SlideshowInterval, mode: Slideshow.SlideshowMode) async throws -> Slideshow {
        ProductionLogger.debug("SlideshowDomainService: Loading photos from repository...")
        ProductionLogger.debug("SlideshowDomainService: About to call repository.loadPhotos")
        
        do {
            let photos = try await repository.loadPhotos(from: folderURL)
            ProductionLogger.debug("SlideshowDomainService: Loaded \(photos.count) photos")
            ProductionLogger.debug("SlideshowDomainService: Successfully loaded \(photos.count) photos")
            
            let slideshow = Slideshow(photos: photos, interval: interval, mode: mode)
            ProductionLogger.debug("SlideshowDomainService: Created slideshow successfully")
            ProductionLogger.debug("SlideshowDomainService: Created slideshow successfully")
            return slideshow
        } catch {
            ProductionLogger.error("SlideshowDomainService: Error in createSlideshow: \(error)")
            ProductionLogger.error("SlideshowDomainService: Error in createSlideshow: \(error)")
            throw error
        }
    }
    
    public func loadImage(for photo: Photo) async throws -> Photo {
        if let cachedImage = await cache.getCachedImage(for: photo.imageURL) {
            var updatedPhoto = photo
            updatedPhoto.updateLoadState(.loaded(cachedImage))
            return updatedPhoto
        }
        
        let loadedPhoto = try await repository.loadImage(for: photo)
        
        if let image = loadedPhoto.loadState.image {
            await cache.setCachedImage(image, for: photo.imageURL)
        }
        
        return loadedPhoto
    }
    
    public func preloadAdjacentImages(for slideshow: Slideshow, preloadRadius: Int = 2) async {
        guard !slideshow.isEmpty else { 
            print("🔄 SlideshowDomainService.preloadAdjacentImages: Slideshow is empty, skipping")
            return 
        }
        
        let currentIndex = slideshow.currentIndex
        let totalPhotos = slideshow.photos.count
        print("🔄 SlideshowDomainService.preloadAdjacentImages: Starting preload from currentIndex=\(currentIndex), totalPhotos=\(totalPhotos)")
        var indicesToPreload: [Int] = []
        
        for offset in 1...preloadRadius {
            let nextIndex = (currentIndex + offset) % totalPhotos
            let prevIndex = (currentIndex - offset + totalPhotos) % totalPhotos
            
            indicesToPreload.append(nextIndex)
            if nextIndex != prevIndex {
                indicesToPreload.append(prevIndex)
            }
        }
        
        print("🔄 SlideshowDomainService.preloadAdjacentImages: Indices to preload: \(indicesToPreload)")
        
        let photosToPreload = indicesToPreload.compactMap { index -> Photo? in
            guard index < slideshow.photos.count else { return nil }
            let photo = slideshow.photos[index]
            let shouldPreload = !photo.loadState.isLoaded
            print("🔄 SlideshowDomainService.preloadAdjacentImages: Photo[\(index)] '\(photo.fileName)' - loadState: \(photo.loadState), shouldPreload: \(shouldPreload)")
            return shouldPreload ? photo : nil
        }
        
        print("🔄 SlideshowDomainService.preloadAdjacentImages: Will preload \(photosToPreload.count) photos: \(photosToPreload.map { $0.fileName })")
        
        await withTaskGroup(of: Void.self) { group in
            for photo in photosToPreload.prefix(maxConcurrentLoads) {
                group.addTask {
                    do {
                        print("🔄 SlideshowDomainService.preloadAdjacentImages: Starting to preload '\(photo.fileName)'")
                        _ = try await self.loadImage(for: photo)
                        print("🔄 SlideshowDomainService.preloadAdjacentImages: Completed preloading '\(photo.fileName)'")
                    } catch {
                        print("❌ SlideshowDomainService.preloadAdjacentImages: Failed to preload '\(photo.fileName)': \(error)")
                    }
                }
            }
        }
        
        print("🔄 SlideshowDomainService.preloadAdjacentImages: All preloading tasks completed")
    }
    
    public func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata? {
        return try await repository.loadMetadata(for: photo)
    }
    
    public func getCacheStatistics() async -> CacheStatistics {
        return await cache.getCacheStatistics()
    }
    
    public func clearCache() async {
        await cache.clearCache()
    }
}