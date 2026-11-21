import Foundation
import AVFoundation
import Photos
import UIKit

public enum CompressionQuality: String, CaseIterable, Identifiable, Sendable {
    case high = "Cao (1080p)"
    case medium = "Cân bằng (720p)"
    case low = "Tiết kiệm tối đa (540p)"
    
    public var id: String { rawValue }
    
    public var exportPreset: String {
        switch self {
        case .high: return AVAssetExportPreset1920x1080
        case .medium: return AVAssetExportPreset1280x720
        case .low: return AVAssetExportPreset960x540
        }
    }
    
    public var estimatedReductionPercentage: Double {
        switch self {
        case .high: return 0.40
        case .medium: return 0.65
        case .low: return 0.85
        }
    }
}

public struct CompressionResult: Sendable {
    public let originalSize: Int64
    public let compressedSize: Int64
    public let savedBytes: Int64
    public let outputURL: URL
    
    public var formattedSavedSize: String {
        ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }
}

public final class VideoCompressorService: @unchecked Sendable {
    public static let shared = VideoCompressorService()
    
    private init() {}
    
    public func compressVideo(
        asset: PHAsset,
        quality: CompressionQuality = .medium,
        progressHandler: (@Sendable (Float) -> Void)? = nil
    ) async throws -> CompressionResult {
        let avAsset = try await fetchAVAsset(for: asset)
        let originalSize = await PhotoLibraryService.shared.getAssetSize(for: asset)
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: avAsset,
            presetName: quality.exportPreset
        ) else {
            throw NSError(domain: "CleanSpace.VideoCompressor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Không thể khởi tạo phiên nén video."
            ])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .milliseconds(200))
        timer.setEventHandler {
            progressHandler?(exportSession.progress)
        }
        timer.resume()
        
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            
            exportSession.exportAsynchronously {
                timer.cancel()
                lock.lock()
                defer { lock.unlock() }
                
                guard !hasResumed else { return }
                hasResumed = true
                
                switch exportSession.status {
                case .completed:
                    let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
                    let compressedSize = Int64((attributes?[.size] as? UInt64) ?? 0)
                    let saved = max(0, originalSize - compressedSize)
                    
                    let result = CompressionResult(
                        originalSize: originalSize,
                        compressedSize: compressedSize,
                        savedBytes: saved,
                        outputURL: outputURL
                    )
                    continuation.resume(returning: result)
                    
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? NSError(domain: "CleanSpace.VideoCompressor", code: -2))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "CleanSpace.VideoCompressor", code: -3, userInfo: [NSLocalizedDescriptionKey: "Đã hủy nén"]))
                default:
                    continuation.resume(throwing: NSError(domain: "CleanSpace.VideoCompressor", code: -4, userInfo: [NSLocalizedDescriptionKey: "Lỗi không xác định khi xuất video"]))
                }
            }
        }
    }
    
    public func saveCompressedVideoToLibrary(url: URL, deleteOriginalAssetId: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let lock = NSLock()
            var hasResumed = false
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                request?.creationDate = Date()
                
                if let originalId = deleteOriginalAssetId {
                    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [originalId], options: nil)
                    if assets.count > 0 {
                        PHAssetChangeRequest.deleteAssets(assets)
                    }
                }
            }, completionHandler: { success, error in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            })
        }
    }
    
    private func fetchAVAsset(for asset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                lock.lock()
                defer { lock.unlock() }
                
                guard !hasResumed else { return }
                hasResumed = true
                
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: NSError(domain: "CleanSpace.VideoCompressor", code: -4, userInfo: [
                        NSLocalizedDescriptionKey: "Không thể tải video từ thư viện."
                    ]))
                }
            }
        }
    }
}
