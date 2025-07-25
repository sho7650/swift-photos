import Foundation
import AppKit

public actor ImageCache: PhotoCache {
    private let cache = NSCache<NSString, NSImage>()
    private var hitCount = 0
    private var missCount = 0
    
    public init(countLimit: Int = 50, totalCostLimit: Int = 100_000_000) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        cache.name = "SwiftPhotos.ImageCache"
    }
    
    public func getCachedImage(for imageURL: ImageURL) -> SendableImage? {
        let key = NSString(string: imageURL.url.absoluteString)
        
        if let cachedImage = cache.object(forKey: key) {
            hitCount += 1
            return SendableImage(cachedImage)
        } else {
            missCount += 1
            return nil
        }
    }
    
    public func setCachedImage(_ image: SendableImage, for imageURL: ImageURL) {
        let key = NSString(string: imageURL.url.absoluteString)
        let estimatedCost = estimateImageCost(image)
        cache.setObject(image.nsImage, forKey: key, cost: estimatedCost)
    }
    
    public func clearCache() {
        cache.removeAllObjects()
        hitCount = 0
        missCount = 0
    }
    
    public func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            totalCost: cache.totalCostLimit,
            currentCount: cache.countLimit
        )
    }
    
    private func estimateImageCost(_ image: SendableImage) -> Int {
        guard let cgImage = image.nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 1000
        }
        
        let bytesPerPixel = 4
        let cost = cgImage.width * cgImage.height * bytesPerPixel
        return cost
    }
}