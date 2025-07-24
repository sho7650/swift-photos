import SwiftUI

/// Keyboard shortcuts view for displaying available keyboard controls
/// Provides comprehensive list of all available shortcuts and their functions
struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Basic Slideshow Controls Section
            KeyboardShortcutsSection(
                title: "Slideshow Controls",
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
            KeyboardShortcutsSection(
                title: "Interface Controls",
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
            KeyboardShortcutsSection(
                title: "Application Controls",
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
            KeyboardShortcutsSection(
                title: "File Navigation",
                icon: "folder",
                description: "Navigate through files and folders"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "Home", description: "Go to first photo")
                    ShortcutRow(key: "End", description: "Go to last photo")
                    ShortcutRow(key: "Page ↑", description: "Previous 10 photos")
                    ShortcutRow(key: "Page ↓", description: "Next 10 photos")
                }
            }
            
            // Tips and Information Section
            KeyboardShortcutsSection(
                title: "Tips & Information",
                icon: "lightbulb",
                description: "Additional information about keyboard usage"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💡 Quick Tips")
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text("• Hold Shift while using arrow keys for faster navigation (10x speed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Press and hold any navigation key for continuous movement")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Most shortcuts work both during slideshow and while paused")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🎯 Accessibility")
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        Text("• All features are accessible via keyboard for full accessibility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• VoiceOver support available for all interface elements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• High contrast mode automatically adjusts control appearance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚡ Performance")
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text("• Keyboard navigation is optimized for large photo collections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Shortcuts work immediately without loading delays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Background preloading ensures smooth navigation")
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

/// Reusable settings section component for keyboard shortcuts
private struct KeyboardShortcutsSection<Content: View>: View {
    let title: String
    let icon: String
    let description: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            content()
        }
        .padding(.vertical, 8)
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