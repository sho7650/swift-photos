import Foundation
import SwiftUI

/// Bridge service to enable gradual migration from legacy to Repository pattern
/// Provides compatibility layer and migration utilities
@MainActor
public class RepositoryMigrationBridge: ObservableObject {
    
    // MARK: - Migration State
    @Published public var migrationStatus: MigrationStatus = .notStarted
    @Published public var repositoryHealth: RepositoryHealthStatus?
    @Published public var migrationProgress: Double = 0.0
    
    // MARK: - Configuration
    public var enableRepositoryPattern: Bool {
        get { UserDefaults.standard.bool(forKey: "SwiftPhotos.EnableRepositoryPattern") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "SwiftPhotos.EnableRepositoryPattern")
            ProductionLogger.info("RepositoryMigrationBridge: Repository pattern \(newValue ? "enabled" : "disabled")")
        }
    }
    
    public var allowAutomaticMigration: Bool {
        get { UserDefaults.standard.bool(forKey: "SwiftPhotos.AllowAutomaticMigration") }
        set { UserDefaults.standard.set(newValue, forKey: "SwiftPhotos.AllowAutomaticMigration") }
    }
    
    // MARK: - Singleton
    public static let shared = RepositoryMigrationBridge()
    
    private init() {
        // Set default values
        if !UserDefaults.standard.bool(forKey: "SwiftPhotos.MigrationInitialized") {
            enableRepositoryPattern = true // Default to enabled for new installations
            allowAutomaticMigration = true
            UserDefaults.standard.set(true, forKey: "SwiftPhotos.MigrationInitialized")
        }
        
        // Start health monitoring
        Task {
            await startHealthMonitoring()
        }
    }
    
    // MARK: - Migration Methods
    
    /// Check if Repository pattern should be used
    public func shouldUseRepositoryPattern() async -> Bool {
        guard enableRepositoryPattern else {
            ProductionLogger.info("RepositoryMigrationBridge: Repository pattern disabled by user preference")
            return false
        }
        
        // Check repository health
        let readiness = await ViewModelFactory.checkRepositoryReadiness()
        repositoryHealth = readiness.healthStatus
        
        if readiness.isReady {
            ProductionLogger.info("RepositoryMigrationBridge: Repository pattern ready and healthy")
            return true
        } else {
            ProductionLogger.warning("RepositoryMigrationBridge: Repository pattern not ready: \(readiness.healthStatus.issues)")
            return false
        }
    }
    
    /// Perform migration assessment
    public func assessMigrationReadiness() async -> MigrationAssessment {
        ProductionLogger.info("RepositoryMigrationBridge: Assessing migration readiness")
        
        let startTime = Date()
        var assessment = MigrationAssessment()
        
        // Check Repository health
        let readiness = await ViewModelFactory.checkRepositoryReadiness()
        assessment.repositoryHealth = readiness.healthStatus
        assessment.repositoryReady = readiness.isReady
        
        // Check performance metrics
        let metrics = await ViewModelFactory.getRepositoryMetrics()
        assessment.repositoryMetrics = metrics
        assessment.hasPerformanceData = !metrics.isEmpty
        
        // Check for potential issues
        assessment.potentialIssues = await identifyPotentialIssues()
        
        // Calculate readiness score
        assessment.readinessScore = calculateReadinessScore(assessment)
        assessment.recommendMigration = assessment.readinessScore >= 0.7
        
        let duration = Date().timeIntervalSince(startTime)
        ProductionLogger.info("RepositoryMigrationBridge: Assessment completed in \(String(format: "%.2f", duration))s - Score: \(String(format: "%.2f", assessment.readinessScore))")
        
        return assessment
    }
    
    /// Perform automatic migration if conditions are met
    public func performAutomaticMigrationIfReady() async -> Bool {
        guard allowAutomaticMigration else {
            ProductionLogger.info("RepositoryMigrationBridge: Automatic migration disabled")
            return false
        }
        
        let assessment = await assessMigrationReadiness()
        
        if assessment.recommendMigration {
            ProductionLogger.info("RepositoryMigrationBridge: Conditions met for automatic migration")
            migrationStatus = .inProgress
            migrationProgress = 0.5
            
            // Perform migration steps
            let success = await performMigrationSteps()
            
            if success {
                migrationStatus = .completed
                migrationProgress = 1.0
                enableRepositoryPattern = true
                ProductionLogger.lifecycle("RepositoryMigrationBridge: Automatic migration completed successfully")
                return true
            } else {
                migrationStatus = .failed
                migrationProgress = 0.0
                ProductionLogger.error("RepositoryMigrationBridge: Automatic migration failed")
                return false
            }
        } else {
            ProductionLogger.info("RepositoryMigrationBridge: Conditions not met for automatic migration (score: \(String(format: "%.2f", assessment.readinessScore)))")
            return false
        }
    }
    
    /// Create appropriate ViewModel based on migration status
    public func createViewModel(
        fileAccess: SecureFileAccess,
        performanceSettings: ModernPerformanceSettingsManager,
        slideshowSettings: ModernSlideshowSettingsManager,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService
    ) async -> any SlideshowViewModelProtocol {
        
        let useRepositoryPattern = await shouldUseRepositoryPattern()
        
        let viewModel = await ViewModelFactory.createSlideshowViewModel(
            fileAccess: fileAccess,
            performanceSettings: performanceSettings,
            slideshowSettings: slideshowSettings,
            sortSettings: sortSettings,
            localizationService: localizationService,
            preferRepositoryPattern: useRepositoryPattern
        )
        
        // Update migration status based on result
        if viewModel is EnhancedModernSlideshowViewModel {
            migrationStatus = .completed
            ProductionLogger.info("RepositoryMigrationBridge: Using Repository-based ViewModel")
        } else {
            migrationStatus = .usingLegacy
            ProductionLogger.info("RepositoryMigrationBridge: Using Legacy ViewModel")
        }
        
        return viewModel
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() async {
        ProductionLogger.info("RepositoryMigrationBridge: Starting health monitoring")
        
        // Monitor repository health periodically
        Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                await self.updateHealthStatus()
            }
        }
        
        // Initial health check
        await updateHealthStatus()
    }
    
    private func updateHealthStatus() async {
        let readiness = await ViewModelFactory.checkRepositoryReadiness()
        repositoryHealth = readiness.healthStatus
        
        // Log significant health changes
        if let health = repositoryHealth {
            if !health.isHealthy && migrationStatus == .completed {
                ProductionLogger.warning("RepositoryMigrationBridge: Repository health degraded: \(health.issues)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func identifyPotentialIssues() async -> [MigrationIssue] {
        var issues: [MigrationIssue] = []
        
        // Check memory availability
        let memoryInfo = ProcessInfo.processInfo.physicalMemory
        if memoryInfo < 4_000_000_000 { // Less than 4GB
            issues.append(.lowMemory(availableGB: Int(memoryInfo / 1_000_000_000)))
        }
        
        // Check storage space
        if let homeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let resources = try homeURL.resourceValues(forKeys: [URLResourceKey.volumeAvailableCapacityKey])
                if let capacity = resources.volumeAvailableCapacity, capacity < 1_000_000_000 { // Less than 1GB
                    issues.append(.lowDiskSpace(availableGB: Int(capacity / 1_000_000_000)))
                }
            } catch {
                issues.append(.storageCheckFailed)
            }
        }
        
        // Check for concurrent image processing capacity
        let processorCount = ProcessInfo.processInfo.processorCount
        if processorCount < 4 {
            issues.append(.limitedProcessingPower(cores: processorCount))
        }
        
        return issues
    }
    
    private func calculateReadinessScore(_ assessment: MigrationAssessment) -> Double {
        var score: Double = 0.0
        
        // Repository health (40% weight)
        if assessment.repositoryReady {
            score += 0.4
        }
        
        // Performance data availability (20% weight)
        if assessment.hasPerformanceData {
            score += 0.2
        }
        
        // Issue penalty (up to -30%)
        let issuePenalty = min(0.3, Double(assessment.potentialIssues.count) * 0.1)
        score -= issuePenalty
        
        // Baseline readiness (30% weight)
        score += 0.3
        
        return max(0.0, min(1.0, score))
    }
    
    private func performMigrationSteps() async -> Bool {
        ProductionLogger.info("RepositoryMigrationBridge: Performing migration steps")
        
        // Step 1: Initialize Repository container
        migrationProgress = 0.2
        let container = RepositoryContainer.shared
        let health = await container.performHealthCheck()
        
        guard health.isHealthy else {
            ProductionLogger.error("RepositoryMigrationBridge: Repository container unhealthy")
            return false
        }
        
        // Step 2: Verify Repository implementations
        migrationProgress = 0.4
        let _ = await container.imageRepository()
        let _ = await container.cacheRepository()
        let _ = await container.metadataRepository()
        let _ = await container.settingsRepository()
        
        // Step 3: Test basic operations
        migrationProgress = 0.6
        // Basic smoke tests would go here
        
        // Step 4: Enable Repository pattern
        migrationProgress = 0.8
        enableRepositoryPattern = true
        
        // Step 5: Complete
        migrationProgress = 1.0
        ProductionLogger.info("RepositoryMigrationBridge: Migration steps completed successfully")
        return true
    }
}

// MARK: - Supporting Types

public enum MigrationStatus: String, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case failed = "Failed"
    case usingLegacy = "Using Legacy"
}

public struct MigrationAssessment {
    public var repositoryReady: Bool = false
    public var repositoryHealth: RepositoryHealthStatus?
    public var repositoryMetrics: [String: RepositoryMetrics] = [:]
    public var hasPerformanceData: Bool = false
    public var potentialIssues: [MigrationIssue] = []
    public var readinessScore: Double = 0.0
    public var recommendMigration: Bool = false
}

public enum MigrationIssue: Equatable {
    case lowMemory(availableGB: Int)
    case lowDiskSpace(availableGB: Int)
    case limitedProcessingPower(cores: Int)
    case storageCheckFailed
    case repositoryInitializationFailed
    
    public var description: String {
        switch self {
        case .lowMemory(let gb):
            return "Low memory: \(gb)GB available"
        case .lowDiskSpace(let gb):
            return "Low disk space: \(gb)GB available"
        case .limitedProcessingPower(let cores):
            return "Limited processing power: \(cores) cores"
        case .storageCheckFailed:
            return "Could not check storage availability"
        case .repositoryInitializationFailed:
            return "Repository initialization failed"
        }
    }
    
    public var severity: IssueSeverity {
        switch self {
        case .lowMemory(let gb) where gb < 2:
            return .high
        case .lowDiskSpace(let gb) where gb < 1:
            return .high
        case .limitedProcessingPower(let cores) where cores < 2:
            return .medium
        default:
            return .low
        }
    }
}

public enum IssueSeverity {
    case low, medium, high
}