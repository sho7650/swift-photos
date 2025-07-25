//
//  WindowAccessor.swift
//  PhotoSlideshow
//
//  Created by Claude Code on 2025/07/23.
//

import SwiftUI
import AppKit

/// WindowAccessor provides reliable access to NSWindow from SwiftUI views
/// Based on Swift 6 best practices for window management
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // Use DispatchQueue to ensure window is available
        DispatchQueue.main.async {
            if let window = view.window {
                ProductionLogger.debug("WindowAccessor: Window found: \(window)")
                self.callback(window)
            } else {
                ProductionLogger.debug("WindowAccessor: Window not yet available, retrying...")
                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = view.window {
                        ProductionLogger.debug("WindowAccessor: Window found on retry: \(window)")
                        self.callback(window)
                    } else {
                        ProductionLogger.warning("WindowAccessor: Window still not available")
                    }
                }
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Check if window changed
        DispatchQueue.main.async {
            self.callback(nsView.window)
        }
    }
}

/// WindowConfigurationView provides a SwiftUI interface for window configuration
struct WindowConfigurationView: View {
    let isTransparent: Bool
    let onWindowReady: (NSWindow) -> Void
    
    var body: some View {
        Color.clear
            .background(
                WindowAccessor { window in
                    guard let window = window else { return }
                    onWindowReady(window)
                }
            )
    }
}