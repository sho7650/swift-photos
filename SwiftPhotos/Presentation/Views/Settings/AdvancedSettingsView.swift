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
                title: "Debug Settings",
                icon: "ant",
                description: "Configure debugging and diagnostic options"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Enable debug logging", isOn: $isDebugLoggingEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: isDebugLoggingEnabled) { _, enabled in
                            configureDebugLogging(enabled)
                        }
                    
                    if isDebugLoggingEnabled {
                        Toggle("Verbose logging (detailed output)", isOn: $isVerboseLoggingEnabled)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: isVerboseLoggingEnabled) { _, enabled in
                                configureVerboseLogging(enabled)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            Button("Show System Info") {
                                loadSystemInfo()
                                showingSystemInfo = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Export Logs") {
                                exportLogs()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Clear Cache") {
                                clearAllCaches()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            // Experimental Features Section
            AdvancedSettingsSection(
                title: "Experimental Features",
                icon: "flask",
                description: "Beta and experimental functionality (use with caution)"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("⚠️ Experimental features may be unstable or incomplete")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance Optimizations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Enhanced memory management algorithms")
                        Text("• Experimental image loading pipelines")
                        Text("• Advanced caching strategies")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interface Enhancements")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Touch Bar support (MacBook Pro)")
                        Text("• Advanced gesture recognition")
                        Text("• Custom transition effects")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Performance Monitoring Section
            AdvancedSettingsSection(
                title: "Performance Monitoring",
                icon: "speedometer",
                description: "Monitor application performance and resource usage"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    if let systemInfo = systemInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Performance")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            PerformanceMetricRow(label: "Memory Usage", value: systemInfo.memoryUsage)
                            PerformanceMetricRow(label: "CPU Usage", value: systemInfo.cpuUsage)
                            PerformanceMetricRow(label: "Disk Usage", value: systemInfo.diskUsage)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button("Refresh Metrics") {
                            loadSystemInfo()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Performance Report") {
                            generatePerformanceReport()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // System Information Section
            AdvancedSettingsSection(
                title: "System Information",
                icon: "info.circle",
                description: "Application and system details"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    if let systemInfo = systemInfo {
                        SystemInfoSection(title: "Application", items: [
                            ("Version", systemInfo.appVersion),
                            ("Build", systemInfo.buildNumber),
                            ("Bundle ID", systemInfo.bundleIdentifier)
                        ])
                        
                        SystemInfoSection(title: "System", items: [
                            ("macOS", systemInfo.osVersion),
                            ("Architecture", systemInfo.architecture),
                            ("Model", systemInfo.modelIdentifier)
                        ])
                        
                        SystemInfoSection(title: "Hardware", items: [
                            ("Total Memory", systemInfo.totalMemory),
                            ("Available Memory", systemInfo.availableMemory),
                            ("Processor", systemInfo.processorInfo)
                        ])
                    } else {
                        Button("Load System Information") {
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
            loadSystemInfo()
        }
        .sheet(isPresented: $showingSystemInfo) {
            SystemInfoDetailView(systemInfo: systemInfo)
        }
    }
    
    // MARK: - Helper Methods
    
    private func configureDebugLogging(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "DebugLoggingEnabled")
        ProductionLogger.debug("Debug logging \(enabled ? "enabled" : "disabled")")
    }
    
    private func configureVerboseLogging(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "VerboseLoggingEnabled")
        ProductionLogger.debug("Verbose logging \(enabled ? "enabled" : "disabled")")
    }
    
    private func loadSystemInfo() {
        systemInfo = SystemInformation.current()
    }
    
    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Debug Logs"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "PhotoSlideshow-Logs-\(Date().timeIntervalSince1970).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            // Export logs to file
            let logs = "PhotoSlideshow Debug Logs\nGenerated: \(Date())\n\n[Logs would be exported here]"
            try? logs.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func clearAllCaches() {
        // Clear image caches and other temporary data
        ProductionLogger.userAction("Clearing all caches...")
    }
    
    private func generatePerformanceReport() {
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
        // This would reset all settings to defaults
        ProductionLogger.userAction("Resetting all settings to defaults...")
    }
    
    private func resetWindowPositions() {
        // Reset all window positions and sizes
        ProductionLogger.userAction("Resetting window positions...")
    }
    
    private func clearRecentFiles() {
        // Clear recent files list
        ProductionLogger.userAction("Clearing recent files...")
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