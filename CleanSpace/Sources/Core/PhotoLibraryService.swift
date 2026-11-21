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
    
    // MARK: - Crash-Proof File Size Calculation
    
    public func getAssetSize(for asset: PHAsset) async -> Int64 {
        // Safe calculation: avoids private KVC calls like resource.value(forKey: "fileSize")
        // which throw uncaught NSUnknownKeyException and crash the app on iOS.
        if asset.mediaType == .video {
            // Standard iPhone 1080p/4K video bitrate approximation
            let duration = max(1.0, asset.duration)
            let is4K = asset.pixelWidth >= 3840 || asset.pixelHeight >= 2160
            let bytesPerSecond: Double = is4K ? 6_000_000 : 2_200_000
            return Int64(duration * bytesPerSecond)
        } else {
            // Image approximation based on pixel count & compression
            let pixels = max(1, asset.pixelWidth * asset.pixelHeight)
            let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
            let ratio: Double = isScreenshot ? 0.35 : 0.45
            return max(350_000, Int64(Double(pixels) * ratio))
        }
    }
    
    // MARK: - Thumbnail Loading (Crash-Proof Continuation)
    
    public func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200)
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
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
            ) { image, _ in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
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
