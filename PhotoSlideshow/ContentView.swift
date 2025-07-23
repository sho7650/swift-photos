//
//  ContentView.swift
//  PhotoSlideshow
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.example.PhotoSlideshow", category: "ContentView")

struct ContentView: View {
    @State private var viewModel: SlideshowViewModel?
    @State private var keyboardHandler: KeyboardHandler?
    @State private var uiControlStateManager: UIControlStateManager?
    @State private var isInitialized = false
    @StateObject private var performanceSettings = PerformanceSettingsManager()
    @StateObject private var slideshowSettings = SlideshowSettingsManager()
    @StateObject private var sortSettings = SortSettingsManager()
    @StateObject private var transitionSettings = TransitionSettingsManager()
    @StateObject private var uiControlSettings = UIControlSettingsManager()
    @StateObject private var settingsWindowManager = SettingsWindowManager()
    
    var body: some View {
        Group {
            if isInitialized, 
               let viewModel = viewModel, 
               let keyboardHandler = keyboardHandler,
               let uiControlStateManager = uiControlStateManager {
                ZStack {
                    // Main content
                    ImageDisplayViewWithObserver(viewModel: viewModel)
                        .environmentObject(transitionSettings)
                        .ignoresSafeArea()
                    
                    // Minimal controls overlay (always present in ZStack, visibility controlled internally)
                    MinimalControlsView(
                        viewModel: viewModel,
                        uiControlStateManager: uiControlStateManager,
                        uiControlSettings: uiControlSettings
                    )
                    .shortcutTooltip("Hide/Show Controls", shortcut: "H")
                    
                    // Detailed info overlay (shown when toggled)
                    DetailedInfoOverlay(
                        viewModel: viewModel,
                        uiControlStateManager: uiControlStateManager,
                        uiControlSettings: uiControlSettings
                    )
                }
                .keyboardHandler(keyboardHandler)
                .onHover { hovering in
                    if hovering {
                        uiControlStateManager.handleMouseInteraction(at: NSEvent.mouseLocation)
                    }
                    uiControlStateManager.updateMouseInWindow(hovering)
                }
                .onTapGesture {
                    uiControlStateManager.handleGestureInteraction()
                }
                .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                    Button("OK") {
                        viewModel.clearError()
                    }
                } message: {
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Initializing...")
                        .padding()
                }
                .onAppear {
                    NSLog("📱 PhotoSlideshow DEBUG: ContentView loading screen appeared")
                    logger.info("📱 ContentView: Loading screen appeared")
                }
            }
        }
        .onAppear {
            if !isInitialized {
                initializeApp()
            }
        }
    }
    
    private func initializeApp() {
        print("📱 PhotoSlideshow DEBUG: initializeApp() called")
        print("🏗️ ContentView: Starting initialization...")
        
        // Add small delay to ensure UI is ready
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            print("📱 PhotoSlideshow DEBUG: Creating dependencies...")
            // Create dependencies safely
            let fileAccess = SecureFileAccess()
            let imageLoader = ImageLoader()
            let imageCache = ImageCache()
            let repository = FileSystemPhotoRepository(fileAccess: fileAccess, imageLoader: imageLoader, sortSettings: sortSettings)
            let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
            
            // Create view model and UI managers
            let createdViewModel = SlideshowViewModel(domainService: domainService, fileAccess: fileAccess, performanceSettings: performanceSettings, slideshowSettings: slideshowSettings)
            let createdKeyboardHandler = KeyboardHandler()
            let createdUIControlStateManager = UIControlStateManager(uiControlSettings: uiControlSettings, slideshowViewModel: createdViewModel)
            
            // Setup keyboard handler connections
            createdKeyboardHandler.viewModel = createdViewModel
            createdKeyboardHandler.performanceSettings = performanceSettings
            createdKeyboardHandler.onOpenSettings = {
                settingsWindowManager.openSettingsWindow(
                    performanceSettings: performanceSettings,
                    slideshowSettings: slideshowSettings,
                    sortSettings: sortSettings,
                    transitionSettings: transitionSettings
                )
            }
            
            // Setup UI control state manager callbacks
            createdKeyboardHandler.onKeyboardInteraction = {
                createdUIControlStateManager.handleKeyboardInteraction()
            }
            createdKeyboardHandler.onToggleDetailedInfo = {
                createdUIControlStateManager.toggleDetailedInfo()
            }
            createdKeyboardHandler.onToggleControlsVisibility = {
                if createdUIControlStateManager.isControlsVisible {
                    createdUIControlStateManager.hideControls(force: true)
                } else {
                    createdUIControlStateManager.showControls()
                }
            }
            
            // Set state
            self.viewModel = createdViewModel
            self.keyboardHandler = createdKeyboardHandler
            self.uiControlStateManager = createdUIControlStateManager
            self.isInitialized = true
            
            print("🏗️ ContentView: Initialization completed successfully")
        }
    }
}

#Preview {
    ContentView()
}
