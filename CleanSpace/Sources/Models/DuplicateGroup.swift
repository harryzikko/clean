import Foundation

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public var items: [MediaItem]
    public var bestItemId: String
    
    public init(id: String = UUID().uuidString, items: [MediaItem], bestItemId: String) {
        self.id = id
        self.items = items
        self.bestItemId = bestItemId
    }
    
    public var potentialSavingsBytes: Int64 {
        items.filter { $0.id != bestItemId && $0.isSelectedForDeletion }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    public var totalGroupSizeBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }
    
    public var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: potentialSavingsBytes, countStyle: .file)
    }
}
