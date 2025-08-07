import Foundation

public struct Slideshow: Equatable, Sendable {
    public private(set) var photos: [Photo]
    public private(set) var currentIndex: Int
    public private(set) var interval: SlideshowInterval
    public private(set) var mode: SlideshowMode
    public private(set) var state: SlideshowState
    
    public init(photos: [Photo], interval: SlideshowInterval = .default, mode: SlideshowMode = .sequential) {
        self.photos = photos
        self.currentIndex = 0
        self.interval = interval
        self.mode = mode
        self.state = .stopped
    }
    
    public enum SlideshowMode: String, CaseIterable, Equatable, Sendable {
        case sequential = "sequential"
        
        public var displayName: String {
            switch self {
            case .sequential:
                return "Sequential"
            }
        }
    }
    
    public enum SlideshowState: Equatable, Sendable {
        case stopped
        case playing
        case paused
        
        public var description: String {
            switch self {
            case .stopped: return "stopped"
            case .playing: return "playing"
            case .paused: return "paused"
            }
        }
    }
    
    public var currentPhoto: Photo? {
        guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else {
            return nil
        }
        return photos[currentIndex]
    }
    
    public var isEmpty: Bool {
        photos.isEmpty
    }
    
    public var count: Int {
        photos.count
    }
    
    public var progress: Double {
        guard !isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(count)
    }
    
    public mutating func updatePhotos(_ newPhotos: [Photo]) {
        self.photos = newPhotos
        if currentIndex >= newPhotos.count {
            currentIndex = max(0, newPhotos.count - 1)
        }
    }
    
    public mutating func updatePhoto(at index: Int, with photo: Photo) throws {
        guard index >= 0 && index < photos.count else {
            throw SlideshowError.invalidIndex(index)
        }
        photos[index] = photo
    }
    
    public mutating func setCurrentIndex(_ index: Int) throws {
        guard index >= 0 && index < photos.count else {
            throw SlideshowError.invalidIndex(index)
        }
        currentIndex = index
    }
    
    public mutating func nextPhoto() {
        guard !isEmpty else { return }
        
        // Always advance to next photo regardless of mode
        // singleLoop mode should still advance but may have different behavior at end
        let oldIndex = currentIndex
        currentIndex = (currentIndex + 1) % photos.count
        print("📸 Slideshow.nextPhoto(): Advanced from photo \(oldIndex) to \(currentIndex) (total: \(photos.count))")
    }
    
    public mutating func previousPhoto() {
        guard !isEmpty else { return }
        
        // Always move to previous photo regardless of mode
        currentIndex = currentIndex > 0 ? currentIndex - 1 : photos.count - 1
    }
    
    public mutating func setInterval(_ newInterval: SlideshowInterval) {
        self.interval = newInterval
    }
    
    public mutating func setMode(_ newMode: SlideshowMode) {
        self.mode = newMode
    }
    
    public mutating func setState(_ newState: SlideshowState) {
        self.state = newState
    }
    
    public mutating func play() {
        state = .playing
    }
    
    public mutating func pause() {
        state = .paused
    }
    
    public mutating func stop() {
        state = .stopped
    }
    
    public var isPlaying: Bool {
        state == .playing
    }
    
    public var isPaused: Bool {
        state == .paused
    }
    
    public var isStopped: Bool {
        state == .stopped
    }
}