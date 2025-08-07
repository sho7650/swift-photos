//
//  SwiftPhotosApp.swift
//  Swift Photos
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import os.log

@main
struct SwiftPhotosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recentFilesManager = RecentFilesManager()
    @State private var localizationService = LocalizationService()
    
    init() {
        ProductionLogger.lifecycle("SwiftPhotosApp: Application started")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recentFilesManager)
                .localizationService(localizationService)
                .onAppear {
                    ProductionLogger.lifecycle("SwiftPhotosApp: WindowGroup appeared")
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
