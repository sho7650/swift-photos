import Foundation

/// キャッシュ操作を抽象化するプロトコル
public protocol CacheRepositoryProtocol: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    /// キャッシュから値を取得
    func get(_ key: Key) async -> Value?
    
    /// キャッシュに値を保存
    func set(_ value: Value, for key: Key, cost: Int?) async
    
    /// キャッシュから値を削除
    func remove(_ key: Key) async
    
    /// 複数のキーの値を一括取得
    func getMultiple(_ keys: [Key]) async -> [Key: Value]
    
    /// 複数の値を一括保存
    func setMultiple(_ items: [(key: Key, value: Value, cost: Int?)]) async
    
    /// 複数のキーを一括削除
    func removeMultiple(_ keys: [Key]) async
    
    /// すべてのキャッシュをクリア
    func removeAll() async
    
    /// キャッシュ統計情報を取得
    func statistics() async -> CacheStatistics
    
    /// キャッシュサイズの制限を設定
    func setLimits(countLimit: Int?, totalCostLimit: Int?) async
    
    /// キャッシュに含まれているか確認
    func contains(_ key: Key) async -> Bool
    
    /// 現在のキャッシュキーのリストを取得
    func allKeys() async -> [Key]
    
    /// メモリ圧迫時のクリーンアップ
    func performCleanup(targetReduction: Double) async
}

/// 画像専用のキャッシュプロトコル
public protocol ImageCacheRepositoryProtocol: CacheRepositoryProtocol where Key == ImageCacheKey, Value == SendableImage {
    /// プリロード用の特別なメソッド
    func preload(_ images: [(key: ImageCacheKey, value: SendableImage)]) async
    
    /// 優先度付きキャッシュ（スライドショー用）
    func setPriority(_ priority: CachePriority, for key: ImageCacheKey) async
    
    /// 指定したサイズのサムネイルをキャッシュ
    func cacheThumbnail(_ image: SendableImage, for originalKey: ImageCacheKey, size: CGSize) async
    
    /// サムネイル専用キャッシュから取得
    func getThumbnail(for key: ImageCacheKey, size: CGSize) async -> SendableImage?
    
    /// 画像の品質別キャッシュ
    func cacheWithQuality(_ image: SendableImage, for key: ImageCacheKey, quality: ImageQuality) async
    
    /// 品質指定での取得
    func getWithQuality(_ key: ImageCacheKey, quality: ImageQuality) async -> SendableImage?
}

/// 画像キャッシュキー
public struct ImageCacheKey: Hashable, Sendable, Codable {
    public let url: URL
    public let size: CGSize?
    public let quality: ImageQuality
    public let transformations: [ImageTransformation]
    
    public init(
        url: URL,
        size: CGSize? = nil,
        quality: ImageQuality = .full,
        transformations: [ImageTransformation] = []
    ) {
        self.url = url
        self.size = size
        self.quality = quality
        self.transformations = transformations
    }
    
    /// キャッシュキーの文字列表現
    public var cacheIdentifier: String {
        var identifier = url.absoluteString
        
        if let size = size {
            identifier += "_\(Int(size.width))x\(Int(size.height))"
        }
        
        identifier += "_\(quality.rawValue)"
        
        if !transformations.isEmpty {
            let transformString = transformations.map { $0.identifier }.joined(separator: "_")
            identifier += "_\(transformString)"
        }
        
        return identifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? identifier
    }
}

/// 画像品質の定義
public enum ImageQuality: String, Sendable, Codable, CaseIterable {
    case thumbnail = "thumbnail"    // 低品質・高速表示用
    case preview = "preview"        // 中品質・プレビュー用  
    case full = "full"             // 原寸・高品質
    case original = "original"      // 無圧縮・元データ
    
    /// 各品質の推奨最大サイズ
    public var maxDimension: CGFloat {
        switch self {
        case .thumbnail: return 150
        case .preview: return 512
        case .full: return 2048
        case .original: return .infinity
        }
    }
    
    /// 圧縮品質（0.0-1.0）
    public var compressionQuality: CGFloat {
        switch self {
        case .thumbnail: return 0.6
        case .preview: return 0.8
        case .full: return 0.9
        case .original: return 1.0
        }
    }
}

/// 画像変換の定義
public enum ImageTransformation: Sendable, Codable, Hashable {
    case rotation(degrees: Double)
    case flip(horizontal: Bool, vertical: Bool)
    case crop(rect: CGRect)
    case scale(factor: CGFloat)
    case colorAdjustment(brightness: Double, contrast: Double, saturation: Double)
    
    /// 変換の識別子
    public var identifier: String {
        switch self {
        case .rotation(let degrees):
            return "rot\(Int(degrees))"
        case .flip(let h, let v):
            return "flip\(h ? "H" : "")\(v ? "V" : "")"
        case .crop(let rect):
            return "crop\(Int(rect.origin.x))\(Int(rect.origin.y))\(Int(rect.width))\(Int(rect.height))"
        case .scale(let factor):
            return "scale\(Int(factor * 100))"
        case .colorAdjustment(let b, let c, let s):
            return "color\(Int(b * 100))\(Int(c * 100))\(Int(s * 100))"
        }
    }
}

/// キャッシュ優先度
public enum CachePriority: Int, Sendable, Codable, CaseIterable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    public static func < (lhs: CachePriority, rhs: CachePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// キャッシュ統計情報の拡張
extension CacheStatistics {
    /// ヒット率の文字列表現
    public var hitRateString: String {
        String(format: "%.1f%%", hitRate * 100)
    }
    
    /// メモリ使用量の文字列表現
    public var memorySizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalCost), countStyle: .memory)
    }
    
    /// 効率性の評価
    public var efficiency: CacheEfficiency {
        switch hitRate {
        case 0.9...: return .excellent
        case 0.7..<0.9: return .good
        case 0.5..<0.7: return .fair
        default: return .poor
        }
    }
}

/// キャッシュ効率性の評価
public enum CacheEfficiency: String, Sendable, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    /// 効率性に対応する色
    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

/// キャッシュイベント通知用
public enum CacheEvent: Sendable {
    case itemAdded(key: String, cost: Int)
    case itemRemoved(key: String, reason: RemovalReason)
    case itemAccessed(key: String)
    case cacheFull
    case memoryWarning
    case cleanupPerformed(itemsRemoved: Int, memoryFreed: Int)
}

/// アイテム削除理由
public enum RemovalReason: String, Sendable, CaseIterable {
    case expired = "expired"
    case evicted = "evicted"
    case removed = "removed"
    case memoryPressure = "memoryPressure"
    case sizeLimit = "sizeLimit"
}

/// キャッシュイベント監視プロトコル
public protocol CacheEventObserver: Sendable {
    func cacheDidReceiveEvent(_ event: CacheEvent) async
}

/// キャッシュ設定
public struct CacheConfiguration: Sendable, Codable {
    public let name: String
    public let maxMemorySize: Int
    public let maxItemCount: Int
    public let defaultTTL: TimeInterval?
    public let enableDiskCache: Bool
    public let diskCacheMaxSize: Int64?
    public let compressionEnabled: Bool
    
    public init(
        name: String,
        maxMemorySize: Int = 500_000_000, // 500MB
        maxItemCount: Int = 1000,
        defaultTTL: TimeInterval? = nil,
        enableDiskCache: Bool = true,
        diskCacheMaxSize: Int64? = 2_000_000_000, // 2GB
        compressionEnabled: Bool = false
    ) {
        self.name = name
        self.maxMemorySize = maxMemorySize
        self.maxItemCount = maxItemCount
        self.defaultTTL = defaultTTL
        self.enableDiskCache = enableDiskCache
        self.diskCacheMaxSize = diskCacheMaxSize
        self.compressionEnabled = compressionEnabled
    }
    
    /// デフォルト設定
    public static let `default` = CacheConfiguration(name: "DefaultImageCache")
    
    /// 高性能設定
    public static let highPerformance = CacheConfiguration(
        name: "HighPerformanceImageCache",
        maxMemorySize: 1_000_000_000, // 1GB
        maxItemCount: 2000,
        enableDiskCache: true,
        diskCacheMaxSize: 5_000_000_000 // 5GB
    )
    
    /// 省メモリ設定
    public static let lowMemory = CacheConfiguration(
        name: "LowMemoryImageCache",
        maxMemorySize: 100_000_000, // 100MB
        maxItemCount: 200,
        enableDiskCache: false
    )
}