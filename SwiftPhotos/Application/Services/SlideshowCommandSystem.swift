import Foundation
import SwiftUI
import AppKit

/// Command pattern implementation for slideshow user actions
/// Provides undo/redo functionality, command history, and macro recording

// MARK: - Command Protocol

/// Base protocol for all slideshow commands
public protocol SlideshowCommand {
    /// Unique identifier for the command
    var id: UUID { get }
    
    /// Display name for the command (for history/undo UI)
    var displayName: String { get }
    
    /// Timestamp when the command was created
    var timestamp: Date { get }
    
    /// Whether this command can be undone
    var isUndoable: Bool { get }
    
    /// Execute the command
    @MainActor
    func execute() async throws
    
    /// Undo the command (if supported)
    @MainActor
    func undo() async throws
    
    /// Whether this command can be merged with another command
    func canMergeWith(_ other: SlideshowCommand) -> Bool
    
    /// Merge this command with another (for command coalescing)
    func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand?
}

// MARK: - Command Context

/// Context information passed to commands for execution
public struct CommandContext {
    public let viewModel: any SlideshowViewModelProtocol
    public let settings: SettingsManagerBundle?
    public let telemetry: TelemetryService?
    public let logger: ProductionLogger.Type
    
    public init(
        viewModel: any SlideshowViewModelProtocol,
        settings: SettingsManagerBundle? = nil,
        telemetry: TelemetryService? = nil,
        logger: ProductionLogger.Type = ProductionLogger.self
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.telemetry = telemetry
        self.logger = logger
    }
}

// MARK: - Base Command Implementation

/// Base implementation for common command functionality
public struct BaseCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName: String
    public let timestamp = Date()
    public let isUndoable: Bool
    
    private let executeAction: @Sendable () async throws -> Void
    private let undoAction: (@Sendable () async throws -> Void)?
    
    public init(
        displayName: String,
        isUndoable: Bool = false,
        execute: @escaping @Sendable () async throws -> Void,
        undo: (@Sendable () async throws -> Void)? = nil
    ) {
        self.displayName = displayName
        self.isUndoable = isUndoable
        self.executeAction = execute
        self.undoAction = undo
    }
    
    @MainActor
    public func execute() async throws {
        try await executeAction()
    }
    
    @MainActor
    public func undo() async throws {
        guard isUndoable, let undoAction = undoAction else {
            throw CommandError.undoNotSupported
        }
        try await undoAction()
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false // Base commands don't support merging
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil // Base commands don't support merging
    }
}

// MARK: - Concrete Commands

/// Command to play the slideshow
@MainActor
public final class PlayCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName = "Play"
    public let timestamp = Date()
    public let isUndoable = true
    
    private let context: CommandContext
    private var wasPlaying = false
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func execute() async throws {
        wasPlaying = context.viewModel.slideshow?.isPlaying ?? false
        context.viewModel.play()
        context.logger.userAction("PlayCommand executed")
        context.telemetry?.recordEvent(.play)
    }
    
    public func undo() async throws {
        if !wasPlaying {
            context.viewModel.pause()
            context.logger.userAction("PlayCommand undone")
        }
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil
    }
}

/// Command to pause the slideshow
@MainActor
public final class PauseCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName = "Pause"
    public let timestamp = Date()
    public let isUndoable = true
    
    private let context: CommandContext
    private var wasPlaying = false
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func execute() async throws {
        wasPlaying = context.viewModel.slideshow?.isPlaying ?? false
        context.viewModel.pause()
        context.logger.userAction("PauseCommand executed")
        context.telemetry?.recordEvent(.pause)
    }
    
    public func undo() async throws {
        if wasPlaying {
            context.viewModel.play()
            context.logger.userAction("PauseCommand undone")
        }
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil
    }
}

/// Command to stop the slideshow
@MainActor
public final class StopCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName = "Stop"
    public let timestamp = Date()
    public let isUndoable = false // Stop is not undoable
    
    private let context: CommandContext
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func execute() async throws {
        context.viewModel.stop()
        context.logger.userAction("StopCommand executed")
        context.telemetry?.recordEvent(.stop)
    }
    
    public func undo() async throws {
        throw CommandError.undoNotSupported
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil
    }
}

/// Command to navigate to the next photo
@MainActor
public final class NextPhotoCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName = "Next Photo"
    public let timestamp = Date()
    public let isUndoable = true
    
    private let context: CommandContext
    private var previousIndex: Int = 0
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func execute() async throws {
        previousIndex = context.viewModel.slideshow?.currentIndex ?? 0
        await context.viewModel.nextPhoto()
        context.logger.userAction("NextPhotoCommand executed")
        context.telemetry?.recordEvent(.next)
    }
    
    public func undo() async throws {
        await context.viewModel.jumpToPhoto(at: previousIndex)
        context.logger.userAction("NextPhotoCommand undone")
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        // Merging disabled for MainActor isolation issues
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        // Merging disabled for MainActor isolation issues
        // We need to create the batch command in a MainActor context
        // For now, return nil to avoid the error - merging can be disabled for individual commands
        return nil
    }
}

/// Command to navigate to the previous photo
@MainActor
public final class PreviousPhotoCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName = "Previous Photo"
    public let timestamp = Date()
    public let isUndoable = true
    
    private let context: CommandContext
    private var previousIndex: Int = 0
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func execute() async throws {
        previousIndex = context.viewModel.slideshow?.currentIndex ?? 0
        await context.viewModel.previousPhoto()
        context.logger.userAction("PreviousPhotoCommand executed")
        context.telemetry?.recordEvent(.previous)
    }
    
    public func undo() async throws {
        await context.viewModel.jumpToPhoto(at: previousIndex)
        context.logger.userAction("PreviousPhotoCommand undone")
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        // Merging disabled for MainActor isolation issues
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        // Merging disabled for MainActor isolation issues
        // We need to create the batch command in a MainActor context
        // For now, return nil to avoid the error - merging can be disabled for individual commands
        return nil
    }
}

/// Command to jump to a specific photo
@MainActor
public final class JumpToPhotoCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName: String
    public let timestamp = Date()
    public let isUndoable = true
    
    private let context: CommandContext
    private let targetIndex: Int
    private var previousIndex: Int = 0
    
    public init(context: CommandContext, targetIndex: Int) {
        self.context = context
        self.targetIndex = targetIndex
        self.displayName = "Jump to Photo \(targetIndex + 1)"
    }
    
    public func execute() async throws {
        previousIndex = context.viewModel.slideshow?.currentIndex ?? 0
        await context.viewModel.jumpToPhoto(at: targetIndex)
        context.logger.userAction("JumpToPhotoCommand executed - target: \(targetIndex)")
        context.telemetry?.recordEvent(.jump(to: targetIndex))
    }
    
    public func undo() async throws {
        await context.viewModel.jumpToPhoto(at: previousIndex)
        context.logger.userAction("JumpToPhotoCommand undone")
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false // Jump commands shouldn't merge
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil
    }
}

/// Batch navigation command for merged next/previous operations
public final class NavigationBatchCommand: SlideshowCommand {
    public enum Direction: Sendable {
        case forward, backward
    }
    
    public let id = UUID()
    public let displayName: String
    public let timestamp = Date()
    public let isUndoable = true
    
    private let context: CommandContext
    private let steps: Int
    private let direction: Direction
    private var startIndex: Int = 0
    
    public init(context: CommandContext, steps: Int, direction: Direction) {
        self.context = context
        self.steps = steps
        self.direction = direction
        self.displayName = "\(direction == .forward ? "Next" : "Previous") \(steps) Photos"
    }
    
    @MainActor
    public func execute() async throws {
        startIndex = context.viewModel.slideshow?.currentIndex ?? 0
        
        for _ in 0..<steps {
            if direction == .forward {
                await context.viewModel.nextPhoto()
            } else {
                await context.viewModel.previousPhoto()
            }
        }
        
        context.logger.userAction("NavigationBatchCommand executed - \(steps) steps \(direction)")
    }
    
    @MainActor
    public func undo() async throws {
        await context.viewModel.jumpToPhoto(at: startIndex)
        context.logger.userAction("NavigationBatchCommand undone")
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        // Merging disabled for MainActor isolation issues
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        // Merging disabled for MainActor isolation issues
        
        // For NavigationBatchCommand, we can still merge, but we need to handle context access differently
        // For now, disable merging to avoid MainActor issues
        return nil
    }
}

/// Command to select a folder
@MainActor
public final class SelectFolderCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName = "Select Folder"
    public let timestamp = Date()
    public let isUndoable = false // Folder selection is not undoable
    
    private let context: CommandContext
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func execute() async throws {
        await context.viewModel.selectFolder()
        context.logger.userAction("SelectFolderCommand executed")
        context.telemetry?.recordEvent(.folderSelected)
    }
    
    public func undo() async throws {
        throw CommandError.undoNotSupported
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil
    }
}

// MARK: - Command Manager

/// Manages command execution, history, and undo/redo functionality
@MainActor
public class SlideshowCommandManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false
    @Published public private(set) var isExecuting = false
    @Published public private(set) var lastError: Error?
    
    // MARK: - Command History
    
    private var history: [SlideshowCommand] = []
    private var redoStack: [SlideshowCommand] = []
    private let maxHistorySize = 100
    
    // MARK: - Configuration
    
    private let enableCommandMerging: Bool
    private let enableMacroRecording: Bool
    private var isRecordingMacro = false
    private var currentMacro: [SlideshowCommand] = []
    
    // MARK: - Dependencies
    
    private let context: CommandContext
    
    // MARK: - Initialization
    
    public init(
        context: CommandContext,
        enableCommandMerging: Bool = true,
        enableMacroRecording: Bool = true
    ) {
        self.context = context
        self.enableCommandMerging = enableCommandMerging
        self.enableMacroRecording = enableMacroRecording
        
        ProductionLogger.lifecycle("SlideshowCommandManager initialized")
    }
    
    // MARK: - Command Execution
    
    /// Execute a command and add it to history
    public func execute(_ command: SlideshowCommand) async {
        guard !isExecuting else {
            ProductionLogger.warning("Command execution blocked - another command is executing")
            return
        }
        
        isExecuting = true
        defer { isExecuting = false }
        
        do {
            // Check for command merging
            if enableCommandMerging,
               let lastCommand = history.last,
               lastCommand.canMergeWith(command),
               let mergedCommand = lastCommand.mergeWith(command) {
                // Replace last command with merged version
                history.removeLast()
                try await mergedCommand.execute()
                history.append(mergedCommand)
                ProductionLogger.debug("Commands merged: \(lastCommand.displayName) + \(command.displayName)")
            } else {
                // Execute as normal
                try await command.execute()
                history.append(command)
            }
            
            // Clear redo stack when new command is executed
            redoStack.removeAll()
            
            // Record to macro if recording
            if isRecordingMacro {
                currentMacro.append(command)
            }
            
            // Trim history if needed
            if history.count > maxHistorySize {
                history.removeFirst(history.count - maxHistorySize)
            }
            
            updateCanUndoRedo()
            lastError = nil
            
        } catch {
            lastError = error
            ProductionLogger.error("Command execution failed: \(error)")
        }
    }
    
    /// Undo the last command
    public func undo() async {
        guard canUndo, !isExecuting else { return }
        
        isExecuting = true
        defer { isExecuting = false }
        
        guard let command = history.popLast() else { return }
        
        do {
            try await command.undo()
            redoStack.append(command)
            updateCanUndoRedo()
            ProductionLogger.userAction("Command undone: \(command.displayName)")
        } catch {
            // Re-add command to history if undo fails
            history.append(command)
            lastError = error
            ProductionLogger.error("Undo failed: \(error)")
        }
    }
    
    /// Redo the last undone command
    public func redo() async {
        guard canRedo, !isExecuting else { return }
        
        isExecuting = true
        defer { isExecuting = false }
        
        guard let command = redoStack.popLast() else { return }
        
        do {
            try await command.execute()
            history.append(command)
            updateCanUndoRedo()
            ProductionLogger.userAction("Command redone: \(command.displayName)")
        } catch {
            // Re-add command to redo stack if redo fails
            redoStack.append(command)
            lastError = error
            ProductionLogger.error("Redo failed: \(error)")
        }
    }
    
    // MARK: - History Management
    
    /// Clear all command history
    public func clearHistory() {
        history.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
        ProductionLogger.debug("Command history cleared")
    }
    
    /// Get displayable command history
    public func getHistory() -> [CommandHistoryItem] {
        return history.enumerated().map { index, command in
            CommandHistoryItem(
                index: index,
                command: command,
                canUndo: command.isUndoable
            )
        }
    }
    
    // MARK: - Macro Recording
    
    /// Start recording a macro
    public func startMacroRecording() {
        guard enableMacroRecording else { return }
        isRecordingMacro = true
        currentMacro.removeAll()
        ProductionLogger.debug("Macro recording started")
    }
    
    /// Stop recording and return the macro
    public func stopMacroRecording() -> MacroCommand? {
        guard enableMacroRecording, isRecordingMacro else { return nil }
        
        isRecordingMacro = false
        let macro = MacroCommand(
            displayName: "Recorded Macro",
            commands: currentMacro,
            context: context
        )
        currentMacro.removeAll()
        
        ProductionLogger.debug("Macro recording stopped - \(macro.commands.count) commands")
        return macro
    }
    
    // MARK: - Private Methods
    
    private func updateCanUndoRedo() {
        canUndo = history.contains { $0.isUndoable }
        canRedo = !redoStack.isEmpty
    }
}

// MARK: - Macro Command

/// Command that executes a sequence of other commands
@MainActor
public final class MacroCommand: SlideshowCommand {
    public let id = UUID()
    public let displayName: String
    public let timestamp = Date()
    public let isUndoable = true
    
    let commands: [SlideshowCommand]
    private let context: CommandContext
    
    public init(displayName: String, commands: [SlideshowCommand], context: CommandContext) {
        self.displayName = displayName
        self.commands = commands
        self.context = context
    }
    
    public func execute() async throws {
        context.logger.userAction("Executing macro: \(displayName) with \(commands.count) commands")
        
        for command in commands {
            try await command.execute()
        }
    }
    
    public func undo() async throws {
        context.logger.userAction("Undoing macro: \(displayName)")
        
        // Undo in reverse order
        for command in commands.reversed() where command.isUndoable {
            try await command.undo()
        }
    }
    
    nonisolated public func canMergeWith(_ other: SlideshowCommand) -> Bool {
        return false // Macros don't merge
    }
    
    nonisolated public func mergeWith(_ other: SlideshowCommand) -> SlideshowCommand? {
        return nil
    }
}

// MARK: - Supporting Types

/// Error types for command execution
public enum CommandError: LocalizedError {
    case undoNotSupported
    case executionFailed(reason: String)
    case invalidState
    
    public var errorDescription: String? {
        switch self {
        case .undoNotSupported:
            return "This command cannot be undone"
        case .executionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .invalidState:
            return "Command cannot be executed in current state"
        }
    }
}

/// Item in command history for display
public struct CommandHistoryItem: Identifiable {
    public let id = UUID()
    public let index: Int
    public let command: SlideshowCommand
    public let canUndo: Bool
}

// MARK: - Telemetry Extension

extension TelemetryService {
    /// Telemetry event types for commands
    public enum CommandEvent {
        case play
        case pause
        case stop
        case next
        case previous
        case jump(to: Int)
        case folderSelected
    }
    
    public func recordEvent(_ event: CommandEvent) {
        // Implementation would record telemetry data
        // This is a placeholder for the actual telemetry implementation
    }
}

// MARK: - Command Factory

/// Factory for creating commands with proper context
@MainActor
public struct SlideshowCommandFactory {
    private let context: CommandContext
    
    public init(context: CommandContext) {
        self.context = context
    }
    
    public func makePlayCommand() -> SlideshowCommand {
        return PlayCommand(context: context)
    }
    
    public func makePauseCommand() -> SlideshowCommand {
        return PauseCommand(context: context)
    }
    
    public func makeStopCommand() -> SlideshowCommand {
        return StopCommand(context: context)
    }
    
    public func makeNextPhotoCommand() -> SlideshowCommand {
        return NextPhotoCommand(context: context)
    }
    
    public func makePreviousPhotoCommand() -> SlideshowCommand {
        return PreviousPhotoCommand(context: context)
    }
    
    public func makeJumpToPhotoCommand(index: Int) -> SlideshowCommand {
        return JumpToPhotoCommand(context: context, targetIndex: index)
    }
    
    public func makeSelectFolderCommand() -> SlideshowCommand {
        return SelectFolderCommand(context: context)
    }
    
    public func makeMacroCommand(name: String, commands: [SlideshowCommand]) -> SlideshowCommand {
        return MacroCommand(displayName: name, commands: commands, context: context)
    }
}