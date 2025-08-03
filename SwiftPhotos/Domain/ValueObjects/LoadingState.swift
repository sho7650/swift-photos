import Foundation

/// Loading states for detailed user feedback during slideshow operations
public enum LoadingState: Equatable {
    case notLoading
    case selectingFolder
    case scanningFolder(Int) // number of files found so far
    case loadingFirstImage
    case preparingSlideshow
    
    public var isLoading: Bool {
        self != .notLoading
    }
    
    public var displayMessage: String {
        switch self {
        case .notLoading:
            return ""
        case .selectingFolder:
            return "Opening folder selection..."
        case .scanningFolder(let count):
            return count > 0 ? "Found \(count) images..." : "Scanning folder..."
        case .loadingFirstImage:
            return "Loading first image..."
        case .preparingSlideshow:
            return "Preparing slideshow..."
        }
    }
}