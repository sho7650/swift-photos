import SwiftUI

/// Unified progress bar component that replaces InteractiveProgressBar, CompactProgressBar, and DetailedProgressBar
/// Supports configuration-based styling and optional features
public struct UnifiedProgressBar: View {
    // MARK: - Core Properties
    let progress: Double
    let currentIndex: Int
    let totalCount: Int
    let onJumpToIndex: (Int) -> Void
    
    // MARK: - Style Configuration
    let style: ProgressBarStyle
    
    // MARK: - State
    @State private var isHovering = false
    @State private var hoveredIndex: Int?
    
    // MARK: - Initialization
    public init(
        progress: Double,
        currentIndex: Int,
        totalCount: Int,
        style: ProgressBarStyle = .standard,
        onJumpToIndex: @escaping (Int) -> Void
    ) {
        self.progress = progress
        self.currentIndex = currentIndex
        self.totalCount = totalCount
        self.style = style
        self.onJumpToIndex = onJumpToIndex
    }
    
    // MARK: - Body
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(style.backgroundColor)
                    .frame(height: style.height)
                    .cornerRadius(style.cornerRadius)
                
                // Progress fill
                Rectangle()
                    .fill(style.fillColor)
                    .frame(width: geometry.size.width * progress, height: style.height)
                    .cornerRadius(style.cornerRadius)
                    .animation(.easeInOut(duration: 0.2), value: progress)
                
                // Hover indicator (style-dependent)
                if isHovering {
                    hoverIndicator(geometry: geometry)
                }
                
                // Hover preview (detailed style only)
                if style.showHoverPreview, isHovering, let hoveredIndex = hoveredIndex {
                    hoverPreview(hoveredIndex: hoveredIndex, geometry: geometry)
                }
            }
            .contentShape(Rectangle()) // Make entire area clickable
            .onTapGesture { location in
                handleTap(at: location, in: geometry)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .gesture(
                // Add drag gesture only for detailed style
                style.showHoverPreview ? 
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateHoveredIndex(at: value.location, in: geometry)
                        } : nil
            )
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private func hoverIndicator(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(style.hoverColor)
            .frame(height: style.height)
            .cornerRadius(style.cornerRadius)
            .transition(.opacity)
    }
    
    @ViewBuilder  
    private func hoverPreview(hoveredIndex: Int, geometry: GeometryProxy) -> some View {
        let hoveredProgress = Double(hoveredIndex) / Double(max(1, totalCount - 1))
        Rectangle()
            .fill(Color.white.opacity(0.4))
            .frame(width: 2, height: style.height + 4)
            .position(
                x: geometry.size.width * hoveredProgress, 
                y: style.height / 2
            )
            .transition(.opacity)
    }
    
    // MARK: - Private Methods
    
    private func handleTap(at location: CGPoint, in geometry: GeometryProxy) {
        let relativeX = location.x / geometry.size.width
        let clampedProgress = max(0, min(1, relativeX))
        let targetIndex = Int(clampedProgress * Double(totalCount - 1))
        let validIndex = max(0, min(totalCount - 1, targetIndex))
        
        // Debug logging for interactive style
        if style.enableDebugLogging {
            ProductionLogger.debug("UnifiedProgressBar: Tap at \(location.x)/\(geometry.size.width) (\(clampedProgress*100)%) -> index \(validIndex)")
        }
        
        // Only jump if clicking on a different photo
        if validIndex != currentIndex {
            onJumpToIndex(validIndex)
        }
    }
    
    private func updateHoveredIndex(at location: CGPoint, in geometry: GeometryProxy) {
        let relativeX = location.x / geometry.size.width
        let clampedProgress = max(0, min(1, relativeX))
        let targetIndex = Int(clampedProgress * Double(totalCount - 1))
        hoveredIndex = max(0, min(totalCount - 1, targetIndex))
    }
}

// MARK: - Style Configuration

public struct ProgressBarStyle: Sendable {
    let height: CGFloat
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let fillColor: Color
    let hoverColor: Color
    let showHoverPreview: Bool
    let enableDebugLogging: Bool
    
    public init(
        height: CGFloat,
        cornerRadius: CGFloat,
        backgroundColor: Color,
        fillColor: Color,
        hoverColor: Color,
        showHoverPreview: Bool = false,
        enableDebugLogging: Bool = false
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.fillColor = fillColor
        self.hoverColor = hoverColor
        self.showHoverPreview = showHoverPreview
        self.enableDebugLogging = enableDebugLogging
    }
}

// MARK: - Predefined Styles

public extension ProgressBarStyle {
    /// Standard style (replaces InteractiveProgressBar)
    static let standard = ProgressBarStyle(
        height: 8,
        cornerRadius: 4,
        backgroundColor: Color.gray.opacity(0.3),
        fillColor: Color.accentColor,
        hoverColor: Color.white.opacity(0.3),
        showHoverPreview: false,
        enableDebugLogging: true
    )
    
    /// Compact style (replaces CompactProgressBar)  
    static let compact = ProgressBarStyle(
        height: 4,
        cornerRadius: 2,
        backgroundColor: Color.white.opacity(0.3),
        fillColor: Color.white.opacity(0.8),
        hoverColor: Color.white.opacity(0.2),
        showHoverPreview: false,
        enableDebugLogging: false
    )
    
    /// Detailed style (replaces DetailedProgressBar)
    static let detailed = ProgressBarStyle(
        height: 8,
        cornerRadius: 4,
        backgroundColor: Color.secondary.opacity(0.3),
        fillColor: Color.accentColor,
        hoverColor: Color.white.opacity(0.3),
        showHoverPreview: true,
        enableDebugLogging: false
    )
}

// MARK: - Preview Provider

struct UnifiedProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            UnifiedProgressBar(
                progress: 0.3,
                currentIndex: 3,
                totalCount: 10,
                style: .standard
            ) { index in
                print("Standard: Jumped to \(index)")
            }
            .frame(height: 8)
            
            UnifiedProgressBar(
                progress: 0.6,
                currentIndex: 6,
                totalCount: 10,
                style: .compact
            ) { index in
                print("Compact: Jumped to \(index)")
            }
            .frame(height: 4)
            
            UnifiedProgressBar(
                progress: 0.8,
                currentIndex: 8,
                totalCount: 10,
                style: .detailed
            ) { index in
                print("Detailed: Jumped to \(index)")
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.black)
    }
}