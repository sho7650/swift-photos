//
//  CursorManager.swift
//  Swift Photos
//
//  Created by Claude on 2025/07/25.
//

import Foundation
import AppKit
import os.log

/// Simple cursor manager for hiding cursor when hovering over images
/// Simplified version focused only on image hover functionality
@MainActor
public class CursorManager: ObservableObject {
    
    // MARK: - Public Properties
    
    /// Current cursor visibility state
    @Published public private(set) var isHidden: Bool = false
    
    /// Whether debug logging is enabled
    public var debugLoggingEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private static var sharedInstance: CursorManager?
    private let logger = Logger(subsystem: "SwiftPhotos", category: "CursorManager")
    
    // MARK: - Singleton Access
    
    /// Shared instance for centralized cursor management
    public static func shared() -> CursorManager {
        if let existing = sharedInstance {
            return existing
        }
        let newInstance = CursorManager()
        sharedInstance = newInstance
        return newInstance
    }
    
    // MARK: - Initialization
    
    public init() {
        logger.info("🖱️ CursorManager: Initialized for image hover functionality")
    }
    
    deinit {
        // Simple cleanup - cursor will be managed by the main actor
        logger.info("🖱️ CursorManager: Deinit cleanup completed")
    }
    
    // MARK: - Public Methods
    
    /// Hide cursor when hovering over image
    public func hideOnImageHover() {
        guard !isHidden else { return }
        
        NSCursor.hide()
        isHidden = true
        logDebug("Cursor hidden on image hover")
    }
    
    /// Show cursor when not hovering over image
    public func showOnImageExit() {
        guard isHidden else { return }
        
        NSCursor.unhide()
        isHidden = false
        logDebug("Cursor shown on image exit")
    }
    
    /// Force cursor to visible state for cleanup
    public func forceShow() {
        if isHidden {
            NSCursor.unhide()
            isHidden = false
            logDebug("Cursor force shown")
        }
    }
    
    // MARK: - Private Methods
    
    private func logDebug(_ message: String) {
        if debugLoggingEnabled {
            logger.debug("🖱️ CursorManager: \(message)")
        }
    }
}