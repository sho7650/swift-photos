import Foundation

/// Factory for creating appropriate ImageRepository implementations
/// Handles migration between legacy and new repository implementations
public actor ImageRepositoryFactory {
    
    // MARK: - Configuration
    public enum RepositoryType: String, Sendable, CaseIterable {
        case legacy = "legacy"           // Use legacy FileSystemPhotoRepository via adapter
        case modern = "modern"           // Use new LocalImageRepository
        case automatic = "automatic"     // Automatically choose based on availability
    }
    
    public struct FactoryConfiguration: Sendable {
        public let repositoryType: RepositoryType
        public let enablePerformanceMonitoring: Bool
        public let enableCaching: Bool
        public let fallbackToLegacy: Bool
        
        public init(
            repositoryType: RepositoryType = .automatic,
            enablePerformanceMonitoring: Bool = true,
            enableCaching: Bool = true,
            fallbackToLegacy: Bool = true
        ) {
            self.repositoryType = repositoryType
            self.enablePerformanceMonitoring = enablePerformanceMonitoring
            self.enableCaching = enableCaching
            self.fallbackToLegacy = fallbackToLegacy
        }
        
        public static let `default` = FactoryConfiguration()
    }
    
    // MARK: - Properties
    private let configuration: FactoryConfiguration
    private let repositoryContainer: RepositoryContainer
    
    // Legacy dependencies (injected when available)
    private let legacyRepository: FileSystemPhotoRepository?
    private let metadataRepository: (any MetadataRepositoryProtocol)?
    
    // MARK: - Initialization
    public init(
        configuration: FactoryConfiguration = .default,
        repositoryContainer: RepositoryContainer = .shared,
        legacyRepository: FileSystemPhotoRepository? = nil,
        metadataRepository: (any MetadataRepositoryProtocol)? = nil
    ) {
        self.configuration = configuration
        self.repositoryContainer = repositoryContainer
        self.legacyRepository = legacyRepository
        self.metadataRepository = metadataRepository
        
        ProductionLogger.info("ImageRepositoryFactory: Initialized with type \(configuration.repositoryType.rawValue)")
    }
    
    // MARK: - Factory Methods
    
    /// Create an ImageRepository based on configuration
    public func createImageRepository() async throws -> any ImageRepositoryProtocol {
        switch configuration.repositoryType {
        case .legacy:
            return try await createLegacyRepository()
            
        case .modern:
            return try await createModernRepository()
            
        case .automatic:
            return try await createAutomaticRepository()
        }
    }
    
    /// Create a legacy repository via adapter
    private func createLegacyRepository() async throws -> any ImageRepositoryProtocol {
        ProductionLogger.debug("ImageRepositoryFactory: Creating legacy repository")
        
        guard let legacyRepo = legacyRepository else {
            if configuration.fallbackToLegacy {
                ProductionLogger.warning("ImageRepositoryFactory: Legacy repository not available, falling back to modern")
                return try await createModernRepository()
            } else {
                throw FactoryError.legacyRepositoryNotAvailable
            }
        }
        
        let metadataRepo: any MetadataRepositoryProtocol
        if let providedRepo = metadataRepository {
            metadataRepo = providedRepo
        } else {
            metadataRepo = await repositoryContainer.metadataRepository()
        }
        
        let adapter = FileSystemPhotoRepositoryAdapter(
            legacyRepository: legacyRepo,
            metadataRepository: metadataRepo
        )
        
        ProductionLogger.info("ImageRepositoryFactory: Created legacy repository adapter")
        return adapter
    }
    
    /// Create a modern repository
    private func createModernRepository() async throws -> any ImageRepositoryProtocol {
        ProductionLogger.debug("ImageRepositoryFactory: Creating modern repository")
        
        let repository = await repositoryContainer.imageRepository()
        
        ProductionLogger.info("ImageRepositoryFactory: Created modern repository")
        return repository
    }
    
    /// Automatically choose the best repository
    private func createAutomaticRepository() async throws -> any ImageRepositoryProtocol {
        ProductionLogger.debug("ImageRepositoryFactory: Automatically selecting repository")
        
        // Prefer modern repository if available and functional
        do {
            let modernRepo = try await createModernRepository()
            
            // Test the modern repository with a simple operation
            if await isRepositoryHealthy(modernRepo) {
                ProductionLogger.info("ImageRepositoryFactory: Selected modern repository (healthy)")
                return modernRepo
            } else {
                ProductionLogger.warning("ImageRepositoryFactory: Modern repository unhealthy, trying legacy")
            }
        } catch {
            ProductionLogger.warning("ImageRepositoryFactory: Failed to create modern repository: \(error)")
        }
        
        // Fallback to legacy repository
        if legacyRepository != nil {
            do {
                let legacyRepo = try await createLegacyRepository()
                ProductionLogger.info("ImageRepositoryFactory: Selected legacy repository (fallback)")
                return legacyRepo
            } catch {
                ProductionLogger.error("ImageRepositoryFactory: Failed to create legacy repository: \(error)")
            }
        }
        
        // If all else fails, throw an error
        throw FactoryError.noRepositoryAvailable
    }
    
    // MARK: - Health Checks
    
    /// Check if a repository is healthy and functional
    private func isRepositoryHealthy(_ repository: any ImageRepositoryProtocol) async -> Bool {
        // For now, just check if the repository supports basic formats
        let hasBasicFormats = !repository.supportedImageFormats.intersection(["jpg", "png"]).isEmpty
        return hasBasicFormats
    }
    
    // MARK: - Repository Information
    
    /// Get information about available repository types
    public func getAvailableRepositoryTypes() async -> [RepositoryType] {
        var availableTypes: [RepositoryType] = [.modern] // Modern is always available via container
        
        if legacyRepository != nil {
            availableTypes.append(.legacy)
        }
        
        availableTypes.append(.automatic) // Automatic is always available
        
        return availableTypes
    }
    
    /// Get repository capabilities
    public func getRepositoryCapabilities(for type: RepositoryType) async -> RepositoryCapabilities {
        switch type {
        case .legacy:
            return RepositoryCapabilities(
                supportedFormats: ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp"],
                supportsMetadata: true,
                supportsThumbnails: true,
                supportsSearch: true,
                supportsAdvancedSorting: true,
                performanceLevel: .good
            )
            
        case .modern:
            return RepositoryCapabilities(
                supportedFormats: ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp", "webp"],
                supportsMetadata: true,
                supportsThumbnails: true,
                supportsSearch: true,
                supportsAdvancedSorting: false, // Would be handled by separate service
                performanceLevel: .excellent
            )
            
        case .automatic:
            // Return combined capabilities
            return RepositoryCapabilities(
                supportedFormats: ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp", "webp"],
                supportsMetadata: true,
                supportsThumbnails: true,
                supportsSearch: true,
                supportsAdvancedSorting: true,
                performanceLevel: .excellent
            )
        }
    }
    
    // MARK: - Migration Support
    
    /// Check if migration from legacy to modern repository is recommended
    public func shouldMigrateToModern() async -> Bool {
        // Migration is recommended if:
        // 1. Currently using legacy repository
        // 2. Modern repository is available and healthy
        // 3. Performance monitoring shows benefits
        
        guard configuration.repositoryType == .legacy else {
            return false // Already using modern or automatic
        }
        
        // Check if modern repository is healthy
        let modernRepo = await repositoryContainer.imageRepository()
        return await isRepositoryHealthy(modernRepo)
    }
    
    /// Perform migration validation
    public func validateMigration() async -> MigrationValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check modern repository availability
        let modernRepo = await repositoryContainer.imageRepository()
        let isHealthy = await isRepositoryHealthy(modernRepo)
        
        if !isHealthy {
            issues.append("Modern repository is not healthy")
        }
        
        // Check legacy repository if required
        if configuration.repositoryType == .legacy && legacyRepository == nil {
            issues.append("Legacy repository is not available but required")
        }
        
        // Performance considerations
        if !configuration.enablePerformanceMonitoring {
            warnings.append("Performance monitoring is disabled")
        }
        
        return MigrationValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
}

// MARK: - Supporting Types

/// Repository capabilities description
public struct RepositoryCapabilities: Sendable {
    public let supportedFormats: [String]
    public let supportsMetadata: Bool
    public let supportsThumbnails: Bool
    public let supportsSearch: Bool
    public let supportsAdvancedSorting: Bool
    public let performanceLevel: PerformanceLevel
    
    public enum PerformanceLevel: String, Sendable {
        case basic = "basic"
        case good = "good"
        case excellent = "excellent"
    }
}

/// Migration validation result
public struct MigrationValidationResult: Sendable {
    public let isValid: Bool
    public let issues: [String]
    public let warnings: [String]
    
    public var hasWarnings: Bool {
        return !warnings.isEmpty
    }
}

/// Factory-specific errors
public enum FactoryError: LocalizedError, Sendable {
    case legacyRepositoryNotAvailable
    case modernRepositoryNotAvailable
    case noRepositoryAvailable
    case configurationInvalid(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .legacyRepositoryNotAvailable:
            return "Legacy repository is not available"
        case .modernRepositoryNotAvailable:
            return "Modern repository is not available"
        case .noRepositoryAvailable:
            return "No repository implementation is available"
        case .configurationInvalid(let reason):
            return "Invalid factory configuration: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .legacyRepositoryNotAvailable:
            return "Ensure legacy repository dependencies are properly injected"
        case .modernRepositoryNotAvailable:
            return "Check repository container configuration"
        case .noRepositoryAvailable:
            return "Verify that at least one repository implementation is available"
        case .configurationInvalid:
            return "Review and correct the factory configuration"
        }
    }
}

// MARK: - Convenience Extensions

extension ImageRepositoryFactory {
    
    /// Create factory with legacy repository from existing dependencies
    public static func createWithLegacySupport(
        fileAccess: SecureFileAccess,
        imageLoader: ImageLoader,
        sortSettings: ModernSortSettingsManager,
        localizationService: LocalizationService,
        configuration: FactoryConfiguration = .default
    ) async -> ImageRepositoryFactory {
        
        let legacyRepository = FileSystemPhotoRepository(
            fileAccess: fileAccess,
            imageLoader: imageLoader,
            sortSettings: sortSettings,
            localizationService: localizationService
        )
        
        let metadataRepository = await RepositoryContainer.shared.metadataRepository()
        
        return ImageRepositoryFactory(
            configuration: configuration,
            legacyRepository: legacyRepository,
            metadataRepository: metadataRepository
        )
    }
    
    /// Create factory for modern-only usage
    public static func createModernOnly() -> ImageRepositoryFactory {
        let config = FactoryConfiguration(
            repositoryType: .modern,
            fallbackToLegacy: false
        )
        
        return ImageRepositoryFactory(configuration: config)
    }
}