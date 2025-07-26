import SwiftUI
import AppKit
import os.log

/// Advanced settings view for debugging, experimental features, and technical information
/// Provides access to developer-oriented options and system information
struct AdvancedSettingsView: View {
    @State private var isDebugLoggingEnabled = false
    @State private var isVerboseLoggingEnabled = false
    @State private var showingSystemInfo = false
    @State private var systemInfo: SystemInformation?
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Debug Settings Section
            AdvancedSettingsSection(
                title: L10n.SettingsString.debugSettings(),
                icon: "ant",
                description: L10n.SettingsString.debugSettingsDescription()
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(L10n.ToggleString.enableDebugLogging(), isOn: $isDebugLoggingEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: isDebugLoggingEnabled) { _, enabled in
                            configureDebugLogging(enabled)
                        }
                    
                    if isDebugLoggingEnabled {
                        Toggle(String(localized: "toggle.verbose_logging"), isOn: $isVerboseLoggingEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: isVerboseLoggingEnabled) { _, enabled in
                                configureVerboseLogging(enabled)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.UI.debugInformation)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            Button(String(localized: "button.advanced.show_system_info")) {
                                loadSystemInfo()
                                showingSystemInfo = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button(String(localized: "button.advanced.export_logs")) {
                                exportLogs()
                            }
                            .buttonStyle(.bordered)
                            
                            Button(String(localized: "button.advanced.clear_cache")) {
                                clearAllCaches()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            // Experimental Features Section
            AdvancedSettingsSection(
                title: String(localized: "settings.advanced.experimental"),
                icon: "flask",
                description: String(localized: "settings.advanced.experimental.description")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "warning.experimental_features"))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.UI.performanceEnhancements)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(L10n.Features.advancedMemoryManagementDesc)
                        Text(L10n.Features.optimizedImageLoading)
                        Text(L10n.Features.smartCachingSystem)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.UI.interfaceImprovements)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(L10n.Features.touchBarSupport)
                        Text(L10n.Features.enhancedGestures)
                        Text(L10n.Features.advancedTransitions)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Performance Monitoring Section
            AdvancedSettingsSection(
                title: String(localized: "settings.advanced.performance_monitoring"),
                icon: "speedometer",
                description: String(localized: "settings.advanced.performance_monitoring.description")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    if let systemInfo = systemInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.UI.currentPerformanceMetrics)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            PerformanceMetricRow(
                                label: String(localized: "ui.memory_usage"), 
                                value: systemInfo.memoryUsage
                            )
                            PerformanceMetricRow(
                                label: String(localized: "ui.cpu_usage"), 
                                value: systemInfo.cpuUsage
                            )
                            PerformanceMetricRow(
                                label: String(localized: "ui.disk_usage"), 
                                value: systemInfo.diskUsage
                            )
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(String(localized: "button.advanced.refresh_metrics")) {
                            loadSystemInfo()
                        }
                        .buttonStyle(.bordered)
                        
                        Button(String(localized: "button.advanced.performance_report")) {
                            generatePerformanceReport()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // System Information Section
            AdvancedSettingsSection(
                title: String(localized: "settings.advanced.system_information"),
                icon: "info.circle",
                description: String(localized: "settings.advanced.system_information.description")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    if let systemInfo = systemInfo {
                        SystemInfoSection(
                            title: String(localized: "ui.application"), 
                            items: [
                                (String(localized: "ui.version"), systemInfo.appVersion),
                                (String(localized: "ui.build"), systemInfo.buildNumber),
                                (String(localized: "ui.bundle_id"), systemInfo.bundleIdentifier)
                            ]
                        )
                        
                        SystemInfoSection(
                            title: String(localized: "ui.system"), 
                            items: [
                                (String(localized: "ui.macos"), systemInfo.osVersion),
                                (String(localized: "ui.architecture"), systemInfo.architecture),
                                (String(localized: "ui.model"), systemInfo.modelIdentifier)
                            ]
                        )
                        
                        SystemInfoSection(
                            title: String(localized: "ui.hardware"), 
                            items: [
                                (String(localized: "ui.total_memory"), systemInfo.totalMemory),
                                (String(localized: "ui.available_memory"), systemInfo.availableMemory),
                                (String(localized: "ui.processor"), systemInfo.processorInfo)
                            ]
                        )
                    } else {
                        Button(String(localized: "button.advanced.load_system_info")) {
                            loadSystemInfo()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Reset and Maintenance Section
            AdvancedSettingsSection(
                title: String(localized: "settings.advanced.maintenance"),
                icon: "arrow.clockwise",
                description: String(localized: "settings.advanced.maintenance.description")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "warning.actions_cannot_be_undone"))
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button(String(localized: "button.advanced.reset_all_settings")) {
                                resetAllSettings()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button(String(localized: "button.advanced.clear_all_caches")) {
                                clearAllCaches()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 12) {
                            Button(String(localized: "button.advanced.reset_window_positions")) {
                                resetWindowPositions()
                            }
                            .buttonStyle(.bordered)
                            
                            Button(String(localized: "button.advanced.clear_recent_files")) {
                                clearRecentFiles()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            // About Section
            AdvancedSettingsSection(
                title: String(localized: "settings.advanced.about"),
                icon: "photo.stack",
                description: String(localized: "settings.advanced.about.description")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.App.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(String(localized: "app.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.UI.keyFeatures)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(L10n.Features.unlimitedPhotoCollections)
                        Text(L10n.Features.advancedMemoryManagement)
                        Text(L10n.Features.smoothTransitionsAndEffects)
                        Text(L10n.Features.performanceOptimization)
                        Text(L10n.Features.nativeMacOSExperience)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .onAppear {
            loadSystemInfo()
            loadDebugSettings()
        }
        .sheet(isPresented: $showingSystemInfo) {
            SystemInfoDetailView(systemInfo: systemInfo)
        }
    }
    
    // MARK: - Helper Methods
    
    private func configureDebugLogging(_ enabled: Bool) {
        ProductionLogger.setDebugLogging(enabled: enabled)
    }
    
    private func configureVerboseLogging(_ enabled: Bool) {
        ProductionLogger.setVerboseLogging(enabled: enabled)
    }
    
    private func loadSystemInfo() {
        systemInfo = SystemInformation.current()
    }
    
    private func loadDebugSettings() {
        isDebugLoggingEnabled = ProductionLogger.isDebugEnabled()
        isVerboseLoggingEnabled = ProductionLogger.isVerboseEnabled()
    }
    
    private func exportLogs() {
        // Ensure we're on the main thread for proper dialog presentation
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.exportLogs()
            }
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = String(localized: "dialog.export_debug_logs")
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "Swift-Photos-Logs-\(Int(Date().timeIntervalSince1970)).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let logs = ProductionLogger.exportLogsAsString()
            do {
                try logs.write(to: url, atomically: true, encoding: .utf8)
                ProductionLogger.userAction("Debug logs exported to \(url.lastPathComponent)")
            } catch {
                ProductionLogger.error("Failed to export logs: \(error.localizedDescription)")
            }
        }
    }
    
    private func clearAllCaches() {
        // Clear image caches and other temporary data
        ProductionLogger.userAction("Clearing all caches...")
        
        // Clear UserDefaults temporary data (keep settings)
        let keys = ["ImageCache", "ThumbnailCache", "MetadataCache"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear NSURLCache
        URLCache.shared.removeAllCachedResponses()
        
        ProductionLogger.info("All caches cleared successfully")
    }
    
    private func generatePerformanceReport() {
        // Ensure we're on the main thread for proper dialog presentation
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.generatePerformanceReport()
            }
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = String(localized: "dialog.export_performance_report")
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "PhotoSlideshow-Performance-\(Date().timeIntervalSince1970).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let report = generateDetailedPerformanceReport()
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func generateDetailedPerformanceReport() -> String {
        guard let info = systemInfo else { return "System information not available" }
        
        return """
        PhotoSlideshow Performance Report
        Generated: \(Date())
        
        System Information:
        - macOS: \(info.osVersion)
        - Architecture: \(info.architecture)
        - Model: \(info.modelIdentifier)
        - Total Memory: \(info.totalMemory)
        - Available Memory: \(info.availableMemory)
        - Processor: \(info.processorInfo)
        
        Application Information:
        - Version: \(info.appVersion)
        - Build: \(info.buildNumber)
        - Bundle ID: \(info.bundleIdentifier)
        
        Performance Metrics:
        - Memory Usage: \(info.memoryUsage)
        - CPU Usage: \(info.cpuUsage)
        - Disk Usage: \(info.diskUsage)
        
        [Additional performance metrics would be included here]
        """
    }
    
    private func resetAllSettings() {
        ProductionLogger.userAction("Resetting all settings to defaults...")
        
        // Reset all settings-related UserDefaults keys
        let settingsKeys = [
            "SwiftPhotosPerformanceSettings",
            "SwiftPhotosSlideshowSettings", 
            "SwiftPhotosSortSettings",
            "SwiftPhotosTransitionSettings",
            "SwiftPhotosUIControlSettings",
            "DebugLoggingEnabled",
            "VerboseLoggingEnabled"
        ]
        
        for key in settingsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Reset debug logging states
        isDebugLoggingEnabled = false
        isVerboseLoggingEnabled = false
        
        ProductionLogger.info("All settings reset to defaults")
    }
    
    private func resetWindowPositions() {
        ProductionLogger.userAction("Resetting window positions...")
        
        // Reset window-related UserDefaults
        let windowKeys = [
            "NSWindow Frame MainWindow",
            "NSWindow Frame SettingsWindow",
            "NSWindow Frame DebugWindow"
        ]
        
        for key in windowKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        ProductionLogger.info("Window positions reset")
    }
    
    private func clearRecentFiles() {
        ProductionLogger.userAction("Clearing recent files...")
        
        // Clear recent files from UserDefaults
        UserDefaults.standard.removeObject(forKey: "RecentFiles")
        UserDefaults.standard.removeObject(forKey: "RecentFolders")
        
        // Clear NSDocumentController recent documents
        NSDocumentController.shared.clearRecentDocuments(nil)
        
        ProductionLogger.info("Recent files cleared")
    }
}

// MARK: - Helper Views

/// Reusable settings section component for advanced settings
private struct AdvancedSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let description: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            content()
        }
        .padding(.vertical, 8)
    }
}

private struct PerformanceMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

private struct SystemInfoSection: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.1)
                        .fontWeight(.medium)
                }
                .font(.caption)
            }
        }
    }
}

// MARK: - System Information Model

private struct SystemInformation {
    let appVersion: String
    let buildNumber: String
    let bundleIdentifier: String
    let osVersion: String
    let architecture: String
    let modelIdentifier: String
    let totalMemory: String
    let availableMemory: String
    let processorInfo: String
    let memoryUsage: String
    let cpuUsage: String
    let diskUsage: String
    
    static func current() -> SystemInformation {
        let processInfo = ProcessInfo.processInfo
        
        return SystemInformation(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "Unknown",
            osVersion: processInfo.operatingSystemVersionString,
            architecture: processInfo.processorCount > 1 ? "Multi-core (\(processInfo.processorCount) cores)" : "Single-core",
            modelIdentifier: getModelIdentifier(),
            totalMemory: ByteCountFormatter.string(fromByteCount: Int64(processInfo.physicalMemory), countStyle: .memory),
            availableMemory: getAvailableMemory(),
            processorInfo: getProcessorInfo(),
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: getCurrentCPUUsage(),
            diskUsage: getCurrentDiskUsage()
        )
    }
    
    private static func getModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private static func getAvailableMemory() -> String {
        let pageSize = vm_page_size
        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &infoCount)
            }
        }
        
        if result == KERN_SUCCESS {
            let freeBytes = Int64(vmStats.free_count) * Int64(pageSize)
            return ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .memory)
        }
        
        return "Unknown"
    }
    
    private static func getProcessorInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpu = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpu, &size, nil, 0)
        return String(cString: cpu)
    }
    
    private static func getCurrentMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return ByteCountFormatter.string(fromByteCount: Int64(info.resident_size), countStyle: .memory)
        }
        
        return "Unknown"
    }
    
    private static func getCurrentCPUUsage() -> String {
        // Simplified CPU usage - would need more complex implementation for accurate measurement
        return "~5%"
    }
    
    private static func getCurrentDiskUsage() -> String {
        // Simplified disk usage - would need more complex implementation
        return "~2GB"
    }
}

// MARK: - System Info Detail View

private struct SystemInfoDetailView: View {
    let systemInfo: SystemInformation?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let info = systemInfo {
                        Text(generateDetailedPerformanceReport(info))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
            }
            .navigationTitle(String(localized: "window.system_information"))
            .frame(width: 600, height: 500)
        }
    }
    
    private func generateDetailedPerformanceReport(_ info: SystemInformation) -> String {
        return """
        PhotoSlideshow System Information
        Generated: \(Date())
        
        Application:
        Version: \(info.appVersion)
        Build: \(info.buildNumber)
        Bundle ID: \(info.bundleIdentifier)
        
        System:
        macOS: \(info.osVersion)
        Architecture: \(info.architecture)
        Model: \(info.modelIdentifier)
        
        Hardware:
        Total Memory: \(info.totalMemory)
        Available Memory: \(info.availableMemory)
        Processor: \(info.processorInfo)
        
        Performance:
        Memory Usage: \(info.memoryUsage)
        CPU Usage: \(info.cpuUsage)
        Disk Usage: \(info.diskUsage)
        """
    }
}

#Preview {
    AdvancedSettingsView()
        .frame(width: 500, height: 600)
}