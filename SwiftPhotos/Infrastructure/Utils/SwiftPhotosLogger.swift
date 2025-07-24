import Foundation
import os.log

public class SwiftPhotosLogger {
    public static let shared = SwiftPhotosLogger()
    
    private let logger = Logger(subsystem: "com.example.SwiftPhotos", category: "swiftphotos")
    
    private init() {}
    
    public func debug(_ message: String) {
        logger.debug("\(message)")
    }
    
    public func info(_ message: String) {
        logger.info("\(message)")
    }
    
    public func warning(_ message: String) {
        logger.warning("\(message)")
    }
    
    public func error(_ message: String) {
        logger.error("\(message)")
    }
    
    public func logImageLoad(_ imageURL: ImageURL, success: Bool, duration: TimeInterval) {
        if success {
            logger.info("Loaded image: \(imageURL.lastPathComponent) in \(String(format: "%.2f", duration))s")
        } else {
            logger.error("Failed to load image: \(imageURL.lastPathComponent)")
        }
    }
    
    public func logCacheStats(_ stats: CacheStatistics) {
        logger.info("Cache stats - Hit rate: \(String(format: "%.2f", stats.hitRate * 100))%, Items: \(stats.currentCount)")
    }
}