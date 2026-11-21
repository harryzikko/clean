import Foundation
import Photos
import Vision
import UIKit

public final class DuplicateDetector: @unchecked Sendable {
    public static let shared = DuplicateDetector()
    
    // Similarity distance threshold (0.0 = identical, 1.0 = completely different)
    // Values <= 0.45 generally indicate very similar or burst photos
    private let similarityThreshold: Float = 0.42
    
    private init() {}
    
    public struct ScannedAsset: Sendable {
        public let asset: PHAsset
        public let featurePrint: VNFeaturePrintObservation
        public let fileSize: Int64
    }
    
    /// Groups similar photos using Apple Vision feature prints
    public func findSimilarPhotos(
        from assets: [PHAsset],
        progress: (@Sendable (Double) -> Void)? = nil
    ) async -> [DuplicateGroup] {
        guard assets.count > 1 else { return [] }
        
        var scannedAssets: [ScannedAsset] = []
        let total = Double(assets.count)
        
        // Step 1: Generate feature prints for assets in chronological order
        // Limiting image thumbnail size for Vision processing ensures low memory & high speed
        let targetSize = CGSize(width: 300, height: 300)
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.resizeMode = .exact
        requestOptions.deliveryMode = .fastFormat
        
        let imageManager = PHImageManager.default()
        
        for (index, asset) in assets.enumerated() {
            if let image = await fetchImageSynchronously(for: asset, targetSize: targetSize, manager: imageManager, options: requestOptions),
               let cgImage = image.cgImage {
                if let print = generateFeaturePrint(for: cgImage) {
                    let size = await PhotoLibraryService.shared.getAssetSize(for: asset)
                    scannedAssets.append(ScannedAsset(asset: asset, featurePrint: print, fileSize: size))
                }
            }
            progress?(Double(index) / total * 0.7) // 70% of progress for feature print extraction
        }
        
        // Step 2: Compare and cluster adjacent / nearby photos
        var visited = Set<String>()
        var duplicateGroups: [DuplicateGroup] = []
        
        let count = scannedAssets.count
        for i in 0..<count {
            let base = scannedAssets[i]
            if visited.contains(base.asset.localIdentifier) { continue }
            
            var cluster: [ScannedAsset] = [base]
            
            // Compare within a window of time or index (photos taken near each other)
            // Checking next 20 items is realistic for consecutive shots
            let windowEnd = min(count, i + 25)
            for j in (i + 1)..<windowEnd {
                let candidate = scannedAssets[j]
                if visited.contains(candidate.asset.localIdentifier) { continue }
                
                // If creation dates differ by more than 2 minutes, unlikely to be similar burst
                if let date1 = base.asset.creationDate, let date2 = candidate.asset.creationDate {
                    if abs(date1.timeIntervalSince(date2)) > 180 {
                        continue
                    }
                }
                
                var distance: Float = 1.0
                do {
                    try base.featurePrint.computeDistance(&distance, to: candidate.featurePrint)
                    if distance <= similarityThreshold {
                        cluster.append(candidate)
                        visited.insert(candidate.asset.localIdentifier)
                    }
                } catch {
                    continue
                }
            }
            
            if cluster.count > 1 {
                visited.insert(base.asset.localIdentifier)
                
                // Pick best photo (favorite first, then largest dimensions, then largest size)
                let sortedByQuality = cluster.sorted { a, b in
                    if a.asset.isFavorite != b.asset.isFavorite {
                        return a.asset.isFavorite && !b.asset.isFavorite
                    }
                    let resA = a.asset.pixelWidth * a.asset.pixelHeight
                    let resB = b.asset.pixelWidth * b.asset.pixelHeight
                    if resA != resB {
                        return resA > resB
                    }
                    return a.fileSize > b.fileSize
                }
                
                let bestId = sortedByQuality.first!.asset.localIdentifier
                
                // Convert to MediaItems, pre-selecting duplicates for deletion
                let mediaItems = cluster.map { item in
                    var media = MediaItem(from: item.asset, estimatedFileSize: item.fileSize)
                    media.isSelectedForDeletion = (item.asset.localIdentifier != bestId)
                    return media
                }
                
                duplicateGroups.append(DuplicateGroup(
                    items: mediaItems,
                    bestItemId: bestId
                ))
            }
        }
        
        progress?(1.0)
        return duplicateGroups
    }
    
    // MARK: - Private Helpers
    
    private func fetchImageSynchronously(
        for asset: PHAsset,
        targetSize: CGSize,
        manager: PHImageManager,
        options: PHImageRequestOptions
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func generateFeaturePrint(for cgImage: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
}
