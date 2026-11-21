import Foundation
import Photos
import UIKit

public final class PhotoLibraryService: @unchecked Sendable {
    public static let shared = PhotoLibraryService()
    
    private let imageManager = PHCachingImageManager()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        thumbnailCache.countLimit = 500 // Cache up to 500 thumbnails in RAM
        thumbnailCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB max RAM cache
    }
    
    // MARK: - Authorization
    
    public var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    public func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    // MARK: - Asset Fetching
    
    public func fetchAllPhotos() -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
    
    public func fetchScreenshots() -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d AND (mediaSubtype & %d) != 0",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
    
    public func fetchVideos() -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
    
    // MARK: - Safe File Size Calculation
    
    public func getAssetSize(for asset: PHAsset) async -> Int64 {
        if asset.mediaType == .video {
            let duration = max(1.0, asset.duration)
            let is4K = asset.pixelWidth >= 3840 || asset.pixelHeight >= 2160
            let bytesPerSecond: Double = is4K ? 5_500_000 : 2_200_000
            return Int64(duration * bytesPerSecond)
        } else {
            let pixels = max(1, asset.pixelWidth * asset.pixelHeight)
            let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
            let ratio: Double = isScreenshot ? 0.35 : 0.45
            return max(350_000, Int64(Double(pixels) * ratio))
        }
    }
    
    // MARK: - Cached High-Performance Thumbnail Loading
    
    public func getCachedThumbnail(for assetId: String) -> UIImage? {
        thumbnailCache.object(forKey: assetId as NSString)
    }
    
    public func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 250, height: 250)
    ) async -> UIImage? {
        let key = "\(asset.localIdentifier)_\(Int(targetSize.width))" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    if let img = image {
                        self?.thumbnailCache.setObject(img, forKey: key)
                    }
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    // MARK: - Asset Deletion
    
    public func deleteAssets(withIdentifiers ids: [String]) async throws -> Bool {
        guard !ids.isEmpty else { return true }
        
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assetsToDelete.count > 0 else { return true }
        
        // Invalidate cache for deleted items
        for id in ids {
            thumbnailCache.removeObject(forKey: id as NSString)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete)
            }, completionHandler: { success, error in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                }
            })
        }
    }
}
