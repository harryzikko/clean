import SwiftUI
import Photos

public struct ThumbnailView: View {
    public let asset: PHAsset?
    public let targetSize: CGSize
    @State private var image: UIImage? = nil
    
    public init(asset: PHAsset?, targetSize: CGSize = CGSize(width: 250, height: 250)) {
        self.asset = asset
        self.targetSize = targetSize
        // Immediate cache hit check to prevent UI flashing
        if let id = asset?.localIdentifier,
           let cached = PhotoLibraryService.shared.getCachedThumbnail(for: "\(id)_\(Int(targetSize.width))") {
            _image = State(initialValue: cached)
        }
    }
    
    public var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.4))
                    )
            }
        }
        .clipped()
        .task(id: asset?.localIdentifier) {
            guard image == nil, let asset = asset else { return }
            let loaded = await PhotoLibraryService.shared.requestThumbnail(for: asset, targetSize: targetSize)
            withAnimation(.easeInOut(duration: 0.15)) {
                self.image = loaded
            }
        }
    }
}
