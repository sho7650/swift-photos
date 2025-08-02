import Foundation

/// アプリケーション設定へのアクセスを抽象化するプロトコル
public protocol SettingsRepositoryProtocol: Sendable {
    /// 設定を読み込む
    func load<T: Codable & Sendable>(_ type: T.Type, for key: SettingsKey) async -> T?
    
    /// 設定を保存
    func save<T: Codable & Sendable>(_ value: T, for key: SettingsKey) async throws
    
    /// 設定を削除
    func remove(for key: SettingsKey) async
    
    /// 複数の設定を一括読み込み
    func loadMultiple<T: Codable & Sendable>(_ type: T.Type, for keys: [SettingsKey]) async -> [SettingsKey: T]
    
    /// 複数の設定を一括保存
    func saveMultiple<T: Codable & Sendable>(_ values: [SettingsKey: T]) async throws
    
    /// すべての設定をリセット
    func resetAll() async
    
    /// 特定のカテゴリの設定をリセット
    func resetCategory(_ category: RepositorySettingsCategory) async
    
    /// 設定をエクスポート
    func export() async throws -> Data
    
    /// 設定をインポート
    func importSettings(from data: Data) async throws
    
    /// 設定の変更を監視
    func observe<T: Codable & Sendable>(_ type: T.Type, for key: SettingsKey) -> AsyncStream<T?>
    
    /// すべての設定キーを取得
    func allKeys() async -> [SettingsKey]
    
    /// 設定が存在するか確認
    func exists(for key: SettingsKey) async -> Bool
    
    /// 設定のメタデータを取得
    func getMetadata(for key: SettingsKey) async -> SettingsMetadata?
    
    /// 設定の検証
    func validate<T: Codable & Sendable>(_ value: T, for key: SettingsKey) async throws -> SettingsValidationResult
}

/// 設定キー
public struct SettingsKey: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    // MARK: - Core Settings
    public static let performance = SettingsKey("performance")
    public static let slideshow = SettingsKey("slideshow")
    public static let sort = SettingsKey("sort")
    public static let transition = SettingsKey("transition")
    public static let uiControl = SettingsKey("uiControl")
    
    // MARK: - Advanced Settings
    public static let cache = SettingsKey("cache")
    public static let security = SettingsKey("security")
    public static let accessibility = SettingsKey("accessibility")
    public static let experimental = SettingsKey("experimental")
    
    // MARK: - User Preferences
    public static let appearance = SettingsKey("appearance")
    public static let keyboard = SettingsKey("keyboard")
    public static let mouse = SettingsKey("mouse")
    public static let audio = SettingsKey("audio")
    
    // MARK: - Integration Settings
    public static let cloud = SettingsKey("cloud")
    public static let plugins = SettingsKey("plugins")
    public static let sharing = SettingsKey("sharing")
    public static let metadata = SettingsKey("metadata")
    
    // MARK: - Development Settings
    public static let logging = SettingsKey("logging")
    public static let debugging = SettingsKey("debugging")
    public static let telemetry = SettingsKey("telemetry")
    
    /// キーの表示名
    public var displayName: String {
        switch self.rawValue {
        case "performance": return "Performance"
        case "slideshow": return "Slideshow"
        case "sort": return "Sort"
        case "transition": return "Transition"
        case "uiControl": return "UI Control"
        case "cache": return "Cache"
        case "security": return "Security"
        case "accessibility": return "Accessibility"
        case "experimental": return "Experimental"
        case "appearance": return "Appearance"
        case "keyboard": return "Keyboard"
        case "mouse": return "Mouse"
        case "audio": return "Audio"
        case "cloud": return "Cloud"
        case "plugins": return "Plugins"
        case "sharing": return "Sharing"
        case "metadata": return "Metadata"
        case "logging": return "Logging"
        case "debugging": return "Debugging"
        case "telemetry": return "Telemetry"
        default: return rawValue.capitalized
        }
    }
    
    /// キーのカテゴリ
    public var category: RepositorySettingsCategory {
        switch self.rawValue {
        case "performance", "cache", "slideshow", "sort", "transition":
            return .core
        case "appearance", "keyboard", "mouse", "audio", "uiControl":
            return .userInterface
        case "security", "accessibility":
            return .system
        case "cloud", "plugins", "sharing", "metadata":
            return .integration
        case "logging", "debugging", "telemetry", "experimental":
            return .development
        default:
            return .other
        }
    }
}

/// Repository設定カテゴリ
public enum RepositorySettingsCategory: String, Sendable, Codable, CaseIterable {
    case core = "Core"
    case userInterface = "User Interface"
    case system = "System"
    case integration = "Integration"
    case development = "Development"
    case other = "Other"
    
    /// カテゴリの表示名
    public var displayName: String {
        switch self {
        case .core: return "Core Settings"
        case .userInterface: return "User Interface"
        case .system: return "System"
        case .integration: return "Integration"
        case .development: return "Development"
        case .other: return "Other"
        }
    }
    
    /// カテゴリの説明
    public var description: String {
        switch self {
        case .core:
            return "Essential application settings for performance and behavior"
        case .userInterface:
            return "Customization options for appearance and interaction"
        case .system:
            return "System-level settings for security and accessibility"
        case .integration:
            return "Settings for external services and plugins"
        case .development:
            return "Development and debugging options"
        case .other:
            return "Miscellaneous settings"
        }
    }
    
    /// カテゴリのアイコン
    public var iconName: String {
        switch self {
        case .core: return "gear"
        case .userInterface: return "paintbrush"
        case .system: return "shield"
        case .integration: return "link"
        case .development: return "hammer"
        case .other: return "ellipsis"
        }
    }
}

/// 設定メタデータ
public struct SettingsMetadata: Sendable, Codable {
    public let key: SettingsKey
    public let lastModified: Date
    public let version: String
    public let size: Int
    public let type: String
    public let isDefault: Bool
    public let validationRules: [ValidationRule]
    
    public init(
        key: SettingsKey,
        lastModified: Date = Date(),
        version: String = "1.0",
        size: Int = 0,
        type: String = "Unknown",
        isDefault: Bool = false,
        validationRules: [ValidationRule] = []
    ) {
        self.key = key
        self.lastModified = lastModified
        self.version = version
        self.size = size
        self.type = type
        self.isDefault = isDefault
        self.validationRules = validationRules
    }
}

/// 検証ルール
public struct ValidationRule: Sendable, Codable {
    public let name: String
    public let description: String
    public let rule: ValidationRuleType
    
    public init(name: String, description: String, rule: ValidationRuleType) {
        self.name = name
        self.description = description
        self.rule = rule
    }
}

/// 検証ルールタイプ
public enum ValidationRuleType: Sendable, Codable {
    case required
    case range(min: Double, max: Double)
    case stringLength(min: Int, max: Int)
    case regex(pattern: String)
    case custom(identifier: String)
    
    /// ルールの説明
    public var description: String {
        switch self {
        case .required:
            return "Value is required"
        case .range(let min, let max):
            return "Value must be between \(min) and \(max)"
        case .stringLength(let min, let max):
            return "String length must be between \(min) and \(max) characters"
        case .regex(let pattern):
            return "Value must match pattern: \(pattern)"
        case .custom(let identifier):
            return "Custom validation: \(identifier)"
        }
    }
}

/// 設定エクスポート形式
public enum SettingsExportFormat: String, Sendable, CaseIterable {
    case json = "json"
    case plist = "plist"
    case yaml = "yaml"
    case csv = "csv"
    
    /// ファイル拡張子
    public var fileExtension: String {
        return rawValue
    }
    
    /// MIME タイプ
    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .plist: return "application/x-plist"
        case .yaml: return "application/x-yaml"
        case .csv: return "text/csv"
        }
    }
}

/// 設定インポート結果
public struct SettingsImportResult: Sendable {
    public let importedCount: Int
    public let skippedCount: Int
    public let errorCount: Int
    public let warnings: [String]
    public let errors: [String]
    
    public init(
        importedCount: Int = 0,
        skippedCount: Int = 0,
        errorCount: Int = 0,
        warnings: [String] = [],
        errors: [String] = []
    ) {
        self.importedCount = importedCount
        self.skippedCount = skippedCount
        self.errorCount = errorCount
        self.warnings = warnings
        self.errors = errors
    }
    
    /// インポートが成功したか
    public var isSuccess: Bool {
        return errorCount == 0 && importedCount > 0
    }
    
    /// 部分的成功（警告があるが致命的エラーはない）
    public var isPartialSuccess: Bool {
        return errorCount == 0 && !warnings.isEmpty
    }
}

/// 設定変更イベント
public struct SettingsChangeEvent: Sendable {
    public let key: SettingsKey
    public let oldValue: String? // Changed from Any? for Sendable compliance
    public let newValue: String? // Changed from Any? for Sendable compliance
    public let timestamp: Date
    public let source: ChangeSource
    
    public init(
        key: SettingsKey,
        oldValue: String? = nil,
        newValue: String? = nil,
        timestamp: Date = Date(),
        source: ChangeSource = .user
    ) {
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = timestamp
        self.source = source
    }
    
    public enum ChangeSource: String, Sendable, CaseIterable {
        case user = "user"
        case system = "system"
        case importData = "import"
        case reset = "reset"
        case migration = "migration"
        case external = "external"
    }
}

/// 設定エラー
public enum SettingsError: LocalizedError, Sendable {
    case keyNotFound(SettingsKey)
    case invalidValue(key: SettingsKey, value: String)
    case validationFailed(key: SettingsKey, rule: ValidationRule)
    case encodingFailed(key: SettingsKey, error: Error)
    case decodingFailed(key: SettingsKey, error: Error)
    case importFailed(format: SettingsExportFormat, error: Error)
    case exportFailed(format: SettingsExportFormat, error: Error)
    case permissionDenied(operation: String)
    case storageError(underlying: Error)
    case migrationFailed(fromVersion: String, toVersion: String, error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .keyNotFound(let key):
            return "Settings key not found: \(key.rawValue)"
        case .invalidValue(let key, _):
            return "Invalid value for settings key: \(key.rawValue)"
        case .validationFailed(let key, let rule):
            return "Validation failed for \(key.rawValue): \(rule.description)"
        case .encodingFailed(let key, _):
            return "Failed to encode settings for key: \(key.rawValue)"
        case .decodingFailed(let key, _):
            return "Failed to decode settings for key: \(key.rawValue)"
        case .importFailed(let format, _):
            return "Failed to import settings from \(format.rawValue) format"
        case .exportFailed(let format, _):
            return "Failed to export settings to \(format.rawValue) format"
        case .permissionDenied(let operation):
            return "Permission denied for operation: \(operation)"
        case .storageError(_):
            return "Settings storage error occurred"
        case .migrationFailed(let from, let to, _):
            return "Settings migration failed from version \(from) to \(to)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .keyNotFound:
            return "Check that the settings key is correct and has been initialized"
        case .invalidValue:
            return "Provide a value that matches the expected type and constraints"
        case .validationFailed:
            return "Ensure the value meets all validation requirements"
        case .encodingFailed, .decodingFailed:
            return "Verify the data format and try again"
        case .importFailed, .exportFailed:
            return "Check the file format and permissions"
        case .permissionDenied:
            return "Grant the necessary permissions and try again"
        case .storageError:
            return "Check available storage space and file permissions"
        case .migrationFailed:
            return "Try resetting settings to defaults or contact support"
        }
    }
}

/// 設定プリセット
public struct SettingsPreset: Sendable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let category: RepositorySettingsCategory
    public let settings: [SettingsKey: Data] // Encoded values
    public let createdDate: Date
    public let author: String?
    public let version: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: RepositorySettingsCategory,
        settings: [SettingsKey: Data] = [:],
        createdDate: Date = Date(),
        author: String? = nil,
        version: String = "1.0"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.settings = settings
        self.createdDate = createdDate
        self.author = author
        self.version = version
    }
    
    /// デフォルトプリセット
    public static let `default` = SettingsPreset(
        name: "Default",
        description: "Default application settings",
        category: .core
    )
    
    /// 高性能プリセット
    public static let highPerformance = SettingsPreset(
        name: "High Performance",
        description: "Optimized for maximum performance",
        category: .core
    )
    
    /// 省エネプリセット
    public static let powerSaver = SettingsPreset(
        name: "Power Saver",
        description: "Optimized for battery life",
        category: .core
    )
}