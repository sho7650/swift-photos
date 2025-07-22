import Foundation
import AppKit

public protocol SlideshowRepository {
    func loadPhotos(from folderURL: URL) async throws -> [Photo]
    func loadImage(for photo: Photo) async throws -> Photo
    func loadMetadata(for photo: Photo) async throws -> Photo.PhotoMetadata?
}

public protocol PhotoCache {
    func getCachedImage(for imageURL: ImageURL) async -> NSImage?
    func setCachedImage(_ image: NSImage, for imageURL: ImageURL) async
    func clearCache() async
    func getCacheStatistics() async -> CacheStatistics
}

public struct CacheStatistics: Equatable {
    public let hitCount: Int
    public let missCount: Int
    public let totalCost: Int
    public let currentCount: Int
    
    public init(hitCount: Int, missCount: Int, totalCost: Int, currentCount: Int) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.totalCost = totalCost
        self.currentCount = currentCount
    }
    
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }
}