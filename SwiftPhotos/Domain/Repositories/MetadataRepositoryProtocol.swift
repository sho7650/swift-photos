import Foundation

/// 画像メタデータへのアクセスを抽象化するプロトコル
public protocol MetadataRepositoryProtocol: Sendable {
    /// EXIFデータを読み込む
    func loadEXIFData(for url: URL) async throws -> EXIFData
    
    /// IPTCデータを読み込む
    func loadIPTCData(for url: URL) async throws -> IPTCData
    
    /// XMPデータを読み込む
    func loadXMPData(for url: URL) async throws -> XMPData
    
    /// すべてのメタデータを統合して読み込む
    func loadAllMetadata(for url: URL) async throws -> ImageMetadata
    
    /// 複数の画像のメタデータを一括読み込み
    func loadAllMetadata(for urls: [URL]) async throws -> [URL: ImageMetadata]
    
    /// メタデータを更新（非破壊的）
    func updateMetadata(_ metadata: ImageMetadata, for url: URL) async throws
    
    /// メタデータをキャッシュ
    func cacheMetadata(_ metadata: ImageMetadata, for url: URL) async
    
    /// キャッシュからメタデータを取得
    func getCachedMetadata(for url: URL) async -> ImageMetadata?
    
    /// メタデータキャッシュをクリア
    func clearMetadataCache() async
    
    /// 対応しているメタデータ形式を取得
    var supportedMetadataFormats: Set<MetadataFormat> { get }
    
    /// メタデータ抽出のパフォーマンス統計
    func getPerformanceStatistics() async -> MetadataPerformanceStatistics
}

/// メタデータ形式の定義
public enum MetadataFormat: String, Sendable, CaseIterable {
    case exif = "EXIF"
    case iptc = "IPTC"
    case xmp = "XMP"
    case tiff = "TIFF" 
    case png = "PNG"
    case heif = "HEIF"
    case colorProfile = "ColorProfile"
    case thumbnail = "Thumbnail"
}

/// メタデータ抽出オプション
public struct MetadataExtractionOptions: Sendable {
    public let includeEXIF: Bool
    public let includeIPTC: Bool
    public let includeXMP: Bool
    public let includeColorProfile: Bool
    public let includeThumbnail: Bool
    public let cacheResult: Bool
    public let timeoutInterval: TimeInterval
    
    public init(
        includeEXIF: Bool = true,
        includeIPTC: Bool = true,
        includeXMP: Bool = true,
        includeColorProfile: Bool = true,
        includeThumbnail: Bool = false,
        cacheResult: Bool = true,
        timeoutInterval: TimeInterval = 30.0
    ) {
        self.includeEXIF = includeEXIF
        self.includeIPTC = includeIPTC
        self.includeXMP = includeXMP
        self.includeColorProfile = includeColorProfile
        self.includeThumbnail = includeThumbnail
        self.cacheResult = cacheResult
        self.timeoutInterval = timeoutInterval
    }
    
    /// デフォルト設定
    public static let `default` = MetadataExtractionOptions()
    
    /// 高速設定（最小限のメタデータのみ）
    public static let fast = MetadataExtractionOptions(
        includeEXIF: true,
        includeIPTC: false,
        includeXMP: false,
        includeColorProfile: false,
        timeoutInterval: 5.0
    )
    
    /// 完全設定（すべてのメタデータを含む）
    public static let complete = MetadataExtractionOptions(
        includeEXIF: true,
        includeIPTC: true,
        includeXMP: true,
        includeColorProfile: true,
        includeThumbnail: true,
        timeoutInterval: 60.0
    )
}

/// メタデータパフォーマンス統計
public struct MetadataPerformanceStatistics: Sendable, Equatable {
    public var totalExtractions: Int
    public var successfulExtractions: Int
    public var failedExtractions: Int
    public var averageExtractionTime: TimeInterval
    public var cacheHitCount: Int
    public var cacheMissCount: Int
    
    public init(
        totalExtractions: Int,
        successfulExtractions: Int,
        failedExtractions: Int,
        averageExtractionTime: TimeInterval,
        cacheHitCount: Int,
        cacheMissCount: Int
    ) {
        self.totalExtractions = totalExtractions
        self.successfulExtractions = successfulExtractions
        self.failedExtractions = failedExtractions
        self.averageExtractionTime = averageExtractionTime
        self.cacheHitCount = cacheHitCount
        self.cacheMissCount = cacheMissCount
    }
    
    /// 成功率
    public var successRate: Double {
        guard totalExtractions > 0 else { return 0.0 }
        return Double(successfulExtractions) / Double(totalExtractions)
    }
    
    /// キャッシュヒット率
    public var cacheHitRate: Double {
        let totalCacheRequests = cacheHitCount + cacheMissCount
        guard totalCacheRequests > 0 else { return 0.0 }
        return Double(cacheHitCount) / Double(totalCacheRequests)
    }
    
    /// 空の統計
    public static let empty = MetadataPerformanceStatistics(
        totalExtractions: 0,
        successfulExtractions: 0,
        failedExtractions: 0,
        averageExtractionTime: 0.0,
        cacheHitCount: 0,
        cacheMissCount: 0
    )
}

/// メタデータ抽出エラー
public enum MetadataError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case fileNotReadable(URL)
    case unsupportedFormat(String)
    case corruptedMetadata(URL, underlying: Error?)
    case extractionTimeout(URL, TimeInterval)
    case insufficientPermissions(URL)
    case networkError(underlying: Error)
    case cacheError(underlying: Error)
    case validationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileNotReadable(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .corruptedMetadata(let url, _):
            return "Corrupted metadata in file: \(url.lastPathComponent)"
        case .extractionTimeout(let url, let timeout):
            return "Metadata extraction timeout (\(timeout)s) for: \(url.lastPathComponent)"
        case .insufficientPermissions(let url):
            return "Insufficient permissions to access: \(url.lastPathComponent)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .fileNotFound:
            return "The specified file does not exist"
        case .fileNotReadable:
            return "The file cannot be read due to format or permission issues"
        case .unsupportedFormat:
            return "The file format is not supported for metadata extraction"
        case .corruptedMetadata:
            return "The metadata in the file is corrupted or invalid"
        case .extractionTimeout:
            return "The metadata extraction process took too long"
        case .insufficientPermissions:
            return "The application does not have permission to read the file"
        case .networkError:
            return "A network error occurred while accessing remote metadata"
        case .cacheError:
            return "An error occurred while accessing the metadata cache"
        case .validationError:
            return "The metadata failed validation checks"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Verify the file path and ensure the file exists"
        case .fileNotReadable:
            return "Check file permissions and format compatibility"
        case .unsupportedFormat:
            return "Convert the file to a supported format"
        case .corruptedMetadata:
            return "Try using a different metadata extraction tool"
        case .extractionTimeout:
            return "Increase the timeout interval or try again later"
        case .insufficientPermissions:
            return "Grant the necessary file access permissions"
        case .networkError:
            return "Check your network connection and try again"
        case .cacheError:
            return "Clear the metadata cache and try again"
        case .validationError:
            return "Review and correct the metadata values"
        }
    }
}

/// メタデータ検証プロトコル
public protocol MetadataValidator: Sendable {
    /// メタデータの整合性を検証
    func validate(_ metadata: ImageMetadata) async throws -> MetadataValidationResult
    
    /// 特定のメタデータフィールドを検証
    func validateField(_ field: MetadataField, value: Any) async throws -> FieldValidationResult
}

/// メタデータ検証結果
public struct MetadataValidationResult: Sendable, Equatable {
    public let isValid: Bool
    public let warnings: [ValidationWarning]
    public let errors: [ValidationError]
    
    public init(isValid: Bool, warnings: [ValidationWarning] = [], errors: [ValidationError] = []) {
        self.isValid = isValid
        self.warnings = warnings
        self.errors = errors
    }
    
    /// 成功した検証結果
    public static let success = MetadataValidationResult(isValid: true)
}

/// フィールド検証結果
public struct FieldValidationResult: Sendable, Equatable {
    public let field: MetadataField
    public let isValid: Bool
    public let message: String?
    
    public init(field: MetadataField, isValid: Bool, message: String? = nil) {
        self.field = field
        self.isValid = isValid
        self.message = message
    }
}

/// メタデータフィールド定義
public enum MetadataField: String, Sendable, CaseIterable {
    case fileName = "fileName"
    case fileSize = "fileSize"
    case imageWidth = "imageWidth"
    case imageHeight = "imageHeight"
    case colorSpace = "colorSpace"
    case cameraModel = "cameraModel"
    case dateTaken = "dateTaken"
    case gpsLatitude = "gpsLatitude"
    case gpsLongitude = "gpsLongitude"
    case aperture = "aperture"
    case shutterSpeed = "shutterSpeed"
    case iso = "iso"
    case focalLength = "focalLength"
    case title = "title"
    case description = "description"
    case keywords = "keywords"
    case copyright = "copyright"
    case creator = "creator"
    case rating = "rating"
    case label = "label"
    
    /// フィールドの表示名
    public var displayName: String {
        switch self {
        case .fileName: return "File Name"
        case .fileSize: return "File Size"
        case .imageWidth: return "Image Width"
        case .imageHeight: return "Image Height"
        case .colorSpace: return "Color Space"
        case .cameraModel: return "Camera Model"
        case .dateTaken: return "Date Taken"
        case .gpsLatitude: return "GPS Latitude"
        case .gpsLongitude: return "GPS Longitude"
        case .aperture: return "Aperture"
        case .shutterSpeed: return "Shutter Speed"
        case .iso: return "ISO"
        case .focalLength: return "Focal Length"
        case .title: return "Title"
        case .description: return "Description"
        case .keywords: return "Keywords"
        case .copyright: return "Copyright"
        case .creator: return "Creator"
        case .rating: return "Rating"
        case .label: return "Label"
        }
    }
    
    /// フィールドのカテゴリ
    public var category: MetadataCategory {
        switch self {
        case .fileName, .fileSize:
            return .file
        case .imageWidth, .imageHeight, .colorSpace:
            return .image
        case .cameraModel, .dateTaken, .aperture, .shutterSpeed, .iso, .focalLength:
            return .camera
        case .gpsLatitude, .gpsLongitude:
            return .location
        case .title, .description, .keywords, .copyright, .creator:
            return .descriptive
        case .rating, .label:
            return .organizational
        }
    }
}

/// メタデータカテゴリ
public enum MetadataCategory: String, Sendable, CaseIterable {
    case file = "File"
    case image = "Image"
    case camera = "Camera"
    case location = "Location"
    case descriptive = "Descriptive"
    case organizational = "Organizational"
    
    /// カテゴリの表示名
    public var displayName: String {
        switch self {
        case .file: return "File Information"
        case .image: return "Image Properties"
        case .camera: return "Camera Settings"
        case .location: return "Location Data"
        case .descriptive: return "Descriptive Data"
        case .organizational: return "Organization"
        }
    }
}

/// 検証警告
public struct ValidationWarning: Sendable, Equatable {
    public let field: MetadataField
    public let message: String
    
    public init(field: MetadataField, message: String) {
        self.field = field
        self.message = message
    }
}

/// 検証エラー
public struct ValidationError: Sendable, Equatable {
    public let field: MetadataField
    public let message: String
    
    public init(field: MetadataField, message: String) {
        self.field = field
        self.message = message
    }
}