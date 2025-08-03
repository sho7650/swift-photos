import Foundation
import AppKit

/// Background preloader that loads images with priority-based queuing for unlimited collections
actor BackgroundPreloader {
    private let imageLoader: ImageLoader
    private var maxConcurrentLoads: Int
    private var preloadTasks: [UUID: Task<Void, Never>] = [:]
    private var priorityQueue: PriorityQueue<PreloadItem>
    private var settings: PerformanceSettings
    
    // Statistics
    private var totalPreloads: Int = 0
    private var successfulPreloads: Int = 0
    private var failedPreloads: Int = 0
    
    // Intelligent preloading
    private var navigationHistory: [Int] = []
    private var lastNavigationTime: Date = Date()
    private var navigationDirection: NavigationDirection = .unknown
    private let maxHistorySize = 10
    
    struct PreloadItem: Comparable, Sendable {
        let photo: Photo
        let priority: Int
        
        static func < (lhs: PreloadItem, rhs: PreloadItem) -> Bool {
            return lhs.priority > rhs.priority // Higher priority first
        }
    }
    
    enum NavigationDirection {
        case forward
        case backward
        case unknown
    }
    
    init(settings: PerformanceSettings = .default) {
        self.settings = settings
        self.maxConcurrentLoads = settings.maxConcurrentLoads
        self.imageLoader = ImageLoader()
        self.priorityQueue = PriorityQueue<PreloadItem>()
        
        ProductionLogger.lifecycle("BackgroundPreloader: Initialized with \(maxConcurrentLoads) concurrent loads")
    }
    
    /// Update performance settings at runtime
    func updateSettings(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
        self.maxConcurrentLoads = newSettings.maxConcurrentLoads
        ProductionLogger.debug("BackgroundPreloader: Settings updated - concurrent loads: \(maxConcurrentLoads)")
    }
    
    /// Schedule photos for preloading with intelligent direction-based priorities
    func schedulePreload(photos: [Photo], currentIndex: Int, windowSize: Int? = nil) async {
        // Update navigation tracking
        updateNavigationHistory(currentIndex: currentIndex)
        
        // Use settings-based window size or provided size
        let effectiveWindowSize = windowSize ?? settings.preloadDistance
        
        // For very large collections, limit preload scope to prevent overwhelming
        let maxPreloadScope = min(effectiveWindowSize, photos.count > 10000 ? 100 : effectiveWindowSize)
        
        // Clear existing tasks
        for task in preloadTasks.values {
            task.cancel()
        }
        preloadTasks.removeAll()
        priorityQueue.clear()
        
        // Calculate asymmetric preload range based on navigation direction
        let (startIndex, endIndex) = calculateIntelligentPreloadRange(
            currentIndex: currentIndex,
            photos: photos,
            maxScope: maxPreloadScope
        )
        
        // Add photos to priority queue with intelligent priority calculation
        for index in startIndex...endIndex {
            let photo = photos[index]
            let priority = calculateIntelligentPriority(
                index: index,
                currentIndex: currentIndex,
                direction: navigationDirection,
                photos: photos
            )
            
            if photo.loadState.isNotLoaded && priority > 0 {
                priorityQueue.enqueue(PreloadItem(photo: photo, priority: priority))
            }
        }
        
        ProductionLogger.performance("BackgroundPreloader: Scheduled \(priorityQueue.count) photos for preload (range: \(startIndex)-\(endIndex), direction: \(navigationDirection))")
        
        // Start preloading
        await processPreloadQueue()
    }
    
    /// Update priorities when current index changes
    func updatePriorities(photos: [Photo], newIndex: Int) async {
        // Re-calculate priorities for queued items
        var items: [PreloadItem] = []
        while let item = priorityQueue.dequeue() {
            items.append(item)
        }
        
        for item in items {
            if let photoIndex = photos.firstIndex(where: { $0.id == item.photo.id }) {
                let distance = abs(photoIndex - newIndex)
                let newPriority = max(0, 100 - distance)
                priorityQueue.enqueue(PreloadItem(photo: item.photo, priority: newPriority))
            }
        }
        
        await processPreloadQueue()
    }
    
    /// Cancel all preloading tasks
    func cancelAllPreloads() {
        for task in preloadTasks.values {
            task.cancel()
        }
        preloadTasks.removeAll()
        priorityQueue.clear()
    }
    
    private func processPreloadQueue() async {
        // Ensure we don't exceed max concurrent loads
        let activeTaskCount = preloadTasks.count
        let availableSlots = max(0, maxConcurrentLoads - activeTaskCount)
        
        for _ in 0..<availableSlots {
            guard let item = priorityQueue.dequeue() else { break }
            
            // Skip if already loading
            if preloadTasks[item.photo.id] != nil {
                continue
            }
            
            let task = Task {
                await self.preloadImage(item.photo)
            }
            
            preloadTasks[item.photo.id] = task
        }
    }
    
    private func preloadImage(_ photo: Photo) async {
        totalPreloads += 1
        
        do {
            _ = try await imageLoader.loadImage(from: photo.imageURL)
            // Image is now in the ImageLoader's cache
            successfulPreloads += 1
        } catch {
            failedPreloads += 1
            if !Task.isCancelled {
                ProductionLogger.warning("Failed to preload image \(photo.id): \(error)")
            }
        }
        
        // Remove from active tasks
        preloadTasks.removeValue(forKey: photo.id)
        
        // Process next item in queue
        await processPreloadQueue()
    }
    
    /// Get preloader statistics
    func getStatistics() -> (total: Int, successful: Int, failed: Int, successRate: Double, activeLoads: Int) {
        let successRate = totalPreloads > 0 ? Double(successfulPreloads) / Double(totalPreloads) : 0.0
        return (
            total: totalPreloads,
            successful: successfulPreloads,
            failed: failedPreloads,
            successRate: successRate,
            activeLoads: preloadTasks.count
        )
    }
    
    // MARK: - Intelligent Preloading Methods
    
    /// Update navigation history and detect direction patterns
    private func updateNavigationHistory(currentIndex: Int) {
        let now = Date()
        
        // Add to history
        navigationHistory.append(currentIndex)
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
        }
        
        // Detect navigation direction from recent history
        if navigationHistory.count >= 3 {
            let recentMoves = Array(navigationHistory.suffix(3))
            let direction1 = recentMoves[1] - recentMoves[0]
            let direction2 = recentMoves[2] - recentMoves[1]
            
            if direction1 > 0 && direction2 > 0 {
                navigationDirection = .forward
            } else if direction1 < 0 && direction2 < 0 {
                navigationDirection = .backward
            } else {
                navigationDirection = .unknown
            }
        }
        
        lastNavigationTime = now
    }
    
    /// Calculate intelligent preload range based on navigation patterns
    private func calculateIntelligentPreloadRange(
        currentIndex: Int,
        photos: [Photo],
        maxScope: Int
    ) -> (startIndex: Int, endIndex: Int) {
        
        switch navigationDirection {
        case .forward:
            // Bias towards loading ahead
            let forwardBias = Int(Double(maxScope) * 0.7)
            let backwardScope = maxScope - forwardBias
            return (
                startIndex: max(0, currentIndex - backwardScope),
                endIndex: min(photos.count - 1, currentIndex + forwardBias)
            )
            
        case .backward:
            // Bias towards loading behind
            let backwardBias = Int(Double(maxScope) * 0.7)
            let forwardScope = maxScope - backwardBias
            return (
                startIndex: max(0, currentIndex - backwardBias),
                endIndex: min(photos.count - 1, currentIndex + forwardScope)
            )
            
        case .unknown:
            // Symmetric loading
            let halfScope = maxScope / 2
            return (
                startIndex: max(0, currentIndex - halfScope),
                endIndex: min(photos.count - 1, currentIndex + halfScope)
            )
        }
    }
    
    /// Calculate intelligent priority based on direction and patterns
    private func calculateIntelligentPriority(
        index: Int,
        currentIndex: Int,
        direction: NavigationDirection,
        photos: [Photo]
    ) -> Int {
        
        let distance = abs(index - currentIndex)
        let isForward = index > currentIndex
        
        // Base priority decreases with distance
        let basePriority = max(0, 100 - (distance * distance / 10))
        
        // Direction-based bonus
        let directionBonus: Double
        switch direction {
        case .forward:
            directionBonus = isForward ? 1.5 : 0.7
        case .backward:
            directionBonus = isForward ? 0.7 : 1.5
        case .unknown:
            directionBonus = 1.0
        }
        
        // Adjacent photos get highest priority
        let adjacencyBonus = distance <= 1 ? 1.8 : 1.0
        
        // File size consideration (smaller files load faster)
        let fileSizeBonus: Double
        if photos.indices.contains(index) {
            let photo = photos[index]
            // Prioritize smaller files slightly (if metadata available)
            if let fileSize = photo.metadata?.fileSize {
                fileSizeBonus = fileSize < 5_000_000 ? 1.1 : 1.0 // 5MB threshold
            } else {
                fileSizeBonus = 1.0 // No metadata available, neutral priority
            }
        } else {
            fileSizeBonus = 1.0
        }
        
        let finalPriority = Double(basePriority) * directionBonus * adjacencyBonus * fileSizeBonus
        return max(0, Int(finalPriority))
    }
}

/// Simple priority queue implementation
struct PriorityQueue<T: Comparable> {
    private var heap: [T] = []
    
    var isEmpty: Bool { heap.isEmpty }
    var count: Int { heap.count }
    
    mutating func enqueue(_ element: T) {
        heap.append(element)
        siftUp(heap.count - 1)
    }
    
    mutating func dequeue() -> T? {
        guard !heap.isEmpty else { return nil }
        
        if heap.count == 1 {
            return heap.removeLast()
        }
        
        let element = heap[0]
        heap[0] = heap.removeLast()
        siftDown(0)
        
        return element
    }
    
    mutating func clear() {
        heap.removeAll()
    }
    
    private mutating func siftUp(_ index: Int) {
        var child = index
        var parent = (child - 1) / 2
        
        while child > 0 && heap[child] < heap[parent] {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }
    
    private mutating func siftDown(_ index: Int) {
        var parent = index
        
        while true {
            let leftChild = 2 * parent + 1
            let rightChild = 2 * parent + 2
            var candidate = parent
            
            if leftChild < heap.count && heap[leftChild] < heap[candidate] {
                candidate = leftChild
            }
            
            if rightChild < heap.count && heap[rightChild] < heap[candidate] {
                candidate = rightChild
            }
            
            if candidate == parent {
                return
            }
            
            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}