import Foundation

public struct SlideshowInterval: Equatable, Hashable, Codable {
    public let seconds: Double
    
    private static let minimumSeconds: Double = 0.5
    private static let maximumSeconds: Double = 60.0
    
    public static let minimum: SlideshowInterval = SlideshowInterval(rawSeconds: minimumSeconds)
    public static let maximum: SlideshowInterval = SlideshowInterval(rawSeconds: maximumSeconds)
    public static let `default`: SlideshowInterval = SlideshowInterval(rawSeconds: 3.0)
    
    private init(rawSeconds: Double) {
        self.seconds = rawSeconds
    }
    
    public init(_ seconds: Double) throws {
        guard seconds >= Self.minimumSeconds && seconds <= Self.maximumSeconds else {
            throw SlideshowError.invalidInterval(seconds)
        }
        self.seconds = seconds
    }
    
    public var timeInterval: TimeInterval {
        seconds
    }
    
    public var displayString: String {
        if seconds < 1.0 {
            return String(format: "%.1fs", seconds)
        } else if seconds.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(seconds))s"
        } else {
            return String(format: "%.1fs", seconds)
        }
    }
}

extension SlideshowInterval {
    public static let presets: [SlideshowInterval] = [
        SlideshowInterval(rawSeconds: 0.5),
        SlideshowInterval(rawSeconds: 1.0),
        SlideshowInterval(rawSeconds: 2.0),
        SlideshowInterval(rawSeconds: 3.0),
        SlideshowInterval(rawSeconds: 5.0),
        SlideshowInterval(rawSeconds: 10.0),
        SlideshowInterval(rawSeconds: 30.0)
    ]
}