import Foundation
import Photos
import SwiftUI

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public var storageInfo: StorageInfo = .mock
    @Published public var isAuthorized: Bool = false
    @Published public var isScanning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var statusMessage: String = "Sẵn sàng quét"
    
    // Scanned categories
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var screenshots: [MediaItem] = []
    @Published public var heavyVideos: [MediaItem] = []
    
    // Swipe clean assets
    @Published public var recentPhotos: [PHAsset] = []
    
    // Quick statistics
    public var totalCleanableBytes: Int64 {
        let duplicateSavings = duplicateGroups.reduce(0) { $0 + $1.potentialSavingsBytes }
        let screenshotSavings = screenshots.filter { $0.isSelectedForDeletion }.reduce(0) { $0 + $1.fileSize }
        let videoSavings = heavyVideos.filter { $0.isSelectedForDeletion }.reduce(0) { $0 + $1.fileSize }
        return duplicateSavings + screenshotSavings + videoSavings
    }
    
    public var formattedCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
    }
    
    public init() {
        checkPermission()
        refreshStorage()
    }
    
    public func checkPermission() {
        let status = PhotoLibraryService.shared.authorizationStatus
        self.isAuthorized = (status == .authorized || status == .limited)
    }
    
    public func requestPermission() async {
        let status = await PhotoLibraryService.shared.requestAuthorization()
        self.isAuthorized = (status == .authorized || status == .limited)
        if isAuthorized {
            await startFullScan()
        }
    }
    
    public func refreshStorage() {
        self.storageInfo = StorageService.shared.fetchStorageInfo()
    }
    
    public func startFullScan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        statusMessage = "Đang kiểm tra thư viện ảnh..."
        
        // 1. Storage update
        refreshStorage()
        
        // 2. Fetch Screenshots
        statusMessage = "Đang tìm ảnh chụp màn hình..."
        let rawScreenshots = PhotoLibraryService.shared.fetchScreenshots()
        var mappedScreenshots: [MediaItem] = []
        for asset in rawScreenshots.prefix(150) {
            let size = await PhotoLibraryService.shared.getAssetSize(for: asset)
            var item = MediaItem(from: asset, estimatedFileSize: size)
            item.isSelectedForDeletion = true // Default select screenshots for convenient 1-tap clean
            mappedScreenshots.append(item)
        }
        self.screenshots = mappedScreenshots
        self.scanProgress = 0.3
        
        // 3. Fetch Heavy Videos (> 15MB or long duration)
        statusMessage = "Đang lọc các video dung lượng lớn..."
        let rawVideos = PhotoLibraryService.shared.fetchVideos()
        var mappedVideos: [MediaItem] = []
        for asset in rawVideos.prefix(50) {
            let size = await PhotoLibraryService.shared.getAssetSize(for: asset)
            if size > 15_000_000 { // > 15 MB
                mappedVideos.append(MediaItem(from: asset, estimatedFileSize: size))
            }
        }
        self.heavyVideos = mappedVideos
        self.scanProgress = 0.5
        
        // 4. Find Similar & Duplicate Photos using Vision
        statusMessage = "AI đang phân tích ảnh trùng lặp..."
        let allPhotos = PhotoLibraryService.shared.fetchAllPhotos()
        self.recentPhotos = Array(allPhotos.prefix(100))
        
        // Scan latest 200 photos for quick responsive UI
        let scanSample = Array(allPhotos.prefix(200))
        self.duplicateGroups = await DuplicateDetector.shared.findSimilarPhotos(
            from: scanSample,
            progress: { [weak self] current in
                Task { @MainActor [weak self] in
                    self?.scanProgress = 0.5 + (current * 0.5)
                }
            }
        )
        
        self.scanProgress = 1.0
        self.isScanning = false
        self.statusMessage = "Quét hoàn tất!"
    }
    
    // MARK: - Cleaning Actions
    
    public func cleanSelectedItems() async throws -> Int64 {
        var assetIdsToDelete: [String] = []
        var totalBytesSaved: Int64 = 0
        
        // Duplicates
        for group in duplicateGroups {
            for item in group.items where item.isSelectedForDeletion && item.id != group.bestItemId {
                assetIdsToDelete.append(item.id)
                totalBytesSaved += item.fileSize
            }
        }
        
        // Screenshots
        for item in screenshots where item.isSelectedForDeletion {
            assetIdsToDelete.append(item.id)
            totalBytesSaved += item.fileSize
        }
        
        // Videos
        for item in heavyVideos where item.isSelectedForDeletion {
            assetIdsToDelete.append(item.id)
            totalBytesSaved += item.fileSize
        }
        
        let success = try await PhotoLibraryService.shared.deleteAssets(withIdentifiers: assetIdsToDelete)
        if success {
            // Remove deleted items from memory
            let deletedSet = Set(assetIdsToDelete)
            
            self.duplicateGroups = duplicateGroups.compactMap { group in
                let remaining = group.items.filter { !deletedSet.contains($0.id) }
                return remaining.count > 1 ? DuplicateGroup(items: remaining, bestItemId: group.bestItemId) : nil
            }
            
            self.screenshots.removeAll { deletedSet.contains($0.id) }
            self.heavyVideos.removeAll { deletedSet.contains($0.id) }
            
            refreshStorage()
            return totalBytesSaved
        }
        
        return 0
    }
}
