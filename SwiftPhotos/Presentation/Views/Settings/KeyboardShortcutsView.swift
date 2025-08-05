import SwiftUI

/// Keyboard shortcuts view for displaying available keyboard controls
/// Provides comprehensive list of all available shortcuts and their functions
struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Basic Slideshow Controls Section
            SettingsComponentFactory.createSection(
                title: String(localized: "keyboard.slideshow_controls"),
                icon: "play.rectangle",
                description: "Control slideshow playback and navigation"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "Space", description: "Play/Pause slideshow")
                    ShortcutRow(key: "→ ↓", description: "Next photo")
                    ShortcutRow(key: "← ↑", description: "Previous photo")
                    ShortcutRow(key: "Esc", description: "Stop slideshow")
                }
            }
            
            // Interface Controls Section
            SettingsComponentFactory.createSection(
                title: String(localized: "keyboard.interface_controls"),
                icon: "rectangle.3.group",
                description: "Show and hide interface elements"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "I", description: "Toggle detailed photo information")
                    ShortcutRow(key: "H", description: "Toggle controls visibility")
                    ShortcutRow(key: "F", description: "Toggle fullscreen mode")
                }
            }
            
            // Application Controls Section
            SettingsComponentFactory.createSection(
                title: String(localized: "keyboard.application_controls"),
                icon: "gear",
                description: "Access application features and settings"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "⌘,", description: "Open settings (this window)")
                    ShortcutRow(key: "⌘O", description: "Open folder")
                    ShortcutRow(key: "⌘W", description: "Close window")
                    ShortcutRow(key: "⌘Q", description: "Quit application")
                }
            }
            
            // File Navigation Section
            SettingsComponentFactory.createSection(
                title: "File Navigation",
                icon: "folder",
                description: "Navigate through photos quickly"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "Home", description: "Go to first photo")
                    ShortcutRow(key: "End", description: "Go to last photo")
                    ShortcutRow(key: "Page ↑", description: "Previous 10 photos")
                    ShortcutRow(key: "Page ↓", description: "Next 10 photos")
                }
            }
            
            // Tips and Information Section
            SettingsComponentFactory.createSection(
                title: "Tips and Information",
                icon: "lightbulb",
                description: "Helpful tips for using keyboard shortcuts"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "keyboard.quick_tips"))
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text(String(localized: "keyboard.quick_tips_content1"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "keyboard.quick_tips_content2"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "keyboard.quick_tips_content3"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "keyboard.accessibility"))
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        Text(String(localized: "keyboard.accessibility_content1"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "keyboard.accessibility_content2"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "keyboard.accessibility_content3"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "keyboard.performance_tips"))
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text(String(localized: "keyboard.performance_content1"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "keyboard.performance_content2"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "keyboard.performance_content3"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}


/// Helper view for keyboard shortcut display
private struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
                .frame(minWidth: 60)
            
            Text(description)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .font(.caption)
    }
}

#Preview {
    KeyboardShortcutsView()
        .frame(width: 500, height: 600)
}