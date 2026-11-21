import Foundation
import Photos
import UIKit

public final class PhotoLibraryService: @unchecked Sendable {
    public static let shared = PhotoLibraryService()
    
    private let imageManager = PHCachingImageManager()
    
    private init() {}
    
    // MARK: - Authorization
    
    public var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    public func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    // MARK: - Asset Fetching
    
    public func fetchAllPhotos() -> [PHAsset] {
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
    
    // MARK: - File Size Estimation & Exact Size
    
    public func getAssetSize(for asset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0
        for resource in resources {
            if let unsignedSize = resource.value(forKey: "fileSize") as? UInt64 {
                totalSize += Int64(unsignedSize)
            }
        }
        
        // Fallback estimate if resource size is zero
        if totalSize == 0 {
            if asset.mediaType == .video {
                // Approximate 2MB per second for 1080p video
                totalSize = max(1_000_000, Int64(asset.duration * 2_500_000))
            } else {
                // Approximate image size from pixel dimensions
                let pixels = asset.pixelWidth * asset.pixelHeight
                totalSize = max(500_000, Int64(Double(pixels) * 0.4))
            }
        }
        return totalSize
    }
    
    // MARK: - Thumbnail Loading
    
    public func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200)
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded || image != nil {
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
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            })
        }
    }
}
