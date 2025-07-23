import Foundation
import AppKit

// Make NSImage Sendable for Swift concurrency
extension NSImage: @retroactive @unchecked Sendable {}

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
    
    struct PreloadItem: Comparable {
        let photo: Photo
        let priority: Int
        
        static func < (lhs: PreloadItem, rhs: PreloadItem) -> Bool {
            return lhs.priority > rhs.priority // Higher priority first
        }
    }
    
    init(settings: PerformanceSettings = .default) {
        self.settings = settings
        self.maxConcurrentLoads = settings.maxConcurrentLoads
        self.imageLoader = ImageLoader()
        self.priorityQueue = PriorityQueue<PreloadItem>()
        
        print("🔄 BackgroundPreloader: Initialized with \(maxConcurrentLoads) concurrent loads")
    }
    
    /// Update performance settings at runtime
    func updateSettings(_ newSettings: PerformanceSettings) {
        self.settings = newSettings
        self.maxConcurrentLoads = newSettings.maxConcurrentLoads
        print("🔄 BackgroundPreloader: Settings updated - concurrent loads: \(maxConcurrentLoads)")
    }
    
    /// Schedule photos for preloading with priorities - supports unlimited collections
    func schedulePreload(photos: [Photo], currentIndex: Int, windowSize: Int? = nil) async {
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
        
        // Calculate preload range efficiently for large collections
        let startIndex = max(0, currentIndex - maxPreloadScope)
        let endIndex = min(photos.count - 1, currentIndex + maxPreloadScope)
        
        // Add photos to priority queue with distance-based priority
        for index in startIndex...endIndex {
            let photo = photos[index]
            let distance = abs(index - currentIndex)
            
            // Exponential priority decay for better performance
            let priority = max(0, 100 - (distance * distance / 10))
            
            if photo.loadState.isNotLoaded {
                priorityQueue.enqueue(PreloadItem(photo: photo, priority: priority))
            }
        }
        
        print("🔄 BackgroundPreloader: Scheduled \(priorityQueue.count) photos for preload (range: \(startIndex)-\(endIndex))")
        
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
                print("Failed to preload image \(photo.id): \(error)")
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