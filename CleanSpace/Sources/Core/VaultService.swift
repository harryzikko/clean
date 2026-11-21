import Foundation
import LocalAuthentication
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
    
    // MARK: - Biometric Authentication
    
    public func authenticateWithBiometrics(reason: String = "Mở khóa kho ảnh bảo mật") async -> (success: Bool, error: String?) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return (false, error?.localizedDescription ?? "Thiết bị không hỗ trợ Face ID / Mã khóa")
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
                if success {
                    continuation.resume(returning: (true, nil))
                } else {
                    continuation.resume(returning: (false, evalError?.localizedDescription))
                }
            }
        }
    }
    
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
        }
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
}
