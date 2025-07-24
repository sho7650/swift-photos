import Foundation
import AppKit

/// LRU (Least Recently Used) cache for images with memory pressure handling
actor LRUImageCache {
    private var cache: [UUID: CacheNode] = [:]
    private var head: CacheNode?
    private var tail: CacheNode?
    private let maxSize: Int
    private var currentSize: Int = 0
    
    class CacheNode {
        let key: UUID
        let image: NSImage
        let size: Int
        var prev: CacheNode?
        var next: CacheNode?
        
        init(key: UUID, image: NSImage) {
            self.key = key
            self.image = image
            // Estimate size: width * height * 4 bytes per pixel
            self.size = Int(image.size.width * image.size.height * 4)
        }
    }
    
    init(maxSizeMB: Int = 500) {
        self.maxSize = maxSizeMB * 1024 * 1024 // Convert to bytes
        
        // Register for memory pressure notifications
        Task {
            await setupMemoryPressureHandler()
        }
    }
    
    /// Store an image in the cache
    func store(_ image: NSImage, for key: UUID) {
        // Remove existing node if present
        if let existingNode = cache[key] {
            remove(node: existingNode)
        }
        
        // Create new node
        let node = CacheNode(key: key, image: image)
        
        // Add to front
        addToFront(node: node)
        cache[key] = node
        currentSize += node.size
        
        // Evict if necessary
        while currentSize > maxSize && tail != nil {
            if let nodeToRemove = tail {
                remove(node: nodeToRemove)
            }
        }
    }
    
    /// Retrieve an image from the cache
    func retrieve(for key: UUID) -> NSImage? {
        guard let node = cache[key] else { return nil }
        
        // Move to front (mark as recently used)
        remove(node: node)
        addToFront(node: node)
        
        return node.image
    }
    
    /// Remove an image from the cache
    func evict(for key: UUID) {
        guard let node = cache[key] else { return }
        remove(node: node)
    }
    
    /// Clear the entire cache
    func clear() {
        cache.removeAll()
        head = nil
        tail = nil
        currentSize = 0
    }
    
    /// Get current cache size in MB
    func getCurrentSizeMB() -> Int {
        return currentSize / (1024 * 1024)
    }
    
    /// Handle memory pressure by evicting least recently used items
    func handleMemoryPressure() {
        // Evict 25% of cache
        let targetSize = maxSize * 3 / 4
        
        while currentSize > targetSize && tail != nil {
            if let nodeToRemove = tail {
                remove(node: nodeToRemove)
            }
        }
    }
    
    private func addToFront(node: CacheNode) {
        node.next = head
        node.prev = nil
        
        if let currentHead = head {
            currentHead.prev = node
        }
        
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func remove(node: CacheNode) {
        cache.removeValue(forKey: node.key)
        currentSize -= node.size
        
        if node.prev != nil {
            node.prev?.next = node.next
        } else {
            head = node.next
        }
        
        if node.next != nil {
            node.next?.prev = node.prev
        } else {
            tail = node.prev
        }
    }
    
    private func setupMemoryPressureHandler() {
        // Note: NSApplication.didReceiveMemoryWarningNotification is iOS only
        // For macOS, we'll monitor available memory periodically
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkMemoryStatus()
            }
        }
    }
    
    private func checkMemoryStatus() {
        let memoryInfo = ProcessInfo.processInfo
        let physicalMemory = memoryInfo.physicalMemory
        
        // Get available memory (this is a simplified check)
        let memoryUsage = Double(currentSize) / Double(physicalMemory)
        
        if memoryUsage > 0.5 { // If using more than 50% of physical memory
            handleMemoryPressure()
        }
    }
}