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
public struct ImageHoverCursorModifier: ViewModifier {
    @State private var cursorManager: CursorManager?
    private let logger = Logger(subsystem: "SwiftPhotos", category: "CursorControlModifiers")
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                setupCursorManager()
            }
            .onHover { hovering in
                if hovering {
                    cursorManager?.hideOnImageHover()
                } else {
                    cursorManager?.showOnImageExit()
                }
            }
    }
    
    private func setupCursorManager() {
        guard cursorManager == nil else { return }
        cursorManager = CursorManager.shared()
        cursorManager?.debugLoggingEnabled = true
    }
}

// MARK: - View Extensions

extension View {
    /// Hide cursor when hovering over images
    public func hideOnImageHover() -> some View {
        modifier(ImageHoverCursorModifier())
    }
}