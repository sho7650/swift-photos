import SwiftUI

struct TooltipView: View {
    let text: String
    let shortcut: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
            
            Text(shortcut)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                )
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct ShortcutTooltip: ViewModifier {
    let text: String
    let shortcut: String
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isHovering {
                    TooltipView(text: text, shortcut: shortcut)
                        .offset(y: -40)
                        .animation(.easeOut(duration: 0.15), value: isHovering)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func shortcutTooltip(_ text: String, shortcut: String) -> some View {
        modifier(ShortcutTooltip(text: text, shortcut: shortcut))
    }
}