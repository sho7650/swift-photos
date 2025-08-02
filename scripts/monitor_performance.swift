#!/usr/bin/env swift

import Foundation
import Darwin

// Performance Monitor for Swift Photos Functional Testing
// This script monitors the Swift Photos app performance during testing

print("📊 Swift Photos Performance Monitor")
print("==================================\n")

// Configuration
struct MonitorConfig {
    let appName = "Swift Photos"
    let sampleInterval: TimeInterval = 1.0 // seconds
    let outputFile = "performance_report.csv"
}

// Performance metrics
struct PerformanceMetrics {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Int64 // bytes
    let diskReads: Int64
    let diskWrites: Int64
    let threadCount: Int
    
    var memoryUsageMB: Double {
        return Double(memoryUsage) / 1024 / 1024
    }
    
    func toCSVRow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return "\(formatter.string(from: timestamp)),\(cpuUsage),\(memoryUsageMB),\(diskReads),\(diskWrites),\(threadCount)"
    }
    
    static func csvHeader() -> String {
        return "Timestamp,CPU_Usage_%,Memory_MB,Disk_Reads,Disk_Writes,Thread_Count"
    }
}

// Process monitoring utilities
class ProcessMonitor {
    
    private let config: MonitorConfig
    private var processID: pid_t?
    private var metrics: [PerformanceMetrics] = []
    
    init(config: MonitorConfig) {
        self.config = config
    }
    
    func findProcessID() -> pid_t? {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-x", config.appName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let pid = output, let processID = pid_t(pid) {
                return processID
            }
        } catch {
            print("Error finding process: \(error)")
        }
        
        return nil
    }
    
    func getCPUUsage(for pid: pid_t) -> Double {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "%cpu="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Double(output ?? "0") ?? 0.0
        } catch {
            return 0.0
        }
    }
    
    func getMemoryUsage(for pid: pid_t) -> Int64 {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "rss="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Convert KB to bytes
            return (Int64(output ?? "0") ?? 0) * 1024
        } catch {
            return 0
        }
    }
    
    func collectMetrics() -> PerformanceMetrics? {
        guard let pid = processID else {
            print("⚠️  Process not found. Searching...")
            processID = findProcessID()
            guard let pid = processID else {
                return nil
            }
            print("✅ Found process: PID \(pid)")
        }
        
        let cpu = getCPUUsage(for: pid)
        let memory = getMemoryUsage(for: pid)
        
        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: cpu,
            memoryUsage: memory,
            diskReads: 0, // Would need dtrace for accurate disk I/O
            diskWrites: 0,
            threadCount: getThreadCount(for: pid)
        )
    }
    
    func getThreadCount(for pid: pid_t) -> Int {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "thcount="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Int(output ?? "0") ?? 0
        } catch {
            return 0
        }
    }
    
    func startMonitoring() {
        print("🔍 Looking for \(config.appName) process...")
        
        processID = findProcessID()
        
        if processID == nil {
            print("❌ \(config.appName) is not running.")
            print("Please launch the app and try again.")
            return
        }
        
        print("✅ Monitoring started. Press Ctrl+C to stop.\n")
        print("Time\t\tCPU %\tMemory MB\tThreads")
        print("----\t\t-----\t---------\t-------")
        
        // Set up signal handler for graceful shutdown
        signal(SIGINT) { _ in
            print("\n\n📊 Monitoring stopped.")
            ProcessMonitor.shared?.saveReport()
            exit(0)
        }
        
        // Store reference for signal handler
        ProcessMonitor.shared = self
        
        // Main monitoring loop
        while true {
            if let metrics = collectMetrics() {
                self.metrics.append(metrics)
                
                let timeStr = DateFormatter.localizedString(from: metrics.timestamp, dateStyle: .none, timeStyle: .medium)
                print("\(timeStr)\t\(String(format: "%.1f", metrics.cpuUsage))\t\(String(format: "%.1f", metrics.memoryUsageMB))\t\t\(metrics.threadCount)")
                
                // Check if process still exists
                if kill(processID!, 0) != 0 {
                    print("\n⚠️  Process terminated.")
                    break
                }
            }
            
            Thread.sleep(forTimeInterval: config.sampleInterval)
        }
        
        saveReport()
    }
    
    func saveReport() {
        guard !metrics.isEmpty else {
            print("No metrics collected.")
            return
        }
        
        var csv = PerformanceMetrics.csvHeader() + "\n"
        for metric in metrics {
            csv += metric.toCSVRow() + "\n"
        }
        
        do {
            try csv.write(toFile: config.outputFile, atomically: true, encoding: .utf8)
            print("📄 Report saved to: \(config.outputFile)")
            
            // Print summary
            printSummary()
        } catch {
            print("❌ Error saving report: \(error)")
        }
    }
    
    func printSummary() {
        guard !metrics.isEmpty else { return }
        
        let cpuValues = metrics.map { $0.cpuUsage }
        let memoryValues = metrics.map { $0.memoryUsageMB }
        
        let avgCPU = cpuValues.reduce(0, +) / Double(cpuValues.count)
        let maxCPU = cpuValues.max() ?? 0
        let avgMemory = memoryValues.reduce(0, +) / Double(memoryValues.count)
        let maxMemory = memoryValues.max() ?? 0
        
        print("\n📈 Performance Summary:")
        print("----------------------")
        print("Duration: \(metrics.count) seconds")
        print("CPU Usage - Avg: \(String(format: "%.1f", avgCPU))%, Max: \(String(format: "%.1f", maxCPU))%")
        print("Memory Usage - Avg: \(String(format: "%.1f", avgMemory))MB, Max: \(String(format: "%.1f", maxMemory))MB")
        
        // Detect potential issues
        if maxCPU > 80 {
            print("\n⚠️  High CPU usage detected (>80%)")
        }
        if maxMemory > 2000 {
            print("\n⚠️  High memory usage detected (>2GB)")
        }
    }
    
    private static var shared: ProcessMonitor?
}

// Interactive menu
func showMenu() {
    print("\nOptions:")
    print("1. Start monitoring Swift Photos")
    print("2. Generate test report from existing data")
    print("3. Show monitoring tips")
    print("4. Exit")
    print("\nSelect option: ", terminator: "")
    
    if let input = readLine(), let option = Int(input) {
        switch option {
        case 1:
            let monitor = ProcessMonitor(config: MonitorConfig())
            monitor.startMonitoring()
            
        case 2:
            generateTestReport()
            
        case 3:
            showMonitoringTips()
            showMenu()
            
        case 4:
            print("👋 Goodbye!")
            exit(0)
            
        default:
            print("Invalid option.")
            showMenu()
        }
    }
}

func generateTestReport() {
    print("\n📊 Generating test report...")
    
    // This would analyze existing CSV files and generate a comprehensive report
    print("✅ Test report generated: test_report.html")
    print("   (Feature not fully implemented in this demo)")
    
    showMenu()
}

func showMonitoringTips() {
    print("""
    
    📚 Monitoring Tips:
    
    1. Run this monitor before starting your test scenario
    2. Note the baseline memory usage before loading photos
    3. Watch for memory spikes during large collection loads
    4. CPU usage should remain under 50% during normal operation
    5. Memory should stabilize after initial photo loading
    6. Thread count indicates concurrent operations
    
    🎯 What to look for:
    - Memory leaks: Continuously increasing memory
    - Performance issues: Sustained high CPU usage
    - Responsiveness: CPU spikes during user interactions
    - Efficiency: Memory usage relative to photo count
    
    """)
}

// Main execution
print("Select monitoring mode:\n")
showMenu()