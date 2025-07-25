import Foundation
import CoreGraphics
import Combine
import SwiftUI
import os.log

/// Manages zoom state for photos across the entire application
/// Provides centralized zoom management with persistence and synchronization
@MainActor
public class PhotoZoomState: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentZoomLevel: Double = 1.0
    @Published public var zoomOffset: CGPoint = .zero
    @Published public var isZoomed: Bool = false
    @Published public var canZoomIn: Bool = true
    @Published public var canZoomOut: Bool = false
    @Published public var fitToScreenMode: FitToScreenMode = .fit
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "SwiftPhotos", category: "PhotoZoomState")
    private var zoomHistory: [ZoomHistoryEntry] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Zoom configuration - allow shrinking to 0.25
    public let minimumZoom: Double = 0.25
    public let maximumZoom: Double = 10.0
    public let defaultZoomSteps: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0]
    
    // Current photo context
    private var currentPhotoId: String?
    private var currentPhotoSize: CGSize = .zero
    private var viewportSize: CGSize = .zero
    
    // State persistence
    private let userDefaults = UserDefaults.standard
    private let zoomStateKey = "PhotoZoomState"
    
    // MARK: - Initialization
    
    public init() {
        setupStateObservation()
        loadPersistedState()
        logger.info("📏 PhotoZoomState: Initialized zoom state manager")
    }
    
    // MARK: - Public Interface
    
    /// Set the current photo context
    public func setPhotoContext(photoId: String, photoSize: CGSize, viewportSize: CGSize) {
        let previousPhotoId = currentPhotoId
        
        self.currentPhotoId = photoId
        self.currentPhotoSize = photoSize
        self.viewportSize = viewportSize
        
        // Reset zoom if photo changed
        if previousPhotoId != photoId {
            resetZoomForNewPhoto()
        }
        
        updateZoomConstraints()
        logger.debug("📏 PhotoZoomState: Set context for photo \\(photoId) (\\(photoSize.width)x\\(photoSize.height))")
    }
    
    /// Set zoom to a specific level with optional animation
    public func setZoom(_ zoomLevel: Double, offset: CGPoint = .zero, animated: Bool = true) {
        let clampedZoom = clampZoomLevel(zoomLevel)
        let constrainedOffset = constrainOffset(offset, forZoom: clampedZoom)
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                updateZoomState(zoom: clampedZoom, offset: constrainedOffset)
            }
        } else {
            updateZoomState(zoom: clampedZoom, offset: constrainedOffset)
        }
        
        addToHistory(zoom: clampedZoom, offset: constrainedOffset)
        logger.debug("📏 PhotoZoomState: Set zoom to \\(clampedZoom) with offset \\(constrainedOffset)")
    }
    
    /// Zoom in to the next level
    public func zoomIn(at point: CGPoint = .zero, animated: Bool = true) {
        let nextZoom = getNextZoomLevel(from: currentZoomLevel, direction: .in)
        let newOffset = calculateOffsetForZoomAtPoint(point, newZoom: nextZoom, currentZoom: currentZoomLevel)
        setZoom(nextZoom, offset: newOffset, animated: animated)
    }
    
    /// Zoom out to the previous level
    public func zoomOut(animated: Bool = true) {
        let nextZoom = getNextZoomLevel(from: currentZoomLevel, direction: .out)
        let newOffset = scaleOffsetForZoom(currentOffset: zoomOffset, oldZoom: currentZoomLevel, newZoom: nextZoom)
        setZoom(nextZoom, offset: newOffset, animated: animated)
    }
    
    /// Reset zoom to fit the photo in the viewport
    public func resetZoom(animated: Bool = true) {
        let fitZoom = calculateFitToScreenZoom()
        setZoom(fitZoom, offset: .zero, animated: animated)
    }
    
    /// Zoom to fit width
    public func zoomToFitWidth(animated: Bool = true) {
        guard currentPhotoSize.width > 0 && viewportSize.width > 0 else { return }
        let fitWidth = viewportSize.width / currentPhotoSize.width
        setZoom(fitWidth, offset: .zero, animated: animated)
    }
    
    /// Zoom to fit height
    public func zoomToFitHeight(animated: Bool = true) {
        guard currentPhotoSize.height > 0 && viewportSize.height > 0 else { return }
        let fitHeight = viewportSize.height / currentPhotoSize.height
        setZoom(fitHeight, offset: .zero, animated: animated)
    }
    
    /// Zoom to actual size (100%)
    public func zoomToActualSize(animated: Bool = true) {
        setZoom(1.0, offset: .zero, animated: animated)
    }
    
    /// Toggle between fit and actual size
    public func toggleZoom(animated: Bool = true) {
        if abs(currentZoomLevel - 1.0) < 0.1 {
            resetZoom(animated: animated)
        } else {
            zoomToActualSize(animated: animated)
        }
    }
    
    /// Pan the zoomed photo
    public func pan(by delta: CGPoint) {
        let newOffset = CGPoint(
            x: zoomOffset.x + delta.x,
            y: zoomOffset.y + delta.y
        )
        let constrainedOffset = constrainOffset(newOffset, forZoom: currentZoomLevel)
        
        withAnimation(.easeOut(duration: 0.1)) {
            zoomOffset = constrainedOffset
        }
    }
    
    /// Get the scaled photo size at current zoom
    public func getScaledPhotoSize() -> CGSize {
        return CGSize(
            width: currentPhotoSize.width * currentZoomLevel,
            height: currentPhotoSize.height * currentZoomLevel
        )
    }
    
    /// Get the visible bounds of the photo in the viewport
    public func getVisibleBounds() -> CGRect {
        let scaledSize = getScaledPhotoSize()
        return CGRect(
            x: -zoomOffset.x,
            y: -zoomOffset.y,
            width: min(scaledSize.width, viewportSize.width),
            height: min(scaledSize.height, viewportSize.height)
        )
    }
    
    /// Check if a point is visible in the current view
    public func isPointVisible(_ point: CGPoint) -> Bool {
        let visibleBounds = getVisibleBounds()
        return visibleBounds.contains(point)
    }
    
    /// Get zoom info for display
    public func getZoomInfo() -> ZoomInfo {
        return ZoomInfo(
            zoomLevel: currentZoomLevel,
            zoomPercentage: Int(currentZoomLevel * 100),
            isZoomed: isZoomed,
            canZoomIn: canZoomIn,
            canZoomOut: canZoomOut,
            fitToScreenMode: fitToScreenMode,
            scaledSize: getScaledPhotoSize(),
            visibleBounds: getVisibleBounds()
        )
    }
    
    /// Go back to previous zoom state
    public func goBack() -> Bool {
        guard let previousEntry = zoomHistory.last else { return false }
        
        zoomHistory.removeLast()
        setZoom(previousEntry.zoomLevel, offset: previousEntry.offset, animated: true)
        return true
    }
    
    /// Clear zoom history
    public func clearHistory() {
        zoomHistory.removeAll()
        logger.debug("📏 PhotoZoomState: Cleared zoom history")
    }
    
    // MARK: - Private Methods
    
    private func setupStateObservation() {
        // Observe zoom level changes
        $currentZoomLevel
            .sink { [weak self] zoomLevel in
                self?.updateZoomFlags(for: zoomLevel)
                self?.persistState()
            }
            .store(in: &cancellables)
        
        // Observe offset changes
        $zoomOffset
            .sink { [weak self] _ in
                self?.persistState()
            }
            .store(in: &cancellables)
    }
    
    private func updateZoomState(zoom: Double, offset: CGPoint) {
        currentZoomLevel = zoom
        zoomOffset = offset
        isZoomed = zoom > 1.1
        updateZoomConstraints()
    }
    
    private func updateZoomFlags(for zoomLevel: Double) {
        canZoomIn = zoomLevel < maximumZoom * 0.99
        canZoomOut = zoomLevel > minimumZoom * 1.01
        
        // Update fit mode based on current zoom
        if abs(zoomLevel - calculateFitToScreenZoom()) < 0.05 {
            fitToScreenMode = .fit
        } else if abs(zoomLevel - calculateFitWidthZoom()) < 0.05 {
            fitToScreenMode = .fitWidth
        } else if abs(zoomLevel - calculateFitHeightZoom()) < 0.05 {
            fitToScreenMode = .fitHeight
        } else if abs(zoomLevel - 1.0) < 0.05 {
            fitToScreenMode = .actualSize
        } else {
            fitToScreenMode = .custom
        }
    }
    
    private func updateZoomConstraints() {
        // Update zoom constraints based on photo and viewport size
        // This could be enhanced to prevent zooming out too much for small photos
    }
    
    private func resetZoomForNewPhoto() {
        let fitZoom = calculateFitToScreenZoom()
        updateZoomState(zoom: fitZoom, offset: .zero)
        clearHistory()
    }
    
    private func clampZoomLevel(_ zoomLevel: Double) -> Double {
        return max(minimumZoom, min(maximumZoom, zoomLevel))
    }
    
    private func constrainOffset(_ offset: CGPoint, forZoom zoomLevel: Double) -> CGPoint {
        guard zoomLevel > 1.0 else { return .zero }
        
        let scaledSize = CGSize(
            width: currentPhotoSize.width * zoomLevel,
            height: currentPhotoSize.height * zoomLevel
        )
        
        let maxOffsetX = max(0, (scaledSize.width - viewportSize.width) / 2)
        let maxOffsetY = max(0, (scaledSize.height - viewportSize.height) / 2)
        
        return CGPoint(
            x: max(-maxOffsetX, min(maxOffsetX, offset.x)),
            y: max(-maxOffsetY, min(maxOffsetY, offset.y))
        )
    }
    
    private func getNextZoomLevel(from currentZoom: Double, direction: ZoomDirection) -> Double {
        let steps = defaultZoomSteps.filter { $0 >= minimumZoom && $0 <= maximumZoom }
        
        switch direction {
        case .in:
            return steps.first { $0 > currentZoom + 0.01 } ?? maximumZoom
        case .out:
            return steps.last { $0 < currentZoom - 0.01 } ?? minimumZoom
        }
    }
    
    private func calculateOffsetForZoomAtPoint(_ point: CGPoint, newZoom: Double, currentZoom: Double) -> CGPoint {
        guard newZoom != currentZoom else { return zoomOffset }
        
        let zoomRatio = newZoom / currentZoom
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let deltaFromCenter = CGPoint(x: point.x - viewportCenter.x, y: point.y - viewportCenter.y)
        
        return CGPoint(
            x: zoomOffset.x * zoomRatio + deltaFromCenter.x * (1 - zoomRatio),
            y: zoomOffset.y * zoomRatio + deltaFromCenter.y * (1 - zoomRatio)
        )
    }
    
    private func scaleOffsetForZoom(currentOffset: CGPoint, oldZoom: Double, newZoom: Double) -> CGPoint {
        guard oldZoom != 0 else { return .zero }
        let scaleFactor = newZoom / oldZoom
        return CGPoint(
            x: currentOffset.x * scaleFactor,
            y: currentOffset.y * scaleFactor
        )
    }
    
    private func calculateFitToScreenZoom() -> Double {
        guard currentPhotoSize.width > 0 && currentPhotoSize.height > 0 &&
              viewportSize.width > 0 && viewportSize.height > 0 else { return 1.0 }
        
        let scaleX = viewportSize.width / currentPhotoSize.width
        let scaleY = viewportSize.height / currentPhotoSize.height
        return min(scaleX, scaleY)
    }
    
    private func calculateFitWidthZoom() -> Double {
        guard currentPhotoSize.width > 0 && viewportSize.width > 0 else { return 1.0 }
        return viewportSize.width / currentPhotoSize.width
    }
    
    private func calculateFitHeightZoom() -> Double {
        guard currentPhotoSize.height > 0 && viewportSize.height > 0 else { return 1.0 }
        return viewportSize.height / currentPhotoSize.height
    }
    
    private func addToHistory(zoom: Double, offset: CGPoint) {
        let entry = ZoomHistoryEntry(
            zoomLevel: zoom,
            offset: offset,
            timestamp: Date()
        )
        
        zoomHistory.append(entry)
        
        // Limit history size
        if zoomHistory.count > 10 {
            zoomHistory.removeFirst()
        }
    }
    
    private func persistState() {
        let state = PersistedZoomState(
            zoomLevel: currentZoomLevel,
            offset: zoomOffset,
            photoId: currentPhotoId
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            userDefaults.set(encoded, forKey: zoomStateKey)
        }
    }
    
    private func loadPersistedState() {
        guard let data = userDefaults.data(forKey: zoomStateKey),
              let state = try? JSONDecoder().decode(PersistedZoomState.self, from: data) else { return }
        
        // Only restore state if it's for the same photo
        if state.photoId == currentPhotoId {
            updateZoomState(zoom: state.zoomLevel, offset: state.offset)
        }
    }
}

// MARK: - Supporting Types

/// Direction for zoom operations
public enum ZoomDirection {
    case `in`
    case out
}

/// Fit to screen modes
public enum FitToScreenMode: String, CaseIterable {
    case fit = "fit"
    case fitWidth = "fitWidth"
    case fitHeight = "fitHeight"
    case actualSize = "actualSize"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .fit: return "Fit to Screen"
        case .fitWidth: return "Fit Width"
        case .fitHeight: return "Fit Height"
        case .actualSize: return "Actual Size"
        case .custom: return "Custom"
        }
    }
}

/// Comprehensive zoom information
public struct ZoomInfo {
    public let zoomLevel: Double
    public let zoomPercentage: Int
    public let isZoomed: Bool
    public let canZoomIn: Bool
    public let canZoomOut: Bool
    public let fitToScreenMode: FitToScreenMode
    public let scaledSize: CGSize
    public let visibleBounds: CGRect
}

/// Zoom history entry
private struct ZoomHistoryEntry {
    let zoomLevel: Double
    let offset: CGPoint
    let timestamp: Date
}

/// Persistable zoom state
private struct PersistedZoomState: Codable {
    let zoomLevel: Double
    let offset: CGPoint
    let photoId: String?
}

// MARK: - Extensions

// Note: CGPoint already conforms to Codable in macOS 15.5+

// MARK: - Environment Support Removed
// PhotoZoomState is a MainActor-isolated ObservableObject that should be passed
// directly rather than through EnvironmentValues to avoid actor isolation issues
// Use @StateObject or @ObservedObject instead of EnvironmentValues for this class