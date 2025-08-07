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

/// WindowLevelAccessor manages window level (always on top, always at bottom, normal)
struct WindowLevelAccessor: NSViewRepresentable {
    let windowLevel: WindowLevel
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        updateWindowLevel(view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        updateWindowLevel(nsView)
    }
    
    private func updateWindowLevel(_ view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                // Retry after a short delay if window is not yet available
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard let window = view.window else {
                        ProductionLogger.warning("WindowLevelAccessor: Window not available")
                        return
                    }
                    self.applyWindowLevel(to: window)
                }
                return
            }
            self.applyWindowLevel(to: window)
        }
    }
    
    private func applyWindowLevel(to window: NSWindow) {
        switch windowLevel {
        case .normal:
            window.level = .normal
            ProductionLogger.debug("WindowLevelAccessor: Set window level to normal")
        case .alwaysOnTop:
            window.level = .floating
            ProductionLogger.debug("WindowLevelAccessor: Set window level to floating (always on top)")
        case .alwaysAtBottom:
            // Using a level below normal to keep window at bottom
            window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
            ProductionLogger.debug("WindowLevelAccessor: Set window level to below normal (always at bottom)")
        }
    }
}