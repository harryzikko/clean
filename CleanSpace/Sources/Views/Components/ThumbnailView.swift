import SwiftUI
import Photos

public struct ThumbnailView: View {
    public let asset: PHAsset?
    public let targetSize: CGSize
    @State private var image: UIImage? = nil
    
    public init(asset: PHAsset?, targetSize: CGSize = CGSize(width: 150, height: 150)) {
        self.asset = asset
        self.targetSize = targetSize
    }
    
    public var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .clipped()
        .task(id: asset?.localIdentifier) {
            guard let asset = asset else { return }
            self.image = await PhotoLibraryService.shared.requestThumbnail(for: asset, targetSize: targetSize)
        }
    }
}
