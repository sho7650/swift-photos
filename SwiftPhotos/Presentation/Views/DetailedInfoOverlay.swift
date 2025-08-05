import SwiftUI
import AppKit
import Combine

/// Expandable detailed information overlay with photo metadata and enhanced controls
public struct DetailedInfoOverlay: View {
    var viewModel: any SlideshowViewModelProtocol
    @ObservedObject var uiInteractionManager: UIInteractionManager
    var uiControlSettings: ModernUIControlSettingsManager
    var localizationService: LocalizationService?
    
    // Add state to force UI updates when language changes
    @State private var languageUpdateTrigger = 0
    
    @State private var isExpanded = false
    @State private var showMetadata = false
    
    public init(
        viewModel: any SlideshowViewModelProtocol,
        uiInteractionManager: UIInteractionManager,
        uiControlSettings: ModernUIControlSettingsManager,
        localizationService: LocalizationService?
    ) {
        self.viewModel = viewModel
        self.uiInteractionManager = uiInteractionManager
        self.uiControlSettings = uiControlSettings
        self.localizationService = localizationService
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            if let slideshow = viewModel.slideshow,
               !slideshow.isEmpty,
               uiInteractionManager.isDetailedInfoVisible {
                detailedInfoPanel(slideshow: slideshow)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: uiControlSettings.settings.fadeAnimationDuration), value: uiInteractionManager.isDetailedInfoVisible)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            languageUpdateTrigger += 1
            ProductionLogger.debug("DetailedInfoOverlay: Received language change notification, trigger: \(languageUpdateTrigger)")
        }
        .onChange(of: localizationService?.currentLanguage) { oldValue, newValue in
            languageUpdateTrigger += 1
            ProductionLogger.debug("DetailedInfoOverlay: Language changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil"), trigger: \(languageUpdateTrigger)")
        }
        // .id(languageUpdateTrigger) // Temporarily disabled to debug photo counter issue
    }
    
    private func detailedInfoPanel(slideshow: Slideshow) -> some View {
        VStack(spacing: 0) {
            // Header with close button and expand toggle
            headerSection(slideshow: slideshow)
            
            // Main content area
            if isExpanded {
                expandedContent(slideshow: slideshow)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .background(
            BlurredDetailedBackground(
                intensity: uiControlSettings.settings.backgroundBlurIntensity,
                opacity: uiControlSettings.settings.backgroundOpacity
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.bottom, uiControlSettings.settings.bottomOffset)
        .onTapGesture {
            uiInteractionManager.handleUserInteraction()
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    private func headerSection(slideshow: Slideshow) -> some View {
        VStack(spacing: 8) {
            // Top control bar
            HStack {
                // Expand/Collapse button
                Button(action: toggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Photo counter  
                Text(String(format: "%lld of %lld", slideshow.currentIndex + 1, slideshow.count))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Close button
                Button(action: {
                    uiInteractionManager.toggleDetailedInfo()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .shortcutTooltip("Close Info", shortcut: "I")
            }
            
            // Photo title
            if let currentPhoto = slideshow.currentPhoto {
                Text(currentPhoto.fileName)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            // Full-width progress bar
            UnifiedProgressBar(
                progress: slideshow.progress,
                currentIndex: slideshow.currentIndex,
                totalCount: slideshow.count,
                style: .detailed
            ) { targetIndex in
                ProductionLogger.userAction("DetailedInfoOverlay: Progress bar clicked - jumping to photo \(targetIndex)")
                uiInteractionManager.handleUserInteraction()
                // Navigate to target photo using standard protocol methods
                Task {
                    // Jump directly to target photo using the new direct navigation method
                    await viewModel.jumpToPhoto(at: targetIndex)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
    }
    
    private func expandedContent(slideshow: Slideshow) -> some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.secondary.opacity(0.3))
            
            // Photo metadata section
            if let currentPhoto = slideshow.currentPhoto {
                photoMetadataSection(photo: currentPhoto)
            }
            
            // Slideshow controls section
            slideshowControlsSection(slideshow: slideshow)
            
            // Quick actions section
            quickActionsSection()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func photoMetadataSection(photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text("Photo Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showMetadata.toggle() }) {
                    Image(systemName: showMetadata ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if showMetadata, let metadata = photo.metadata {
                VStack(alignment: .leading, spacing: 4) {
                    metadataRow("Dimensions", metadata.dimensionsString)
                    metadataRow("File Size", metadata.fileSizeString)
                    
                    if let colorSpace = metadata.colorSpace {
                        metadataRow("Color Space", colorSpace)
                    }
                    
                    if let creationDate = metadata.creationDate {
                        let formattedDate = formatDate(creationDate)
                        metadataRow("Created", formattedDate)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: showMetadata)
    }
    
    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
    
    private func slideshowControlsSection(slideshow: Slideshow) -> some View {
        VStack(spacing: 8) {
            Text("Slideshow Controls")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                // Previous photo
                DetailedControlButton(
                    systemName: "backward.fill",
                    label: "Previous",
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        Task {
                            await viewModel.previousPhoto()
                        }
                    }
                )
                
                // Play/Pause
                DetailedControlButton(
                    systemName: slideshow.isPlaying ? "pause.fill" : "play.fill",
                    label: slideshow.isPlaying ? "Pause" : "Play",
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        if slideshow.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play()
                        }
                    }
                )
                
                // Next photo
                DetailedControlButton(
                    systemName: "forward.fill",
                    label: "Next",
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        Task {
                            await viewModel.nextPhoto()
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    private func quickActionsSection() -> some View {
        VStack(spacing: 8) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                // Reveal in Finder (if possible)
                DetailedControlButton(
                    systemName: "folder",
                    label: "Folder",
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        revealCurrentPhotoInFinder()
                        ProductionLogger.userAction("Reveal in Finder action")
                    }
                )
                
                // Settings
                DetailedControlButton(
                    systemName: "gear",
                    label: "Settings",
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        // TODO: Open settings window
                        ProductionLogger.userAction("Open settings action")
                    }
                )
                
                // Info toggle
                DetailedControlButton(
                    systemName: showMetadata ? "info.circle.fill" : "info.circle",
                    label: "Info",
                    action: {
                        uiInteractionManager.handleUserInteraction()
                        showMetadata.toggle()
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    private func toggleExpanded() {
        uiInteractionManager.handleUserInteraction()
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded.toggle()
        }
    }
    
    /// Reveal the current photo in Finder
    private func revealCurrentPhotoInFinder() {
        guard let slideshow = viewModel.slideshow,
              !slideshow.isEmpty,
              let currentPhoto = slideshow.currentPhoto else {
            ProductionLogger.warning("DetailedInfoOverlay: No current photo to reveal in Finder")
            return
        }
        
        let fileURL = currentPhoto.imageURL.url
        
        // Verify the file exists before trying to reveal it
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            ProductionLogger.error("DetailedInfoOverlay: Photo file does not exist at path: \(fileURL.path)")
            return
        }
        
        // Use NSWorkspace to reveal the file in Finder
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        ProductionLogger.info("DetailedInfoOverlay: Revealed photo '\(currentPhoto.fileName)' in Finder")
    }
}

/// Detailed control button with icon and label
private struct DetailedControlButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .opacity(isPressed ? 0.6 : 1.0)
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Note: DetailedProgressBar has been replaced by UnifiedProgressBar with .detailed style

/// Enhanced blurred background for detailed info
private struct BlurredDetailedBackground: View {
    let intensity: Double
    let opacity: Double
    
    var body: some View {
        ZStack {
            // Base material with stronger blur
            Rectangle()
                .fill(.regularMaterial)
                .opacity(intensity)
            
            // Additional tinted layer
            Rectangle()
                .fill(Color.black.opacity(opacity * 1.2))
        }
    }
}

// MARK: - Helper Methods

extension DetailedInfoOverlay {
    /// Format date using current localization settings
    private func formatDate(_ date: Date) -> String {
        // First try to get formatted date from localization service
        if let service = localizationService {
            let formatter = DateFormatter()
            formatter.locale = service.currentLocale
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        // Fallback to system locale
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format file size with locale-aware number formatting
    private func formatFileSize(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        // Use localization service for number formatting if available
        if let service = localizationService {
            let formatter = NumberFormatter()
            formatter.locale = service.currentLocale
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = unitIndex == 0 ? 0 : 1
            
            if let formattedSize = formatter.string(from: NSNumber(value: size)) {
                return "\(formattedSize) \(units[unitIndex])"
            }
        }
        
        // Fallback formatting
        return String(format: "%.1f %@", size, units[unitIndex])
    }
    
    /// Format dimensions with locale-aware number formatting
    private func formatDimensions(width: Int, height: Int) -> String {
        if let service = localizationService {
            let formatter = NumberFormatter()
            formatter.locale = service.currentLocale
            formatter.numberStyle = .decimal
            
            if let widthStr = formatter.string(from: NSNumber(value: width)),
               let heightStr = formatter.string(from: NSNumber(value: height)) {
                return "\(widthStr) × \(heightStr)"
            }
        }
        
        // Fallback formatting
        return "\(width) × \(height)"
    }
}