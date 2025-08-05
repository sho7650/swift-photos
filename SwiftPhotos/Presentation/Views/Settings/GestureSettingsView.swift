import SwiftUI

/// Gesture settings configuration view
/// Provides comprehensive gesture customization interface
public struct GestureSettingsView: View {
    
    // MARK: - Dependencies
    
    @State private var gestureSettingsManager = ModernGestureSettingsManager()
    
    // MARK: - State
    
    @State private var selectedPreset: GestureSettings.Preset = .default
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportedJSON = ""
    @State private var importJSON = ""
    @State private var showingResetAlert = false
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                presetsSection
                gestureTogglesSection
                sensitivitySection
                thresholdsSection
                zonesSection
                advancedFeaturesSection
                actionButtonsSection
            }
            .padding(20)
        }
        .navigationTitle("Gesture Settings")
        .sheet(isPresented: $showingExportSheet) {
            exportView
        }
        .sheet(isPresented: $showingImportSheet) {
            importView
        }
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                gestureSettingsManager.resetToDefaults()
            }
        } message: {
            Text("This will reset all gesture settings to their default values. This action cannot be undone.")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.tap")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Gesture Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Reset", action: { showingResetAlert = true })
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
            }
            
            Text("Configure gesture recognition, sensitivity, and advanced features for photo slideshow interaction.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Presets", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Preset", selection: $selectedPreset) {
                ForEach(GestureSettings.Preset.allCases) { preset in
                    VStack(alignment: .leading) {
                        Text(preset.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedPreset) { _, newPreset in
                gestureSettingsManager.applyPreset(newPreset)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Gesture Toggles Section
    
    private var gestureTogglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enabled Gestures", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(GestureType.allCases, id: \.self) { gestureType in
                    gestureToggleRow(for: gestureType)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func gestureToggleRow(for gestureType: GestureType) -> some View {
        HStack {
            Image(systemName: iconForGesture(gestureType))
                .foregroundColor(gestureSettingsManager.settings.enabledGestures.contains(gestureType) ? .accentColor : .secondary)
                .frame(width: 20)
            
            Text(gestureType.rawValue.capitalized)
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { gestureSettingsManager.settings.enabledGestures.contains(gestureType) },
                set: { _ in gestureSettingsManager.toggleGesture(gestureType) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(8)
        .background(Color(NSColor.controlColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    // MARK: - Sensitivity Section
    
    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Gesture Sensitivity", systemImage: "dial.max")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Adjust how responsive each gesture type is to user input.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(GestureType.allCases, id: \.self) { gestureType in
                if gestureSettingsManager.settings.enabledGestures.contains(gestureType) {
                    sensitivitySlider(for: gestureType)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func sensitivitySlider(for gestureType: GestureType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(gestureType.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1fx", gestureSettingsManager.settings.sensitivity(for: gestureType)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(
                value: Binding(
                    get: { gestureSettingsManager.settings.sensitivity(for: gestureType) },
                    set: { gestureSettingsManager.updateGestureSensitivity(gestureType, sensitivity: $0) }
                ),
                in: 0.1...3.0,
                step: 0.1
            )
        }
        .padding(8)
        .background(Color(NSColor.controlColor).opacity(0.3))
        .cornerRadius(6)
    }
    
    // MARK: - Thresholds Section
    
    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Detection Thresholds", systemImage: "ruler")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Set minimum values required to trigger each gesture type.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(GestureType.allCases, id: \.self) { gestureType in
                if gestureSettingsManager.settings.enabledGestures.contains(gestureType) {
                    thresholdSlider(for: gestureType)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func thresholdSlider(for gestureType: GestureType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(gestureType.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1f", gestureSettingsManager.settings.threshold(for: gestureType)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(
                value: Binding(
                    get: { gestureSettingsManager.settings.threshold(for: gestureType) },
                    set: { gestureSettingsManager.updateGestureThreshold(gestureType, threshold: $0) }
                ),
                in: 1.0...200.0,
                step: 1.0
            )
        }
        .padding(8)
        .background(Color(NSColor.controlColor).opacity(0.3))
        .cornerRadius(6)
    }
    
    // MARK: - Zones Section
    
    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Interaction Zones", systemImage: "square.3.layers.3d")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Configure which areas of the interface respond to gestures.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(InteractionZone.ZoneType.allCases, id: \.self) { zoneType in
                    zoneToggleRow(for: zoneType)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func zoneToggleRow(for zoneType: InteractionZone.ZoneType) -> some View {
        HStack {
            Image(systemName: iconForZone(zoneType))
                .foregroundColor(gestureSettingsManager.settings.enabledZones.contains(zoneType) ? .accentColor : .secondary)
                .frame(width: 20)
            
            Text(zoneType.name)
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { gestureSettingsManager.settings.enabledZones.contains(zoneType) },
                set: { isEnabled in
                    var newZones = gestureSettingsManager.settings.enabledZones
                    if isEnabled {
                        newZones.insert(zoneType)
                    } else {
                        newZones.remove(zoneType)
                    }
                    
                    gestureSettingsManager.settings = GestureSettings(
                        enabledGestures: gestureSettingsManager.settings.enabledGestures,
                        gestureSensitivities: gestureSettingsManager.settings.gestureSensitivities,
                        gestureThresholds: gestureSettingsManager.settings.gestureThresholds,
                        enabledZones: newZones,
                        simultaneousGestureRecognition: gestureSettingsManager.settings.simultaneousGestureRecognition,
                        feedbackHaptics: gestureSettingsManager.settings.feedbackHaptics,
                        advancedFeatures: gestureSettingsManager.settings.advancedFeatures
                    )
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(8)
        .background(Color(NSColor.controlColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    // MARK: - Advanced Features Section
    
    private var advancedFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Advanced Features", systemImage: "gearshape.2")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Enable experimental and advanced gesture processing features.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                featureToggle(
                    title: "Simultaneous Recognition",
                    description: "Allow multiple gestures to be recognized at once",
                    isEnabled: gestureSettingsManager.settings.simultaneousGestureRecognition
                ) { isEnabled in
                    gestureSettingsManager.settings = GestureSettings(
                        enabledGestures: gestureSettingsManager.settings.enabledGestures,
                        gestureSensitivities: gestureSettingsManager.settings.gestureSensitivities,
                        gestureThresholds: gestureSettingsManager.settings.gestureThresholds,
                        enabledZones: gestureSettingsManager.settings.enabledZones,
                        simultaneousGestureRecognition: isEnabled,
                        feedbackHaptics: gestureSettingsManager.settings.feedbackHaptics,
                        advancedFeatures: gestureSettingsManager.settings.advancedFeatures
                    )
                }
                
                featureToggle(
                    title: "Haptic Feedback",
                    description: "Provide tactile feedback for gesture recognition",
                    isEnabled: gestureSettingsManager.settings.feedbackHaptics
                ) { isEnabled in
                    gestureSettingsManager.settings = GestureSettings(
                        enabledGestures: gestureSettingsManager.settings.enabledGestures,
                        gestureSensitivities: gestureSettingsManager.settings.gestureSensitivities,
                        gestureThresholds: gestureSettingsManager.settings.gestureThresholds,
                        enabledZones: gestureSettingsManager.settings.enabledZones,
                        simultaneousGestureRecognition: gestureSettingsManager.settings.simultaneousGestureRecognition,
                        feedbackHaptics: isEnabled,
                        advancedFeatures: gestureSettingsManager.settings.advancedFeatures
                    )
                }
                
                featureToggle(
                    title: "Momentum Effects",
                    description: "Enable inertia and momentum for pan gestures",
                    isEnabled: gestureSettingsManager.settings.advancedFeatures.momentumEnabled
                ) { isEnabled in
                    let newFeatures = AdvancedGestureFeatures(
                        momentumEnabled: isEnabled,
                        predictionEnabled: gestureSettingsManager.settings.advancedFeatures.predictionEnabled,
                        conflictResolutionEnabled: gestureSettingsManager.settings.advancedFeatures.conflictResolutionEnabled,
                        analyticsEnabled: gestureSettingsManager.settings.advancedFeatures.analyticsEnabled,
                        adaptiveSensitivityEnabled: gestureSettingsManager.settings.advancedFeatures.adaptiveSensitivityEnabled,
                        multiFingerGesturesEnabled: gestureSettingsManager.settings.advancedFeatures.multiFingerGesturesEnabled,
                        customGesturesEnabled: gestureSettingsManager.settings.advancedFeatures.customGesturesEnabled
                    )
                    
                    gestureSettingsManager.settings = GestureSettings(
                        enabledGestures: gestureSettingsManager.settings.enabledGestures,
                        gestureSensitivities: gestureSettingsManager.settings.gestureSensitivities,
                        gestureThresholds: gestureSettingsManager.settings.gestureThresholds,
                        enabledZones: gestureSettingsManager.settings.enabledZones,
                        simultaneousGestureRecognition: gestureSettingsManager.settings.simultaneousGestureRecognition,
                        feedbackHaptics: gestureSettingsManager.settings.feedbackHaptics,
                        advancedFeatures: newFeatures
                    )
                }
                
                featureToggle(
                    title: "Analytics Collection",
                    description: "Collect gesture usage data for optimization",
                    isEnabled: gestureSettingsManager.settings.advancedFeatures.analyticsEnabled
                ) { isEnabled in
                    let newFeatures = AdvancedGestureFeatures(
                        momentumEnabled: gestureSettingsManager.settings.advancedFeatures.momentumEnabled,
                        predictionEnabled: gestureSettingsManager.settings.advancedFeatures.predictionEnabled,
                        conflictResolutionEnabled: gestureSettingsManager.settings.advancedFeatures.conflictResolutionEnabled,
                        analyticsEnabled: isEnabled,
                        adaptiveSensitivityEnabled: gestureSettingsManager.settings.advancedFeatures.adaptiveSensitivityEnabled,
                        multiFingerGesturesEnabled: gestureSettingsManager.settings.advancedFeatures.multiFingerGesturesEnabled,
                        customGesturesEnabled: gestureSettingsManager.settings.advancedFeatures.customGesturesEnabled
                    )
                    
                    gestureSettingsManager.settings = GestureSettings(
                        enabledGestures: gestureSettingsManager.settings.enabledGestures,
                        gestureSensitivities: gestureSettingsManager.settings.gestureSensitivities,
                        gestureThresholds: gestureSettingsManager.settings.gestureThresholds,
                        enabledZones: gestureSettingsManager.settings.enabledZones,
                        simultaneousGestureRecognition: gestureSettingsManager.settings.simultaneousGestureRecognition,
                        feedbackHaptics: gestureSettingsManager.settings.feedbackHaptics,
                        advancedFeatures: newFeatures
                    )
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func featureToggle(
        title: String,
        description: String,
        isEnabled: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: onToggle
            ))
            .toggleStyle(.switch)
        }
        .padding(8)
        .background(Color(NSColor.controlColor).opacity(0.3))
        .cornerRadius(6)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button("Export Settings") {
                if let exported = gestureSettingsManager.exportSettings() {
                    exportedJSON = exported
                    showingExportSheet = true
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Import Settings") {
                showingImportSheet = true
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Reset to Defaults") {
                showingResetAlert = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Export View
    
    private var exportView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Gesture Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Copy the JSON below to share or backup your gesture settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextEditor(text: .constant(exportedJSON))
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .border(Color.secondary, width: 1)
                
                HStack {
                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(exportedJSON, forType: .string)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Close") {
                        showingExportSheet = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .frame(width: 500, height: 400)
        }
    }
    
    // MARK: - Import View
    
    private var importView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Gesture Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Paste gesture settings JSON below to import configuration.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextEditor(text: $importJSON)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .border(Color.secondary, width: 1)
                
                HStack {
                    Button("Import") {
                        if gestureSettingsManager.importSettings(from: importJSON) {
                            showingImportSheet = false
                            importJSON = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importJSON.isEmpty)
                    
                    Button("Cancel") {
                        showingImportSheet = false
                        importJSON = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .frame(width: 500, height: 400)
        }
    }
    
    // MARK: - Helper Methods
    
    private func iconForGesture(_ gestureType: GestureType) -> String {
        switch gestureType {
        case .tap: return "hand.tap"
        case .doubleTap: return "hand.tap.fill"
        case .longPress: return "hand.press"
        case .pan: return "hand.drag"
        case .pinch: return "hand.draw"
        case .rotation: return "rotate.3d"
        case .swipeLeft: return "arrow.left"
        case .swipeRight: return "arrow.right"
        case .swipeUp: return "arrow.up"
        case .swipeDown: return "arrow.down"
        case .magnify: return "magnifyingglass"
        case .smartMagnify: return "magnifyingglass.circle"
        case .hover: return "cursorarrow"
        }
    }
    
    private func iconForZone(_ zoneType: InteractionZone.ZoneType) -> String {
        switch zoneType {
        case .imageArea: return "photo"
        case .controlsArea: return "slider.horizontal.3"
        case .navigationArea: return "arrow.left.arrow.right"
        case .infoArea: return "info.circle"
        case .globalArea: return "globe"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct GestureSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GestureSettingsView()
            .frame(width: 600, height: 800)
    }
}
#endif