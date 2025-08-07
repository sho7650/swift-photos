import Foundation
import AppKit

/// 画像データへのアクセスを抽象化するプロトコル
public protocol ImageRepositoryProtocol: Sendable {
    /// 指定されたURLから画像を読み込む
    func loadImage(from url: URL) async throws -> SendableImage
    
    /// 指定されたフォルダから画像URLのリストを取得
    func loadImageURLs(from folder: URL) async throws -> [ImageURL]
    
    /// 画像のメタデータを読み込む
    func loadMetadata(for url: URL) async throws -> ImageMetadata
    
    /// 画像のサムネイルを生成
    func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage
    
    /// 指定された条件で画像を検索
    func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL]
    
    /// 対応している画像フォーマットを取得
    var supportedImageFormats: Set<String> { get }
}

/// 画像検索条件
public struct SearchCriteria: Sendable, Equatable {
    public let fileName: String?
    public let dateRange: DateRange?
    public let sizeRange: SizeRange?
    public let fileTypes: Set<String>?
    
    public init(
        fileName: String? = nil,
        dateRange: DateRange? = nil,
        sizeRange: SizeRange? = nil,
        fileTypes: Set<String>? = nil
    ) {
        self.fileName = fileName
        self.dateRange = dateRange
        self.sizeRange = sizeRange
        self.fileTypes = fileTypes
    }
    
    public struct DateRange: Sendable, Equatable {
        public let start: Date
        public let end: Date
        
        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }
    
    public struct SizeRange: Sendable, Equatable {
        public let minSize: Int64
        public let maxSize: Int64
        
        public init(minSize: Int64, maxSize: Int64) {
            self.minSize = minSize
            self.maxSize = maxSize
        }
    }
}

/// 統合メタデータ構造体
public struct ImageMetadata: Sendable, Codable, Equatable {
    public let fileInfo: FileInfo
    public let imageInfo: ImageInfo
    public let exifData: EXIFData?
    public let iptcData: IPTCData?
    public let xmpData: XMPData?
    public let colorProfile: ColorProfile?
    
    public init(
        fileInfo: FileInfo,
        imageInfo: ImageInfo,
        exifData: EXIFData? = nil,
        iptcData: IPTCData? = nil,
        xmpData: XMPData? = nil,
        colorProfile: ColorProfile? = nil
    ) {
        self.fileInfo = fileInfo
        self.imageInfo = imageInfo
        self.exifData = exifData
        self.iptcData = iptcData
        self.xmpData = xmpData
        self.colorProfile = colorProfile
    }
    
    public struct FileInfo: Sendable, Codable, Equatable {
        public let size: Int64
        public let createdDate: Date
        public let modifiedDate: Date
        public let fileName: String
        public let fileExtension: String
        
        public init(
            size: Int64,
            createdDate: Date,
            modifiedDate: Date,
            fileName: String,
            fileExtension: String
        ) {
            self.size = size
            self.createdDate = createdDate
            self.modifiedDate = modifiedDate
            self.fileName = fileName
            self.fileExtension = fileExtension
        }
    }
    
    public struct ImageInfo: Sendable, Codable, Equatable {
        public let width: Int
        public let height: Int
        public let colorSpace: String?
        public let bitDepth: Int?
        public let hasAlpha: Bool
        
        public init(
            width: Int,
            height: Int,
            colorSpace: String? = nil,
            bitDepth: Int? = nil,
            hasAlpha: Bool = false
        ) {
            self.width = width
            self.height = height
            self.colorSpace = colorSpace
            self.bitDepth = bitDepth
            self.hasAlpha = hasAlpha
        }
    }
}

/// EXIF データ構造体
public struct EXIFData: Sendable, Codable, Equatable {
    public let cameraModel: String?
    public let dateTaken: Date?
    public let gpsLocation: GPSLocation?
    public let exposureSettings: ExposureSettings?
    public let rawData: [String: String]
    
    public init(
        cameraModel: String? = nil,
        dateTaken: Date? = nil,
        gpsLocation: GPSLocation? = nil,
        exposureSettings: ExposureSettings? = nil,
        rawData: [String: String] = [:]
    ) {
        self.cameraModel = cameraModel
        self.dateTaken = dateTaken
        self.gpsLocation = gpsLocation
        self.exposureSettings = exposureSettings
        self.rawData = rawData
    }
    
    public struct GPSLocation: Sendable, Codable, Equatable {
        public let latitude: Double
        public let longitude: Double
        public let altitude: Double?
        
        public init(latitude: Double, longitude: Double, altitude: Double? = nil) {
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
        }
    }
    
    public struct ExposureSettings: Sendable, Codable, Equatable {
        public let aperture: String?
        public let shutterSpeed: String?
        public let iso: Int?
        public let focalLength: String?
        
        public init(
            aperture: String? = nil,
            shutterSpeed: String? = nil,
            iso: Int? = nil,
            focalLength: String? = nil
        ) {
            self.aperture = aperture
            self.shutterSpeed = shutterSpeed
            self.iso = iso
            self.focalLength = focalLength
        }
    }
}

/// IPTC データ構造体
public struct IPTCData: Sendable, Codable, Equatable {
    public let title: String?
    public let description: String?
    public let keywords: [String]
    public let copyright: String?
    public let creator: String?
    
    public init(
        title: String? = nil,
        description: String? = nil,
        keywords: [String] = [],
        copyright: String? = nil,
        creator: String? = nil
    ) {
        self.title = title
        self.description = description
        self.keywords = keywords
        self.copyright = copyright
        self.creator = creator
    }
}

/// XMP データ構造体
public struct XMPData: Sendable, Codable, Equatable {
    public let rating: Int?
    public let label: String?
    public let customProperties: [String: String]
    
    public init(
        rating: Int? = nil,
        label: String? = nil,
        customProperties: [String: String] = [:]
    ) {
        self.rating = rating
        self.label = label
        self.customProperties = customProperties
    }
}

/// カラープロファイル情報
public struct ColorProfile: Sendable, Codable, Equatable {
    public let name: String
    public let type: ColorProfileType
    public let description: String?
    
    public init(name: String, type: ColorProfileType, description: String? = nil) {
        self.name = name
        self.type = type
        self.description = description
    }
    
    public enum ColorProfileType: String, Sendable, Codable, CaseIterable {
        case sRGB = "sRGB"
        case adobeRGB = "Adobe RGB"
        case displayP3 = "Display P3"
        case rec2020 = "Rec. 2020"
        case other = "Other"
    }
}