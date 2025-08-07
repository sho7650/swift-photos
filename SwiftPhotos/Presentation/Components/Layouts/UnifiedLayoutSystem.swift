//
//  UnifiedLayoutSystem.swift
//  Swift Photos
//
//  Unified layout container system consolidating common layout patterns
//  Phase 3.2: Presentation Layer Optimization - Layout Commonalization
//

import SwiftUI

// MARK: - Layout Configuration

/// Configuration for unified layout containers
public struct LayoutConfiguration: Sendable {
    public let spacing: LayoutSpacing
    public let alignment: LayoutAlignment
    public let padding: LayoutPadding
    public let scrolling: ScrollingBehavior
    public let background: BackgroundStyle
    
    public init(
        spacing: LayoutSpacing = .standard,
        alignment: LayoutAlignment = .standard,
        padding: LayoutPadding = .standard,
        scrolling: ScrollingBehavior = .none,
        background: BackgroundStyle = .none
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.padding = padding
        self.scrolling = scrolling
        self.background = background
    }
}

// MARK: - Layout Types

public enum LayoutSpacing: Sendable {
    case none
    case xxxSmall  // 4pt
    case xxSmall   // 8pt
    case xSmall    // 12pt
    case small     // 16pt
    case standard  // 24pt
    case medium    // 32pt
    case large     // 48pt
    case custom(CGFloat)
    
    var value: CGFloat {
        switch self {
        case .none: return 0
        case .xxxSmall: return DesignTokens.Spacing.xxxSmall
        case .xxSmall: return DesignTokens.Spacing.xxSmall
        case .xSmall: return DesignTokens.Spacing.xSmall
        case .small: return DesignTokens.Spacing.small
        case .standard: return DesignTokens.Spacing.medium
        case .medium: return DesignTokens.Spacing.large
        case .large: return DesignTokens.Spacing.xLarge
        case .custom(let value): return value
        }
    }
}

public enum LayoutAlignment: Sendable {
    case leading
    case center
    case trailing
    case standard
    case justified
    
    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center, .standard: return .center
        case .trailing: return .trailing
        case .justified: return .center
        }
    }
    
    var vertical: VerticalAlignment {
        switch self {
        case .leading: return .top
        case .center, .standard: return .center
        case .trailing: return .bottom
        case .justified: return .center
        }
    }
}

public enum LayoutPadding: Sendable {
    case none
    case minimal    // 8pt
    case standard   // 16pt
    case generous   // 24pt
    case custom(EdgeInsets)
    case symmetric(horizontal: CGFloat, vertical: CGFloat)
    
    var edgeInsets: EdgeInsets {
        switch self {
        case .none: return EdgeInsets()
        case .minimal: return EdgeInsets(
            top: DesignTokens.Spacing.xxSmall,
            leading: DesignTokens.Spacing.xxSmall,
            bottom: DesignTokens.Spacing.xxSmall,
            trailing: DesignTokens.Spacing.xxSmall
        )
        case .standard: return EdgeInsets(
            top: DesignTokens.Spacing.small,
            leading: DesignTokens.Spacing.small,
            bottom: DesignTokens.Spacing.small,
            trailing: DesignTokens.Spacing.small
        )
        case .generous: return EdgeInsets(
            top: DesignTokens.Spacing.medium,
            leading: DesignTokens.Spacing.medium,
            bottom: DesignTokens.Spacing.medium,
            trailing: DesignTokens.Spacing.medium
        )
        case .custom(let insets): return insets
        case .symmetric(let horizontal, let vertical): return EdgeInsets(
            top: vertical,
            leading: horizontal,
            bottom: vertical,
            trailing: horizontal
        )
        }
    }
}

public enum ScrollingBehavior: Sendable {
    case none
    case vertical
    case horizontal
    case both
    case adaptive
    
    var axes: Axis.Set {
        switch self {
        case .none: return []
        case .vertical: return .vertical
        case .horizontal: return .horizontal
        case .both, .adaptive: return [.horizontal, .vertical]
        }
    }
}

public enum BackgroundStyle: Sendable {
    case none
    case standard
    case card
    case overlay
    case glassmorphic
    case custom(Color)
    
    @ViewBuilder
    var background: some View {
        switch self {
        case .none:
            EmptyView()
        case .standard:
            Rectangle()
                .fill(DesignTokens.Colors.secondaryBackground)
        case .card:
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                .fill(DesignTokens.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                        .stroke(DesignTokens.Colors.border, lineWidth: 1)
                )
        case .overlay:
            Rectangle()
                .fill(DesignTokens.Colors.overlayBackground)
        case .glassmorphic:
            Rectangle()
                .fill(Material.ultraThinMaterial)
                .overlay(DesignTokens.Colors.glassFill)
        case .custom(let color):
            Rectangle()
                .fill(color)
        }
    }
}

// MARK: - Unified Layout Containers

/// Vertical layout container with consistent spacing and styling
public struct UnifiedVContainer<Content: View>: View {
    let configuration: LayoutConfiguration
    let content: Content
    
    public init(
        configuration: LayoutConfiguration = LayoutConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.content = content()
    }
    
    public var body: some View {
        containerBody(
            VStack(alignment: configuration.alignment.horizontal, spacing: configuration.spacing.value) {
                content
            }
        )
    }
    
    @ViewBuilder
    private func containerBody<Container: View>(_ container: Container) -> some View {
        if configuration.scrolling != .none {
            ScrollView(configuration.scrolling.axes, showsIndicators: false) {
                container
                    .padding(.top, configuration.padding.edgeInsets.top)
                    .padding(.leading, configuration.padding.edgeInsets.leading)
                    .padding(.bottom, configuration.padding.edgeInsets.bottom)
                    .padding(.trailing, configuration.padding.edgeInsets.trailing)
            }
            .background(configuration.background.background)
        } else {
            container
                .padding(.top, configuration.padding.edgeInsets.top)
                .padding(.leading, configuration.padding.edgeInsets.leading)
                .padding(.bottom, configuration.padding.edgeInsets.bottom)
                .padding(.trailing, configuration.padding.edgeInsets.trailing)
                .background(configuration.background.background)
        }
    }
}

/// Horizontal layout container with consistent spacing and styling
public struct UnifiedHContainer<Content: View>: View {
    let configuration: LayoutConfiguration
    let content: Content
    
    public init(
        configuration: LayoutConfiguration = LayoutConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.content = content()
    }
    
    public var body: some View {
        containerBody(
            HStack(alignment: configuration.alignment.vertical, spacing: configuration.spacing.value) {
                content
            }
        )
    }
    
    @ViewBuilder
    private func containerBody<Container: View>(_ container: Container) -> some View {
        if configuration.scrolling != .none {
            ScrollView(configuration.scrolling.axes, showsIndicators: false) {
                container
                    .padding(.top, configuration.padding.edgeInsets.top)
                    .padding(.leading, configuration.padding.edgeInsets.leading)
                    .padding(.bottom, configuration.padding.edgeInsets.bottom)
                    .padding(.trailing, configuration.padding.edgeInsets.trailing)
            }
            .background(configuration.background.background)
        } else {
            container
                .padding(.top, configuration.padding.edgeInsets.top)
                .padding(.leading, configuration.padding.edgeInsets.leading)
                .padding(.bottom, configuration.padding.edgeInsets.bottom)
                .padding(.trailing, configuration.padding.edgeInsets.trailing)
                .background(configuration.background.background)
        }
    }
}

/// Grid layout container with adaptive columns
public struct UnifiedGridContainer<Content: View>: View {
    let configuration: LayoutConfiguration
    let columns: [GridItem]
    let content: Content
    
    public init(
        configuration: LayoutConfiguration = LayoutConfiguration(),
        columns: [GridItem] = [GridItem(.adaptive(minimum: 200))],
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.columns = columns
        self.content = content()
    }
    
    public var body: some View {
        containerBody(
            LazyVGrid(columns: columns, spacing: configuration.spacing.value) {
                content
            }
        )
    }
    
    @ViewBuilder
    private func containerBody<Container: View>(_ container: Container) -> some View {
        if configuration.scrolling != .none {
            ScrollView(configuration.scrolling.axes, showsIndicators: false) {
                container
                    .padding(.top, configuration.padding.edgeInsets.top)
                    .padding(.leading, configuration.padding.edgeInsets.leading)
                    .padding(.bottom, configuration.padding.edgeInsets.bottom)
                    .padding(.trailing, configuration.padding.edgeInsets.trailing)
            }
            .background(configuration.background.background)
        } else {
            container
                .padding(.top, configuration.padding.edgeInsets.top)
                .padding(.leading, configuration.padding.edgeInsets.leading)
                .padding(.bottom, configuration.padding.edgeInsets.bottom)
                .padding(.trailing, configuration.padding.edgeInsets.trailing)
                .background(configuration.background.background)
        }
    }
}

/// Settings page container with consistent styling
public struct SettingsContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    
    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    public var body: some View {
        UnifiedVContainer(
            configuration: LayoutConfiguration(
                spacing: .standard,
                padding: .generous,
                scrolling: .vertical,
                background: .none
            )
        ) {
            // Header
            UnifiedVContainer(
                configuration: LayoutConfiguration(
                    spacing: .xxSmall,
                    alignment: .leading,
                    padding: .none
                )
            ) {
                Text(title)
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Colors.interactive)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.interactiveSecondary)
                }
            }
            
            Divider()
                .background(DesignTokens.Colors.border)
            
            // Content
            content
        }
    }
}

/// Control panel container for buttons and controls
public struct ControlsContainer<Content: View>: View {
    let configuration: LayoutConfiguration
    let content: Content
    
    public init(
        configuration: LayoutConfiguration = LayoutConfiguration(
            spacing: .small,
            padding: .standard,
            background: .glassmorphic
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.content = content()
    }
    
    public var body: some View {
        UnifiedHContainer(configuration: configuration) {
            content
        }
        .cornerRadius(DesignTokens.CornerRadius.medium)
        .shadow(color: DesignTokens.Shadows.medium, radius: 4, x: 0, y: 2)
    }
}

/// Information display container with optional header
public struct InfoContainer<Content: View>: View {
    let title: String?
    let icon: String?
    let content: Content
    
    public init(
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    public var body: some View {
        UnifiedVContainer(
            configuration: LayoutConfiguration(
                spacing: .small,
                padding: .standard,
                background: .card
            )
        ) {
            if title != nil || icon != nil {
                UnifiedHContainer(
                    configuration: LayoutConfiguration(
                        spacing: .xxSmall,
                        alignment: .leading,
                        padding: .none
                    )
                ) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(DesignTokens.Typography.title3)
                            .foregroundColor(DesignTokens.Colors.accent)
                    }
                    
                    if let title = title {
                        Text(title)
                            .font(DesignTokens.Typography.bodyEmphasized)
                            .foregroundColor(DesignTokens.Colors.interactive)
                    }
                    
                    Spacer()
                }
            }
            
            content
        }
        .cornerRadius(DesignTokens.CornerRadius.card)
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply unified vertical layout
    func unifiedVLayout(
        spacing: LayoutSpacing = .standard,
        alignment: LayoutAlignment = .standard,
        padding: LayoutPadding = .standard
    ) -> some View {
        UnifiedVContainer(
            configuration: LayoutConfiguration(
                spacing: spacing,
                alignment: alignment,
                padding: padding
            )
        ) {
            self
        }
    }
    
    /// Apply unified horizontal layout
    func unifiedHLayout(
        spacing: LayoutSpacing = .standard,
        alignment: LayoutAlignment = .standard,
        padding: LayoutPadding = .standard
    ) -> some View {
        UnifiedHContainer(
            configuration: LayoutConfiguration(
                spacing: spacing,
                alignment: alignment,
                padding: padding
            )
        ) {
            self
        }
    }
    
    /// Apply settings page styling
    func settingsPage(title: String, subtitle: String? = nil) -> some View {
        SettingsContainer(title: title, subtitle: subtitle) {
            self
        }
    }
    
    /// Apply controls styling
    func controlsPanel() -> some View {
        ControlsContainer {
            self
        }
    }
    
    /// Apply info container styling
    func infoContainer(title: String? = nil, icon: String? = nil) -> some View {
        InfoContainer(title: title, icon: icon) {
            self
        }
    }
}

// MARK: - Predefined Configurations

public extension LayoutConfiguration {
    /// Standard settings section layout
    static let settingsSection = LayoutConfiguration(
        spacing: .small,
        alignment: .leading,
        padding: .standard,
        scrolling: .none,
        background: .none
    )
    
    /// Control button layout
    static let controls = LayoutConfiguration(
        spacing: .small,
        alignment: .center,
        padding: .minimal,
        scrolling: .none,
        background: .glassmorphic
    )
    
    /// Information display layout
    static let info = LayoutConfiguration(
        spacing: .xxSmall,
        alignment: .leading,
        padding: .standard,
        scrolling: .vertical,
        background: .card
    )
    
    /// Compact horizontal layout
    static let compactHorizontal = LayoutConfiguration(
        spacing: .xxSmall,
        alignment: .center,
        padding: .minimal,
        scrolling: .none,
        background: .none
    )
    
    /// Spacious vertical layout
    static let spaciousVertical = LayoutConfiguration(
        spacing: .medium,
        alignment: .leading,
        padding: .generous,
        scrolling: .vertical,
        background: .none
    )
}

// MARK: - Legacy Compatibility

/// Migration helpers for existing layout patterns
public extension View {
    @available(*, deprecated, message: "Use UnifiedVContainer instead")
    func legacyVStack(spacing: CGFloat) -> some View {
        UnifiedVContainer(
            configuration: LayoutConfiguration(
                spacing: .custom(spacing),
                padding: .none
            )
        ) {
            self
        }
    }
    
    @available(*, deprecated, message: "Use UnifiedHContainer instead")
    func legacyHStack(spacing: CGFloat) -> some View {
        UnifiedHContainer(
            configuration: LayoutConfiguration(
                spacing: .custom(spacing),
                padding: .none
            )
        ) {
            self
        }
    }
}