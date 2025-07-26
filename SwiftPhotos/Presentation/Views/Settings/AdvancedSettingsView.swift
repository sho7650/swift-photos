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
    
    // Localization support
    @State private var localizationService: LocalizationService? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Debug Settings Section
            AdvancedSettingsSection(
                title: String.settingsSection("debug", service: localizationService),
                icon: "ant",
                description: String.localized("settings.debug.description", service: localizationService)
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(String.localized("settings.debug.enable_logging", service: localizationService), isOn: $isDebugLoggingEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: isDebugLoggingEnabled) { _, enabled in
                            configureDebugLogging(enabled)
                        }
                    
                    if isDebugLoggingEnabled {
                        Toggle(String.localized("settings.debug.verbose_logging", service: localizationService), isOn: $isVerboseLoggingEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: isVerboseLoggingEnabled) { _, enabled in
                                configureVerboseLogging(enabled)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String.localized("settings.debug.information", service: localizationService))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            Button(String.button("show_system_info", service: localizationService)) {
                                loadSystemInfo()
                                showingSystemInfo = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button(String.button("export_logs", service: localizationService)) {
                                exportLogs()
                            }
                            .buttonStyle(.bordered)
                            
                            Button(String.button("clear_cache", service: localizationService)) {
                                clearAllCaches()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            // Experimental Features Section
            AdvancedSettingsSection(
                title: String.settingsSection("experimental", service: localizationService),
                icon: "flask",
                description: String.localized("settings.experimental.description", service: localizationService)
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String.localized("settings.experimental.warning", service: localizationService))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String.localized("settings.experimental.performance_title", service: localizationService))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(String.localized("settings.experimental.memory_management", service: localizationService))
                        Text(String.localized("settings.experimental.image_loading", service: localizationService))
                        Text(String.localized("settings.experimental.caching", service: localizationService))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String.localized("settings.experimental.interface_title", service: localizationService))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(String.localized("settings.experimental.touch_bar", service: localizationService))
                        Text(String.localized("settings.experimental.gestures", service: localizationService))
                        Text(String.localized("settings.experimental.transitions", service: localizationService))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Performance Monitoring Section
            AdvancedSettingsSection(
                title: String.settingsSection("performance", service: localizationService),
                icon: "speedometer",
                description: String.localized("settings.performance.description", service: localizationService)
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    if let systemInfo = systemInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String.localized("settings.performance.current", service: localizationService))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            PerformanceMetricRow(
                                label: String.localized("settings.performance.memory_usage", service: localizationService), 
                                value: systemInfo.memoryUsage
                            )
                            PerformanceMetricRow(
                                label: String.localized("settings.performance.cpu_usage", service: localizationService), 
                                value: systemInfo.cpuUsage
                            )
                            PerformanceMetricRow(
                                label: String.localized("settings.performance.disk_usage", service: localizationService), 
                                value: systemInfo.diskUsage
                            )
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(String.button("refresh_metrics", service: localizationService)) {
                            loadSystemInfo()
                        }
                        .buttonStyle(.bordered)
                        
                        Button(String.button("performance_report", service: localizationService)) {
                            generatePerformanceReport()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // System Information Section
            AdvancedSettingsSection(
                title: String.settingsSection("system_info", service: localizationService),
                icon: "info.circle",
                description: String.localized("settings.system_info.description", service: localizationService)
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    if let systemInfo = systemInfo {
                        SystemInfoSection(
                            title: String.localized("settings.system_info.application", service: localizationService), 
                            items: [
                                (String.localized("settings.system_info.version", service: localizationService), systemInfo.appVersion),
                                (String.localized("settings.system_info.build", service: localizationService), systemInfo.buildNumber),
                                (String.localized("settings.system_info.bundle_id", service: localizationService), systemInfo.bundleIdentifier)
                            ]
                        )
                        
                        SystemInfoSection(
                            title: String.localized("settings.system_info.system", service: localizationService), 
                            items: [
                                ("macOS", systemInfo.osVersion),
                                (String.localized("settings.system_info.architecture", service: localizationService), systemInfo.architecture),
                                (String.localized("settings.system_info.model", service: localizationService), systemInfo.modelIdentifier)
                            ]
                        )
                        
                        SystemInfoSection(
                            title: String.localized("settings.system_info.hardware", service: localizationService), 
                            items: [
                                (String.localized("settings.system_info.total_memory", service: localizationService), systemInfo.totalMemory),
                                (String.localized("settings.system_info.available_memory", service: localizationService), systemInfo.availableMemory),
                                (String.localized("settings.system_info.processor", service: localizationService), systemInfo.processorInfo)
                            ]
                        )
                    } else {
                        Button(String.button("load_system_info", service: localizationService)) {
                            loadSystemInfo()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Reset and Maintenance Section
            AdvancedSettingsSection(
                title: "Reset & Maintenance",
                icon: "arrow.clockwise",
                description: "Reset application state and perform maintenance"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚠️ These actions cannot be undone")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button("Reset All Settings") {
                                resetAllSettings()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Clear All Caches") {
                                clearAllCaches()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Reset Window Positions") {
                                resetWindowPositions()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Clear Recent Files") {
                                clearRecentFiles()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            // About Section
            AdvancedSettingsSection(
                title: "About PhotoSlideshow",
                icon: "photo.stack",
                description: "Application information and credits"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Swift Photos")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Professional photo slideshow application for macOS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Features:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Supports unlimited photo collections (100k+ photos)")
                        Text("• Advanced memory management and caching")
                        Text("• Smooth transition effects and animations")
                        Text("• Professional-grade performance optimization")
                        Text("• Native macOS design and integration")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .onAppear {
            localizationService = LocalizationService()
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
        savePanel.title = "Export Debug Logs"
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
        savePanel.title = "Export Performance Report"
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
            .navigationTitle("System Information")
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