import SwiftUI

/// Settings view for Repository pattern configuration and monitoring
public struct RepositorySettingsView: View {
    
    @StateObject private var telemetryService = TelemetryService.shared
    @State private var showAdvancedOptions = false
    @State private var showDiagnostics = false
    @State private var repositoryHealth: RepositoryHealth?
    @State private var performanceMetrics: RepositoryMetrics?
    
    // Repository pattern preferences
    @AppStorage("RepositoryPatternEnabled") private var repositoryPatternEnabled = true
    @AppStorage("AutomaticPatternSelection") private var automaticPatternSelection = true
    @AppStorage("LargeCollectionThreshold") private var largeCollectionThreshold = 100
    @AppStorage("MemoryPressureFallback") private var memoryPressureFallback = true
    @AppStorage("VirtualLoadingEnabled") private var virtualLoadingEnabled = true
    @AppStorage("RepositoryHealthMonitoring") private var healthMonitoring = true
    
    public init() {}
    
    public var body: some View {
        Form {
            // MARK: - Repository Pattern Settings
            Section(header: Label("Repository Pattern", systemImage: "externaldrive.connected")) {
                Toggle("Enable Repository Pattern", isOn: $repositoryPatternEnabled)
                    .help("Use the advanced Repository pattern for improved performance with large photo collections")
                
                if repositoryPatternEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Automatic Pattern Selection", isOn: $automaticPatternSelection)
                            .help("Automatically choose the best pattern based on collection size and system resources")
                        
                        if !automaticPatternSelection {
                            Text("Manual mode: Repository pattern will always be used when enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Large Collection Threshold:")
                        Spacer()
                        TextField("Photos", value: $largeCollectionThreshold, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("photos")
                    }
                    .help("Collections larger than this will automatically use Repository pattern")
                }
            }
            
            // MARK: - Performance Settings
            Section(header: Label("Performance", systemImage: "speedometer")) {
                Toggle("Virtual Loading", isOn: $virtualLoadingEnabled)
                    .help("Load only visible photos to reduce memory usage with large collections")
                    .disabled(!repositoryPatternEnabled)
                
                Toggle("Memory Pressure Fallback", isOn: $memoryPressureFallback)
                    .help("Automatically switch to Legacy mode when system memory is low")
                
                Toggle("Health Monitoring", isOn: $healthMonitoring)
                    .help("Monitor Repository pattern performance and automatically handle issues")
            }
            
            // MARK: - Current Status
            Section(header: Label("Current Status", systemImage: "info.circle")) {
                CurrentStatusView(
                    repositoryHealth: repositoryHealth,
                    performanceMetrics: performanceMetrics
                )
            }
            
            // MARK: - Privacy & Analytics
            Section(header: Label("Privacy & Analytics", systemImage: "shield.lefthalf.filled")) {
                PrivacySettingsView()
            }
            
            // MARK: - Advanced Options
            Section(header: Label("Advanced", systemImage: "gearshape.2")) {
                DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                    AdvancedOptionsView()
                }
                
                DisclosureGroup("Diagnostics", isExpanded: $showDiagnostics) {
                    DiagnosticsView(
                        repositoryHealth: repositoryHealth,
                        performanceMetrics: performanceMetrics
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Repository Settings")
        .task {
            await loadRepositoryStatus()
        }
        .refreshable {
            await loadRepositoryStatus()
        }
        .onChange(of: repositoryPatternEnabled) { _, newValue in
            telemetryService.recordFeatureUsage(.repositoryPattern, properties: [
                "enabled": newValue,
                "trigger": "settings_toggle"
            ])
        }
    }
    
    @MainActor
    private func loadRepositoryStatus() async {
        // In a real implementation, this would query the actual Repository pattern status
        // For now, we'll simulate the data
        
        repositoryHealth = RepositoryHealth(
            isHealthy: true,
            status: .healthy,
            responseTime: 0.05,
            errors: [],
            warnings: []
        )
        
        performanceMetrics = RepositoryMetrics(
            operationCount: 150,
            successCount: 148,
            errorCount: 2,
            averageResponseTime: 0.08,
            cacheHitRate: 0.92,
            totalDataTransferred: 2048576,
            lastOperation: Date()
        )
    }
}

// MARK: - Current Status View

private struct CurrentStatusView: View {
    let repositoryHealth: RepositoryHealth?
    let performanceMetrics: RepositoryMetrics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Health Status
            HStack {
                Image(systemName: healthStatusIcon)
                    .foregroundColor(healthStatusColor)
                Text(healthStatusText)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Performance Metrics
            if let metrics = performanceMetrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    MetricCard(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", metrics.successRate * 100),
                        icon: "checkmark.circle.fill",
                        color: metrics.successRate > 0.95 ? .green : .orange
                    )
                    
                    MetricCard(
                        title: "Avg Response",
                        value: String(format: "%.0fms", metrics.averageResponseTime * 1000),
                        icon: "timer",
                        color: metrics.averageResponseTime < 0.1 ? .green : .orange
                    )
                    
                    MetricCard(
                        title: "Cache Hit Rate",
                        value: String(format: "%.1f%%", metrics.cacheHitRate * 100),
                        icon: "memorychip.fill",
                        color: metrics.cacheHitRate > 0.8 ? .green : .orange
                    )
                    
                    MetricCard(
                        title: "Operations",
                        value: "\(metrics.operationCount)",
                        icon: "number.circle.fill",
                        color: .blue
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var healthStatusIcon: String {
        guard let health = repositoryHealth else { return "questionmark.circle" }
        
        switch health.status {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unhealthy: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var healthStatusColor: Color {
        guard let health = repositoryHealth else { return .gray }
        
        switch health.status {
        case .healthy: return .green
        case .degraded: return .orange
        case .unhealthy: return .red
        case .unknown: return .gray
        }
    }
    
    private var healthStatusText: String {
        guard let health = repositoryHealth else { return "Status Unknown" }
        
        switch health.status {
        case .healthy: return "Repository Pattern Healthy"
        case .degraded: return "Repository Pattern Degraded"
        case .unhealthy: return "Repository Pattern Unhealthy"
        case .unknown: return "Repository Pattern Status Unknown"
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Spacer()
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Privacy Settings View

private struct PrivacySettingsView: View {
    @StateObject private var telemetryService = TelemetryService.shared
    @State private var showDataSummary = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Analytics", isOn: $telemetryService.isEnabled)
                .help("Help improve Swift Photos by sharing anonymous usage data")
            
            if telemetryService.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Share Performance Data", isOn: $telemetryService.sharePerformanceData)
                        .help("Share performance metrics to help optimize the app")
                    
                    Toggle("Share Usage Data", isOn: $telemetryService.shareUsageData)
                        .help("Share feature usage data to prioritize improvements")
                }
                .padding(.leading, 20)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Button("View Data Summary") {
                    showDataSummary = true
                }
                .buttonStyle(.link)
                
                Button("Export Analytics Data") {
                    exportAnalyticsData()
                }
                .buttonStyle(.link)
                
                Button("Clear All Data", role: .destructive) {
                    telemetryService.clearAnalyticsData()
                }
                .buttonStyle(.link)
            }
        }
        .sheet(isPresented: $showDataSummary) {
            DataSummaryView()
        }
    }
    
    private func exportAnalyticsData() {
        guard let data = telemetryService.exportAnalyticsData() else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "swift-photos-analytics.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try data.write(to: url)
            } catch {
                print("Failed to export analytics data: \(error)")
            }
        }
    }
}

// MARK: - Data Summary View

private struct DataSummaryView: View {
    @StateObject private var telemetryService = TelemetryService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Analytics Data Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Swift Photos collects anonymous usage data to improve performance and user experience. No personal information or photo content is collected.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Text(telemetryService.getDataSummary())
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    
                    Text("All data is stored locally and only shared if you enable analytics. You can export or delete this data at any time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Data Summary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Advanced Options View

private struct AdvancedOptionsView: View {
    @AppStorage("RepositoryDebugLogging") private var debugLogging = false
    @AppStorage("CacheValidationEnabled") private var cacheValidation = true
    @AppStorage("MetadataExtractionEnabled") private var metadataExtraction = true
    @AppStorage("ConcurrentLoadingLimit") private var concurrentLoadingLimit = 5
    @AppStorage("VirtualLoadingWindowSize") private var windowSize = 50
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Debug Logging", isOn: $debugLogging)
                .help("Enable detailed logging for troubleshooting")
            
            Toggle("Cache Validation", isOn: $cacheValidation)
                .help("Validate cached data integrity")
            
            Toggle("Metadata Extraction", isOn: $metadataExtraction)
                .help("Extract EXIF and other metadata from images")
            
            HStack {
                Text("Concurrent Loading Limit:")
                Spacer()
                Stepper(value: $concurrentLoadingLimit, in: 1...20) {
                    Text("\(concurrentLoadingLimit)")
                }
            }
            .help("Maximum number of images to load simultaneously")
            
            HStack {
                Text("Virtual Loading Window:")
                Spacer()
                Stepper(value: $windowSize, in: 10...500) {
                    Text("\(windowSize)")
                }
            }
            .help("Number of images to keep in memory around current photo")
        }
    }
}

// MARK: - Diagnostics View

private struct DiagnosticsView: View {
    let repositoryHealth: RepositoryHealth?
    let performanceMetrics: RepositoryMetrics?
    
    @State private var showDetailedMetrics = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Run Health Check") {
                // Trigger manual health check
            }
            .buttonStyle(.borderedProminent)
            
            Button("Export Debug Log") {
                exportDebugLog()
            }
            .buttonStyle(.bordered)
            
            Button("Reset Repository State") {
                // Reset Repository pattern to initial state
            }
            .buttonStyle(.bordered)
            
            Toggle("Show Detailed Metrics", isOn: $showDetailedMetrics)
            
            if showDetailedMetrics, let metrics = performanceMetrics {
                DetailedMetricsView(metrics: metrics)
            }
        }
    }
    
    private func exportDebugLog() {
        // Export debug logs for support
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.log]
        savePanel.nameFieldStringValue = "swift-photos-debug.log"
        
        if savePanel.runModal() == .OK, let _ = savePanel.url {
            // Export debug information
        }
    }
}

// MARK: - Detailed Metrics View

private struct DetailedMetricsView: View {
    let metrics: RepositoryMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Performance Metrics")
                .font(.headline)
                .padding(.bottom, 4)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Total Operations:")
                    Text("\(metrics.operationCount)")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("Success Count:")
                    Text("\(metrics.successCount)")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("Error Count:")
                    Text("\(metrics.errorCount)")
                        .fontWeight(.medium)
                        .foregroundColor(metrics.errorCount > 0 ? .red : .primary)
                }
                
                GridRow {
                    Text("Average Response Time:")
                    Text(String(format: "%.1fms", metrics.averageResponseTime * 1000))
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("Cache Hit Rate:")
                    Text(String(format: "%.1f%%", metrics.cacheHitRate * 100))
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("Data Transferred:")
                    Text(metrics.dataTransferredString)
                        .fontWeight(.medium)
                }
                
                if let lastOperation = metrics.lastOperation {
                    GridRow {
                        Text("Last Operation:")
                        Text(lastOperation, style: .relative)
                            .fontWeight(.medium)
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        RepositorySettingsView()
    }
    .frame(width: 600, height: 800)
}