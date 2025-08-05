import SwiftUI
import Foundation

/// Settings component factory using static methods to create reusable UI components
/// Reduces code duplication across 12 settings views by providing common UI patterns
@MainActor
public struct SettingsComponentFactory {
    
    // MARK: - Section Components
    
    /// Create a standardized settings section with title, icon, and description
    public static func createSection<Content: View>(
        title: String,
        icon: String,
        description: String = "",
        theme: SettingsTheme = .default,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.sectionSpacing) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(theme.iconColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.titleColor)
                
                Spacer()
            }
            
            // Section Description
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(theme.descriptionColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Section Content
            content()
        }
        .padding(theme.sectionPadding)
        .background(theme.sectionBackgroundColor)
        .cornerRadius(theme.cornerRadius)
    }
    
    // MARK: - Control Components
    
    /// Create a standardized slider with label and value display
    public static func createSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        step: Double = 1.0,
        theme: SettingsTheme = .default,
        onChange: @escaping (Double) -> Void = { _ in }
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.titleColor)
                
                Spacer()
                
                Text(String(format: format, value.wrappedValue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.valueColor)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
            }
            
            Slider(
                value: value,
                in: range,
                step: step
            ) { editing in
                if !editing {
                    onChange(value.wrappedValue)
                }
            }
            .accentColor(theme.sliderAccentColor)
        }
        .padding(theme.controlPadding)
        .background(theme.controlBackgroundColor)
        .cornerRadius(theme.controlCornerRadius)
    }
    
    /// Create a standardized toggle with label
    public static func createToggle(
        title: String,
        isOn: Binding<Bool>,
        theme: SettingsTheme = .default,
        onChange: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.titleColor)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    isOn.wrappedValue = newValue
                    onChange(newValue)
                }
            ))
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
        }
        .padding(theme.controlPadding)
        .background(theme.controlBackgroundColor)
        .cornerRadius(theme.controlCornerRadius)
    }
    
    /// Create a standardized picker with options
    public static func createPicker<T: Hashable & CaseIterable>(
        title: String,
        selection: Binding<T>,
        options: [T],
        displayName: @escaping (T) -> String,
        icon: @escaping (T) -> String? = { _ in nil },
        theme: SettingsTheme = .default,
        onChange: @escaping (T) -> Void = { _ in }
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.titleColor)
            
            Picker(title, selection: Binding(
                get: { selection.wrappedValue },
                set: { newValue in
                    selection.wrappedValue = newValue
                    onChange(newValue)
                }
            )) {
                ForEach(options, id: \.self) { option in
                    HStack {
                        if let iconName = icon(option) {
                            Image(systemName: iconName)
                                .foregroundColor(theme.iconColor)
                        }
                        Text(displayName(option))
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(theme.controlPadding)
        .background(theme.controlBackgroundColor)
        .cornerRadius(theme.controlCornerRadius)
    }
    
    // MARK: - Button Components
    
    /// Create preset buttons in a grid layout
    public static func createPresetButtons<T: Hashable>(
        presets: [T],
        currentSelection: T,
        displayName: @escaping (T) -> String,
        theme: SettingsTheme = .default,
        onSelection: @escaping (T) -> Void
    ) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: theme.buttonSpacing) {
            ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                Button(action: {
                    onSelection(preset)
                    ProductionLogger.debug("SettingsComponentFactory: Preset selected - \(displayName(preset))")
                }) {
                    Text(displayName(preset))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(BorderedButtonStyle())
                .background(preset.hashValue == currentSelection.hashValue ? theme.selectedPresetColor : Color.clear)
                .cornerRadius(6)
            }
        }
    }
    
    // Note: Action buttons removed due to Swift type system complexity with button styles
    
    // MARK: - Helper Methods
    
    /// Create binding helper for settings updates
    public static func createSettingsBinding<T, SettingsType: Codable & Equatable & DefaultConfigurable>(
        keyPath: WritableKeyPath<SettingsType, T>,
        manager: some AbstractSettingsManager<SettingsType>
    ) -> Binding<T> {
        Binding(
            get: { manager.settings[keyPath: keyPath] },
            set: { newValue in
                var newSettings = manager.settings
                newSettings[keyPath: keyPath] = newValue
                manager.updateSettings(newSettings)
            }
        )
    }
}

// MARK: - Supporting Types

/// Theme configuration for consistent settings UI appearance
public struct SettingsTheme: Sendable {
    let sectionSpacing: CGFloat
    let sectionPadding: CGFloat
    let cornerRadius: CGFloat
    let buttonSpacing: CGFloat
    let controlPadding: CGFloat
    let controlCornerRadius: CGFloat
    
    let titleColor: Color
    let descriptionColor: Color
    let iconColor: Color
    let valueColor: Color
    let sliderAccentColor: Color
    let selectedPresetColor: Color
    let sectionBackgroundColor: Color
    let controlBackgroundColor: Color
    
    public static let `default` = SettingsTheme(
        sectionSpacing: 12,
        sectionPadding: 16,
        cornerRadius: 10,
        buttonSpacing: 8,
        controlPadding: 12,
        controlCornerRadius: 6,
        titleColor: .primary,
        descriptionColor: .secondary,
        iconColor: .accentColor,
        valueColor: .secondary,
        sliderAccentColor: .accentColor,
        selectedPresetColor: Color.accentColor.opacity(0.1),
        sectionBackgroundColor: Color(NSColor.controlBackgroundColor),
        controlBackgroundColor: Color(NSColor.controlColor).opacity(0.3)
    )
    
    public static let performance = SettingsTheme(
        sectionSpacing: 12,
        sectionPadding: 16,
        cornerRadius: 10,
        buttonSpacing: 8,
        controlPadding: 12,
        controlCornerRadius: 6,
        titleColor: .primary,
        descriptionColor: .secondary,
        iconColor: .green,
        valueColor: .secondary,
        sliderAccentColor: .green,
        selectedPresetColor: Color.green.opacity(0.1),
        sectionBackgroundColor: Color(NSColor.controlBackgroundColor),
        controlBackgroundColor: Color(NSColor.controlColor).opacity(0.3)
    )
    
    public static let transitions = SettingsTheme(
        sectionSpacing: 12,
        sectionPadding: 16,
        cornerRadius: 10,
        buttonSpacing: 8,
        controlPadding: 12,
        controlCornerRadius: 6,
        titleColor: .primary,
        descriptionColor: .secondary,
        iconColor: .blue,
        valueColor: .secondary,
        sliderAccentColor: .blue,
        selectedPresetColor: Color.blue.opacity(0.1),
        sectionBackgroundColor: Color(NSColor.controlBackgroundColor),
        controlBackgroundColor: Color(NSColor.controlColor).opacity(0.3)
    )
}

// MARK: - Convenience Extensions

extension SettingsComponentFactory {
    
    /// Simplified section creator for most common use case
    public static func section<Content: View>(
        _ title: String,
        icon: String,
        description: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        createSection(title: title, icon: icon, description: description, content: content)
    }
    
    /// Simplified slider creator
    public static func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String = "%.0f"
    ) -> some View {
        createSlider(title: title, value: value, range: range, format: format)
    }
    
    /// Simplified toggle creator
    public static func toggle(
        _ title: String,
        isOn: Binding<Bool>
    ) -> some View {
        createToggle(title: title, isOn: isOn)
    }
}