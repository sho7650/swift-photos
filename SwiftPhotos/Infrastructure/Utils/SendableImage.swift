import Foundation
import AppKit

/// A thread-safe wrapper for NSImage that conforms to Sendable
/// This allows NSImage to be safely passed between actors in Swift concurrency
struct SendableImage: @unchecked Sendable {
    private let image: NSImage
    
    init(_ image: NSImage) {
        self.image = image
    }
    
    /// Access the underlying NSImage
    /// Note: NSImage is thread-safe for read operations, which is why this wrapper is safe
    var nsImage: NSImage {
        image
    }
    
    /// Convenience properties
    var size: NSSize {
        image.size
    }
    
    var representations: [NSImageRep] {
        image.representations
    }
}

// Extension to make it easy to convert between NSImage and SendableImage
extension NSImage {
    /// Convert to a Sendable wrapper
    var sendable: SendableImage {
        SendableImage(self)
    }
}