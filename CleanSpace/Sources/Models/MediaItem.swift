import Foundation
import Photos
import UIKit

public struct MediaItem: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let asset: PHAsset?
    public let creationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let duration: TimeInterval
    public let fileSize: Int64
    public let isScreenshot: Bool
    public let isVideo: Bool
    public var isSelectedForDeletion: Bool
    
    public init(
        id: String,
        asset: PHAsset? = nil,
        creationDate: Date? = nil,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        isScreenshot: Bool = false,
        isVideo: Bool = false,
        isSelectedForDeletion: Bool = false
    ) {
        self.id = id
        self.asset = asset
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.fileSize = fileSize
        self.isScreenshot = isScreenshot
        self.isVideo = isVideo
        self.isSelectedForDeletion = isSelectedForDeletion
    }
    
    public init(from asset: PHAsset, estimatedFileSize: Int64 = 0) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.duration = asset.duration
        self.fileSize = estimatedFileSize
        self.isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        self.isVideo = asset.mediaType == .video
        self.isSelectedForDeletion = false
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var formattedDuration: String {
        guard isVideo else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}
