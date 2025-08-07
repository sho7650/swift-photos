@preconcurrency import Foundation
import SwiftUI
import AppKit

/// Advanced positioning strategies for multi-display setups
/// Provides intelligent overlay positioning across multiple monitors

// MARK: - Multi-Display Strategy

/// Multi-display aware positioning strategy with screen preference support
public struct MultiDisplayPositioningStrategy: PositioningStrategy {
    public let screenPreference: ScreenPreference
    public let fallbackStrategy: PositioningStrategy
    
    public init(
        screenPreference: ScreenPreference = .current,
        fallbackStrategy: PositioningStrategy? = nil
    ) {
        self.screenPreference = screenPreference
        self.fallbackStrategy = fallbackStrategy ?? AdaptivePositioningStrategy()
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        // Get target screen configuration
        let screenInfo = getTargetScreenInfo()
        
        // If we have multiple screens, use multi-display logic
        if NSScreen.screens.count > 1 {
            return calculateMultiDisplayPosition(
                for: overlay,
                in: bounds,
                targetScreen: screenInfo,
                avoiding: obstacles
            )
        } else {
            // Single display fallback
            return fallbackStrategy.position(for: overlay, in: bounds, avoiding: obstacles)
        }
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        // Validate across all screen boundaries
        let allScreensBounds = getAllScreensBounds()
        
        let overlaySize = CGSize(width: 100, height: 50)
        let overlayFrame = CGRect(
            origin: CGPoint(
                x: position.x - overlaySize.width / 2,
                y: position.y - overlaySize.height / 2
            ),
            size: overlaySize
        )
        
        // Check if overlay is within any screen bounds
        let isWithinScreens = NSScreen.screens.contains { screen in
            screen.frame.intersects(overlayFrame)
        }
        
        return isWithinScreens && !hasObstacleCollisions(overlayFrame, obstacles: constraints.obstacles)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        let screenInfo = getTargetScreenInfo()
        return getPreferredZonesForScreen(overlay: overlay, screen: screenInfo)
    }
    
    // MARK: - Private Methods
    
    private func getTargetScreenInfo() -> ScreenDisplayInfo {
        let screens = NSScreen.screens
        
        let targetScreen: NSScreen
        switch screenPreference {
        case .current:
            targetScreen = NSScreen.main ?? screens.first!
        case .primary:
            targetScreen = screens.first { $0.frame.origin == .zero } ?? screens.first!
        case .secondary:
            targetScreen = screens.first { $0 != NSScreen.main } ?? NSScreen.main ?? screens.first!
        case .largest:
            targetScreen = screens.max { screen1, screen2 in
                let area1 = screen1.frame.width * screen1.frame.height
                let area2 = screen2.frame.width * screen2.frame.height
                return area1 < area2
            } ?? screens.first!
        case .specific(let index):
            targetScreen = screens.indices.contains(index) ? screens[index] : screens.first!
        }
        
        return ScreenDisplayInfo(
            screen: targetScreen,
            frame: targetScreen.frame,
            visibleFrame: targetScreen.visibleFrame,
            isMain: targetScreen == NSScreen.main,
            scaleFactor: targetScreen.backingScaleFactor
        )
    }
    
    private func calculateMultiDisplayPosition(
        for overlay: OverlayType,
        in bounds: CGRect,
        targetScreen: ScreenDisplayInfo,
        avoiding obstacles: [CGRect]
    ) -> CGPoint {
        // Get preferred zones for this overlay type on the target screen
        let zones = getPreferredZonesForScreen(overlay: overlay, screen: targetScreen)
        
        // Try each zone in order of preference
        for zone in zones {
            if let position = findBestPositionInZone(zone, avoiding: obstacles) {
                return convertToWindowCoordinates(position, from: targetScreen.frame, to: bounds)
            }
        }
        
        // Fallback to center of target screen
        let screenCenter = CGPoint(
            x: targetScreen.frame.midX,
            y: targetScreen.frame.midY
        )
        
        return convertToWindowCoordinates(screenCenter, from: targetScreen.frame, to: bounds)
    }
    
    private func getPreferredZonesForScreen(overlay: OverlayType, screen: ScreenDisplayInfo) -> [CGRect] {
        let frame = screen.visibleFrame
        let margin: CGFloat = 20
        
        switch overlay {
        case .controls:
            return [
                // Bottom center of target screen
                CGRect(x: frame.midX - 150, y: frame.maxY - 100, width: 300, height: 60),
                // Bottom left of target screen
                CGRect(x: frame.minX + margin, y: frame.maxY - 100, width: 200, height: 60),
                // Bottom right of target screen
                CGRect(x: frame.maxX - 220, y: frame.maxY - 100, width: 200, height: 60)
            ]
        case .information:
            return [
                // Top right of target screen for secondary display
                CGRect(x: frame.maxX - 420, y: frame.minY + margin, width: 400, height: 200),
                // Bottom center for main display
                CGRect(x: frame.midX - 200, y: frame.maxY - 250, width: 400, height: 200)
            ]
        case .progress:
            return [
                // Top of target screen
                CGRect(x: frame.midX - 200, y: frame.minY + margin, width: 400, height: 30)
            ]
        case .menu:
            return [
                // Top right corner of target screen
                CGRect(x: frame.maxX - 170, y: frame.minY + margin, width: 150, height: 300)
            ]
        case .tooltip, .notification:
            return [
                // Top right of target screen
                CGRect(x: frame.maxX - 320, y: frame.minY + margin, width: 300, height: 80)
            ]
        }
    }
    
    private func findBestPositionInZone(_ zone: CGRect, avoiding obstacles: [CGRect]) -> CGPoint? {
        let stepSize: CGFloat = 30
        
        for y in stride(from: zone.minY, through: zone.maxY, by: stepSize) {
            for x in stride(from: zone.minX, through: zone.maxX, by: stepSize) {
                let candidate = CGPoint(x: x, y: y)
                let testFrame = CGRect(x: x - 50, y: y - 25, width: 100, height: 50)
                
                let hasConflict = obstacles.contains { obstacle in
                    obstacle.intersects(testFrame)
                }
                
                if !hasConflict {
                    return candidate
                }
            }
        }
        
        return nil
    }
    
    private func convertToWindowCoordinates(_ screenPosition: CGPoint, from screenFrame: CGRect, to windowBounds: CGRect) -> CGPoint {
        // Convert screen coordinates to relative position
        let relativeX = (screenPosition.x - screenFrame.minX) / screenFrame.width
        let relativeY = (screenPosition.y - screenFrame.minY) / screenFrame.height
        
        // Apply to window bounds
        return CGPoint(
            x: windowBounds.minX + (windowBounds.width * relativeX),
            y: windowBounds.minY + (windowBounds.height * relativeY)
        )
    }
    
    private func getAllScreensBounds() -> CGRect {
        return NSScreen.screens.reduce(CGRect.zero) { result, screen in
            result.union(screen.frame)
        }
    }
    
    private func hasObstacleCollisions(_ frame: CGRect, obstacles: [CGRect]) -> Bool {
        return obstacles.contains { obstacle in
            frame.intersects(obstacle)
        }
    }
}

// MARK: - Presenter Display Strategy

/// Strategy optimized for presentation mode with dual displays
public struct PresenterDisplayStrategy: PositioningStrategy {
    public let presenterScreen: NSScreen?
    public let audienceScreen: NSScreen?
    
    public init() {
        let screens = NSScreen.screens
        
        if screens.count >= 2 {
            // Primary screen is for audience, secondary for presenter
            let audience = screens.first { $0.frame.origin == .zero } ?? screens.first
            self.audienceScreen = audience
            self.presenterScreen = screens.first { $0 != audience }
        } else {
            self.audienceScreen = screens.first
            self.presenterScreen = nil
        }
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        // Determine which screen should show this overlay
        let targetScreen = getTargetScreenForOverlay(overlay)
        
        guard let screen = targetScreen else {
            // Fallback to center
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }
        
        let position = calculatePresenterPosition(for: overlay, on: screen)
        return convertToWindowCoordinates(position, from: screen.frame, to: bounds)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        let targetScreen = getTargetScreenForOverlay(overlay)
        
        guard let screen = targetScreen else { return false }
        
        let overlaySize = CGSize(width: 100, height: 50)
        let overlayFrame = CGRect(
            origin: CGPoint(
                x: position.x - overlaySize.width / 2,
                y: position.y - overlaySize.height / 2
            ),
            size: overlaySize
        )
        
        return screen.frame.contains(overlayFrame)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        return calculatePresenterZones(for: overlay, in: bounds)
    }
    
    private func calculatePresenterZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        return [bounds] // Simple fallback implementation
    }
    
    private func getTargetScreenForOverlay(_ overlay: OverlayType) -> NSScreen? {
        switch overlay {
        case .controls, .information, .menu:
            // Presenter controls go on presenter screen
            return presenterScreen ?? audienceScreen
        case .progress, .notification:
            // Progress and notifications on audience screen
            return audienceScreen
        case .tooltip:
            // Tooltips follow context
            return presenterScreen ?? audienceScreen
        }
    }
    
    private func calculatePresenterPosition(for overlay: OverlayType, on screen: NSScreen) -> CGPoint {
        let frame = screen.visibleFrame
        
        switch overlay {
        case .controls:
            // Bottom center of presenter screen
            return CGPoint(x: frame.midX, y: frame.maxY - 80)
        case .information:
            // Right side of presenter screen
            return CGPoint(x: frame.maxX - 250, y: frame.midY)
        case .progress:
            // Top of audience screen
            return CGPoint(x: frame.midX, y: frame.minY + 30)
        case .menu:
            // Top right of presenter screen
            return CGPoint(x: frame.maxX - 100, y: frame.minY + 100)
        case .tooltip, .notification:
            // Context-dependent positioning
            return CGPoint(x: frame.midX, y: frame.minY + 100)
        }
    }
    
    private func convertToWindowCoordinates(_ screenPosition: CGPoint, from screenFrame: CGRect, to windowBounds: CGRect) -> CGPoint {
        let relativeX = (screenPosition.x - screenFrame.minX) / screenFrame.width
        let relativeY = (screenPosition.y - screenFrame.minY) / screenFrame.height
        
        return CGPoint(
            x: windowBounds.minX + (windowBounds.width * relativeX),
            y: windowBounds.minY + (windowBounds.height * relativeY)
        )
    }
}

// MARK: - Screen Preference Types

/// Screen selection preferences for multi-display positioning
public enum ScreenPreference: Codable, Sendable, Equatable, Hashable {
    case current
    case primary
    case secondary
    case largest
    case specific(Int)
}

/// Detailed screen information for positioning calculations
public struct ScreenDisplayInfo {
    public let screen: NSScreen
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let isMain: Bool
    public let scaleFactor: CGFloat
    
    public var workingArea: CGRect {
        // Account for dock and menu bar
        return visibleFrame
    }
    
    public var effectiveResolution: CGSize {
        return CGSize(
            width: frame.width * scaleFactor,
            height: frame.height * scaleFactor
        )
    }
}

// MARK: - Adaptive Multi-Display Strategy

/// Intelligent strategy that adapts to screen configuration changes
public struct AdaptiveMultiDisplayStrategy: PositioningStrategy {
    private let strategies: [PositioningStrategy]
    
    public init() {
        self.strategies = [
            PresenterDisplayStrategy(),
            MultiDisplayPositioningStrategy(screenPreference: .largest),
            MultiDisplayPositioningStrategy(screenPreference: .primary),
            AdaptivePositioningStrategy() // Fallback
        ]
    }
    
    public func position(for overlay: OverlayType, in bounds: CGRect, avoiding obstacles: [CGRect]) -> CGPoint {
        let screenCount = NSScreen.screens.count
        
        // Choose strategy based on screen configuration
        let strategy: PositioningStrategy
        
        switch screenCount {
        case 1:
            strategy = strategies.last! // AdaptivePositioningStrategy
        case 2:
            strategy = strategies.first! // PresenterDisplayStrategy
        default:
            strategy = strategies[1] // MultiDisplayPositioningStrategy with largest screen
        }
        
        return strategy.position(for: overlay, in: bounds, avoiding: obstacles)
    }
    
    public func validatePosition(_ position: CGPoint, for overlay: OverlayType, constraints: PositionConstraints) -> Bool {
        // Use the same strategy selection logic
        let screenCount = NSScreen.screens.count
        let strategy: PositioningStrategy
        
        switch screenCount {
        case 1:
            strategy = strategies.last!
        case 2:
            strategy = strategies.first!
        default:
            strategy = strategies[1]
        }
        
        return strategy.validatePosition(position, for: overlay, constraints: constraints)
    }
    
    public func getPreferredZones(for overlay: OverlayType, in bounds: CGRect) -> [CGRect] {
        let screenCount = NSScreen.screens.count
        let strategy: PositioningStrategy
        
        switch screenCount {
        case 1:
            strategy = strategies.last!
        case 2:
            strategy = strategies.first!
        default:
            strategy = strategies[1]
        }
        
        return strategy.getPreferredZones(for: overlay, in: bounds)
    }
}

// MARK: - Screen Configuration Monitor

/// Monitor for screen configuration changes
@MainActor
public class ScreenConfigurationMonitor: ObservableObject {
    @Published public private(set) var screenConfiguration: [ScreenDisplayInfo] = []
    @Published public private(set) var primaryScreen: ScreenDisplayInfo?
    @Published public private(set) var screenCount: Int = 0
    
    public weak var delegate: ScreenConfigurationMonitorDelegate?
    
    private var observer: NSObjectProtocol?
    
    public init() {
        updateScreenConfiguration()
        setupNotificationObserver()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotificationObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenConfigurationChange()
            }
        }
    }
    
    private func handleScreenConfigurationChange() {
        let oldConfiguration = screenConfiguration
        updateScreenConfiguration()
        
        let configurationChanged = oldConfiguration.count != screenConfiguration.count ||
                                 oldConfiguration.first?.frame != screenConfiguration.first?.frame
        
        if configurationChanged {
            delegate?.screenConfigurationDidChange(from: oldConfiguration, to: screenConfiguration)
        }
    }
    
    private func updateScreenConfiguration() {
        let screens = NSScreen.screens
        
        screenConfiguration = screens.map { screen in
            ScreenDisplayInfo(
                screen: screen,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                isMain: screen == NSScreen.main,
                scaleFactor: screen.backingScaleFactor
            )
        }
        
        primaryScreen = screenConfiguration.first { $0.isMain }
        screenCount = screens.count
    }
    
    public func getOptimalScreenFor(overlay: OverlayType) -> ScreenDisplayInfo? {
        guard !screenConfiguration.isEmpty else { return nil }
        
        switch overlay {
        case .controls, .information:
            // Prefer main screen for primary controls
            return primaryScreen ?? screenConfiguration.first
        case .progress, .notification:
            // Progress can go on any screen, prefer largest
            return screenConfiguration.max { screen1, screen2 in
                let area1 = screen1.frame.width * screen1.frame.height
                let area2 = screen2.frame.width * screen2.frame.height
                return area1 < area2
            }
        case .menu, .tooltip:
            // Context-dependent, prefer current
            return primaryScreen ?? screenConfiguration.first
        }
    }
}

/// Delegate protocol for screen configuration monitoring
public protocol ScreenConfigurationMonitorDelegate: AnyObject {
    func screenConfigurationDidChange(from oldConfiguration: [ScreenDisplayInfo], to newConfiguration: [ScreenDisplayInfo])
}