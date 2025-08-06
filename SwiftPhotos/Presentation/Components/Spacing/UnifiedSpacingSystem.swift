//
//  UnifiedSpacingSystem.swift
//  Swift Photos
//
//  Unified spacing and positioning system based on DesignTokens
//  Phase 3.2: Presentation Layer Optimization - Spacing Consolidation
//

import SwiftUI

// MARK: - Spacing Configuration

/// Comprehensive spacing configuration using design tokens
public struct SpacingConfiguration: Sendable {
    public let insets: SpacingInsets
    public let gaps: SpacingGaps
    public let positioning: PositioningBehavior
    public let responsive: ResponsiveBehavior
    
    public init(
        insets: SpacingInsets = .standard,
        gaps: SpacingGaps = .standard,
        positioning: PositioningBehavior = .automatic,
        responsive: ResponsiveBehavior = .adaptive
    ) {
        self.insets = insets
        self.gaps = gaps
        self.positioning = positioning
        self.responsive = responsive
    }
}

// MARK: - Spacing Types

public enum SpacingInsets: Sendable {
    case none
    case minimal     // 4pt all sides
    case compact     // 8pt all sides
    case standard    // 16pt all sides
    case generous    // 24pt all sides
    case spacious    // 32pt all sides
    case asymmetric(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat)
    case horizontal(CGFloat)
    case vertical(CGFloat)
    case custom(EdgeInsets)
    
    public var edgeInsets: EdgeInsets {
        switch self {
        case .none:
            return EdgeInsets()
        case .minimal:
            return EdgeInsets(
                top: DesignTokens.Spacing.xxxSmall,
                leading: DesignTokens.Spacing.xxxSmall,
                bottom: DesignTokens.Spacing.xxxSmall,
                trailing: DesignTokens.Spacing.xxxSmall
            )
        case .compact:
            return EdgeInsets(
                top: DesignTokens.Spacing.xxSmall,
                leading: DesignTokens.Spacing.xxSmall,
                bottom: DesignTokens.Spacing.xxSmall,
                trailing: DesignTokens.Spacing.xxSmall
            )
        case .standard:
            return EdgeInsets(
                top: DesignTokens.Spacing.small,
                leading: DesignTokens.Spacing.small,
                bottom: DesignTokens.Spacing.small,
                trailing: DesignTokens.Spacing.small
            )
        case .generous:
            return EdgeInsets(
                top: DesignTokens.Spacing.medium,
                leading: DesignTokens.Spacing.medium,
                bottom: DesignTokens.Spacing.medium,
                trailing: DesignTokens.Spacing.medium
            )
        case .spacious:
            return EdgeInsets(
                top: DesignTokens.Spacing.large,
                leading: DesignTokens.Spacing.large,
                bottom: DesignTokens.Spacing.large,
                trailing: DesignTokens.Spacing.large
            )
        case .asymmetric(let top, let leading, let bottom, let trailing):
            return EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        case .horizontal(let value):
            return EdgeInsets(top: 0, leading: value, bottom: 0, trailing: value)
        case .vertical(let value):
            return EdgeInsets(top: value, leading: 0, bottom: value, trailing: 0)
        case .custom(let insets):
            return insets
        }
    }
}

public enum SpacingGaps: Sendable {
    case none        // 0pt
    case tight       // 4pt
    case compact     // 8pt
    case standard    // 16pt
    case comfortable // 24pt
    case spacious    // 32pt
    case loose       // 48pt
    case custom(CGFloat)
    
    public var value: CGFloat {
        switch self {
        case .none: return 0
        case .tight: return DesignTokens.Spacing.xxxSmall
        case .compact: return DesignTokens.Spacing.xxSmall
        case .standard: return DesignTokens.Spacing.small
        case .comfortable: return DesignTokens.Spacing.medium
        case .spacious: return DesignTokens.Spacing.large
        case .loose: return DesignTokens.Spacing.xLarge
        case .custom(let value): return value
        }
    }
}

public enum PositioningBehavior: Sendable {
    case automatic
    case fixed(x: CGFloat, y: CGFloat)
    case relative(x: CGFloat, y: CGFloat)
    case centered
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case customAlignment(Alignment)
    
    var alignment: Alignment {
        switch self {
        case .automatic, .fixed, .relative: return .center
        case .centered: return .center
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        case .customAlignment(let alignment): return alignment
        }
    }
    
    var offset: CGSize {
        switch self {
        case .automatic, .centered, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing, .customAlignment:
            return .zero
        case .fixed(let x, let y), .relative(let x, let y):
            return CGSize(width: x, height: y)
        }
    }
}

public indirect enum ResponsiveBehavior: Sendable {
    case fixed
    case adaptive
    case sizeClassBased
    case custom(compact: SpacingConfiguration, regular: SpacingConfiguration)
    
    func configuration(for sizeClass: UserInterfaceSizeClass?) -> SpacingConfiguration? {
        switch self {
        case .fixed, .adaptive:
            return nil
        case .sizeClassBased:
            return sizeClass == .compact ? 
                SpacingConfiguration(insets: .compact, gaps: .compact) :
                SpacingConfiguration(insets: .standard, gaps: .standard)
        case .custom(let compact, let regular):
            return sizeClass == .compact ? compact : regular
        }
    }
}

// MARK: - Unified Spacing Modifier

/// ViewModifier that applies unified spacing and positioning
public struct UnifiedSpacingModifier: ViewModifier {
    let configuration: SpacingConfiguration
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(configuration: SpacingConfiguration) {
        self.configuration = configuration
    }
    
    public func body(content: Content) -> some View {
        let effectiveConfig = effectiveConfiguration
        
        content
            .padding(.top, effectiveConfig.insets.edgeInsets.top)
            .padding(.leading, effectiveConfig.insets.edgeInsets.leading)
            .padding(.bottom, effectiveConfig.insets.edgeInsets.bottom)
            .padding(.trailing, effectiveConfig.insets.edgeInsets.trailing)
            .offset(effectiveConfig.positioning.offset)
    }
    
    private var effectiveConfiguration: SpacingConfiguration {
        if let responsiveConfig = configuration.responsive.configuration(for: horizontalSizeClass) {
            return responsiveConfig
        }
        return configuration
    }
}

// MARK: - Stack Spacing Modifiers

/// Unified VStack with consistent spacing
public struct UnifiedVStack<Content: View>: View {
    let spacing: SpacingGaps
    let alignment: HorizontalAlignment
    let content: Content
    
    public init(
        spacing: SpacingGaps = .standard,
        alignment: HorizontalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: spacing.value) {
            content
        }
    }
}

/// Unified HStack with consistent spacing
public struct UnifiedHStack<Content: View>: View {
    let spacing: SpacingGaps
    let alignment: VerticalAlignment
    let content: Content
    
    public init(
        spacing: SpacingGaps = .standard,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content()
    }
    
    public var body: some View {
        HStack(alignment: alignment, spacing: spacing.value) {
            content
        }
    }
}

/// Unified LazyVGrid with consistent spacing
public struct UnifiedLazyVGrid<Content: View>: View {
    let columns: [GridItem]
    let spacing: SpacingGaps
    let content: Content
    
    public init(
        columns: [GridItem],
        spacing: SpacingGaps = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        LazyVGrid(columns: columns, spacing: spacing.value) {
            content
        }
    }
}

// MARK: - Spacer Components

/// Unified spacer with design token values
public struct UnifiedSpacer: View {
    let size: SpacingGaps
    let axis: Axis
    
    public init(size: SpacingGaps = .standard, axis: Axis = .vertical) {
        self.size = size
        self.axis = axis
    }
    
    public var body: some View {
        switch axis {
        case .vertical:
            Spacer()
                .frame(height: size.value)
        case .horizontal:
            Spacer()
                .frame(width: size.value)
        }
    }
}

/// Fixed spacer with specific size
public struct FixedSpacer: View {
    let width: CGFloat?
    let height: CGFloat?
    
    public init(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: width, height: height)
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply unified spacing configuration
    func unifiedSpacing(_ configuration: SpacingConfiguration) -> some View {
        modifier(UnifiedSpacingModifier(configuration: configuration))
    }
    
    /// Apply standard app padding
    func appPadding(_ insets: SpacingInsets = .standard) -> some View {
        let edgeInsets = insets.edgeInsets
        return self
            .padding(.top, edgeInsets.top)
            .padding(.leading, edgeInsets.leading)
            .padding(.bottom, edgeInsets.bottom)
            .padding(.trailing, edgeInsets.trailing)
    }
    
    /// Apply semantic padding for specific contexts
    func controlPadding() -> some View {
        let edgeInsets = SpacingInsets.compact.edgeInsets
        return self
            .padding(.top, edgeInsets.top)
            .padding(.leading, edgeInsets.leading)
            .padding(.bottom, edgeInsets.bottom)
            .padding(.trailing, edgeInsets.trailing)
    }
    
    func containerPadding() -> some View {
        let edgeInsets = SpacingInsets.standard.edgeInsets
        return self
            .padding(.top, edgeInsets.top)
            .padding(.leading, edgeInsets.leading)
            .padding(.bottom, edgeInsets.bottom)
            .padding(.trailing, edgeInsets.trailing)
    }
    
    func sectionPadding() -> some View {
        let edgeInsets = SpacingInsets.generous.edgeInsets
        return self
            .padding(.top, edgeInsets.top)
            .padding(.leading, edgeInsets.leading)
            .padding(.bottom, edgeInsets.bottom)
            .padding(.trailing, edgeInsets.trailing)
    }
    
    /// Apply spacing between elements
    func elementSpacing(_ gaps: SpacingGaps = .standard) -> some View {
        self.padding(.vertical, gaps.value / 2)
    }
    
    /// Position with unified system
    func unifiedPosition(_ positioning: PositioningBehavior) -> some View {
        self.offset(positioning.offset)
    }
    
    /// Responsive spacing
    func responsiveSpacing(
        compact: SpacingConfiguration,
        regular: SpacingConfiguration
    ) -> some View {
        unifiedSpacing(SpacingConfiguration(
            responsive: .custom(compact: compact, regular: regular)
        ))
    }
}

// MARK: - Predefined Configurations

public extension SpacingConfiguration {
    /// Button spacing configuration
    static let button = SpacingConfiguration(
        insets: .compact,
        gaps: .compact,
        positioning: .automatic
    )
    
    /// Card content spacing
    static let card = SpacingConfiguration(
        insets: .standard,
        gaps: .standard,
        positioning: .automatic
    )
    
    /// Settings page spacing
    static let settings = SpacingConfiguration(
        insets: .generous,
        gaps: .comfortable,
        positioning: .automatic,
        responsive: .sizeClassBased
    )
    
    /// Control panel spacing
    static let controls = SpacingConfiguration(
        insets: .compact,
        gaps: .compact,
        positioning: .automatic
    )
    
    /// Info display spacing
    static let info = SpacingConfiguration(
        insets: .standard,
        gaps: .compact,
        positioning: .automatic
    )
    
    /// List item spacing
    static let listItem = SpacingConfiguration(
        insets: .asymmetric(
            top: DesignTokens.Spacing.xxSmall,
            leading: DesignTokens.Spacing.small,
            bottom: DesignTokens.Spacing.xxSmall,
            trailing: DesignTokens.Spacing.small
        ),
        gaps: .compact
    )
    
    /// Toolbar spacing
    static let toolbar = SpacingConfiguration(
        insets: .horizontal(DesignTokens.Spacing.small),
        gaps: .compact,
        positioning: .automatic
    )
}

// MARK: - Grid Helpers

public extension GridItem {
    /// Standard flexible grid item
    static let standardFlexible = GridItem(.flexible(), spacing: DesignTokens.Spacing.small)
    
    /// Fixed size grid item with standard spacing
    static func standardFixed(size: CGFloat) -> GridItem {
        GridItem(.fixed(size), spacing: DesignTokens.Spacing.small)
    }
    
    /// Adaptive grid item with minimum size
    static func standardAdaptive(minimum: CGFloat) -> GridItem {
        GridItem(.adaptive(minimum: minimum), spacing: DesignTokens.Spacing.small)
    }
}

// MARK: - Legacy Compatibility

/// Migration helpers for existing spacing patterns
public extension View {
    @available(*, deprecated, message: "Use appPadding() instead")
    func legacyPadding(_ value: CGFloat) -> some View {
        padding(value)
    }
    
    @available(*, deprecated, message: "Use UnifiedVStack instead")
    func legacyVSpacing(_ value: CGFloat) -> some View {
        self
    }
    
    @available(*, deprecated, message: "Use UnifiedHStack instead") 
    func legacyHSpacing(_ value: CGFloat) -> some View {
        self
    }
}

// MARK: - Debug Helpers

#if DEBUG
public extension View {
    /// Visualize spacing for debugging
    func debugSpacing(color: Color = .red) -> some View {
        self.overlay(
            Rectangle()
                .stroke(color, lineWidth: 1)
                .opacity(0.3)
        )
    }
    
    /// Show spacing guides
    func spacingGuides() -> some View {
        self.overlay(
            VStack {
                HStack {
                    Rectangle().fill(Color.blue).frame(width: 1, height: 10)
                    Spacer()
                    Rectangle().fill(Color.blue).frame(width: 1, height: 10)
                }
                Spacer()
                HStack {
                    Rectangle().fill(Color.blue).frame(width: 1, height: 10)
                    Spacer()
                    Rectangle().fill(Color.blue).frame(width: 1, height: 10)
                }
            }
            .overlay(
                HStack {
                    Rectangle().fill(Color.blue).frame(width: 10, height: 1)
                    Spacer()
                    Rectangle().fill(Color.blue).frame(width: 10, height: 1)
                }
            )
            .opacity(0.3)
        )
    }
}
#endif