//
//  UnifiedImageRepository.swift
//  Swift Photos
//
//  Unified image repository interface consolidating SlideshowRepository and ImageRepositoryProtocol
//  Phase 4.1a: Repository Layer Consolidation - Unified Architecture
//

import Foundation
import AppKit

// MARK: - Unified Image Repository Protocol

/// Unified interface for all image-related repository operations
/// Consolidates SlideshowRepository and ImageRepositoryProtocol into single coherent interface
public protocol UnifiedImageRepository: Sendable {
    
    // MARK: - Core Image Operations
    
    /// Load photos from a directory or source
    func loadPhotos(from source: ImageSource, options: LoadOptions) async throws -> [Photo]
    
    /// Load a specific image with caching and quality control
    func loadImage(for photo: Photo, quality: ImageQuality, options: LoadOptions) async throws -> Photo
    
    /// Load image metadata
    func loadMetadata(for photo: Photo, options: MetadataOptions) async throws -> ImageMetadata
    
    // MARK: - Bulk Operations
    
    /// Load multiple images efficiently
    func loadImages(for photos: [Photo], quality: ImageQuality, options: LoadOptions) async throws -> [Photo]
    
    /// Load metadata for multiple photos
    func loadMetadata(for photos: [Photo], options: MetadataOptions) async throws -> [URL: ImageMetadata]
    
    // MARK: - Search and Discovery
    
    /// Search for images matching criteria
    func searchImages(in source: ImageSource, criteria: SearchCriteria, options: LoadOptions) async throws -> [Photo]
    
    /// Get all supported image formats
    var supportedFormats: Set<String> { get }
    
    // MARK: - Performance and Statistics
    
    /// Get repository performance metrics
    func getMetrics() async -> RepositoryMetrics
    
    /// Clear caches and reset state
    func clearCache() async
}

// MARK: - Unified Cache Repository Protocol

/// Simplified unified cache interface
public protocol UnifiedCacheRepository: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    /// Basic cache operations
    func get(_ key: Key) async -> Value?
    func set(_ value: Value, for key: Key, cost: Int?) async
    func remove(_ key: Key) async
    func removeAll() async
    
    /// Batch operations
    func getMultiple(_ keys: [Key]) async -> [Key: Value]
    func setMultiple(_ items: [(key: Key, value: Value, cost: Int?)]) async
    
    /// Cache information
    func statistics() async -> CacheStatistics
    func contains(_ key: Key) async -> Bool
}

// MARK: - Specialized Image Cache

/// Specialized image cache with quality and priority support
public protocol ImageCacheRepository: UnifiedCacheRepository where Key == ImageCacheKey, Value == SendableImage {
    
    /// Priority-based caching for slideshow optimization
    func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async
    
    /// Quality-specific caching
    func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async
    func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage?
    
    /// Thumbnail caching
    func cacheThumbnail(_ image: SendableImage, for key: ImageCacheKey, size: CGSize) async
    func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage?
    
    /// Preloading for performance
    func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async
    
    /// Memory management
    func performCleanup(targetReduction: Double) async
}

// MARK: - Unified Data Types

/// Unified image source specification
public enum ImageSource: Sendable {
    case directory(URL)
    case urls([URL])
    case photos([Photo])
    case search(in: URL, criteria: SearchCriteria)
    
    /// Get the primary URL for this source
    public var primaryURL: URL? {
        switch self {
        case .directory(let url):
            return url
        case .urls(let urls):
            return urls.first
        case .photos(let photos):
            return photos.first?.imageURL.url
        case .search(let url, _):
            return url
        }
    }
}

/// Unified load options
public struct LoadOptions: Sendable {
    public let timeout: TimeInterval?
    public let cachePolicy: CachePolicy
    public let concurrent: Bool
    public let maxConcurrency: Int?
    public let sortOrder: SortOrder?
    
    public init(
        timeout: TimeInterval? = nil,
        cachePolicy: CachePolicy = .ifAvailable,
        concurrent: Bool = true,
        maxConcurrency: Int? = nil,
        sortOrder: SortOrder? = nil
    ) {
        self.timeout = timeout
        self.cachePolicy = cachePolicy
        self.concurrent = concurrent
        self.maxConcurrency = maxConcurrency
        self.sortOrder = sortOrder
    }
    
    /// Default loading options
    public static let `default` = LoadOptions()
    
    /// High performance options
    public static let highPerformance = LoadOptions(
        cachePolicy: CachePolicy.always,
        concurrent: true,
        maxConcurrency: 10
    )
    
    /// Memory optimized options
    public static let memoryOptimized = LoadOptions(
        cachePolicy: CachePolicy.never,
        concurrent: false
    )
}

/// Unified metadata options
public struct MetadataOptions: Sendable {
    public let includeEXIF: Bool
    public let includeIPTC: Bool
    public let includeXMP: Bool
    public let includeColorProfile: Bool
    public let cacheResult: Bool
    public let timeout: TimeInterval?
    
    public init(
        includeEXIF: Bool = true,
        includeIPTC: Bool = false,
        includeXMP: Bool = false,
        includeColorProfile: Bool = false,
        cacheResult: Bool = true,
        timeout: TimeInterval? = nil
    ) {
        self.includeEXIF = includeEXIF
        self.includeIPTC = includeIPTC
        self.includeXMP = includeXMP
        self.includeColorProfile = includeColorProfile
        self.cacheResult = cacheResult
        self.timeout = timeout
    }
    
    /// Default metadata extraction
    public static let `default` = MetadataOptions()
    
    /// Fast metadata extraction (EXIF only)
    public static let fast = MetadataOptions(
        includeEXIF: true,
        includeIPTC: false,
        includeXMP: false,
        timeout: 5.0
    )
    
    /// Complete metadata extraction
    public static let complete = MetadataOptions(
        includeEXIF: true,
        includeIPTC: true,
        includeXMP: true,
        includeColorProfile: true,
        timeout: 30.0
    )
}

/// Simplified sort order
public enum SortOrder: Sendable {
    case fileName(ascending: Bool)
    case creationDate(ascending: Bool)
    case modificationDate(ascending: Bool)
    case fileSize(ascending: Bool)
    case random(seed: Int?)
    
    /// Default sort order
    public static let `default` = SortOrder.fileName(ascending: true)
}

/// Unified error handling
public enum UnifiedRepositoryError: LocalizedError, Sendable {
    case sourceNotFound(ImageSource)
    case loadingFailed(Photo, underlying: Error)
    case metadataExtractionFailed(URL, underlying: Error)
    case searchFailed(SearchCriteria, underlying: Error)
    case cacheError(underlying: Error)
    case timeout(operation: String, duration: TimeInterval)
    case unsupportedFormat(String)
    case accessDenied(URL)
    case operationCancelled
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let source):
            return "Image source not found: \(source.primaryURL?.path ?? "unknown")"
        case .loadingFailed(let photo, _):
            return "Failed to load image: \(photo.imageURL.url.lastPathComponent)"
        case .metadataExtractionFailed(let url, _):
            return "Failed to extract metadata: \(url.lastPathComponent)"
        case .searchFailed(_, _):
            return "Image search failed"
        case .cacheError(_):
            return "Cache operation failed"
        case .timeout(let operation, let duration):
            return "Operation '\(operation)' timed out after \(duration) seconds"
        case .unsupportedFormat(let format):
            return "Unsupported image format: \(format)"
        case .accessDenied(let url):
            return "Access denied to: \(url.path)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknown(_):
            return "Unknown repository error occurred"
        }
    }
}

// Note: RepositoryMetrics is defined in RepositoryTypes.swift

// Note: CachePolicy is defined in RepositoryTypes.swift

// Note: ImageCacheKey is defined in CacheRepositoryProtocol.swift

// Note: ImageQuality is defined in CacheRepositoryProtocol.swift

// Note: CachePriority and CacheStatistics are defined in existing repository protocols

// MARK: - Repository Extensions for Convenience

public extension UnifiedImageRepository {
    
    /// Load photos from a directory URL
    func loadPhotos(from directory: URL) async throws -> [Photo] {
        try await loadPhotos(from: .directory(directory), options: .default)
    }
    
    /// Load image with default options
    func loadImage(for photo: Photo) async throws -> Photo {
        try await loadImage(for: photo, quality: ImageQuality.full, options: LoadOptions.default)
    }
    
    /// Load metadata with default options
    func loadMetadata(for photo: Photo) async throws -> ImageMetadata {
        try await loadMetadata(for: photo, options: MetadataOptions.default)
    }
}