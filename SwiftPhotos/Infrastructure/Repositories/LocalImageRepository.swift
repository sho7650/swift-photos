import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// ローカルファイルシステムから画像を読み込むRepository
/// 既存のFileSystemPhotoRepositoryの機能を新アーキテクチャで実装
public actor LocalImageRepository: ImageRepositoryProtocol {
    
    // MARK: - Properties
    private let fileAccess: SecureFileAccess
    private let imageLoader: ImageLoader
    private let supportedFormats: Set<String>
    
    // MARK: - Performance Tracking
    private var loadOperationCount = 0
    private var lastOperationTime = Date()
    
    // MARK: - Initialization
    public init(
        fileAccess: SecureFileAccess? = nil,
        imageLoader: ImageLoader? = nil,
        additionalFormats: Set<String> = []
    ) {
        self.fileAccess = fileAccess ?? SecureFileAccess()
        self.imageLoader = imageLoader ?? ImageLoader()
        
        // デフォルトでサポートする画像形式
        var formats: Set<String> = [
            "jpg", "jpeg", "png", "gif", "tiff", "tif",
            "heic", "heif", "webp", "bmp", "ico",
            "jp2", "jpx", "j2k", "jpc"
        ]
        formats.formUnion(additionalFormats)
        self.supportedFormats = formats
    }
    
    // MARK: - ImageRepositoryProtocol Implementation
    
    public func loadImage(from url: URL) async throws -> SendableImage {
        loadOperationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("LocalImageRepository: Loading image from \(url.lastPathComponent)")
        
        // ファイルアクセス検証
        try fileAccess.validateFileAccess(for: url)
        
        // 画像形式チェック
        let fileExtension = url.pathExtension.lowercased()
        guard supportedFormats.contains(fileExtension) else {
            throw RepositoryError.validationError("Unsupported image format: \(fileExtension)")
        }
        
        // 画像読み込み
        do {
            let image = try await imageLoader.loadImage(from: url)
            ProductionLogger.debug("LocalImageRepository: Successfully loaded \(url.lastPathComponent)")
            return image
        } catch {
            ProductionLogger.error("LocalImageRepository: Failed to load \(url.lastPathComponent): \(error)")
            throw RepositoryError.storageError(underlying: error)
        }
    }
    
    public func loadImageURLs(from folder: URL) async throws -> [ImageURL] {
        loadOperationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("LocalImageRepository: Loading image URLs from \(folder.path)")
        
        // ファイルアクセス検証
        try fileAccess.validateFileAccess(for: folder)
        
        // 画像ファイル列挙
        do {
            let imageFileURLs = try fileAccess.enumerateImages(in: folder)
            
            // ImageURLオブジェクトに変換
            let imageURLs = try imageFileURLs.compactMap { url -> ImageURL? in
                do {
                    return try ImageURL(url)
                } catch {
                    ProductionLogger.warning("LocalImageRepository: Failed to create ImageURL for \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
            
            ProductionLogger.info("LocalImageRepository: Found \(imageURLs.count) images in \(folder.lastPathComponent)")
            return imageURLs
            
        } catch {
            ProductionLogger.error("LocalImageRepository: Failed to enumerate images in \(folder.path): \(error)")
            throw RepositoryError.storageError(underlying: error)
        }
    }
    
    public func loadMetadata(for url: URL) async throws -> ImageMetadata {
        loadOperationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("LocalImageRepository: Loading metadata for \(url.lastPathComponent)")
        
        // ファイルアクセス検証
        try fileAccess.validateFileAccess(for: url)
        
        // ファイル情報取得
        let fileInfo = try await extractFileInfo(from: url)
        
        // 画像情報取得
        let imageInfo = try await extractImageInfo(from: url)
        
        // EXIF情報取得（オプション）
        let exifData = try? await extractEXIFData(from: url)
        
        return ImageMetadata(
            fileInfo: fileInfo,
            imageInfo: imageInfo,
            exifData: exifData,
            iptcData: nil, // 基本実装では省略
            xmpData: nil,  // 基本実装では省略
            colorProfile: try? await extractColorProfile(from: url)
        )
    }
    
    public func generateThumbnail(for url: URL, size: CGSize) async throws -> SendableImage {
        loadOperationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("LocalImageRepository: Generating thumbnail for \(url.lastPathComponent) at size \(size)")
        
        // 元画像を読み込み
        let originalImage = try await loadImage(from: url)
        
        // サムネイル生成
        let thumbnail = await generateThumbnailFromImage(originalImage, targetSize: size)
        
        ProductionLogger.debug("LocalImageRepository: Generated thumbnail for \(url.lastPathComponent)")
        return thumbnail
    }
    
    public func searchImages(in folder: URL, matching criteria: SearchCriteria) async throws -> [ImageURL] {
        loadOperationCount += 1
        lastOperationTime = Date()
        
        ProductionLogger.debug("LocalImageRepository: Searching images in \(folder.lastPathComponent)")
        
        // すべての画像URLを取得
        let allImageURLs = try await loadImageURLs(from: folder)
        
        // 検索条件に基づいてフィルタリング
        let matchingURLs = try await filterImageURLs(allImageURLs, criteria: criteria)
        
        ProductionLogger.info("LocalImageRepository: Found \(matchingURLs.count) matching images out of \(allImageURLs.count)")
        return matchingURLs
    }
    
    nonisolated public var supportedImageFormats: Set<String> {
        return supportedFormats
    }
    
    // MARK: - Private Helper Methods
    
    private func extractFileInfo(from url: URL) async throws -> ImageMetadata.FileInfo {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            
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
        } catch {
            throw RepositoryError.storageError(underlying: error)
        }
    }
    
    private func extractImageInfo(from url: URL) async throws -> ImageMetadata.ImageInfo {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw RepositoryError.validationError("Cannot create image source for \(url.lastPathComponent)")
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw RepositoryError.validationError("Cannot read image properties for \(url.lastPathComponent)")
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
    
    private func extractEXIFData(from url: URL) async throws -> EXIFData {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw RepositoryError.validationError("Cannot create image source for EXIF extraction")
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw RepositoryError.validationError("Cannot read image properties for EXIF extraction")
        }
        
        let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        
        // カメラモデル
        let cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        
        // 撮影日時
        let dateTaken = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String
        let dateTakenDate = dateTaken.flatMap { DateFormatter.exifDateFormatter.date(from: $0) }
        
        // GPS位置情報
        let gpsLocation = extractGPSLocation(from: gpsDict)
        
        // 露出設定
        let exposureSettings = extractExposureSettings(from: exifDict)
        
        // 生データ
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
        let aperture = exifDict[kCGImagePropertyExifApertureValue as String] as? Double
        let shutterSpeed = exifDict[kCGImagePropertyExifShutterSpeedValue as String] as? Double
        let iso = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int]
        let focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
        
        return EXIFData.ExposureSettings(
            aperture: aperture.map { String(format: "f/%.1f", pow(2, $0 / 2)) },
            shutterSpeed: shutterSpeed.map { String(format: "1/%.0f", pow(2, $0)) },
            iso: iso?.first,
            focalLength: focalLength.map { String(format: "%.1fmm", $0) }
        )
    }
    
    private func extractColorProfile(from url: URL) async throws -> ColorProfile {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw RepositoryError.validationError("Cannot create image source for color profile extraction")
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw RepositoryError.validationError("Cannot read image properties for color profile extraction")
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
            description: "Color profile extracted from image metadata"
        )
    }
    
    private func generateThumbnailFromImage(_ image: SendableImage, targetSize: CGSize) async -> SendableImage {
        let originalSize = image.size
        
        // アスペクト比を保持してサイズを計算
        let aspectRatio = originalSize.width / originalSize.height
        var thumbnailSize = targetSize
        
        if targetSize.width / targetSize.height > aspectRatio {
            thumbnailSize.width = targetSize.height * aspectRatio
        } else {
            thumbnailSize.height = targetSize.width / aspectRatio
        }
        
        // サムネイル画像を作成
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.nsImage.draw(in: NSRect(origin: .zero, size: thumbnailSize))
        thumbnail.unlockFocus()
        
        return SendableImage(thumbnail)
    }
    
    private func filterImageURLs(_ imageURLs: [ImageURL], criteria: SearchCriteria) async throws -> [ImageURL] {
        var matchingURLs: [ImageURL] = []
        
        for imageURL in imageURLs {
            var matches = true
            
            // ファイル名フィルター
            if let fileName = criteria.fileName,
               !imageURL.url.lastPathComponent.localizedCaseInsensitiveContains(fileName) {
                matches = false
            }
            
            // ファイルタイプフィルター
            if let fileTypes = criteria.fileTypes,
               !fileTypes.contains(imageURL.url.pathExtension.lowercased()) {
                matches = false
            }
            
            // 日付範囲フィルター
            if let dateRange = criteria.dateRange {
                do {
                    let fileInfo = try await extractFileInfo(from: imageURL.url)
                    if fileInfo.createdDate < dateRange.start || fileInfo.createdDate > dateRange.end {
                        matches = false
                    }
                } catch {
                    // メタデータが読み込めない場合はスキップ
                    matches = false
                }
            }
            
            // サイズ範囲フィルター
            if let sizeRange = criteria.sizeRange {
                do {
                    let fileInfo = try await extractFileInfo(from: imageURL.url)
                    if fileInfo.size < sizeRange.minSize || fileInfo.size > sizeRange.maxSize {
                        matches = false
                    }
                } catch {
                    // メタデータが読み込めない場合はスキップ
                    matches = false
                }
            }
            
            if matches {
                matchingURLs.append(imageURL)
            }
        }
        
        return matchingURLs
    }
    
    // MARK: - Performance Monitoring
    
    public func getPerformanceMetrics() async -> RepositoryMetrics {
        return RepositoryMetrics(
            operationCount: loadOperationCount,
            successCount: loadOperationCount, // 簡略化
            errorCount: 0,
            averageResponseTime: 0.1, // 仮の値
            cacheHitRate: 0.0, // キャッシュなし
            totalDataTransferred: 0, // 実装を簡略化
            lastOperation: lastOperationTime
        )
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}