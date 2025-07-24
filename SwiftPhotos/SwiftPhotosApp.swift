//
//  SwiftPhotosApp.swift
//  Swift Photos
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.example.SwiftPhotos", category: "App")

@main
struct SwiftPhotosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recentFilesManager = RecentFilesManager()
    
    init() {
        NSLog("🚀 SwiftPhotosApp: Application started")
        logger.info("🚀 SwiftPhotosApp: Application started via Logger")
        print("🚀 SwiftPhotosApp: Application started via print")
        fflush(stdout)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recentFilesManager)
                .onAppear {
                    NSLog("🚀 SwiftPhotosApp: WindowGroup appeared")
                    logger.info("🚀 SwiftPhotosApp: WindowGroup appeared via Logger")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SwiftPhotosMenuBar.integrated(
                recentFilesManager: recentFilesManager,
                onFolderSelected: { url in
                    // This will be handled by ContentView through notifications
                    NotificationCenter.default.post(
                        name: .init("SwiftPhotosFolderSelected"),
                        object: url
                    )
                }
            )
        }
    }
}
