import Foundation
import AppKit
import SwiftUI

public struct Photo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let imageURL: ImageURL
    public private(set) var loadState: LoadState
    public private(set) var metadata: PhotoMetadata?
    
    public init(id: UUID = UUID(), imageURL: ImageURL) {
        self.id = id
        self.imageURL = imageURL
        self.loadState = .notLoaded
        self.metadata = nil
    }
    
    public enum LoadState: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded(SendableImage)
        case failed(SlideshowError)
        
        public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.notLoaded, .notLoaded), (.loading, .loading):
                return true
            case (.loaded(let lhsImage), .loaded(let rhsImage)):
                return lhsImage.nsImage === rhsImage.nsImage
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
        
        public var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
        
        public var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        public var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
        
        public var isNotLoaded: Bool {
            if case .notLoaded = self { return true }
            return false
        }
        
        public var image: NSImage? {
            if case .loaded(let sendableImage) = self { return sendableImage.nsImage }
            return nil
        }
        
        public var error: SlideshowError? {
            if case .failed(let error) = self { return error }
            return nil
        }
        
        public var description: String {
            switch self {
            case .notLoaded:
                return "notLoaded"
            case .loading:
                return "loading"
            case .loaded(let image):
                return "loaded(\(image.size))"
            case .failed(let error):
                return "failed(\(error.localizedDescription))"
            }
        }
    }
    
    public struct PhotoMetadata: Equatable, Sendable {
        public let fileSize: Int64
        public let dimensions: CGSize
        public let creationDate: Date?
        public let colorSpace: String?
        
        public init(fileSize: Int64, dimensions: CGSize, creationDate: Date?, colorSpace: String?) {
            self.fileSize = fileSize
            self.dimensions = dimensions
            self.creationDate = creationDate
            self.colorSpace = colorSpace
        }
        
        public var fileSizeString: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }
        
        public var dimensionsString: String {
            return "\(Int(dimensions.width))×\(Int(dimensions.height))"
        }
    }
    
    public mutating func updateLoadState(_ newState: LoadState) {
        self.loadState = newState
    }
    
    public mutating func updateMetadata(_ metadata: PhotoMetadata?) {
        self.metadata = metadata
    }
    
    public var fileName: String {
        imageURL.lastPathComponent
    }
}