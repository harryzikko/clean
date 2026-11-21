import Foundation
import Photos
import UIKit

public struct VaultItem: Identifiable, Sendable {
    public let id: String
    public let fileName: String
    public let dateAdded: Date
    public let fileSize: Int64
    public let isVideo: Bool
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

public final class VaultService: @unchecked Sendable {
    public static let shared = VaultService()
    
    private let fileManager = FileManager.default
    private var vaultDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vault = docs.appendingPathComponent(".secret_vault", isDirectory: true)
        if !fileManager.fileExists(atPath: vault.path) {
            try? fileManager.createDirectory(at: vault, withIntermediateDirectories: true)
        }
        return vault
    }
    
    private init() {}
    
    // MARK: - Vault Operations
    
    public func saveImageToVault(image: UIImage) async throws -> VaultItem {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "CleanSpace.Vault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể mã hóa ảnh"])
        }
        
        let id = UUID().uuidString
        let fileName = "\(id).jpg"
        let fileURL = vaultDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL, options: .completeFileProtection)
        
        return VaultItem(
            id: id,
            fileName: fileName,
            dateAdded: Date(),
            fileSize: Int64(data.count),
            isVideo: false
        )
    }
    
    public func listVaultItems() -> [VaultItem] {
        guard let files = try? fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            return []
        }
        
        return files.compactMap { url in
            let id = url.deletingPathExtension().lastPathComponent
            guard !id.isEmpty else { return nil }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.creationDate ?? Date()
            let isVideo = url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov"
            
            return VaultItem(id: id, fileName: url.lastPathComponent, dateAdded: date, fileSize: size, isVideo: isVideo)
        }.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    public func loadVaultImage(fileName: String) -> UIImage? {
        let fileURL = vaultDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    public func deleteVaultItem(fileName: String) {
        let fileURL = vaultDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    public func exportItemToPhotosLibrary(fileName: String) async throws {
        guard let image = loadVaultImage(fileName: fileName) else {
            throw NSError(domain: "CleanSpace.Vault", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ảnh để xuất"])
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let lock = NSLock()
            var hasResumed = false
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
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
}
