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
    
    init() {
        NSLog("🚀 PhotoSlideshowApp: Application started")
        logger.info("🚀 PhotoSlideshowApp: Application started via Logger")
        print("🚀 PhotoSlideshowApp: Application started via print")
        fflush(stdout)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NSLog("🚀 PhotoSlideshowApp: WindowGroup appeared")
                    logger.info("🚀 PhotoSlideshowApp: WindowGroup appeared via Logger")
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
