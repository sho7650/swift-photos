import Foundation
import AppKit

public class FileSystemPhotoRepository: SlideshowRepository {
    private let fileAccess: SecureFileAccess
    private let imageLoader: ImageLoader
    
    public init(fileAccess: SecureFileAccess, imageLoader: ImageLoader) {
        self.fileAccess = fileAccess
        self.imageLoader = imageLoader
    }
    
    public func loadPhotos(from folderURL: URL) async throws -> [Photo] {
        print("🗂️ FileSystemPhotoRepository: Starting loadPhotos for: \(folderURL.path)")
        NSLog("🗂️ FileSystemPhotoRepository: Starting loadPhotos")
        
        do {
            print("🗂️ FileSystemPhotoRepository: Validating file access...")
            NSLog("🗂️ FileSystemPhotoRepository: About to validate file access")
            try await fileAccess.validateFileAccess(for: folderURL)
            NSLog("🗂️ FileSystemPhotoRepository: File access validation completed")
            
            print("🗂️ FileSystemPhotoRepository: Enumerating images...")
            NSLog("🗂️ FileSystemPhotoRepository: About to enumerate images")
            let imageURLs = try await fileAccess.enumerateImages(in: folderURL)
            NSLog("🗂️ FileSystemPhotoRepository: Image enumeration completed with \(imageURLs.count) images")
            
            print("🗂️ FileSystemPhotoRepository: Creating \(imageURLs.count) photo objects...")
            var photos: [Photo] = []
            var failedCount = 0
            
            for url in imageURLs {
                do {
                    let imageURL = try ImageURL(url)
                    let photo = Photo(imageURL: imageURL)
                    photos.append(photo)
                } catch {
                    print("⚠️ Failed to create Photo for \(url.lastPathComponent): \(error)")
                    failedCount += 1
                }
            }
            
            print("🗂️ FileSystemPhotoRepository: Successfully created \(photos.count) photos, failed: \(failedCount)")
            return photos
            
        } catch {
            print("❌ FileSystemPhotoRepository: Failed in loadPhotos: \(error)")
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
}