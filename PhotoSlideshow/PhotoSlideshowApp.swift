//
//  PhotoSlideshowApp.swift
//  PhotoSlideshow
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.example.PhotoSlideshow", category: "App")

@main
struct PhotoSlideshowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recentFilesManager = RecentFilesManager()
    
    init() {
        NSLog("🚀 PhotoSlideshowApp: Application started")
        logger.info("🚀 PhotoSlideshowApp: Application started via Logger")
        print("🚀 PhotoSlideshowApp: Application started via print")
        fflush(stdout)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recentFilesManager)
                .onAppear {
                    NSLog("🚀 PhotoSlideshowApp: WindowGroup appeared")
                    logger.info("🚀 PhotoSlideshowApp: WindowGroup appeared via Logger")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            PhotoSlideshowMenuBar.integrated(
                recentFilesManager: recentFilesManager,
                onFolderSelected: { url in
                    // This will be handled by ContentView through notifications
                    NotificationCenter.default.post(
                        name: .init("PhotoSlideshowFolderSelected"),
                        object: url
                    )
                }
            )
        }
    }
}
