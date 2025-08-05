//
//  ContentView.swift
//  Swift Photos
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @State private var viewModel: (any SlideshowViewModelProtocol)?
    @State private var keyboardHandler: KeyboardHandler?
    @State private var uiControlStateManager: UIControlStateManager?
    @State private var isInitialized = false
    @State private var secureFileAccess = SecureFileAccess()
    @State private var appSettingsCoordinator = AppSettingsCoordinator()
    @State private var localizationSettings: ModernLocalizationSettingsManager?
    @StateObject private var settingsWindowManager = SettingsWindowManager()
    @EnvironmentObject private var recentFilesManager: RecentFilesManager
    @Environment(\.localizationService) private var localizationService
    
    // Add a computed property to ensure SwiftUI observes the LocalizationService
    private var observedLanguage: String {
        localizationService?.currentLanguage.rawValue ?? "system"
    }
    @State private var languageUpdateTrigger = 0
    
    // Add direct observation of the LocalizationService
    @State private var currentLanguageObserver: String = ""
    
    init() {
        // Initialize is now moved to onAppear to ensure environment values are available
    }
    
    var body: some View {
        Group {
            if isInitialized {
                mainContentView
            } else {
                loadingView
            }
        }
        .onAppear {
            if !isInitialized {
                initializeApp()
                setupMenuNotificationObserver()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            languageUpdateTrigger += 1
            ProductionLogger.debug("ContentView: Received language change notification, trigger: \(languageUpdateTrigger)")
        }
        .onChange(of: localizationService?.currentLanguage) { oldValue, newValue in
            languageUpdateTrigger += 1
            ProductionLogger.debug("ContentView: Language changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil"), trigger: \(languageUpdateTrigger)")
        }
        .onChange(of: localizationService?.currentLocale) { oldValue, newValue in
            languageUpdateTrigger += 1 
            ProductionLogger.debug("ContentView: Locale changed from \(oldValue?.identifier ?? "nil") to \(newValue?.identifier ?? "nil"), trigger: \(languageUpdateTrigger)")
        }
        .id(languageUpdateTrigger) // Force view recreation when language changes
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if let viewModel = viewModel, 
           let keyboardHandler = keyboardHandler,
           let uiControlStateManager = uiControlStateManager {
            slideshowContentView(viewModel: viewModel, keyboardHandler: keyboardHandler, uiControlStateManager: uiControlStateManager)
        } else {
            componentLoadingView
        }
    }
    
    @ViewBuilder
    private func slideshowContentView(viewModel: any SlideshowViewModelProtocol, keyboardHandler: KeyboardHandler, uiControlStateManager: UIControlStateManager) -> some View {
                ZStack {
                    // Main content with unified ViewModel approach
                    // Use UnifiedImageDisplayView for all ViewModel types
                    UnifiedImageDisplayView(
                        viewModel: viewModel,
                        transitionSettings: appSettingsCoordinator.transition,
                        uiInteractionManager: nil // TODO: Implement UIInteractionManager creation
                    )
                    .ignoresSafeArea()
                    
                    // Window level accessor
                    WindowLevelAccessor(windowLevel: viewModel.windowLevel)
                        .allowsHitTesting(false)
                        .frame(width: 0, height: 0)
                    
                    // Minimal controls overlay (always present in ZStack, visibility controlled internally)
                    MinimalControlsView(
                        viewModel: viewModel,
                        uiControlStateManager: uiControlStateManager,
                        uiControlSettings: appSettingsCoordinator.uiControl,
                        localizationService: localizationService
                    )
                    .shortcutTooltip("Hide/Show Controls", shortcut: "H")
                    
                    // Detailed info overlay (shown when toggled)
                    DetailedInfoOverlay(
                        viewModel: viewModel,
                        uiControlStateManager: uiControlStateManager,
                        uiControlSettings: appSettingsCoordinator.uiControl,
                        localizationService: localizationService
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
                // Loading overlay for detailed feedback - only show when no photos are loaded yet
                .overlay {
                    if viewModel.loadingState.isLoading && viewModel.slideshow?.currentPhoto == nil {
                        ZStack {
                            Color.black.opacity(0.8)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(2.0)
                                    .tint(.white)
                                
                                VStack(spacing: 8) {
                                    Text("Swift Photos")
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text(viewModel.loadingState.displayMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .animation(.easeInOut, value: viewModel.loadingState)
                                }
                            }
                        }
                    }
                }
    }
    
    @ViewBuilder
    private var componentLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2.0)
                .tint(.white)
            
            Text("Loading components...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2.0)
                .tint(.white)
            
            VStack(spacing: 8) {
                Text("Swift Photos")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Initializing application...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            ProductionLogger.lifecycle("ContentView loading screen appeared")
        }
    }
    
    private func initializeApp() {
        ProductionLogger.lifecycle("initializeApp() called")
        ProductionLogger.lifecycle("Starting initialization")
        
        // Add small delay to ensure UI is ready
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            ProductionLogger.debug("Creating dependencies")
            // Create localization settings with global service
            let createdLocalizationSettings = ModernLocalizationSettingsManager(localizationService: localizationService)
            
            // Create dependencies safely using persistent SecureFileAccess
            let imageLoader = ImageLoader()
            let imageCache = ImageCache()
            let repository = FileSystemPhotoRepository(fileAccess: secureFileAccess, imageLoader: imageLoader, sortSettings: appSettingsCoordinator.sort, localizationService: localizationService!)
            let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
            
            // Create view model using ViewModelFactory unified approach
            ProductionLogger.info("ContentView: Creating unified ViewModel with automatic architecture detection")
            // Create settings coordinator from individual settings
            // Use the unified AppSettingsCoordinator instance
            let settingsCoordinator = appSettingsCoordinator
            
            let createdViewModel = await ViewModelFactory.createSlideshowViewModel(
                fileAccess: secureFileAccess,
                settingsCoordinator: settingsCoordinator,
                localizationService: localizationService!,
                preferRepositoryPattern: true
            )
            
            let createdKeyboardHandler = KeyboardHandler()
            
            // Setup UI Control State Manager with unified ViewModel approach
            let createdUIControlStateManager = UIControlStateManager(
                uiControlSettings: appSettingsCoordinator.uiControl,
                slideshowViewModel: createdViewModel
            )
            
            // Setup keyboard handler connections for both ViewModel types
            createdKeyboardHandler.viewModel = createdViewModel
            createdKeyboardHandler.performanceSettings = appSettingsCoordinator.performance
            createdKeyboardHandler.onOpenSettings = {
                settingsWindowManager.openSettingsWindow(
                    settingsCoordinator: settingsCoordinator,
                    recentFilesManager: recentFilesManager
                )
            }
            createdKeyboardHandler.onOpenFolder = {
                Task {
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
            self.localizationSettings = createdLocalizationSettings
            self.isInitialized = true
            
            ProductionLogger.lifecycle("Initialization completed successfully")
        }
    }
    
    // MARK: - Folder Selection Integration
    
    private func handleTraditionalFolderSelection() async {
        ProductionLogger.userAction("Handling traditional folder selection (Cmd+O)")
        
        guard let viewModel = viewModel else {
            ProductionLogger.error("No view model available")
            return
        }
        
        // Store current folder URL for recent files integration
        let previousFolderURL = viewModel.selectedFolderURL
        
        // Call the viewModel's selectFolder method
        await viewModel.selectFolder()
        
        // If a new folder was selected, add it to recent files
        if let newFolderURL = viewModel.selectedFolderURL,
           newFolderURL != previousFolderURL {
            ProductionLogger.userAction("New folder selected via traditional method: \(newFolderURL.path)")
            
            do {
                // Create security bookmark for the folder
                let bookmarkData = try newFolderURL.bookmarkData(
                    options: [URL.BookmarkCreationOptions.withSecurityScope],
                    includingResourceValuesForKeys: nil as Set<URLResourceKey>?,
                    relativeTo: nil as URL?
                )
                
                // Add to recent files
                await recentFilesManager.addRecentFile(url: newFolderURL, securityBookmark: bookmarkData)
                ProductionLogger.debug("Added traditional folder selection to recent files")
                
            } catch {
                ProductionLogger.error("Failed to create security bookmark for traditional folder selection: \(error)")
            }
        }
    }
    
    // MARK: - File Menu Integration
    
    private func setupMenuNotificationObserver() {
        ProductionLogger.debug("Setting up menu notification observer")
        
        // Listen for folder selection from File menu
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwiftPhotosFolderSelected"),
            object: nil,
            queue: .main
        ) { notification in
            if let folderURL = notification.object as? URL {
                ProductionLogger.userAction("Received folder selection from menu: \(folderURL.path)")
                Task {
                    await self.handleFolderSelectedFromMenu(url: folderURL)
                }
            }
        }
        
        // Listen for window level changes from Window menu
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwiftPhotosWindowLevelChanged"),
            object: nil,
            queue: .main
        ) { @Sendable notification in
            // Extract windowLevel outside async context to avoid data race
            guard let windowLevel = notification.object as? WindowLevel else { return }
            
            Task { @MainActor [windowLevel] in
                if let viewModel = self.viewModel {
                    ProductionLogger.userAction("Received window level change: \(windowLevel.displayName)")
                    viewModel.windowLevel = windowLevel
                }
            }
        }
    }
    
    private func handleFolderSelectedFromMenu(url: URL) async {
        ProductionLogger.userAction("Handling folder selection from menu: \(url.path)")
        
        guard let viewModel = viewModel else {
            ProductionLogger.error("No view model available")
            return
        }
        
        // Store the URL and trigger slideshow creation
        viewModel.selectedFolderURL = url
        
        // Generate new random seed if sort order is random
        if appSettingsCoordinator.sort.settings.order == .random {
            ProductionLogger.debug("Generating new random seed for menu folder selection")
            appSettingsCoordinator.sort.regenerateRandomSeedSilently()
        }
        
        // Create slideshow from the selected folder with proper security scoped access
        viewModel.loadingState = .scanningFolder(0)
        viewModel.error = nil
        
        do {
            // Check if this URL needs security scoped access
            let needsSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            ProductionLogger.debug("Security scoped access \(needsSecurityAccess ? "enabled" : "not required") for: \(url.path)")
            
            // Use private method access through viewModel
            try await createSlideshowForMenuSelection(from: url)
        } catch {
            ProductionLogger.error("Failed to create slideshow from menu selection: \(error)")
            viewModel.error = error as? SlideshowError ?? SlideshowError.loadingFailed(underlying: error)
        }
        
        viewModel.loadingState = .notLoading
    }
    
    
    private func createSlideshowForMenuSelection(from folderURL: URL) async throws {
        ProductionLogger.userAction("Creating slideshow from menu selection: \(folderURL.path)")
        
        guard let viewModel = viewModel else { 
            ProductionLogger.error("No view model available")
            return 
        }
        
        do {
            // Use the persistent secure file access instance
            // Prepare access for the folder with security bookmark if available
            if let recentFile = recentFilesManager.recentFiles.first(where: { $0.url == folderURL }) {
                ProductionLogger.debug("Preparing access using security bookmark from recent files")
                try secureFileAccess.prepareForAccess(url: folderURL, bookmarkData: recentFile.securityBookmark)
            } else {
                ProductionLogger.debug("Preparing access without security bookmark (direct access)")
                try secureFileAccess.prepareForAccess(url: folderURL)
            }
            
            let imageLoader = ImageLoader()
            let imageCache = ImageCache()
            let repository = FileSystemPhotoRepository(fileAccess: secureFileAccess, imageLoader: imageLoader, sortSettings: appSettingsCoordinator.sort, localizationService: localizationService!)
            let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
            
            // Apply slideshow settings
            let mode: Slideshow.SlideshowMode = .sequential
            let customInterval = try SlideshowInterval(appSettingsCoordinator.slideshow.settings.slideDuration)
            
            ProductionLogger.debug("Creating slideshow with domain service")
            let newSlideshow = try await domainService.createSlideshow(
                from: folderURL,
                interval: customInterval,
                mode: mode
            )
            
            ProductionLogger.info("Created slideshow with \(newSlideshow.photos.count) photos")
            ProductionLogger.debug("ContentView: Created slideshow details - photos.count: \(newSlideshow.photos.count), currentIndex: \(newSlideshow.currentIndex), count: \(newSlideshow.count), isEmpty: \(newSlideshow.isEmpty)")
            viewModel.setSlideshow(newSlideshow)
            
            if !newSlideshow.isEmpty {
                // Auto-recommend settings for collection size
                let recommendedSettings = appSettingsCoordinator.performance.recommendedSettings(for: newSlideshow.photos.count)
                if recommendedSettings != appSettingsCoordinator.performance.settings {
                    ProductionLogger.info("Auto-applying recommended settings for \(newSlideshow.photos.count) photos")
                    appSettingsCoordinator.performance.updateSettings(recommendedSettings)
                }
                
                // Load current image
                if newSlideshow.photos.count > appSettingsCoordinator.performance.settings.largeCollectionThreshold {
                    ProductionLogger.performance("Large collection detected - using virtual loading")
                    // Use viewModel's internal loading mechanisms
                    viewModel.currentPhoto = newSlideshow.currentPhoto
                    viewModel.refreshCounter += 1
                } else {
                    ProductionLogger.debug("Small collection - loading current image")
                    viewModel.currentPhoto = newSlideshow.currentPhoto
                    viewModel.refreshCounter += 1
                }
                
                // Auto-start slideshow if enabled
                if appSettingsCoordinator.slideshow.settings.autoStart {
                    ProductionLogger.debug("Auto-starting slideshow per settings")
                    viewModel.play()
                }
            }
            
        } catch {
            ProductionLogger.error("Failed to create slideshow: \(error)")
            throw error
        }
    }
}

#Preview {
    ContentView()
}
