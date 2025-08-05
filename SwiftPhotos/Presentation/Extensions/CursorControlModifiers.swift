//
//  CursorControlModifiers.swift
//  Swift Photos
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import AppKit
import os.log

// MARK: - Simple Image Hover Cursor Modifier

/// Simple ViewModifier for hiding cursor when hovering over images
/// Now works with UIInteractionManager's integrated cursor functionality
public struct ImageHoverCursorModifier: ViewModifier {
    @State private var uiInteractionManager: UIInteractionManager?
    private let logger = Logger(subsystem: "SwiftPhotos", category: "CursorControlModifiers")
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                setupUIInteractionManager()
            }
            .onHover { hovering in
                if hovering {
                    uiInteractionManager?.handleMouseEnteredImage()
                } else {
                    uiInteractionManager?.handleMouseExitedImage()
                }
            }
    }
    
    private func setupUIInteractionManager() {
        guard uiInteractionManager == nil else { return }
        // Create a simple UIInteractionManager for cursor management only
        let uiControlSettings = ModernUIControlSettingsManager()
        uiInteractionManager = UIInteractionManager(uiControlSettings: uiControlSettings)
        logger.info("🖱️ ImageHoverCursorModifier: Setup UIInteractionManager for cursor control")
    }
}

// MARK: - View Extensions

extension View {
    /// Hide cursor when hovering over images
    public func hideOnImageHover() -> some View {
        modifier(ImageHoverCursorModifier())
    }
}