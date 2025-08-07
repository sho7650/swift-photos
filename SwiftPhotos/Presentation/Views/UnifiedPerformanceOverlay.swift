import SwiftUI
import Foundation

/// Unified Performance Overlay UI Component
/// Displays comprehensive performance metrics from PerformanceMetricsManager
/// Features real-time updates, category filtering, and smart recommendations
@MainActor
public struct UnifiedPerformanceOverlay: View {
    
    // MARK: - Configuration
    
    public enum DisplayMode: String, CaseIterable {
        case minimal = "Minimal"
        case detailed = "Detailed" 
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .minimal: return "speedometer"
            case .detailed: return "chart.bar"
            case .advanced: return "cpu"
            }
        }
    }
    
    public enum Position: String, CaseIterable {
        case topLeading = "Top Left"
        case topTrailing = "Top Right"
        case bottomLeading = "Bottom Left"
        case bottomTrailing = "Bottom Right"
        
        var alignment: Alignment {
            switch self {
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
            }
        }
    }
    
    // MARK: - Properties
    
    private var metricsManager = PerformanceMetricsManager.shared
    
    // Configuration
    let displayMode: DisplayMode
    let position: Position
    let enabledCategories: Set<PerformanceCategory>
    let refreshInterval: TimeInterval
    
    // State
    @State private var isExpanded = false
    @State private var selectedCategory: PerformanceCategory? = nil
    @State private var showRecommendations = false
    @State private var lastUpdateTime = Date()
    
    // Animation
    private let animationDuration: Double = 0.3
    
    // MARK: - Initialization
    
    public init(
        displayMode: DisplayMode = .detailed,
        position: Position = .topTrailing,
        enabledCategories: Set<PerformanceCategory> = Set(PerformanceCategory.allCases),
        refreshInterval: TimeInterval = 2.0
    ) {
        self.displayMode = displayMode
        self.position = position
        self.enabledCategories = enabledCategories
        self.refreshInterval = refreshInterval
    }
    
    // MARK: - Body
    
    public var body: some View {
        overlayContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
            .padding(20)
            .onAppear {
                startMonitoring()
            }
            .onDisappear {
                stopMonitoring()
            }
    }
    
    @ViewBuilder
    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 8)
                
                contentView
                    .transition(.scale.combined(with: .opacity))
                
                if showRecommendations {
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    recommendationsView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(16)
        .background(backgroundView)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .animation(.spring(response: animationDuration, dampingFraction: 0.8), value: isExpanded)
        .animation(.easeInOut(duration: animationDuration), value: showRecommendations)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: displayMode.icon)
                    .foregroundColor(.white)
                    .font(.title3)
                
                Text("Performance")
                    .font(.headline)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                
                if !isExpanded {
                    quickStatsView
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if isExpanded {
                    // Recommendations toggle
                    Button(action: { showRecommendations.toggle() }) {
                        Image(systemName: showRecommendations ? "lightbulb.fill" : "lightbulb")
                            .font(.title3)
                            .foregroundColor(showRecommendations ? .yellow : .white.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle Recommendations")
                }
                
                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .help(isExpanded ? "Collapse" : "Expand")
            }
        }
    }
    
    // MARK: - Quick Stats View (Collapsed State)
    
    private var quickStatsView: some View {
        HStack(spacing: 16) {
            if let stats = metricsManager.unifiedStats.systemStats {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(stats.memoryUsageMB)MB")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            if metricsManager.unifiedStats.totalOperations > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(metricsManager.unifiedStats.totalOperations)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Content View (Expanded State)
    
    @ViewBuilder
    private var contentView: some View {
        switch displayMode {
        case .minimal:
            minimalContentView
        case .detailed:
            detailedContentView
        case .advanced:
            advancedContentView
        }
    }
    
    private var minimalContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overall stats
            overallStatsView
            
            // Active categories count
            HStack {
                Text("Active Categories:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(metricsManager.enabledCategories.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var detailedContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            overallStatsView
            
            // Category metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(enabledCategories), id: \.self) { category in
                    categoryMetricCard(for: category)
                }
            }
        }
    }
    
    private var advancedContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            overallStatsView
            
            // Category selection tabs
            categoryTabsView
            
            // Selected category detail
            if let selectedCategory = selectedCategory {
                selectedCategoryDetailView(for: selectedCategory)
            } else {
                allCategoriesGridView
            }
        }
    }
    
    // MARK: - Overall Stats
    
    private var overallStatsView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Operations")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(metricsManager.unifiedStats.totalOperations)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Avg Response")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(String(format: "%.2f", metricsManager.unifiedStats.overallAverageResponseTime))s")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if let systemStats = metricsManager.unifiedStats.systemStats {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(systemStats.memoryUsageMB)MB")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(memoryColor(for: systemStats.memoryUsageMB))
                }
            }
        }
    }
    
    // MARK: - Category Views
    
    private func categoryMetricCard(for category: PerformanceCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(categoryColor(for: category))
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let stats = metricsManager.getStats(for: category) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Ops:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(stats.operationCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    if stats.averageResponseTime > 0 {
                        HStack {
                            Text("Avg:")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(String(format: "%.3f", stats.averageResponseTime))s")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                }
            } else {
                Text("No Data")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    private var categoryTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button("All") {
                    selectedCategory = nil
                }
                .buttonStyle(TabButtonStyle(isSelected: selectedCategory == nil))
                
                ForEach(Array(enabledCategories), id: \.self) { category in
                    Button(category.displayName) {
                        selectedCategory = category
                    }
                    .buttonStyle(TabButtonStyle(isSelected: selectedCategory == category))
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func selectedCategoryDetailView(for category: PerformanceCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(categoryColor(for: category))
                
                Text(category.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let stats = metricsManager.getStats(for: category) {
                categoryDetailMetrics(stats: stats)
            } else {
                Text("No metrics available for this category")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var allCategoriesGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(Array(enabledCategories), id: \.self) { category in
                categoryMetricCard(for: category)
                    .onTapGesture {
                        selectedCategory = category
                    }
            }
        }
    }
    
    private func categoryDetailMetrics(stats: CategoryPerformanceStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricRow(label: "Operations", value: "\(stats.operationCount)")
            
            if stats.averageResponseTime > 0 {
                MetricRow(label: "Avg Response Time", value: "\(String(format: "%.3f", stats.averageResponseTime))s")
            }
            
            if stats.errorRate > 0 {
                MetricRow(label: "Error Rate", value: "\(String(format: "%.2f", stats.errorRate * 100))%")
            }
            
            if stats.memoryUsageMB > 0 {
                MetricRow(label: "Memory Usage", value: "\(stats.memoryUsageMB)MB")
            }
            
            if stats.cpuUsagePercentage > 0 {
                MetricRow(label: "CPU Usage", value: "\(String(format: "%.1f", stats.cpuUsagePercentage))%")
            }
            
            // Custom metrics
            if !stats.customMetrics.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.3))
                
                ForEach(Array(stats.customMetrics.keys.sorted()), id: \.self) { key in
                    if let value = stats.customMetrics[key] {
                        MetricRow(
                            label: key.replacingOccurrences(of: "_", with: " ").capitalized,
                            value: formatCustomMetricValue(value)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Recommendations View
    
    private var recommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Text("Performance Recommendations")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            let report = metricsManager.getComprehensiveReport()
            if report.recommendations.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("System is performing optimally")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                ForEach(Array(report.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    recommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    private func recommendationCard(recommendation: PerformanceRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: severityIcon(for: recommendation.severity))
                    .font(.caption)
                    .foregroundColor(severityColor(for: recommendation.severity))
                
                Text(recommendation.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Text(recommendation.description)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            HStack {
                Text("Action:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(recommendation.action)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(6)
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        ZStack {
            // Glassmorphism effect
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            
            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func startMonitoring() {
        if !metricsManager.isMonitoring {
            metricsManager.startMonitoring()
        }
    }
    
    private func stopMonitoring() {
        // Don't stop monitoring as other components might be using it
        // metricsManager.stopMonitoring()
    }
    
    private func categoryColor(for category: PerformanceCategory) -> Color {
        switch category {
        case .system: return .blue
        case .repository: return .green
        case .imageLoading: return .orange
        case .settings: return .purple
        case .ui: return .pink
        }
    }
    
    private func memoryColor(for memoryMB: UInt64) -> Color {
        switch memoryMB {
        case 0..<512: return .green
        case 512..<1024: return .yellow
        case 1024..<2048: return .orange
        default: return .red
        }
    }
    
    private func severityColor(for severity: PerformanceRecommendation.Severity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private func severityIcon(for severity: PerformanceRecommendation.Severity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    private func formatCustomMetricValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if value < 1 {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Supporting Views

private struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

private struct TabButtonStyle: SwiftUI.ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: SwiftUI.ButtonStyle.Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
            )
            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.7))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct UnifiedPerformanceOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            UnifiedPerformanceOverlay(
                displayMode: .detailed,
                position: .topTrailing
            )
        }
        .frame(width: 800, height: 600)
    }
}
#endif