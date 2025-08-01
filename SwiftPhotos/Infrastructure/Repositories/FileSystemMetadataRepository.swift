import Foundation
import ImageIO
import AppKit

/// ファイルシステムからメタデータを抽出・管理するRepository
public actor FileSystemMetadataRepository: MetadataRepositoryProtocol {
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let metadataCache: NSCache<NSString, CachedMetadata>
    private let supportedFormats: Set<MetadataFormat>
    
    // MARK: - Performance Tracking
    private var statistics = MetadataPerformanceStatistics.empty
    
    // MARK: - Cache Entry
    private class CachedMetadata: NSObject {
        let metadata: ImageMetadata
        let timestamp: Date
        
        init(metadata: ImageMetadata, timestamp: Date = Date()) {
            self.metadata = metadata
            self.timestamp = timestamp
        }
    }
    
    // MARK: - Initialization
    public init(
        cacheCountLimit: Int = 1000,
        cacheTotalCostLimit: Int = 50_000_000, // 50MB
        supportedFormats: Set<MetadataFormat>? = nil
    ) {
        self.metadataCache = NSCache<NSString, CachedMetadata>()
        self.metadataCache.countLimit = cacheCountLimit
        self.metadataCache.totalCostLimit = cacheTotalCostLimit
        self.metadataCache.name = "SwiftPhotos.MetadataCache"
        
        // デフォルトでサポートするメタデータ形式
        self.supportedFormats = supportedFormats ?? [
            .exif, .iptc, .xmp, .tiff, .png, .heif, .colorProfile
        ]
    }
    
    // MARK: - MetadataRepositoryProtocol Implementation
    
    public func loadEXIFData(for url: URL) async throws -> EXIFData {
        let startTime = Date()
        statistics.totalExtractions += 1
        
        do {
            let exifData = try await extractEXIFDataFromFile(url)
            updateSuccessStatistics(startTime: startTime)
            return exifData
        } catch {
            statistics.failedExtractions += 1
            throw MetadataError.corruptedMetadata(url, underlying: error)
        }
    }
    
    public func loadIPTCData(for url: URL) async throws -> IPTCData {
        let startTime = Date()
        statistics.totalExtractions += 1
        
        do {
            let iptcData = try await extractIPTCDataFromFile(url)
            updateSuccessStatistics(startTime: startTime)
            return iptcData
        } catch {
            statistics.failedExtractions += 1
            throw MetadataError.corruptedMetadata(url, underlying: error)
        }
    }
    
    public func loadXMPData(for url: URL) async throws -> XMPData {
        let startTime = Date()
        statistics.totalExtractions += 1
        
        do {
            let xmpData = try await extractXMPDataFromFile(url)
            updateSuccessStatistics(startTime: startTime)
            return xmpData
        } catch {
            statistics.failedExtractions += 1
            throw MetadataError.corruptedMetadata(url, underlying: error)
        }
    }
    
    public func loadAllMetadata(for url: URL) async throws -> ImageMetadata {
        let cacheKey = NSString(string: url.absoluteString)
        
        // キャッシュチェック
        if let cachedEntry = metadataCache.object(forKey: cacheKey) {
            // 1時間以内のキャッシュは有効
            if Date().timeIntervalSince(cachedEntry.timestamp) < 3600 {
                statistics.cacheHitCount += 1
                return cachedEntry.metadata
            }
        }
        
        statistics.cacheMissCount += 1
        let startTime = Date()
        statistics.totalExtractions += 1
        
        do {
            // ファイル存在確認
            guard fileManager.fileExists(atPath: url.path) else {
                throw MetadataError.fileNotFound(url)
            }
            
            // ファイル情報取得
            let fileInfo = try await extractFileInfo(from: url)
            
            // 画像情報取得
            let imageInfo = try await extractImageInfo(from: url)
            
            // メタデータ抽出（エラーが発生しても続行）
            let exifData = try? await extractEXIFDataFromFile(url)
            let iptcData = try? await extractIPTCDataFromFile(url)
            let xmpData = try? await extractXMPDataFromFile(url)
            let colorProfile = try? await extractColorProfile(from: url)
            
            let metadata = ImageMetadata(
                fileInfo: fileInfo,
                imageInfo: imageInfo,
                exifData: exifData,
                iptcData: iptcData,
                xmpData: xmpData,
                colorProfile: colorProfile
            )
            
            // キャッシュに保存
            await cacheMetadata(metadata, for: url)
            
            updateSuccessStatistics(startTime: startTime)
            return metadata
            
        } catch {
            statistics.failedExtractions += 1
            throw MetadataError.corruptedMetadata(url, underlying: error)
        }
    }
    
    public func loadAllMetadata(for urls: [URL]) async throws -> [URL: ImageMetadata] {
        var results: [URL: ImageMetadata] = [:]
        
        // 並列処理でメタデータを取得
        await withThrowingTaskGroup(of: (URL, ImageMetadata).self) { group in
            for url in urls {
                group.addTask {
                    let metadata = try await self.loadAllMetadata(for: url)
                    return (url, metadata)
                }
            }
            
            do {
                for try await (url, metadata) in group {
                    results[url] = metadata
                }
            } catch {
                ProductionLogger.warning("Failed to load metadata for some URLs: \(error)")
            }
        }
        
        return results
    }
    
    public func updateMetadata(_ metadata: ImageMetadata, for url: URL) async throws {
        // ファイルシステムRepositoryでは読み取り専用
        // 実際の更新は専用のツールや別のサービスで行う
        ProductionLogger.warning("FileSystemMetadataRepository: Metadata updates are not supported")
        throw MetadataError.validationError("Metadata updates are not supported by FileSystemMetadataRepository")
    }
    
    public func cacheMetadata(_ metadata: ImageMetadata, for url: URL) async {
        let cacheKey = NSString(string: url.absoluteString)
        let cachedEntry = CachedMetadata(metadata: metadata)
        
        // メタデータのサイズを推定してコストを設定
        let estimatedCost = estimateMetadataSize(metadata)
        metadataCache.setObject(cachedEntry, forKey: cacheKey, cost: estimatedCost)
        
        ProductionLogger.debug("Cached metadata for \(url.lastPathComponent)")
    }
    
    public func getCachedMetadata(for url: URL) async -> ImageMetadata? {
        let cacheKey = NSString(string: url.absoluteString)
        
        if let cachedEntry = metadataCache.object(forKey: cacheKey) {
            // 1時間以内のキャッシュは有効
            if Date().timeIntervalSince(cachedEntry.timestamp) < 3600 {
                statistics.cacheHitCount += 1
                return cachedEntry.metadata
            }
        }
        
        statistics.cacheMissCount += 1
        return nil
    }
    
    public func clearMetadataCache() async {
        metadataCache.removeAllObjects()
        ProductionLogger.info("Metadata cache cleared")
    }
    
    nonisolated public var supportedMetadataFormats: Set<MetadataFormat> {
        return supportedFormats
    }
    
    public func getPerformanceStatistics() async -> MetadataPerformanceStatistics {
        return statistics
    }
    
    // MARK: - Private Extraction Methods
    
    private func extractFileInfo(from url: URL) async throws -> ImageMetadata.FileInfo {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        
        let size = attributes[.size] as? Int64 ?? 0
        let createdDate = attributes[.creationDate] as? Date ?? Date()
        let modifiedDate = attributes[.modificationDate] as? Date ?? Date()
        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        return ImageMetadata.FileInfo(
            size: size,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            fileName: fileName,
            fileExtension: fileExtension
        )
    }
    
    private func extractImageInfo(from url: URL) async throws -> ImageMetadata.ImageInfo {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        let colorSpace = properties[kCGImagePropertyColorModel as String] as? String
        let bitDepth = properties[kCGImagePropertyDepth as String] as? Int
        let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool ?? false
        
        return ImageMetadata.ImageInfo(
            width: width,
            height: height,
            colorSpace: colorSpace,
            bitDepth: bitDepth,
            hasAlpha: hasAlpha
        )
    }
    
    private func extractEXIFDataFromFile(_ url: URL) async throws -> EXIFData {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        
        // カメラモデル
        let cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        
        // 撮影日時
        let dateTaken = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String
        let dateTakenDate = dateTaken.flatMap { parseEXIFDate($0) }
        
        // GPS位置情報
        let gpsLocation = extractGPSLocation(from: gpsDict)
        
        // 露出設定
        let exposureSettings = extractExposureSettings(from: exifDict)
        
        // 生データ（文字列化）
        var rawData: [String: String] = [:]
        for (key, value) in exifDict {
            rawData[key] = String(describing: value)
        }
        
        return EXIFData(
            cameraModel: cameraModel,
            dateTaken: dateTakenDate,
            gpsLocation: gpsLocation,
            exposureSettings: exposureSettings,
            rawData: rawData
        )
    }
    
    private func extractIPTCDataFromFile(_ url: URL) async throws -> IPTCData {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        let iptcDict = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        
        let title = iptcDict[kCGImagePropertyIPTCObjectName as String] as? String
        let description = iptcDict[kCGImagePropertyIPTCCaptionAbstract as String] as? String
        let keywords = iptcDict[kCGImagePropertyIPTCKeywords as String] as? [String] ?? []
        let copyright = iptcDict[kCGImagePropertyIPTCCopyrightNotice as String] as? String
        let creator = iptcDict[kCGImagePropertyIPTCByline as String] as? String
        
        return IPTCData(
            title: title,
            description: description,
            keywords: keywords,
            copyright: copyright,
            creator: creator
        )
    }
    
    private func extractXMPDataFromFile(_ url: URL) async throws -> XMPData {
        // XMP抽出は複雑なため、基本的な実装のみ
        // 実際のプロダクションでは専用ライブラリの使用を推奨
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        // XMPデータが利用可能な場合の基本的な抽出
        // ここでは簡略化した実装
        return XMPData(
            rating: nil,
            label: nil,
            customProperties: [:]
        )
    }
    
    private func extractColorProfile(from url: URL) async throws -> ColorProfile {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw MetadataError.corruptedMetadata(url, underlying: nil)
        }
        
        let colorSpace = properties[kCGImagePropertyColorModel as String] as? String ?? "Unknown"
        
        // 色域の判定
        let profileType: ColorProfile.ColorProfileType
        switch colorSpace.lowercased() {
        case "rgb":
            profileType = .sRGB
        case "cmyk":
            profileType = .other
        default:
            profileType = .other
        }
        
        return ColorProfile(
            name: colorSpace,
            type: profileType,
            description: "Extracted from image source"
        )
    }
    
    private func extractGPSLocation(from gpsDict: [String: Any]) -> EXIFData.GPSLocation? {
        guard let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String,
              let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }
        
        let finalLatitude = latitudeRef == "S" ? -latitude : latitude
        let finalLongitude = longitudeRef == "W" ? -longitude : longitude
        let altitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double
        
        return EXIFData.GPSLocation(
            latitude: finalLatitude,
            longitude: finalLongitude,
            altitude: altitude
        )
    }
    
    private func extractExposureSettings(from exifDict: [String: Any]) -> EXIFData.ExposureSettings? {
        let fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double
        let exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
        let isoSpeed = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int]
        let focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
        
        return EXIFData.ExposureSettings(
            aperture: fNumber.map { String(format: "f/%.1f", $0) },
            shutterSpeed: exposureTime.map { formatShutterSpeed($0) },
            iso: isoSpeed?.first,
            focalLength: focalLength.map { String(format: "%.1fmm", $0) }
        )
    }
    
    // MARK: - Helper Methods
    
    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
    
    private func formatShutterSpeed(_ exposureTime: Double) -> String {
        if exposureTime >= 1 {
            return String(format: "%.1fs", exposureTime)
        } else {
            return String(format: "1/%.0f", 1.0 / exposureTime)
        }
    }
    
    private func estimateMetadataSize(_ metadata: ImageMetadata) -> Int {
        // メタデータのメモリサイズを概算
        var size = 0
        
        // 基本情報
        size += 200 // 基本的なプロパティ
        
        // EXIF データ
        if let exifData = metadata.exifData {
            size += exifData.rawData.count * 50 // 概算
        }
        
        // IPTC データ
        if let iptcData = metadata.iptcData {
            size += iptcData.keywords.count * 20
            size += (iptcData.title?.count ?? 0) + (iptcData.description?.count ?? 0)
        }
        
        return max(size, 100) // 最小サイズ
    }
    
    private func updateSuccessStatistics(startTime: Date) {
        statistics.successfulExtractions += 1
        let operationTime = Date().timeIntervalSince(startTime)
        
        // 移動平均でレスポンス時間を更新
        let totalOperations = Double(statistics.totalExtractions)
        let currentAverage = statistics.averageExtractionTime
        statistics.averageExtractionTime = (currentAverage * (totalOperations - 1) + operationTime) / totalOperations
    }
}

// MARK: - Metadata Validation
extension FileSystemMetadataRepository: MetadataValidator {
    public func validate(_ metadata: ImageMetadata) async throws -> MetadataValidationResult {
        var warnings: [ValidationWarning] = []
        var errors: [ValidationError] = []
        
        // ファイル情報の検証
        if metadata.fileInfo.size <= 0 {
            errors.append(ValidationError(field: .fileSize, message: "File size must be greater than 0"))
        }
        
        // 画像情報の検証
        if metadata.imageInfo.width <= 0 || metadata.imageInfo.height <= 0 {
            errors.append(ValidationError(field: .imageWidth, message: "Image dimensions must be positive"))
        }
        
        // GPS座標の検証
        if let gpsLocation = metadata.exifData?.gpsLocation {
            if abs(gpsLocation.latitude) > 90 {
                errors.append(ValidationError(field: .gpsLatitude, message: "Latitude must be between -90 and 90"))
            }
            if abs(gpsLocation.longitude) > 180 {
                errors.append(ValidationError(field: .gpsLongitude, message: "Longitude must be between -180 and 180"))
            }
        }
        
        // 警告の追加
        if metadata.exifData == nil {
            warnings.append(ValidationWarning(field: .dateTaken, message: "No EXIF data found"))
        }
        
        return MetadataValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }
    
    public func validateField(_ field: MetadataField, value: Any) async throws -> FieldValidationResult {
        var isValid = true
        var message: String?
        
        switch field {
        case .fileSize:
            if let size = value as? Int64, size <= 0 {
                isValid = false
                message = "File size must be positive"
            }
        case .imageWidth, .imageHeight:
            if let dimension = value as? Int, dimension <= 0 {
                isValid = false
                message = "Image dimensions must be positive"
            }
        case .gpsLatitude:
            if let lat = value as? Double, abs(lat) > 90 {
                isValid = false
                message = "Latitude must be between -90 and 90"
            }
        case .gpsLongitude:
            if let lon = value as? Double, abs(lon) > 180 {
                isValid = false
                message = "Longitude must be between -180 and 180"
            }
        default:
            // その他のフィールドは基本的に有効
            break
        }
        
        return FieldValidationResult(field: field, isValid: isValid, message: message)
    }
}