//
//  UnifiedTooltipSystem.swift
//  Swift Photos
//
//  Unified tooltip system consolidating all tooltip implementations
//  Phase 3.1: View Layer Consolidation - Tooltip Unification
//

import SwiftUI

// MARK: - Tooltip Model

/// Data model for tooltip content and configuration
public struct TooltipModel {
    public let text: String
    public let shortcut: String?
    public let style: TooltipStyle
    public let placement: TooltipPlacement
    public let showDelay: TimeInterval
    public let hideDelay: TimeInterval
    
    public init(
        text: String,
        shortcut: String? = nil,
        style: TooltipStyle = .standard,
        placement: TooltipPlacement = .top,
        showDelay: TimeInterval = 0.5,
        hideDelay: TimeInterval = 0.1
    ) {
        self.text = text
        self.shortcut = shortcut
        self.style = style
        self.placement = placement
        self.showDelay = showDelay
        self.hideDelay = hideDelay
    }
    
    // Convenience initializers
    public static func quick(_ text: String, shortcut: String? = nil) -> TooltipModel {
        TooltipModel(text: text, shortcut: shortcut, showDelay: 0.2)
    }
    
    public static func delayed(_ text: String, shortcut: String? = nil) -> TooltipModel {
        TooltipModel(text: text, shortcut: shortcut, showDelay: 1.0)
    }
}

// MARK: - Tooltip Styles

public enum TooltipStyle {
    case standard
    case compact
    case prominent
    case glassmorphic
    case minimal
    
    var backgroundColor: Color {
        switch self {
        case .standard: return DesignTokens.Colors.tooltipBackground
        case .compact: return DesignTokens.Colors.tooltipBackground.opacity(0.9)
        case .prominent: return DesignTokens.Colors.tooltipBackground
        case .glassmorphic: return DesignTokens.Colors.glassFill
        case .minimal: return Color.clear
        }
    }
    
    var textColor: Color {
        switch self {
        case .standard, .compact, .prominent: return DesignTokens.Colors.interactive
        case .glassmorphic: return DesignTokens.Colors.interactive
        case .minimal: return DesignTokens.Colors.interactiveSecondary
        }
    }
    
    var font: Font {
        switch self {
        case .standard, .glassmorphic: return DesignTokens.Typography.caption
        case .compact: return DesignTokens.Typography.caption2
        case .prominent: return DesignTokens.Typography.footnote
        case .minimal: return DesignTokens.Typography.caption2
        }
    }
    
    var shortcutFont: Font {
        switch self {
        case .standard, .glassmorphic: return DesignTokens.Typography.monospaceSmall
        case .compact: return Font.system(.caption2, design: .monospaced)
        case .prominent: return DesignTokens.Typography.monospace
        case .minimal: return Font.system(.caption2, design: .monospaced)
        }
    }
    
    var paddingValue: CGFloat {
        switch self {
        case .standard: return DesignTokens.Spacing.xxSmall
        case .compact: return DesignTokens.Spacing.xxxSmall
        case .prominent: return DesignTokens.Spacing.xSmall
        case .glassmorphic: return DesignTokens.Spacing.xxSmall
        case .minimal: return DesignTokens.Spacing.xxxSmall
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .standard: return DesignTokens.CornerRadius.tooltip
        case .compact: return DesignTokens.CornerRadius.small
        case .prominent: return DesignTokens.CornerRadius.medium
        case .glassmorphic: return DesignTokens.CornerRadius.medium
        case .minimal: return 0
        }
    }
    
    var hasBorder: Bool {
        switch self {
        case .standard, .prominent: return true
        case .compact, .glassmorphic, .minimal: return false
        }
    }
    
    var hasBackground: Bool {
        switch self {
        case .standard, .compact, .prominent, .glassmorphic: return true
        case .minimal: return false
        }
    }
}

// MARK: - Tooltip Placement

public enum TooltipPlacement {
    case top, bottom, leading, trailing
    case topLeading, topTrailing
    case bottomLeading, bottomTrailing
    
    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }
    
    var offset: CGSize {
        switch self {
        case .top: return CGSize(width: 0, height: -8)
        case .bottom: return CGSize(width: 0, height: 8)
        case .leading: return CGSize(width: -8, height: 0)
        case .trailing: return CGSize(width: 8, height: 0)
        case .topLeading: return CGSize(width: -8, height: -8)
        case .topTrailing: return CGSize(width: 8, height: -8)
        case .bottomLeading: return CGSize(width: -8, height: 8)
        case .bottomTrailing: return CGSize(width: 8, height: 8)
        }
    }
}

// MARK: - Unified Tooltip View

/// The unified tooltip view that renders all tooltip styles
public struct UnifiedTooltipView: View {
    let model: TooltipModel
    
    public init(model: TooltipModel) {
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxxSmall) {
            Text(model.text)
                .font(model.style.font)
                .foregroundColor(model.style.textColor)
            
            if let shortcut = model.shortcut {
                Text(shortcut)
                    .font(model.style.shortcutFont)
                    .foregroundColor(model.style.textColor.opacity(0.8))
                    .padding(.horizontal, DesignTokens.Spacing.xxxSmall)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignTokens.Colors.interactive.opacity(0.1))
                    )
            }
        }
        .padding(model.style.paddingValue)
        .background(tooltipBackground)
        .cornerRadius(model.style.cornerRadius)
        .overlay(tooltipBorder)
        .shadow(color: DesignTokens.Shadows.tooltip, radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var tooltipBackground: some View {
        if model.style.hasBackground {
            if model.style == .glassmorphic {
                Rectangle()
                    .fill(Material.ultraThinMaterial)
                    .overlay(model.style.backgroundColor)
            } else {
                Rectangle()
                    .fill(model.style.backgroundColor)
            }
        }
    }
    
    @ViewBuilder
    private var tooltipBorder: some View {
        if model.style.hasBorder {
            RoundedRectangle(cornerRadius: model.style.cornerRadius)
                .stroke(DesignTokens.Colors.border, lineWidth: 0.5)
        }
    }
}

// MARK: - Unified Tooltip Modifier

/// The unified tooltip modifier that handles showing/hiding tooltips
public struct UnifiedTooltipModifier: ViewModifier {
    let model: TooltipModel
    @State private var isHovering: Bool = false
    @State private var showTask: Task<Void, Never>?
    @State private var hideTask: Task<Void, Never>?
    
    public init(model: TooltipModel) {
        self.model = model
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: model.placement.alignment) {
                if isHovering {
                    UnifiedTooltipView(model: model)
                        .offset(model.placement.offset)
                        .transition(.asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.8))
                                .animation(DesignTokens.Animation.tooltip),
                            removal: .opacity
                                .animation(DesignTokens.Animation.fast)
                        ))
                        .zIndex(1000) // Ensure tooltip appears above other content
                }
            }
            .onHover { hovering in
                handleHover(hovering)
            }
    }
    
    private func handleHover(_ hovering: Bool) {
        // Cancel any pending tasks
        showTask?.cancel()
        hideTask?.cancel()
        
        if hovering {
            // Show tooltip after delay
            showTask = Task {
                try? await Task.sleep(for: .seconds(model.showDelay))
                if !Task.isCancelled {
                    withAnimation {
                        isHovering = true
                    }
                }
            }
        } else {
            // Hide tooltip after delay
            hideTask = Task {
                try? await Task.sleep(for: .seconds(model.hideDelay))
                if !Task.isCancelled {
                    withAnimation {
                        isHovering = false
                    }
                }
            }
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply unified tooltip to any view
    func tooltip(_ model: TooltipModel) -> some View {
        modifier(UnifiedTooltipModifier(model: model))
    }
    
    /// Quick tooltip with text only
    func tooltip(_ text: String) -> some View {
        tooltip(TooltipModel(text: text))
    }
    
    /// Quick tooltip with text and keyboard shortcut
    func tooltip(_ text: String, shortcut: String) -> some View {
        tooltip(TooltipModel(text: text, shortcut: shortcut))
    }
    
    /// Quick tooltip with custom style
    func tooltip(_ text: String, style: TooltipStyle) -> some View {
        tooltip(TooltipModel(text: text, style: style))
    }
    
    /// Quick tooltip with text, shortcut, and placement
    func tooltip(_ text: String, shortcut: String? = nil, placement: TooltipPlacement) -> some View {
        tooltip(TooltipModel(text: text, shortcut: shortcut, placement: placement))
    }
}

// MARK: - Legacy Compatibility

/// Compatibility wrapper for existing ShortcutTooltip usage
@available(*, deprecated, message: "Use tooltip(_:) modifier instead")
public struct LegacyShortcutTooltip: ViewModifier {
    let text: String
    let shortcut: String
    
    public init(text: String, shortcut: String) {
        self.text = text
        self.shortcut = shortcut
    }
    
    public func body(content: Content) -> some View {
        content.tooltip(TooltipModel(text: text, shortcut: shortcut))
    }
}

// Note: shortcutTooltip(_:shortcut:) already exists in TooltipView.swift
// Use the new tooltip(_:shortcut:) method instead for new implementations