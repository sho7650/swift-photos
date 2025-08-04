import SwiftUI
import AppKit

/// Enhanced ContentView with Repository pattern integration
/// This view can seamlessly switch between Repository-based and legacy ViewModels
struct EnhancedContentView: View {
    
    // MARK: - State Properties
    @State private var viewModel: (any SlideshowViewModelProtocol)?
    @State private var keyboardHandler: KeyboardHandler?
    @State private var unifiedInteractionManager: UnifiedInteractionManager?
    @State private var isInitializing = true
    @State private var initializationError: Error?
    @State private var isUsingRepositoryPattern = false
    
    // MARK: - Settings Managers
    @State private var performanceSettings = ModernPerformanceSettingsManager()
    @State private var slideshowSettings = ModernSlideshowSettingsManager()
    @State private var sortSettings = ModernSortSettingsManager()
    @State private var transitionSettings = ModernTransitionSettingsManager()
    @State private var uiControlSettings = ModernUIControlSettingsManager()
    @State private var localizationSettings = ModernLocalizationSettingsManager()
    @State private var settingsWindowManager = SettingsWindowManager()
    @State private var settingsCoordinator: UnifiedAppSettingsCoordinator?
    
    // MARK: - Body
    var body: some View {
        Group {
            if isInitializing {
                initializationView
            } else if let error = initializationError {
                errorView(error)
            } else if let viewModel = viewModel,
                      let keyboardHandler = keyboardHandler,
                      let unifiedInteractionManager = unifiedInteractionManager {
                slideshowContentView(
                    viewModel: viewModel,
                    keyboardHandler: keyboardHandler,
                    unifiedInteractionManager: unifiedInteractionManager
                )
            } else {
                Text("Unexpected state")
                    .foregroundColor(.red)
            }
        }
        .task {
            await initializeApplication()
        }
        .onAppear {
            ProductionLogger.lifecycle("EnhancedContentView appeared")
        }
    }
    
    // MARK: - Initialization View
    private var initializationView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Initializing Swift Photos...")
                .font(.headline)
            
            Text("Setting up Repository pattern...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Error View
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Initialization Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Retry with Legacy Mode") {
                Task {
                    await initializeApplicationLegacyMode()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Slideshow Content View
    private func slideshowContentView(
        viewModel: any SlideshowViewModelProtocol,
        keyboardHandler: KeyboardHandler,
        unifiedInteractionManager: UnifiedInteractionManager
    ) -> some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Main slideshow content
            Group {
                if viewModel.slideshow != nil,
                   let currentPhoto = viewModel.currentPhoto {
                    
                    // Image display with unified implementation
                    UnifiedImageDisplayView(
                        viewModel: viewModel,
                        transitionSettings: transitionSettings,
                        uiControlStateManager: unifiedInteractionManager.legacyUIControlManager,
                        enablePerformanceMetrics: true
                    )
                    .id(currentPhoto.id)
                    
                } else if let error = viewModel.error {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Error")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    
                } else {
                    // Empty state
                    ContentUnavailableView(
                        "No Photos Loaded",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Select a folder to start slideshow")
                    )
                    .foregroundColor(.white)
                }
            }
            
            // UI Controls Overlay - only show when no photo is displayed
            VStack {
                if unifiedInteractionManager.isControlsVisible && viewModel.slideshow?.currentPhoto == nil {
                    repositoryAwareControlsOverlay(
                        viewModel: viewModel,
                        unifiedInteractionManager: unifiedInteractionManager
                    )
                } else if unifiedInteractionManager.isControlsVisible && viewModel.slideshow?.currentPhoto != nil {
                    // Show minimal controls only when photo is displayed
                    MinimalControlsView(
                        viewModel: viewModel,
                        transitionSettings: transitionSettings,
                        uiControlSettings: uiControlSettings
                    )
                }
                
                Spacer()
            }
        }
        .focusable()
    }
    
    // MARK: - Repository-Aware Controls
    private func repositoryAwareControlsOverlay(
        viewModel: any SlideshowViewModelProtocol,
        unifiedInteractionManager: UnifiedInteractionManager
    ) -> some View {
        VStack {
            // Top controls with Repository status
            HStack {
                if isUsingRepositoryPattern {
                    Label("Repository Mode", systemImage: "externaldrive.connected")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                // Settings button
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding()
            }
            
            Spacer()
            
            // Bottom controls
            MinimalControlsView(
                viewModel: viewModel,
                transitionSettings: transitionSettings,
                uiControlSettings: uiControlSettings
            )
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
    
    // MARK: - Repository Status Indicator
    private var repositoryStatusIndicator: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(isUsingRepositoryPattern ? "Repository" : "Legacy")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    Circle()
                        .fill(isUsingRepositoryPattern ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Repository-Aware Controls View
    private struct MinimalControlsView: View {
        let viewModel: any SlideshowViewModelProtocol
        let transitionSettings: ModernTransitionSettingsManager
        let uiControlSettings: ModernUIControlSettingsManager
        
        var body: some View {
            HStack(spacing: 20) {
                // Previous button
                Button(action: {
                    Task { await viewModel.previousPhoto() }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Play/Pause button
                Button(action: {
                    if viewModel.slideshow?.isPlaying == true {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }) {
                    Image(systemName: viewModel.slideshow?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Next button
                Button(action: {
                    Task { await viewModel.nextPhoto() }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(25)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Initialization Methods
    
    private func initializeApplication() async {
        ProductionLogger.lifecycle("EnhancedContentView: Starting application initialization")
        
        do {
            // Check Repository readiness
            let readinessStatus = await ViewModelFactory.checkRepositoryReadiness()
            ProductionLogger.info("Repository readiness: \(readinessStatus.isReady)")
            
            // Initialize dependencies
            let secureFileAccess = SecureFileAccess()
            
            // Attempt localization service creation
            guard let localizationService = try? await createLocalizationService() else {
                throw InitializationError.localizationServiceCreationFailed
            }
            
            // Create settings coordinator from individual settings
            let settingsCoordinator = UnifiedAppSettingsCoordinator()
            // Note: Individual settings would need to be set on the coordinator if needed
            
            // Create ViewModel using factory
            let createdViewModel = await ViewModelFactory.createSlideshowViewModel(
                fileAccess: secureFileAccess,
                settingsCoordinator: settingsCoordinator,
                localizationService: localizationService,
                preferRepositoryPattern: readinessStatus.recommendUseRepositoryPattern
            )
            
            // Determine if Repository pattern is being used
            isUsingRepositoryPattern = createdViewModel is UnifiedSlideshowViewModel
            
            // Create keyboard handler
            let createdKeyboardHandler = KeyboardHandler()
            setupKeyboardHandler(createdKeyboardHandler, with: createdViewModel)
            
            // Create unified interaction manager
            let createdUnifiedInteractionManager = UnifiedInteractionManager(
                uiControlSettings: uiControlSettings,
                enableEnhancedFeatures: readinessStatus.recommendUseRepositoryPattern
            )
            
            // Set properties
            self.viewModel = createdViewModel
            self.keyboardHandler = createdKeyboardHandler
            self.unifiedInteractionManager = createdUnifiedInteractionManager
            self.settingsCoordinator = settingsCoordinator
            self.isInitializing = false
            
            ProductionLogger.lifecycle("EnhancedContentView: Application initialized successfully with \(isUsingRepositoryPattern ? "Repository" : "Legacy") pattern")
            
        } catch {
            ProductionLogger.error("EnhancedContentView: Initialization failed: \(error)")
            self.initializationError = error
            self.isInitializing = false
        }
    }
    
    private func initializeApplicationLegacyMode() async {
        ProductionLogger.lifecycle("EnhancedContentView: Initializing in legacy mode")
        
        do {
            let secureFileAccess = SecureFileAccess()
            guard let localizationService = try? await createLocalizationService() else {
                throw InitializationError.localizationServiceCreationFailed
            }
            
            // Create settings coordinator from individual settings
            let settingsCoordinator = UnifiedAppSettingsCoordinator()
            
            // Use unified ViewModel creation with legacy preference
            let legacyViewModel = await ViewModelFactory.createSlideshowViewModel(
                fileAccess: secureFileAccess,
                settingsCoordinator: settingsCoordinator,
                localizationService: localizationService,
                preferRepositoryPattern: false
            )
            
            let createdKeyboardHandler = KeyboardHandler()
            setupKeyboardHandler(createdKeyboardHandler, with: legacyViewModel)
            
            let createdUnifiedInteractionManager = UnifiedInteractionManager(
                uiControlSettings: uiControlSettings,
                enableEnhancedFeatures: false // Legacy mode - no enhanced features
            )
            
            self.viewModel = legacyViewModel
            self.keyboardHandler = createdKeyboardHandler
            self.unifiedInteractionManager = createdUnifiedInteractionManager
            self.settingsCoordinator = settingsCoordinator
            self.isUsingRepositoryPattern = false
            self.isInitializing = false
            self.initializationError = nil
            
            ProductionLogger.lifecycle("EnhancedContentView: Legacy mode initialization completed")
            
        } catch {
            ProductionLogger.error("EnhancedContentView: Legacy mode initialization failed: \(error)")
            self.initializationError = error
        }
    }
    
    private func createLocalizationService() async throws -> LocalizationService {
        let localizationService = LocalizationService()
        // LocalizationService initialization handled elsewhere
        return localizationService
    }
    
    private func setupKeyboardHandler(_ keyboardHandler: KeyboardHandler, with viewModel: any SlideshowViewModelProtocol) {
        // Setup keyboard handler with unified ViewModel
        keyboardHandler.viewModel = viewModel
        keyboardHandler.performanceSettings = performanceSettings
        keyboardHandler.onOpenSettings = openSettings
        
        // Integrate keyboard handler with unified interaction manager
        keyboardHandler.onKeyboardInteraction = {
            unifiedInteractionManager?.handleKeyboardInteraction()
        }
    }
    
    private func openSettings() {
        guard let settingsCoordinator = settingsCoordinator else {
            ProductionLogger.error("EnhancedContentView: Cannot open settings - settingsCoordinator is nil")
            return
        }
        
        settingsWindowManager.openSettingsWindow(
            settingsCoordinator: settingsCoordinator
        )
    }
}

// MARK: - Supporting Types

enum InitializationError: LocalizedError {
    case localizationServiceCreationFailed
    case repositoryInitializationFailed(underlying: Error)
    case viewModelCreationFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .localizationServiceCreationFailed:
            return "Failed to initialize localization service"
        case .repositoryInitializationFailed(let error):
            return "Repository initialization failed: \(error.localizedDescription)"
        case .viewModelCreationFailed(let error):
            return "ViewModel creation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting ViewModifiers

/// Modifier to handle optional KeyboardHandler
private struct OptionalKeyboardHandlerModifier: ViewModifier {
    let keyboardHandler: KeyboardHandler?
    
    func body(content: Content) -> some View {
        if let keyboardHandler = keyboardHandler {
            content.keyboardHandler(keyboardHandler)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedContentView()
        .frame(width: 800, height: 600)
}