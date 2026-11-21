import Foundation

public final class StorageService: @unchecked Sendable {
    public static let shared = StorageService()
    
    private init() {}
    
    public func fetchStorageInfo() -> StorageInfo {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            let used = max(0, total - free)
            
            return StorageInfo(totalBytes: total, freeBytes: free, usedBytes: used)
        } catch {
            #if targetEnvironment(simulator)
            return StorageInfo.mock
            #else
            return StorageInfo(totalBytes: 0, freeBytes: 0, usedBytes: 0)
            #endif
        }
    }
}
