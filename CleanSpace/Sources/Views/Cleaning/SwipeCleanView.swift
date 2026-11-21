import SwiftUI
import Photos

public struct SwipeCleanView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var trashedAssets: [PHAsset] = []
    @State private var keptAssets: [PHAsset] = []
    @State private var isDeleting = false
    @State private var showingFinishSheet = false
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    private var currentAsset: PHAsset? {
        guard currentIndex < viewModel.recentPhotos.count else { return nil }
        return viewModel.recentPhotos[currentIndex]
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vuốt để dọn dẹp")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Trái: Xóa • Phải: Giữ lại")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(min(currentIndex + 1, viewModel.recentPhotos.count)) / \(viewModel.recentPhotos.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Card Swiper Area
                ZStack {
                    if currentIndex < viewModel.recentPhotos.count {
                        // Background Card preview (Next photo)
                        if currentIndex + 1 < viewModel.recentPhotos.count {
                            ThumbnailView(asset: viewModel.recentPhotos[currentIndex + 1], targetSize: CGSize(width: 400, height: 500))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .cornerRadius(24)
                                .scaleEffect(0.94)
                                .opacity(0.6)
                                .padding(.horizontal, 20)
                        }
                        
                        // Active Top Card
                        if let asset = currentAsset {
                            ZStack(alignment: .top) {
                                ThumbnailView(asset: asset, targetSize: CGSize(width: 600, height: 750))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .cornerRadius(24)
                                    .clipped()
                                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                                
                                // Swipe indicator overlays
                                HStack {
                                    Text("XÓA")
                                        .font(.headline)
                                        .fontWeight(.heavy)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                        .rotationEffect(.degrees(15))
                                        .opacity(Double(-offset.width / 100))
                                    
                                    Spacer()
                                    
                                    Text("GIỮ")
                                        .font(.headline)
                                        .fontWeight(.heavy)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.green.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                        .rotationEffect(.degrees(-15))
                                        .opacity(Double(offset.width / 100))
                                }
                                .padding(24)
                            }
                            .padding(.horizontal, 16)
                            .offset(x: offset.width, y: offset.height * 0.4)
                            .rotationEffect(.degrees(Double(offset.width / 20)))
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        offset = gesture.translation
                                    }
                                    .onEnded { gesture in
                                        handleSwipeEnd(translation: gesture.translation)
                                    }
                            )
                        }
                    } else {
                        // All swiped
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 64))
                                .foregroundColor(.yellow)
                            Text("Đã duyệt xong tất cả ảnh!")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Bạn đã chọn \(trashedAssets.count) ảnh để xóa.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if !trashedAssets.isEmpty {
                                Button {
                                    showingFinishSheet = true
                                } label: {
                                    Text("Xem và dọn dẹp (\(trashedAssets.count) ảnh)")
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 14)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(14)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 520)
                
                // Bottom Control Buttons
                HStack(spacing: 36) {
                    // Undo button
                    Button {
                        undoLastSwipe()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title2)
                            .frame(width: 54, height: 54)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.orange)
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex == 0)
                    
                    // Discard / Trash button (Swipe Left)
                    Button {
                        simulateSwipe(direction: -1)
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title)
                            .frame(width: 68, height: 68)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex >= viewModel.recentPhotos.count)
                    
                    // Keep button (Swipe Right)
                    Button {
                        simulateSwipe(direction: 1)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title)
                            .frame(width: 68, height: 68)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex >= viewModel.recentPhotos.count)
                }
                .padding(.bottom, 12)
            }
            .sheet(isPresented: $showingFinishSheet) {
                SwipeFinishSummarySheet(trashedAssets: $trashedAssets, isDeleting: $isDeleting) {
                    deleteTrashedAssets()
                }
            }
        }
    }
    
    private func handleSwipeEnd(translation: CGSize) {
        if translation.width > 120 {
            // Swiped Right -> Keep
            if let asset = currentAsset {
                keptAssets.append(asset)
            }
            nextCard()
        } else if translation.width < -120 {
            // Swiped Left -> Trash
            if let asset = currentAsset {
                trashedAssets.append(asset)
            }
            nextCard()
        } else {
            // Return to center
            withAnimation(.spring()) {
                offset = .zero
            }
        }
    }
    
    private func simulateSwipe(direction: CGFloat) {
        withAnimation(.easeOut(duration: 0.25)) {
            offset = CGSize(width: direction * 400, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if direction > 0, let asset = currentAsset {
                keptAssets.append(asset)
            } else if direction < 0, let asset = currentAsset {
                trashedAssets.append(asset)
            }
            nextCard()
        }
    }
    
    private func nextCard() {
        offset = .zero
        currentIndex += 1
    }
    
    private func undoLastSwipe() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        if let lastAsset = viewModel.recentPhotos[safe: currentIndex] {
            trashedAssets.removeAll { $0.localIdentifier == lastAsset.localIdentifier }
            keptAssets.removeAll { $0.localIdentifier == lastAsset.localIdentifier }
        }
    }
    
    private func deleteTrashedAssets() {
        Task {
            isDeleting = true
            let ids = trashedAssets.map { $0.localIdentifier }
            _ = try? await PhotoLibraryService.shared.deleteAssets(withIdentifiers: ids)
            trashedAssets.removeAll()
            showingFinishSheet = false
            isDeleting = false
            viewModel.refreshStorage()
        }
    }
}

struct SwipeFinishSummarySheet: View {
    @Binding var trashedAssets: [PHAsset]
    @Binding var isDeleting: Bool
    let onConfirmDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Xác nhận xóa")
                    .font(.headline)
                    .padding(.top)
                
                Text("Bạn đã chọn \(trashedAssets.count) bức ảnh để xóa khỏi thư viện.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button {
                    onConfirmDelete()
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Xóa vĩnh viễn \(trashedAssets.count) ảnh")
                        }
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal)
                .disabled(isDeleting)
            }
            .navigationBarItems(trailing: Button("Đóng") { dismiss() })
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
