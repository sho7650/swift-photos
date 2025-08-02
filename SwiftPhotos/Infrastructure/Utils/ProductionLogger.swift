import Foundation
import os.log

/// Production-ready logging system for App Store compliance
/// Provides controlled debug output and production-safe logging
public final class ProductionLogger: Sendable {
    
    // MARK: - Singleton
    public static let shared = ProductionLogger()
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.example.SwiftPhotos", category: "production")
    
    // MARK: - Runtime Debug Control
    private static var isDebugLoggingEnabled: Bool {
        UserDefaults.standard.bool(forKey: "DebugLoggingEnabled")
    }
    
    private static var isVerboseLoggingEnabled: Bool {
        UserDefaults.standard.bool(forKey: "VerboseLoggingEnabled")
    }
    
    private init() {}
    
    // MARK: - Debug Logging (Development Only)
    
    /// Debug logging - controlled by runtime debug settings
    /// Safe for App Store submission as it respects user preferences
    public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        if isDebugLoggingEnabled {
            let fileName = (file as NSString).lastPathComponent
            shared.logger.debug("[\(fileName):\(line)] \(function): \(message)")
        }
        #endif
    }
    
    /// Verbose debugging output controlled by runtime settings
    /// Use this for detailed debugging that can be toggled by user
    public static func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        if isDebugLoggingEnabled && isVerboseLoggingEnabled {
            let fileName = (file as NSString).lastPathComponent
            print("🔍 [\(fileName):\(line)] \(function): \(message)")
            shared.logger.debug("VERBOSE [\(fileName):\(line)] \(function): \(message)")
        }
        #endif
    }
    
    // MARK: - Production Logging
    
    /// Info logging - appropriate for production use
    /// Use for important user actions and app state changes
    public static func info(_ message: String) {
        shared.logger.info("\(message)")
    }
    
    /// Warning logging - for non-critical issues
    /// Use for recoverable errors and unexpected conditions
    public static func warning(_ message: String) {
        shared.logger.warning("\(message)")
    }
    
    /// Error logging - for critical issues
    /// Use for errors that affect functionality
    public static func error(_ message: String) {
        shared.logger.error("\(message)")
    }
    
    // MARK: - Performance Logging
    
    /// Log performance metrics (production-safe)
    public static func performance(_ message: String, duration: TimeInterval) {
        shared.logger.info("⚡ Performance: \(message) in \(String(format: "%.2f", duration * 1000))ms")
    }
    
    /// Log performance metrics without duration (production-safe)
    public static func performance(_ message: String) {
        shared.logger.info("⚡ Performance: \(message)")
    }
    
    /// Log memory usage (debug only)
    public static func memory(_ message: String, usage: Int) {
        #if DEBUG
        shared.logger.debug("🧠 Memory: \(message) - \(usage)MB used")
        #endif
    }
    
    // MARK: - User Action Logging
    
    /// Log user interactions (production-safe)
    public static func userAction(_ action: String) {
        shared.logger.info("👤 User: \(action)")
    }
    
    /// Log app lifecycle events (production-safe)
    public static func lifecycle(_ event: String) {
        shared.logger.info("🚀 Lifecycle: \(event)")
    }
    
    // MARK: - Image Loading Logging
    
    /// Log image loading events (production optimized)
    public static func imageLoad(_ imageURL: String, success: Bool, duration: TimeInterval? = nil) {
        if success {
            if let duration = duration {
                shared.logger.info("🖼️ Loaded: \((imageURL as NSString).lastPathComponent) in \(String(format: "%.2f", duration))s")
            } else {
                shared.logger.info("🖼️ Loaded: \((imageURL as NSString).lastPathComponent)")
            }
        } else {
            shared.logger.error("❌ Failed to load: \((imageURL as NSString).lastPathComponent)")
        }
    }
    
    // MARK: - Cache Logging
    
    /// Log cache statistics (debug only)
    public static func cacheStats(hitRate: Double, items: Int, memoryUsage: Int) {
        #if DEBUG
        shared.logger.debug("📊 Cache: \(String(format: "%.1f", hitRate * 100))% hit rate, \(items) items, \(memoryUsage)MB")
        #endif
    }
    
    // MARK: - Conditional Logging Helper
    
    /// Conditional debug logging based on feature flags
    public static func conditionalDebug(_ message: String, condition: Bool = true) {
        #if DEBUG
        if condition && isDebugLoggingEnabled {
            shared.logger.debug("\(message)")
        }
        #endif
    }
    
    // MARK: - Debug Control Methods
    
    /// Enable or disable debug logging at runtime
    public static func setDebugLogging(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "DebugLoggingEnabled")
        info("Debug logging \(enabled ? "enabled" : "disabled")")
    }
    
    /// Enable or disable verbose logging at runtime
    public static func setVerboseLogging(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "VerboseLoggingEnabled")
        info("Verbose logging \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get current debug logging state
    public static func isDebugEnabled() -> Bool {
        return isDebugLoggingEnabled
    }
    
    /// Get current verbose logging state
    public static func isVerboseEnabled() -> Bool {
        return isVerboseLoggingEnabled
    }
    
    /// Export logs to a string (for debugging purposes)
    /// Note: This is a simplified version - in production you might want to read from system logs
    public static func exportLogsAsString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        return """
        Swift Photos Debug Log Export
        Generated: \(dateFormatter.string(from: Date()))
        Debug Logging: \(isDebugLoggingEnabled ? "Enabled" : "Disabled")
        Verbose Logging: \(isVerboseLoggingEnabled ? "Enabled" : "Disabled")
        
        ===== Recent Log Entries =====
        [This would contain recent log entries in a production implementation]
        
        Note: Full log access requires reading from system unified logging
        Use Console.app or log stream commands for complete logs.
        """
    }
}

// MARK: - App Store Compliance Extensions

extension ProductionLogger {
    
    /// Replace NSLog calls with App Store compliant logging
    public static func replaceNSLog(_ message: String) {
        // NSLog is deprecated and should not be used in production
        // Use structured logging instead
        info(message)
    }
    
    /// Replace print calls with appropriate logging level
    public static func replacePrint(_ message: String, level: LogLevel = .debug) {
        switch level {
        case .debug:
            debug(message)
        case .info:
            info(message)
        case .warning:
            warning(message)
        case .error:
            error(message)
        }
    }
}

// MARK: - Log Level Enumeration

public enum LogLevel {
    case debug
    case info
    case warning
    case error
}

// MARK: - Migration Helper

/// Helper for systematic migration from print/NSLog
/// This will be removed after migration is complete
public struct LoggingMigrationHelper {
    
    /// Analyze and categorize print statements for migration
    public static func categorizeMessage(_ message: String) -> LogLevel {
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("error") || lowerMessage.contains("failed") || lowerMessage.contains("❌") {
            return .error
        } else if lowerMessage.contains("warning") || lowerMessage.contains("⚠️") {
            return .warning
        } else if lowerMessage.contains("info") || lowerMessage.contains("user") || lowerMessage.contains("lifecycle") {
            return .info
        } else {
            return .debug
        }
    }
    
    /// Replace print statement with appropriate ProductionLogger call
    public static func replacePrintStatement(_ message: String) {
        let level = categorizeMessage(message)
        ProductionLogger.replacePrint(message, level: level)
    }
}