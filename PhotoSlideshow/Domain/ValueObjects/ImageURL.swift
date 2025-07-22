import Foundation

public struct ImageURL: Equatable, Hashable, Codable {
    public let url: URL
    
    public init(_ url: URL) throws {
        guard Self.isValidImageURL(url) else {
            throw SlideshowError.invalidImageFormat(url.pathExtension)
        }
        self.url = url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let url = try container.decode(URL.self)
        try self.init(url)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(url)
    }
    
    private static func isValidImageURL(_ url: URL) -> Bool {
        let supportedExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
        let pathExtension = url.pathExtension.lowercased()
        let isValid = supportedExtensions.contains(pathExtension)
        
        if !isValid {
            print("⚠️ Invalid image format for \(url.lastPathComponent): .\(pathExtension)")
        }
        
        return isValid
    }
    
    public var pathExtension: String {
        url.pathExtension.lowercased()
    }
    
    public var lastPathComponent: String {
        url.lastPathComponent
    }
}

public enum SlideshowError: Error, LocalizedError, Equatable {
    case invalidImageFormat(String)
    case fileNotFound(URL)
    case loadingFailed(underlying: Error)
    case invalidInterval(Double)
    case invalidIndex(Int)
    case securityError(String)
    
    public static func == (lhs: SlideshowError, rhs: SlideshowError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidImageFormat(let lhsFormat), .invalidImageFormat(let rhsFormat)):
            return lhsFormat == rhsFormat
        case (.fileNotFound(let lhsURL), .fileNotFound(let rhsURL)):
            return lhsURL == rhsURL
        case (.loadingFailed(let lhsError), .loadingFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.invalidInterval(let lhsInterval), .invalidInterval(let rhsInterval)):
            return lhsInterval == rhsInterval
        case (.invalidIndex(let lhsIndex), .invalidIndex(let rhsIndex)):
            return lhsIndex == rhsIndex
        case (.securityError(let lhsMessage), .securityError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .invalidImageFormat(let format):
            return "Unsupported image format: \(format)"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .loadingFailed(let error):
            return "Loading failed: \(error.localizedDescription)"
        case .invalidInterval(let interval):
            return "Invalid interval: \(interval)"
        case .invalidIndex(let index):
            return "Invalid index: \(index)"
        case .securityError(let message):
            return "Security error: \(message)"
        }
    }
}