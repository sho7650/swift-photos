//
//  ContentView.swift
//  Swift Photos
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.example.SwiftPhotos", category: "ContentView")

struct ContentView: View {
    @State private var viewModel: SlideshowViewModel?
    @State private var keyboardHandler: KeyboardHandler?
    @State private var uiControlStateManager: UIControlStateManager?
    @State private var isInitialized = false
    @State private var secureFileAccess = SecureFileAccess()
    @StateObject private var performanceSettings = PerformanceSettingsManager()
    @StateObject private var slideshowSettings = SlideshowSettingsManager()
    @StateObject private var sortSettings = SortSettingsManager()
    @StateObject private var transitionSettings = TransitionSettingsManager()
    @StateObject private var uiControlSettings = UIControlSettingsManager()
    @StateObject private var settingsWindowManager = SettingsWindowManager()
    @EnvironmentObject private var recentFilesManager: RecentFilesManager
    
    var body: some View {
        Group {
            if isInitialized, 
               let viewModel = viewModel, 
               let keyboardHandler = keyboardHandler,
               let uiControlStateManager = uiControlStateManager {
                ZStack {
                    // Main content (gesture functionality removed)
                    SimpleImageDisplayView(
                        viewModel: viewModel
                    )
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
                // Temporarily disable tap gesture to test swipe functionality
                // .onTapGesture {
                //     uiControlStateManager.handleGestureInteraction()
                // }
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
                    NSLog("📱 Swift Photos DEBUG: ContentView loading screen appeared")
                    logger.info("📱 ContentView: Loading screen appeared")
                }
            }
        }
        .onAppear {
            if !isInitialized {
                initializeApp()
                setupMenuNotificationObserver()
            }
        }
    }
    
    private func initializeApp() {
        print("📱 Swift Photos DEBUG: initializeApp() called")
        print("🏗️ ContentView: Starting initialization...")
        
        // Add small delay to ensure UI is ready
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            print("📱 Swift Photos DEBUG: Creating dependencies...")
            // Create dependencies safely using persistent SecureFileAccess
            let imageLoader = ImageLoader()
            let imageCache = ImageCache()
            let repository = FileSystemPhotoRepository(fileAccess: secureFileAccess, imageLoader: imageLoader, sortSettings: sortSettings)
            let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
            
            // Create view model and UI managers
            let createdViewModel = SlideshowViewModel(domainService: domainService, fileAccess: secureFileAccess, performanceSettings: performanceSettings, slideshowSettings: slideshowSettings, sortSettings: sortSettings)
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
                    transitionSettings: transitionSettings,
                    uiControlSettings: uiControlSettings,
                    recentFilesManager: recentFilesManager
                )
            }
            createdKeyboardHandler.onOpenFolder = {
                Task { @MainActor in
                    await self.handleTraditionalFolderSelection()
                }
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
            
            // Zoom callbacks removed (gesture functionality removed)
            
            // Set state
            self.viewModel = createdViewModel
            self.keyboardHandler = createdKeyboardHandler
            self.uiControlStateManager = createdUIControlStateManager
            self.isInitialized = true
            
            print("🏗️ ContentView: Initialization completed successfully")
        }
    }
    
    // MARK: - Folder Selection Integration
    
    private func handleTraditionalFolderSelection() async {
        print("📁 ContentView: Handling traditional folder selection (Cmd+O)")
        
        guard let viewModel = viewModel else {
            print("❌ ContentView: No view model available")
            return
        }
        
        // Store current folder URL for recent files integration
        let previousFolderURL = viewModel.selectedFolderURL
        
        // Call the viewModel's selectFolder method
        await viewModel.selectFolder()
        
        // If a new folder was selected, add it to recent files
        if let newFolderURL = viewModel.selectedFolderURL,
           newFolderURL != previousFolderURL {
            print("📁 ContentView: New folder selected via traditional method: \(newFolderURL.path)")
            
            do {
                // Create security bookmark for the folder
                let bookmarkData = try newFolderURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                // Add to recent files
                await recentFilesManager.addRecentFile(url: newFolderURL, securityBookmark: bookmarkData)
                print("📁 ContentView: Added traditional folder selection to recent files")
                
            } catch {
                print("❌ ContentView: Failed to create security bookmark for traditional folder selection: \(error)")
            }
        }
    }
    
    // MARK: - File Menu Integration
    
    private func setupMenuNotificationObserver() {
        print("📁 ContentView: Setting up menu notification observer")
        
        // Listen for folder selection from File menu
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwiftPhotosFolderSelected"),
            object: nil,
            queue: .main
        ) { notification in
            if let folderURL = notification.object as? URL {
                print("📁 ContentView: Received folder selection from menu: \(folderURL.path)")
                Task { @MainActor in
                    await self.handleFolderSelectedFromMenu(url: folderURL)
                }
            }
        }
    }
    
    private func handleFolderSelectedFromMenu(url: URL) async {
        print("📁 ContentView: Handling folder selection from menu: \(url.path)")
        
        guard let viewModel = viewModel else {
            print("❌ ContentView: No view model available")
            return
        }
        
        // Store the URL and trigger slideshow creation
        viewModel.selectedFolderURL = url
        
        // Generate new random seed if sort order is random
        if sortSettings.settings.order == .random {
            print("🎲 ContentView: Generating new random seed for menu folder selection")
            sortSettings.regenerateRandomSeed()
        }
        
        // Create slideshow from the selected folder with proper security scoped access
        viewModel.isLoading = true
        viewModel.error = nil
        
        do {
            // Check if this URL needs security scoped access
            let needsSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            print("📁 ContentView: Security scoped access \(needsSecurityAccess ? "enabled" : "not required") for: \(url.path)")
            
            // Use private method access through viewModel
            try await createSlideshowForMenuSelection(from: url)
        } catch {
            print("❌ ContentView: Failed to create slideshow from menu selection: \(error)")
            viewModel.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
        }
        
        viewModel.isLoading = false
    }
    
    private func createSlideshowForMenuSelection(from folderURL: URL) async throws {
        print("📁 ContentView: Creating slideshow from menu selection: \(folderURL.path)")
        
        guard let viewModel = viewModel else { 
            print("❌ ContentView: No view model available")
            return 
        }
        
        do {
            // Use the persistent secure file access instance
            // Prepare access for the folder with security bookmark if available
            if let recentFile = recentFilesManager.recentFiles.first(where: { $0.url == folderURL }) {
                print("📁 ContentView: Preparing access using security bookmark from recent files")
                try secureFileAccess.prepareForAccess(url: folderURL, bookmarkData: recentFile.securityBookmark)
            } else {
                print("📁 ContentView: Preparing access without security bookmark (direct access)")
                try secureFileAccess.prepareForAccess(url: folderURL)
            }
            
            let imageLoader = ImageLoader()
            let imageCache = ImageCache()
            let repository = FileSystemPhotoRepository(fileAccess: secureFileAccess, imageLoader: imageLoader, sortSettings: sortSettings)
            let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
            
            // Apply slideshow settings
            let mode: Slideshow.SlideshowMode = .sequential
            let customInterval = try SlideshowInterval(slideshowSettings.settings.slideDuration)
            
            print("📁 ContentView: Creating slideshow with domain service...")
            let newSlideshow = try await domainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            print("📁 ContentView: Created slideshow with \(newSlideshow.photos.count) photos")
            viewModel.slideshow = newSlideshow
            
            if !newSlideshow.isEmpty {
                // Auto-recommend settings for collection size
                let recommendedSettings = performanceSettings.recommendedSettings(for: newSlideshow.photos.count)
                if recommendedSettings != performanceSettings.settings {
                    print("📁 ContentView: Auto-applying recommended settings for \(newSlideshow.photos.count) photos")
                    performanceSettings.updateSettings(recommendedSettings)
                }
                
                // Load current image
                if newSlideshow.photos.count > performanceSettings.settings.largeCollectionThreshold {
                    print("📁 ContentView: Large collection detected - using virtual loading")
                    // Use viewModel's internal loading mechanisms
                    viewModel.currentPhoto = newSlideshow.currentPhoto
                    viewModel.refreshCounter += 1
                } else {
                    print("📁 ContentView: Small collection - loading current image")
                    viewModel.currentPhoto = newSlideshow.currentPhoto
                    viewModel.refreshCounter += 1
                }
                
                // Auto-start slideshow if enabled
                if slideshowSettings.settings.autoStart {
                    print("📁 ContentView: Auto-starting slideshow per settings")
                    viewModel.play()
                }
            }
            
        } catch {
            print("❌ ContentView: Failed to create slideshow: \(error)")
            throw error
        }
    }
}

#Preview {
    ContentView()
}
