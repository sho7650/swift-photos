import Foundation
import SwiftUI
import AppKit
import Observation
import os.log

/// Comprehensive presentation manager for multi-monitor slideshow presentations
/// Provides professional presentation features with audience/presenter display separation
@MainActor
@Observable
public class MultiMonitorPresentationManager {
    
    // MARK: - State Properties
    
    public private(set) var isPresentationMode: Bool = false
    public private(set) var isFullscreenPresentation: Bool = false
    public private(set) var presenterScreen: NSScreen?
    public private(set) var audienceScreen: NSScreen?
    public private(set) var presentationNotes: [UUID: String] = [:]
    public private(set) var isConfigured: Bool = false
    
    // MARK: - Configuration
    
    public struct PresentationConfiguration: Equatable {
        public var presenterScreenPreference: ScreenPreference = .secondary
        public var audienceScreenPreference: ScreenPreference = .primary
        public var showPresenterNotes: Bool = true
        public var showPhotoInformation: Bool = true
        public var presenterControlsVisible: Bool = true
        public var audienceControlsVisible: Bool = false
        public var syncNavigation: Bool = true
        public var backgroundDimming: Bool = true
        public var showUpcomingPhotos: Bool = true
        public var notesAutosave: Bool = true
        public var presentationTheme: PresentationTheme = .dark
        
        public init() {}
    }
    
    public enum PresentationTheme: Equatable {
        case light, dark, auto
    }
    
    public var configuration = PresentationConfiguration()
    
    // MARK: - Dependencies
    
    private let screenMonitor: ScreenConfigurationMonitor
    private let positionStrategy: PresenterDisplayStrategy
    private let eventBus: UnifiedEventBus
    private let logger = Logger(subsystem: "SwiftPhotos", category: "MultiMonitorPresentationManager")
    
    // MARK: - Windows Management
    
    private var presenterWindow: NSWindow?
    private var audienceWindow: NSWindow?
    private var presenterViewController: NSViewController?
    private var enhancedFeaturesEnabled: Bool
    
    // MARK: - Current Presentation State
    
    public private(set) var currentPhotoId: UUID?
    public private(set) var currentPhotoIndex: Int = 0
    public private(set) var totalPhotos: Int = 0
    public private(set) var isPlaying: Bool = false
    public private(set) var upcomingPhotos: [UUID] = []
    
    // MARK: - Initialization
    
    public init(enableEnhancedFeatures: Bool = true, eventBus: UnifiedEventBus? = nil) {
        self.enhancedFeaturesEnabled = enableEnhancedFeatures
        self.eventBus = eventBus ?? UnifiedEventBus.shared
        self.screenMonitor = ScreenConfigurationMonitor()
        self.positionStrategy = PresenterDisplayStrategy()
        
        setupScreenMonitoring()
        configureInitialScreens()
        
        logger.info("🖥️ MultiMonitorPresentationManager: Initialized with enhanced features: \(enableEnhancedFeatures)")
    }
    
    deinit {
        // Note: Cannot perform async operations in deinit
        // Cleanup will happen when the presentation manager is released
    }
    
    // MARK: - Public Interface
    
    /// Check if multi-monitor presentation is available
    public var isMultiMonitorAvailable: Bool {
        return NSScreen.screens.count > 1
    }
    
    /// Get current presentation status
    public var presentationStatus: PresentationStatus {
        if isPresentationMode && isFullscreenPresentation {
            return .fullscreenPresentation
        } else if isPresentationMode {
            return .windowedPresentation
        } else {
            return .inactive
        }
    }
    
    public enum PresentationStatus {
        case inactive
        case windowedPresentation
        case fullscreenPresentation
    }
    
    // MARK: - Presentation Mode Control
    
    /// Toggle presentation mode
    public func togglePresentationMode() async {
        if isPresentationMode {
            await exitPresentationMode()
        } else {
            await enterPresentationMode()
        }
    }
    
    /// Enter presentation mode
    public func enterPresentationMode() async {
        guard !isPresentationMode else { return }
        
        logger.info("🖥️ Entering presentation mode")
        
        // Configure screens
        await configureScreens()
        
        // Create presentation windows if multi-monitor setup
        if isMultiMonitorAvailable && presenterScreen != audienceScreen {
            await createPresentationWindows()
        }
        
        isPresentationMode = true
        isConfigured = true
        
        // Publish event
        eventBus.publishUIState(component: "PresentationManager", state: .shown)
        
        logger.info("🖥️ Presentation mode activated")
    }
    
    /// Enter fullscreen presentation mode
    public func enterFullscreenPresentation() async {
        await enterPresentationMode()
        
        guard isPresentationMode else { return }
        
        // Make audience window fullscreen
        if let audienceWindow = audienceWindow {
            audienceWindow.toggleFullScreen(nil)
        } else if let mainWindow = NSApp.mainWindow {
            mainWindow.toggleFullScreen(nil)
        }
        
        isFullscreenPresentation = true
        logger.info("🖥️ Fullscreen presentation activated")
        
        eventBus.publishSystem(type: .startup, message: "Entered fullscreen presentation mode")
    }
    
    /// Exit presentation mode
    @MainActor
    public func exitPresentationMode() async {
        guard isPresentationMode else { return }
        
        logger.info("🖥️ Exiting presentation mode")
        
        // Save notes if autosave is enabled
        if configuration.notesAutosave {
            await saveAllNotes()
        }
        
        // Close presentation windows
        await closePresentationWindows()
        
        // Exit fullscreen if active
        if isFullscreenPresentation {
            if let mainWindow = NSApp.mainWindow, mainWindow.styleMask.contains(.fullScreen) {
                mainWindow.toggleFullScreen(nil)
            }
            isFullscreenPresentation = false
        }
        
        isPresentationMode = false
        isConfigured = false
        
        // Reset state
        currentPhotoId = nil
        currentPhotoIndex = 0
        isPlaying = false
        upcomingPhotos.removeAll()
        
        // Publish event
        eventBus.publishUIState(component: "PresentationManager", state: .hidden)
        eventBus.publishSystem(type: .shutdown, message: "Exited presentation mode")
        
        logger.info("🖥️ Presentation mode deactivated")
    }
    
    // MARK: - Screen Configuration
    
    public func updateScreenConfiguration() async {
        guard isPresentationMode else { return }
        
        await configureScreens()
        
        // Recreate windows if screen setup changed significantly
        if isMultiMonitorAvailable && presenterScreen != audienceScreen {
            await closePresentationWindows()
            await createPresentationWindows()
        }
    }
    
    private func configureInitialScreens() {
        Task { @MainActor in
            await configureScreens()
        }
    }
    
    private func configureScreens() async {
        let screens = NSScreen.screens
        
        guard !screens.isEmpty else {
            logger.error("🖥️ No screens available")
            return
        }
        
        // Configure audience screen (primary display)
        switch configuration.audienceScreenPreference {
        case .primary:
            audienceScreen = screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        case .secondary:
            audienceScreen = screens.first { $0 != NSScreen.main } ?? NSScreen.main
        case .largest:
            audienceScreen = screens.max { s1, s2 in
                (s1.frame.width * s1.frame.height) < (s2.frame.width * s2.frame.height)
            }
        case .current:
            audienceScreen = NSScreen.main
        case .specific(let index):
            audienceScreen = screens.indices.contains(index) ? screens[index] : NSScreen.main
        }
        
        // Configure presenter screen (secondary display if available)
        if screens.count > 1 {
            switch configuration.presenterScreenPreference {
            case .primary:
                presenterScreen = screens.first { $0.frame.origin == .zero } ?? screens.first
            case .secondary:
                presenterScreen = screens.first { $0 != audienceScreen } ?? audienceScreen
            case .largest:
                presenterScreen = screens.max { s1, s2 in
                    (s1.frame.width * s1.frame.height) < (s2.frame.width * s2.frame.height)
                }
            case .current:
                presenterScreen = NSScreen.main
            case .specific(let index):
                presenterScreen = screens.indices.contains(index) ? screens[index] : screens.first
            }
        } else {
            // Single screen setup
            presenterScreen = audienceScreen
        }
        
        logger.info("🖥️ Configured screens - Audience: \(self.audienceScreen?.localizedName ?? "Unknown"), Presenter: \(self.presenterScreen?.localizedName ?? "Unknown")")
    }
    
    // MARK: - Window Management
    
    private func createPresentationWindows() async {
        guard let presenterScreen = presenterScreen,
              let audienceScreen = audienceScreen,
              presenterScreen != audienceScreen else {
            logger.warning("🖥️ Cannot create separate windows - insufficient screens or same screen")
            return
        }
        
        // Create audience window (main slideshow)
        await createAudienceWindow(on: audienceScreen)
        
        // Create presenter window (controls and notes)
        await createPresenterWindow(on: presenterScreen)
        
        logger.info("🖥️ Created presentation windows")
    }
    
    private func createAudienceWindow(on screen: NSScreen) async {
        let contentRect = screen.visibleFrame
        
        audienceWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        audienceWindow?.title = "Swift Photos - Presentation"
        audienceWindow?.backgroundColor = .black
        audienceWindow?.level = .floating
        audienceWindow?.isReleasedWhenClosed = false
        audienceWindow?.collectionBehavior = [.fullScreenPrimary]
        
        // Position on audience screen
        audienceWindow?.setFrame(contentRect, display: true, animate: false)
        
        // Configure window properties for presentation
        audienceWindow?.hidesOnDeactivate = false
        audienceWindow?.canHide = false
        
        // Make it the main presentation view
        if let audienceWindow = audienceWindow {
            audienceWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func createPresenterWindow(on screen: NSScreen) async {
        let contentRect = screen.visibleFrame
        
        presenterWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        presenterWindow?.title = "Swift Photos - Presenter View"
        presenterWindow?.backgroundColor = NSColor.controlBackgroundColor
        presenterWindow?.level = .normal
        presenterWindow?.isReleasedWhenClosed = false
        
        // Create presenter view content
        let presenterView = createPresenterView()
        let hostingView = NSHostingView(rootView: presenterView)
        presenterWindow?.contentView = hostingView
        
        // Position on presenter screen
        presenterWindow?.setFrame(contentRect, display: true, animate: false)
        presenterWindow?.orderFront(nil)
    }
    
    private func closePresentationWindows() async {
        presenterWindow?.close()
        presenterWindow = nil
        presenterViewController = nil
        
        audienceWindow?.close()
        audienceWindow = nil
        
        logger.debug("🖥️ Closed presentation windows")
    }
    
    // MARK: - Presenter View Creation
    
    private func createPresenterView() -> some View {
        PresenterControlView(presentationManager: self)
    }
    
    // MARK: - Presentation Coordination
    
    public func startPresentationSlideshow() async {
        isPlaying = true
        logger.info("🖥️ Starting presentation slideshow")
        eventBus.publishSlideshow(action: .started)
    }
    
    public func pausePresentationSlideshow() async {
        isPlaying = false
        logger.info("🖥️ Pausing presentation slideshow")
        eventBus.publishSlideshow(action: .paused)
    }
    
    public func stopPresentationSlideshow() async {
        isPlaying = false
        currentPhotoIndex = 0
        logger.info("🖥️ Stopping presentation slideshow")
        eventBus.publishSlideshow(action: .stopped)
    }
    
    public func navigateToPhoto(index: Int) async {
        guard index >= 0 && index < totalPhotos else { return }
        
        currentPhotoIndex = index
        updateUpcomingPhotos()
        
        logger.debug("🖥️ Navigated to photo \(index)")
        eventBus.publishSlideshow(action: .photoChanged, index: index)
    }
    
    public func nextPhoto() async {
        let nextIndex = currentPhotoIndex + 1
        if nextIndex < totalPhotos {
            await navigateToPhoto(index: nextIndex)
        }
    }
    
    public func previousPhoto() async {
        let prevIndex = currentPhotoIndex - 1
        if prevIndex >= 0 {
            await navigateToPhoto(index: prevIndex)
        }
    }
    
    public func updateCurrentPhoto(photoId: UUID?, index: Int?) async {
        // Synchronize photo display across screens
        if let photoId = photoId {
            currentPhotoId = photoId
        }
        
        if let index = index {
            currentPhotoIndex = index
            updateUpcomingPhotos()
        }
        
        if configuration.syncNavigation {
            logger.debug("🖥️ Syncing photo display: \(photoId?.uuidString ?? "nil") at index \(index ?? -1)")
        }
    }
    
    public func updateTotalPhotos(_ count: Int) {
        totalPhotos = count
        updateUpcomingPhotos()
    }
    
    private func updateUpcomingPhotos() {
        guard configuration.showUpcomingPhotos else {
            upcomingPhotos.removeAll()
            return
        }
        
        // Show next 3 photos
        let upcomingCount = min(3, totalPhotos - currentPhotoIndex - 1)
        upcomingPhotos = Array(0..<upcomingCount).map { _ in UUID() }
    }
    
    public func refreshPresentationLayout() async {
        // Refresh layout when settings change
        logger.debug("🖥️ Refreshing presentation layout")
        
        if isPresentationMode && isMultiMonitorAvailable {
            await closePresentationWindows()
            await createPresentationWindows()
        }
    }
    
    public func synchronizeUIState(_ event: UIStateEvent) async {
        // Synchronize UI state between presenter and audience displays
        logger.debug("🖥️ Synchronizing UI state for component: \(event.component)")
    }
    
    public func optimizeResources() async {
        // Optimize resources under memory pressure
        logger.info("🖥️ Optimizing presentation resources")
        
        // Save notes before potential memory cleanup
        if configuration.notesAutosave {
            await saveAllNotes()
        }
    }
    
    // MARK: - Notes Management
    
    public func addNote(for photoId: UUID, note: String) {
        presentationNotes[photoId] = note
        eventBus.publishUIState(component: "PresenterNotes", state: .shown, data: ["photoId": photoId.uuidString])
        
        if configuration.notesAutosave {
            Task {
                await saveNote(for: photoId, note: note)
            }
        }
    }
    
    public func getNote(for photoId: UUID) -> String? {
        return presentationNotes[photoId]
    }
    
    public func removeNote(for photoId: UUID) {
        presentationNotes.removeValue(forKey: photoId)
        eventBus.publishUIState(component: "PresenterNotes", state: .hidden, data: ["photoId": photoId.uuidString])
    }
    
    public func getAllNotes() -> [UUID: String] {
        return presentationNotes
    }
    
    public func clearAllNotes() {
        presentationNotes.removeAll()
        eventBus.publishUIState(component: "PresenterNotes", state: .hidden)
    }
    
    private func saveNote(for photoId: UUID, note: String) async {
        // Save individual note (implementation depends on storage backend)
        logger.debug("💾 Saving note for photo: \(photoId.uuidString)")
    }
    
    private func saveAllNotes() async {
        // Save all notes (implementation depends on storage backend)
        logger.info("💾 Saving all presentation notes (\(self.presentationNotes.count) notes)")
    }
    
    // MARK: - Configuration Management
    
    public func updateConfiguration(_ newConfiguration: PresentationConfiguration) async {
        let oldConfiguration = configuration
        configuration = newConfiguration
        
        // Apply configuration changes if in presentation mode
        if isPresentationMode {
            // Check if screen preferences changed
            if oldConfiguration.presenterScreenPreference != newConfiguration.presenterScreenPreference ||
               oldConfiguration.audienceScreenPreference != newConfiguration.audienceScreenPreference {
                await updateScreenConfiguration()
            }
            
            // Refresh layout if visual settings changed
            if oldConfiguration.presentationTheme != newConfiguration.presentationTheme ||
               oldConfiguration.showPresenterNotes != newConfiguration.showPresenterNotes {
                await refreshPresentationLayout()
            }
        }
        
        logger.info("🖥️ Presentation configuration updated")
    }
    
    // MARK: - Statistics and Monitoring
    
    public func getPresentationStatistics() -> PresentationStatistics {
        return PresentationStatistics(
            isActive: isPresentationMode,
            isFullscreen: isFullscreenPresentation,
            screenCount: NSScreen.screens.count,
            hasMultiMonitor: isMultiMonitorAvailable,
            currentPhotoIndex: currentPhotoIndex,
            totalPhotos: totalPhotos,
            notesCount: presentationNotes.count,
            upcomingPhotosCount: upcomingPhotos.count
        )
    }
    
    // MARK: - Private Methods
    
    private func setupScreenMonitoring() {
        screenMonitor.delegate = self
    }
}

// MARK: - Supporting Types

public struct PresentationStatistics {
    public let isActive: Bool
    public let isFullscreen: Bool
    public let screenCount: Int
    public let hasMultiMonitor: Bool
    public let currentPhotoIndex: Int
    public let totalPhotos: Int
    public let notesCount: Int
    public let upcomingPhotosCount: Int
    
    public var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return Double(currentPhotoIndex) / Double(totalPhotos)
    }
}

// MARK: - Screen Configuration Monitor Delegate

extension MultiMonitorPresentationManager: ScreenConfigurationMonitorDelegate {
    
    nonisolated public func screenConfigurationDidChange(
        from oldConfiguration: [ScreenDisplayInfo], 
        to newConfiguration: [ScreenDisplayInfo]
    ) {
        let oldCount = oldConfiguration.count
        let newCount = newConfiguration.count
        
        Task { @MainActor in
            logger.info("🖥️ Screen configuration changed: \(oldCount) → \(newCount) screens")
            await updateScreenConfiguration()
        }
    }
}

// MARK: - Presenter Control View

/// SwiftUI view for presenter controls on secondary display
struct PresenterControlView: View {
    @State var presentationManager: MultiMonitorPresentationManager
    
    @State private var currentNote: String = ""
    @State private var selectedNotePhotoId: UUID?
    
    var body: some View {
        HSplitView {
            // Left panel - Current photo preview and upcoming
            photoPreviewPanel
                .frame(minWidth: 400, idealWidth: 500)
            
            // Right panel - Controls and notes
            controlsPanel
                .frame(minWidth: 300, idealWidth: 400)
        }
        .background(backgroundColor)
        .onAppear {
            loadCurrentNote()
        }
        .onChange(of: presentationManager.currentPhotoId) { _, newValue in
            loadCurrentNote()
        }
    }
    
    private var backgroundColor: Color {
        switch presentationManager.configuration.presentationTheme {
        case .dark:
            return Color(NSColor.controlBackgroundColor).opacity(0.95)
        case .light:
            return Color.white
        case .auto:
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    private var photoPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Photo")
                .font(.headline)
                .padding(.horizontal)
            
            // Photo preview area
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .overlay(
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Photo Preview")
                            .foregroundColor(.white.opacity(0.6))
                    }
                )
                .aspectRatio(16/9, contentMode: .fit)
                .padding(.horizontal)
            
            // Photo information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Photo \(presentationManager.currentPhotoIndex + 1) of \(presentationManager.totalPhotos)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("2.4 MB • 4032×3024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("IMG_2024_001.jpg")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Progress bar
                ProgressView(value: presentationManager.getPresentationStatistics().progress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            .padding(.horizontal)
            
            // Upcoming photos (if enabled)
            if presentationManager.configuration.showUpcomingPhotos && !presentationManager.upcomingPhotos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming")
                        .font(.subheadline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<min(3, presentationManager.upcomingPhotos.count), id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fit)
                                .frame(height: 40)
                                .overlay(
                                    Text("\(presentationManager.currentPhotoIndex + index + 2)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                )
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
    }
    
    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Presentation controls
            VStack(alignment: .leading, spacing: 12) {
                Text("Presentation Controls")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task { await presentationManager.previousPhoto() }
                    }) {
                        Label("Previous", systemImage: "backward.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(presentationManager.currentPhotoIndex <= 0)
                    
                    Button(action: {
                        Task {
                            if presentationManager.isPlaying {
                                await presentationManager.pausePresentationSlideshow()
                            } else {
                                await presentationManager.startPresentationSlideshow()
                            }
                        }
                    }) {
                        Label(
                            presentationManager.isPlaying ? "Pause" : "Play",
                            systemImage: presentationManager.isPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        Task { await presentationManager.nextPhoto() }
                    }) {
                        Label("Next", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(presentationManager.currentPhotoIndex >= presentationManager.totalPhotos - 1)
                }
                
                HStack {
                    Button("Exit Presentation") {
                        Task {
                            await presentationManager.exitPresentationMode()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    if !presentationManager.isFullscreenPresentation {
                        Button("Fullscreen") {
                            Task {
                                await presentationManager.enterFullscreenPresentation()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Divider()
            
            // Notes section
            if presentationManager.configuration.showPresenterNotes {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presenter Notes")
                        .font(.headline)
                    
                    TextEditor(text: $currentNote)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .frame(minHeight: 120)
                        .onChange(of: currentNote) { _, newValue in
                            saveCurrentNote()
                        }
                    
                    HStack {
                        Button("Clear") {
                            currentNote = ""
                            saveCurrentNote()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("\(presentationManager.presentationNotes.count) notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
            }
            
            // Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Presentation Settings")
                    .font(.headline)
                
                Toggle("Show presenter notes", isOn: .constant(presentationManager.configuration.showPresenterNotes))
                    .disabled(true) // Read-only in this view
                
                Toggle("Sync navigation", isOn: .constant(presentationManager.configuration.syncNavigation))
                    .disabled(true) // Read-only in this view
                
                Toggle("Show upcoming photos", isOn: .constant(presentationManager.configuration.showUpcomingPhotos))
                    .disabled(true) // Read-only in this view
                
                HStack {
                    Text("Theme:")
                    Spacer()
                    Text(presentationManager.configuration.presentationTheme == .dark ? "Dark" : 
                         presentationManager.configuration.presentationTheme == .light ? "Light" : "Auto")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func loadCurrentNote() {
        guard let photoId = presentationManager.currentPhotoId else {
            currentNote = ""
            return
        }
        
        selectedNotePhotoId = photoId
        currentNote = presentationManager.getNote(for: photoId) ?? ""
    }
    
    private func saveCurrentNote() {
        guard let photoId = selectedNotePhotoId else { return }
        
        if currentNote.isEmpty {
            presentationManager.removeNote(for: photoId)
        } else {
            presentationManager.addNote(for: photoId, note: currentNote)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PresenterControlView(
        presentationManager: MultiMonitorPresentationManager(
            enableEnhancedFeatures: true,
            eventBus: UnifiedEventBus.shared
        )
    )
    .frame(width: 800, height: 600)
}
#endif