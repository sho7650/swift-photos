import Foundation

public enum WindowLevel: String, CaseIterable, Codable, Sendable {
    case normal = "normal"
    case alwaysOnTop = "alwaysOnTop"
    case alwaysAtBottom = "alwaysAtBottom"
    
    public var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .alwaysOnTop:
            return "Always on Top"
        case .alwaysAtBottom:
            return "Always at Bottom"
        }
    }
    
    public var description: String {
        switch self {
        case .normal:
            return "Window behaves normally"
        case .alwaysOnTop:
            return "Window stays above all other windows"
        case .alwaysAtBottom:
            return "Window stays behind all other windows"
        }
    }
}