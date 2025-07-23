import Foundation
import AppKit

/// 特定画像の最優先即座ロード機能 - プログレスバージャンプ時の遅延解決
/// 他のキャッシュ処理と独立して、選択された画像のみを緊急ロードする
actor TargetImageLoader {
    private let imageLoader: ImageLoader
    private var emergencyTasks: [UUID: Task<NSImage, Error>] = [:]
    private var completionCallbacks: [UUID: (Result<NSImage, Error>) -> Void] = [:]
    
    // パフォーマンス統計
    private var emergencyLoads: Int = 0
    private var emergencyLoadTime: [Double] = []
    
    init() {
        self.imageLoader = ImageLoader()
        print("🚨 TargetImageLoader: Initialized for emergency image loading")
    }
    
    /// 指定画像を最優先で即座ロード - プログレスバージャンプ専用
    /// - Parameters:
    ///   - photo: ロード対象の写真
    ///   - completion: ロード完了時のコールバック（メインスレッドで実行）
    func loadImageEmergency(
        photo: Photo,
        completion: @escaping @MainActor (Result<NSImage, Error>) -> Void
    ) {
        let startTime = Date()
        emergencyLoads += 1
        
        print("🚨 TargetImageLoader: Emergency loading photo \(photo.id) (\(photo.imageURL.url.lastPathComponent))")
        
        // 既存の緊急タスクをキャンセル（新しいジャンプが最優先）
        cancelPreviousEmergencyLoads()
        
        // 緊急ロードタスクを作成
        let task = Task<NSImage, Error> { [weak self] in
            do {
                let image = try await self?.imageLoader.loadImage(from: photo.imageURL) ?? {
                    throw SlideshowError.fileNotFound(photo.imageURL.url)
                }()
                
                // パフォーマンス測定
                let loadTime = Date().timeIntervalSince(startTime)
                await self?.recordEmergencyLoadTime(loadTime)
                
                print("🚨 TargetImageLoader: Emergency load completed in \(String(format: "%.2f", loadTime * 1000))ms")
                return image
            } catch {
                print("❌ TargetImageLoader: Emergency load failed: \(error)")
                throw error
            }
        }
        
        // タスクを登録
        emergencyTasks[photo.id] = task
        
        // 完了処理
        Task {
            do {
                let loadedImage = try await task.value
                await MainActor.run {
                    completion(.success(loadedImage))
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        completion(.failure(error))
                    }
                }
            }
            
            // クリーンアップ
            await self.cleanupEmergencyTask(photoId: photo.id)
        }
    }
    
    /// 既存の緊急ロードをすべてキャンセル
    private func cancelPreviousEmergencyLoads() {
        for (photoId, task) in emergencyTasks {
            task.cancel()
            print("🚫 TargetImageLoader: Cancelled emergency load for photo \(photoId)")
        }
        emergencyTasks.removeAll()
        completionCallbacks.removeAll()
    }
    
    /// 指定された画像の緊急ロードをキャンセル
    func cancelEmergencyLoad(for photoId: UUID) {
        if let task = emergencyTasks[photoId] {
            task.cancel()
            emergencyTasks.removeValue(forKey: photoId)
            completionCallbacks.removeValue(forKey: photoId)
            print("🚫 TargetImageLoader: Cancelled emergency load for photo \(photoId)")
        }
    }
    
    /// 指定画像が緊急ロード中かチェック
    func isEmergencyLoading(photoId: UUID) -> Bool {
        return emergencyTasks[photoId] != nil
    }
    
    /// 緊急タスクのクリーンアップ
    private func cleanupEmergencyTask(photoId: UUID) {
        emergencyTasks.removeValue(forKey: photoId)
        completionCallbacks.removeValue(forKey: photoId)
    }
    
    /// パフォーマンス統計の記録
    private func recordEmergencyLoadTime(_ time: Double) {
        emergencyLoadTime.append(time)
        
        // 最近の10回の平均を保持
        if emergencyLoadTime.count > 10 {
            emergencyLoadTime.removeFirst()
        }
    }
    
    /// パフォーマンス統計の取得
    func getPerformanceStats() -> (loads: Int, averageTime: Double) {
        let avgTime = emergencyLoadTime.isEmpty ? 0.0 : emergencyLoadTime.reduce(0, +) / Double(emergencyLoadTime.count)
        return (loads: emergencyLoads, averageTime: avgTime)
    }
    
    /// 全ての緊急ロードをクリーンアップ
    func cleanup() {
        cancelPreviousEmergencyLoads()
        emergencyLoads = 0
        emergencyLoadTime.removeAll()
        print("🧹 TargetImageLoader: Cleaned up all emergency loads")
    }
}

/// プログレスバージャンプ専用の高速化拡張
extension TargetImageLoader {
    
    /// プログレスバーからのジャンプ要求を処理
    /// - Parameters:
    ///   - targetPhoto: ジャンプ先の写真
    ///   - completion: 完了時のコールバック
    func handleProgressBarJump(
        to targetPhoto: Photo,
        completion: @escaping @MainActor (Result<NSImage, Error>) -> Void
    ) {
        print("🎯 TargetImageLoader: Handling progress bar jump to photo \(targetPhoto.id)")
        
        // プログレスバージャンプは常に最優先
        loadImageEmergency(photo: targetPhoto) { result in
            completion(result)
        }
    }
    
    /// 複数画像の並行緊急ロード（隣接画像の先読み用）
    func loadMultipleEmergency(
        photos: [Photo],
        primaryPhotoId: UUID,
        completion: @escaping @MainActor ([UUID: NSImage]) -> Void
    ) async {
        print("🚨 TargetImageLoader: Loading \(photos.count) images with primary \(primaryPhotoId)")
        
        let startTime = Date()
        var results: [UUID: NSImage] = [:]
        
        await withTaskGroup(of: (UUID, NSImage)?.self) { group in
            for photo in photos {
                let isPrimary = photo.id == primaryPhotoId
                let priority = isPrimary ? TaskPriority.userInitiated : TaskPriority.utility
                
                group.addTask(priority: priority) { [self] in
                    do {
                        let image = try await self.imageLoader.loadImage(from: photo.imageURL)
                        return (photo.id, image)
                    } catch {
                        print("❌ TargetImageLoader: Failed to load \(photo.id): \(error)")
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let (photoId, image) = result {
                    results[photoId] = image
                }
            }
        }
        
        let loadTime = Date().timeIntervalSince(startTime)
        print("🚨 TargetImageLoader: Batch loaded \(results.count) images in \(String(format: "%.2f", loadTime * 1000))ms")
        
        await MainActor.run {
            completion(results)
        }
    }
}