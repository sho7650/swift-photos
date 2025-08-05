import SwiftUI
import AppKit

/// Presentation controls view that integrates with the main slideshow interface
/// Provides easy access to multi-monitor presentation features
public struct PresentationControlsView: View {
    
    @State private var presentationManager: MultiMonitorPresentationManager
    @State private var showingConfiguration = false
    
    public init(presentationManager: MultiMonitorPresentationManager) {
        self._presentationManager = State(initialValue: presentationManager)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "display.2")
                    .foregroundColor(.blue)
                Text("Multi-Monitor Presentation")
                    .font(.headline)
                
                Spacer()
                
                // Status indicator
                statusIndicator
            }
            
            // Main controls
            presentationControls
            
            // Configuration section
            if showingConfiguration {
                configurationSection
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(presentationManager.isPresentationMode ? .green : .gray)
                .frame(width: 8, height: 8)
            
            Text(presentationManager.isPresentationMode ? "Active" : "Inactive")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var presentationControls: some View {
        VStack(spacing: 12) {
            // Multi-monitor availability check
            if !presentationManager.isMultiMonitorAvailable {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Connect a second display for full presentation features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Primary controls
            HStack(spacing: 12) {
                // Start/Stop presentation
                Button(action: {
                    Task {
                        await presentationManager.togglePresentationMode()
                    }
                }) {
                    HStack {
                        Image(systemName: presentationManager.isPresentationMode ? "stop.fill" : "play.fill")
                        Text(presentationManager.isPresentationMode ? "Exit Presentation" : "Start Presentation")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // Fullscreen toggle (only when presentation is active)
                if presentationManager.isPresentationMode {
                    Button(action: {
                        Task {
                            if presentationManager.isFullscreenPresentation {
                                await presentationManager.exitPresentationMode()
                                await presentationManager.enterPresentationMode()
                            } else {
                                await presentationManager.enterFullscreenPresentation()
                            }
                        }
                    }) {
                        Image(systemName: presentationManager.isFullscreenPresentation ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help(presentationManager.isFullscreenPresentation ? "Exit Fullscreen" : "Enter Fullscreen")
                }
            }
            
            // Secondary controls (when presentation is active)
            if presentationManager.isPresentationMode {
                HStack(spacing: 8) {
                    Button("Configuration") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingConfiguration.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    // Quick stats
                    HStack(spacing: 16) {
                        Label("\(NSScreen.screens.count)", systemImage: "display")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if presentationManager.getPresentationStatistics().notesCount > 0 {
                            Label("\(presentationManager.getPresentationStatistics().notesCount)", systemImage: "note.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                // Screen preferences
                GroupBox("Screens") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Audience:")
                                .font(.caption)
                            Spacer()
                            Text(screenPreferenceName(presentationManager.configuration.audienceScreenPreference))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Presenter:")
                                .font(.caption)
                            Spacer()
                            Text(screenPreferenceName(presentationManager.configuration.presenterScreenPreference))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .controlSize(.small)
                
                // Features
                GroupBox("Features") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: presentationManager.configuration.showPresenterNotes ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(presentationManager.configuration.showPresenterNotes ? .green : .gray)
                            Text("Notes")
                                .font(.caption)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: presentationManager.configuration.syncNavigation ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(presentationManager.configuration.syncNavigation ? .green : .gray)
                            Text("Sync Navigation")
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
                .controlSize(.small)
            }
            
            // Quick configuration buttons
            HStack {
                Button("Reset to Defaults") {
                    Task {
                        await presentationManager.updateConfiguration(
                            MultiMonitorPresentationManager.PresentationConfiguration()
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Advanced Settings...") {
                    openAdvancedSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 8)
    }
    
    private func screenPreferenceName(_ preference: ScreenPreference) -> String {
        switch preference {
        case .primary:
            return "Primary"
        case .secondary:
            return "Secondary"
        case .current:
            return "Current"
        case .largest:
            return "Largest"
        case .specific(let index):
            return "Display \(index + 1)"
        }
    }
    
    private func openAdvancedSettings() {
        // Open advanced presentation settings window
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow.title = "Presentation Settings"
        settingsWindow.contentView = NSHostingView(
            rootView: AdvancedPresentationSettingsView(presentationManager: presentationManager)
        )
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Advanced Presentation Settings View

struct AdvancedPresentationSettingsView: View {
    @State var presentationManager: MultiMonitorPresentationManager
    @State private var configuration: MultiMonitorPresentationManager.PresentationConfiguration
    
    init(presentationManager: MultiMonitorPresentationManager) {
        self._presentationManager = State(initialValue: presentationManager)
        self._configuration = State(initialValue: presentationManager.configuration)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Screen Configuration
                    GroupBox("Screen Configuration") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Audience screen preference
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Audience Display")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Audience Screen", selection: $configuration.audienceScreenPreference) {
                                    Text("Primary Display").tag(ScreenPreference.primary)
                                    Text("Secondary Display").tag(ScreenPreference.secondary)
                                    Text("Current Display").tag(ScreenPreference.current)
                                    Text("Largest Display").tag(ScreenPreference.largest)
                                    
                                    ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                                        Text("Display \(index + 1)").tag(ScreenPreference.specific(index))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            // Presenter screen preference
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Presenter Display")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Presenter Screen", selection: $configuration.presenterScreenPreference) {
                                    Text("Primary Display").tag(ScreenPreference.primary)
                                    Text("Secondary Display").tag(ScreenPreference.secondary)
                                    Text("Current Display").tag(ScreenPreference.current)
                                    Text("Largest Display").tag(ScreenPreference.largest)
                                    
                                    ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                                        Text("Display \(index + 1)").tag(ScreenPreference.specific(index))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    
                    // Presenter Features
                    GroupBox("Presenter Features") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Show presenter notes", isOn: $configuration.showPresenterNotes)
                            Toggle("Show photo information", isOn: $configuration.showPhotoInformation)
                            Toggle("Show upcoming photos", isOn: $configuration.showUpcomingPhotos)
                            Toggle("Auto-save notes", isOn: $configuration.notesAutosave)
                        }
                    }
                    
                    // Display Options
                    GroupBox("Display Options") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Presenter controls visible", isOn: $configuration.presenterControlsVisible)
                            Toggle("Audience controls visible", isOn: $configuration.audienceControlsVisible)
                            Toggle("Background dimming", isOn: $configuration.backgroundDimming)
                            
                            HStack {
                                Text("Theme:")
                                Spacer()
                                Picker("Theme", selection: $configuration.presentationTheme) {
                                    Text("Light").tag(MultiMonitorPresentationManager.PresentationTheme.light)
                                    Text("Dark").tag(MultiMonitorPresentationManager.PresentationTheme.dark)
                                    Text("Auto").tag(MultiMonitorPresentationManager.PresentationTheme.auto)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 200)
                            }
                        }
                    }
                    
                    // Navigation
                    GroupBox("Navigation") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Sync navigation between displays", isOn: $configuration.syncNavigation)
                                .help("Keep both displays synchronized when navigating photos")
                        }
                    }
                    
                    // Current Status
                    GroupBox("Current Status") {
                        let stats = presentationManager.getPresentationStatistics()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Presentation Status:")
                                Spacer()
                                Text(stats.isActive ? (stats.isFullscreen ? "Fullscreen" : "Windowed") : "Inactive")
                                    .foregroundColor(stats.isActive ? .green : .secondary)
                            }
                            
                            HStack {
                                Text("Available Displays:")
                                Spacer()
                                Text("\(stats.screenCount)")
                                    .foregroundColor(stats.hasMultiMonitor ? .primary : .orange)
                            }
                            
                            if stats.isActive {
                                HStack {
                                    Text("Current Photo:")
                                    Spacer()
                                    Text("\(stats.currentPhotoIndex + 1) of \(stats.totalPhotos)")
                                        .foregroundColor(.secondary)
                                }
                                
                                if stats.notesCount > 0 {
                                    HStack {
                                        Text("Presenter Notes:")
                                        Spacer()
                                        Text("\(stats.notesCount)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            
            // Bottom buttons
            Divider()
            
            HStack {
                Button("Reset to Defaults") {
                    configuration = MultiMonitorPresentationManager.PresentationConfiguration()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cancel") {
                    // Close window
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.bordered)
                
                Button("Apply") {
                    Task {
                        await presentationManager.updateConfiguration(configuration)
                    }
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onChange(of: presentationManager.configuration) { _, newValue in
            configuration = newValue
        }
    }
}

// MARK: - Presentation Status Bar Item

/// A compact status view that can be embedded in toolbars or status areas
public struct PresentationStatusView: View {
    @State private var presentationManager: MultiMonitorPresentationManager
    
    public init(presentationManager: MultiMonitorPresentationManager) {
        self._presentationManager = State(initialValue: presentationManager)
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "display.2")
                .foregroundColor(presentationManager.isPresentationMode ? .blue : .gray)
            
            if presentationManager.isPresentationMode {
                Text(presentationManager.isFullscreenPresentation ? "Presenting" : "Presentation")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Screen count indicator
            Text("\(NSScreen.screens.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(presentationManager.isPresentationMode ? 
                      Color.blue.opacity(0.1) : 
                      Color.clear)
        )
        .onTapGesture {
            Task {
                await presentationManager.togglePresentationMode()
            }
        }
        .help("Multi-monitor presentation: \(presentationManager.isPresentationMode ? "Active" : "Inactive")")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Presentation Controls") {
    PresentationControlsView(
        presentationManager: MultiMonitorPresentationManager(
            enableEnhancedFeatures: true,
            eventBus: UnifiedEventBus.shared
        )
    )
    .frame(width: 400)
    .padding()
}

#Preview("Advanced Settings") {
    AdvancedPresentationSettingsView(
        presentationManager: MultiMonitorPresentationManager(
            enableEnhancedFeatures: true,
            eventBus: UnifiedEventBus.shared
        )
    )
}

#Preview("Status View") {
    PresentationStatusView(
        presentationManager: MultiMonitorPresentationManager(
            enableEnhancedFeatures: true,
            eventBus: UnifiedEventBus.shared
        )
    )
    .padding()
}
#endif