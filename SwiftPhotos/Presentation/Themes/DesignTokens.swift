//
//  DesignTokens.swift
//  Swift Photos
//
//  Centralized design token system for consistent styling across the application
//  Phase 3.1: View Layer Consolidation - Design System Foundation
//

import SwiftUI

// MARK: - Design Token System

/// Centralized design token system for consistent styling across the application
public struct DesignTokens {
    
    // MARK: - Colors
    public struct Colors {
        // Background colors
        public static let primaryBackground = Color.black
        public static let secondaryBackground = Color.black.opacity(0.8)
        public static let controlsBackground = Color.black.opacity(0.7)
        public static let tooltipBackground = Color.black.opacity(0.9)
        public static let overlayBackground = Color.black.opacity(0.4)
        
        // Interactive colors
        public static let accent = Color.accentColor
        public static let interactive = Color.white
        public static let interactiveSecondary = Color.white.opacity(0.7)
        public static let interactiveDimmed = Color.white.opacity(0.5)
        
        // Status colors
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue
        
        // Border and divider colors
        public static let border = Color.white.opacity(0.2)
        public static let divider = Color.white.opacity(0.1)
        
        // Glass morphism colors
        public static let glassFill = Color.white.opacity(0.1)
        public static let glassStroke = Color.white.opacity(0.2)
    }
    
    // MARK: - Typography
    public struct Typography {
        // Headings
        public static let largeTitle = Font.largeTitle.weight(.bold)
        public static let title = Font.title.weight(.semibold)
        public static let title2 = Font.title2.weight(.medium)
        public static let title3 = Font.title3.weight(.medium)
        
        // Body text
        public static let body = Font.body
        public static let bodyEmphasized = Font.body.weight(.medium)
        public static let callout = Font.callout
        public static let subheadline = Font.subheadline
        
        // Small text
        public static let footnote = Font.footnote
        public static let caption = Font.caption
        public static let caption2 = Font.caption2
        
        // Button text
        public static let buttonLarge = Font.title2.weight(.medium)
        public static let buttonMedium = Font.body.weight(.medium)
        public static let buttonSmall = Font.callout.weight(.medium)
        
        // Monospace for shortcuts and technical info
        public static let monospace = Font.system(.body, design: .monospaced)
        public static let monospaceSmall = Font.system(.caption, design: .monospaced)
    }
    
    // MARK: - Spacing
    public struct Spacing {
        // Base spacing unit (4pt)
        public static let unit: CGFloat = 4
        
        // Common spacing values
        public static let xxxSmall: CGFloat = unit * 1      // 4pt
        public static let xxSmall: CGFloat = unit * 2       // 8pt
        public static let xSmall: CGFloat = unit * 3        // 12pt
        public static let small: CGFloat = unit * 4         // 16pt
        public static let medium: CGFloat = unit * 6        // 24pt
        public static let large: CGFloat = unit * 8         // 32pt
        public static let xLarge: CGFloat = unit * 12       // 48pt
        public static let xxLarge: CGFloat = unit * 16      // 64pt
        public static let xxxLarge: CGFloat = unit * 20     // 80pt
        
        // Semantic spacing
        public static let controlPadding = small
        public static let buttonPadding = xSmall
        public static let containerPadding = medium
        public static let sectionSpacing = large
        
        // Edge insets helpers
        public static func edgeInsets(_ value: CGFloat) -> EdgeInsets {
            EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
        }
        
        public static func edgeInsets(vertical: CGFloat, horizontal: CGFloat) -> EdgeInsets {
            EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
        }
    }
    
    // MARK: - Corner Radius
    public struct CornerRadius {
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let xLarge: CGFloat = 16
        
        // Semantic corner radius
        public static let button = medium
        public static let card = large
        public static let overlay = xLarge
        public static let tooltip = small
    }
    
    // MARK: - Shadows
    public struct Shadows {
        public static let small = Color.black.opacity(0.1)
        public static let medium = Color.black.opacity(0.2)
        public static let large = Color.black.opacity(0.3)
        
        public static let tooltip = medium
        public static let overlay = large
        public static let button = small
    }
    
    // MARK: - Animation
    public struct Animation {
        public static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        
        // Semantic animations
        public static let tooltip = fast
        public static let button = fast
        public static let overlay = standard
        public static let transition = slow
    }
}

// MARK: - SwiftUI Extensions for Design Tokens

public extension Color {
    // Quick access to design tokens
    static var appPrimaryBackground: Color { DesignTokens.Colors.primaryBackground }
    static var appSecondaryBackground: Color { DesignTokens.Colors.secondaryBackground }
    static var appControlsBackground: Color { DesignTokens.Colors.controlsBackground }
    static var appTooltipBackground: Color { DesignTokens.Colors.tooltipBackground }
    static var appOverlayBackground: Color { DesignTokens.Colors.overlayBackground }
    static var appInteractive: Color { DesignTokens.Colors.interactive }
    static var appInteractiveSecondary: Color { DesignTokens.Colors.interactiveSecondary }
    static var appBorder: Color { DesignTokens.Colors.border }
    static var appGlassFill: Color { DesignTokens.Colors.glassFill }
    static var appGlassStroke: Color { DesignTokens.Colors.glassStroke }
}

public extension Font {
    // Quick access to typography tokens
    static var appLargeTitle: Font { DesignTokens.Typography.largeTitle }
    static var appTitle: Font { DesignTokens.Typography.title }
    static var appBodyEmphasized: Font { DesignTokens.Typography.bodyEmphasized }
    static var appButtonLarge: Font { DesignTokens.Typography.buttonLarge }
    static var appButtonMedium: Font { DesignTokens.Typography.buttonMedium }
    static var appButtonSmall: Font { DesignTokens.Typography.buttonSmall }
    static var appMonospace: Font { DesignTokens.Typography.monospace }
}

// MARK: - View Extensions for Common Patterns

public extension View {
    /// Apply standard app button styling
    func appButtonStyle(size: DesignTokens.ButtonSize = .medium) -> some View {
        let paddingValue: CGFloat
        let font: Font
        
        switch size {
        case .small:
            paddingValue = DesignTokens.Spacing.xxSmall
            font = .appButtonSmall
        case .medium:
            paddingValue = DesignTokens.Spacing.xSmall
            font = .appButtonMedium
        case .large:
            paddingValue = DesignTokens.Spacing.small
            font = .appButtonLarge
        }
        
        return self
            .font(font)
            .padding(paddingValue)
    }
    
    /// Apply standard app card styling
    func appCardStyle() -> some View {
        self
            .background(Color.appSecondaryBackground)
            .cornerRadius(DesignTokens.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
    
    /// Apply glassmorphic styling
    func glassStyle() -> some View {
        self
            .background(
                Rectangle()
                    .fill(Material.ultraThinMaterial)
                    .overlay(Color.appGlassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .stroke(Color.appGlassStroke, lineWidth: 1)
            )
    }
}

// MARK: - Supporting Enums

public extension DesignTokens {
    enum ButtonSize {
        case small, medium, large
    }
}