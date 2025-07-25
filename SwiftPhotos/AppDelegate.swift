//
//  AppDelegate.swift
//  Swift Photos
//
//  Created by Claude Code on 2025/07/23.
//

import Cocoa
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.example.SwiftPhotos", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ProductionLogger.lifecycle("AppDelegate: Application did finish launching")
        logger.info("🚀 AppDelegate: Application did finish launching via Logger")
        
        // Configure window transparency after app has fully loaded
        configureWindowTransparency()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ProductionLogger.lifecycle("AppDelegate: Application will terminate")
    }
    
    private func configureWindowTransparency() {
        // Wait a short moment for windows to be properly initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupWindowTransparency()
        }
    }
    
    private func setupWindowTransparency() {
        ProductionLogger.debug("AppDelegate: Setting up window for blur support (best practices)")
        
        for window in NSApplication.shared.windows {
            guard window.isVisible else { continue }
            
            ProductionLogger.debug("AppDelegate: Configuring window: \(window)")
            
            // Best practices for blur-capable window
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            
            // Performance optimizations for blur
            window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            
            // Enable content view layer for Material effects
            if let contentView = window.contentView {
                contentView.wantsLayer = true
            }
            
            // Store window reference for later blur control
            TransparencyManager.shared.registerWindow(window)
            
            ProductionLogger.debug("AppDelegate: Window configured for Material blur support")
        }
    }
}

/// Singleton class to manage window transparency state
class TransparencyManager: ObservableObject {
    static let shared = TransparencyManager()
    
    private var registeredWindows: [NSWindow] = []
    
    private init() {}
    
    func registerWindow(_ window: NSWindow) {
        if !registeredWindows.contains(window) {
            registeredWindows.append(window)
            ProductionLogger.debug("TransparencyManager: Registered window: \(window)")
        }
    }
    
    func enableTransparency() {
        ProductionLogger.debug("TransparencyManager: Enabling blur transparency (best practices)")
        
        for window in registeredWindows {
            // Best practices for Material blur transparency
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = false
            
            // Optimize for blur performance
            window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            
            // Ensure content view supports Material effects
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.clear.cgColor
            }
            
            window.invalidateShadow()
            window.display()
            
            ProductionLogger.debug("TransparencyManager: Material blur transparency enabled for window: \(window)")
        }
    }
    
    func disableTransparency() {
        ProductionLogger.debug("TransparencyManager: Disabling blur transparency")
        
        for window in registeredWindows {
            window.isOpaque = true
            window.backgroundColor = NSColor.black
            window.hasShadow = false
            
            // Reset window settings
            window.collectionBehavior = []
            
            if let contentView = window.contentView {
                contentView.layer?.backgroundColor = NSColor.black.cgColor
            }
            
            window.invalidateShadow()
            window.display()
            
            ProductionLogger.debug("TransparencyManager: Blur transparency disabled for window: \(window)")
        }
    }
    
    // MARK: - Fullscreen Management
    
    func toggleFullscreen() {
        ProductionLogger.userAction("TransparencyManager: Toggling fullscreen")
        
        guard let mainWindow = registeredWindows.first ?? NSApplication.shared.mainWindow else {
            ProductionLogger.error("TransparencyManager: No main window found for fullscreen toggle")
            return
        }
        
        if mainWindow.styleMask.contains(.fullScreen) {
            ProductionLogger.debug("TransparencyManager: Exiting fullscreen")
            mainWindow.toggleFullScreen(nil)
        } else {
            ProductionLogger.debug("TransparencyManager: Entering fullscreen")
            mainWindow.toggleFullScreen(nil)
        }
    }
    
    var isFullscreen: Bool {
        guard let mainWindow = registeredWindows.first ?? NSApplication.shared.mainWindow else {
            return false
        }
        return mainWindow.styleMask.contains(.fullScreen)
    }
}