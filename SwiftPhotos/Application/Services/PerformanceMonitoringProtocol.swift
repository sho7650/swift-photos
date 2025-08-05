//
//  PerformanceMonitoringProtocol.swift
//  Swift Photos
//
//  Clean Architecture Interface for Performance Monitoring
//  Application layer defines the contract, Infrastructure implements it
//

import Foundation

// MARK: - Performance Monitoring Protocol

/// Protocol for performance monitoring services
/// Defines the contract that Infrastructure implementations must fulfill
public protocol PerformanceMonitoringProtocol: AnyObject, Sendable {
    
    // MARK: - Monitoring Control
    
    /// Whether monitoring is currently active
    var isMonitoring: Bool { get }
    
    /// Start performance monitoring
    func startMonitoring() async
    
    /// Stop performance monitoring
    func stopMonitoring() async
    
    // MARK: - Operation Tracking
    
    /// Record the start of an operation
    func startOperation(_ name: String) async
    
    /// Record the end of an operation
    func endOperation(_ name: String) async
    
    /// Get statistics for a specific operation
    func getOperationStats(_ name: String) async -> Any?
    
    // MARK: - Metrics Access
    
    /// Get current performance metrics
    func getCurrentMetrics() async -> Any
    
    /// Get comprehensive performance report
    func getPerformanceReport() async -> Any
    
    /// Reset all performance data
    func resetPerformanceData() async
}

// MARK: - Supporting Types

/// Protocol types are imported from Infrastructure layer
/// This maintains consistency with existing implementations
/// The Infrastructure types are already well-designed and follow Clean Architecture principles

// MARK: - Performance Factory Protocol

/// Factory for creating performance monitoring instances
/// Allows Application layer to create Infrastructure services without direct dependencies
public protocol PerformanceMonitoringFactory: Sendable {
    
    /// Create a performance monitoring instance
    func createPerformanceMonitor() -> PerformanceMonitoringProtocol
}