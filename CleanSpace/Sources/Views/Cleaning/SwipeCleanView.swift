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
    @State private var isLoadingPhotos = false
    @State private var hasTriggeredHaptic = false
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    private var currentAsset: PHAsset? {
        guard currentIndex < viewModel.recentPhotos.count else { return nil }
        return viewModel.recentPhotos[currentIndex]
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // Header status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vuốt để dọn dẹp")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Trái: Xóa • Phải: Giữ lại")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !viewModel.recentPhotos.isEmpty {
                        Text("\(min(currentIndex + 1, viewModel.recentPhotos.count)) / \(viewModel.recentPhotos.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }
                }
                .padding(.horizontal, 20)
                
                // 3D Card Swiper Stack
                ZStack {
                    if isLoadingPhotos {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Đang nạp ảnh gần đây...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } else if !viewModel.recentPhotos.isEmpty && currentIndex < viewModel.recentPhotos.count {
                        // Background Card 2 (3rd in stack)
                        if currentIndex + 2 < viewModel.recentPhotos.count {
                            ThumbnailView(asset: viewModel.recentPhotos[currentIndex + 2], targetSize: CGSize(width: 400, height: 500))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .cornerRadius(24)
                                .scaleEffect(0.88)
                                .offset(y: 24)
                                .opacity(0.4)
                                .padding(.horizontal, 28)
                        }
                        
                        // Background Card 1 (2nd in stack)
                        if currentIndex + 1 < viewModel.recentPhotos.count {
                            ThumbnailView(asset: viewModel.recentPhotos[currentIndex + 1], targetSize: CGSize(width: 500, height: 600))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .cornerRadius(24)
                                .scaleEffect(0.94)
                                .offset(y: 12)
                                .opacity(0.75)
                                .padding(.horizontal, 20)
                        }
                        
                        // Active Top Card
                        if let asset = currentAsset {
                            ZStack(alignment: .top) {
                                ThumbnailView(asset: asset, targetSize: CGSize(width: 700, height: 850))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .cornerRadius(24)
                                    .clipped()
                                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
                                
                                // Stamp Overlays
                                HStack {
                                    Text("XÓA")
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.9))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .rotationEffect(.degrees(16))
                                        .opacity(min(Double(-offset.width / 90), 1.0))
                                    
                                    Spacer()
                                    
                                    Text("GIỮ")
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.green.opacity(0.9))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .rotationEffect(.degrees(-16))
                                        .opacity(min(Double(offset.width / 90), 1.0))
                                }
                                .padding(24)
                            }
                            .padding(.horizontal, 16)
                            .offset(x: offset.width, y: offset.height * 0.35)
                            .rotationEffect(.degrees(Double(offset.width / 16)))
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        offset = gesture.translation
                                        if abs(offset.width) > 120 && !hasTriggeredHaptic {
                                            hasTriggeredHaptic = true
                                            HapticManager.shared.impact(.light)
                                        } else if abs(offset.width) <= 120 {
                                            hasTriggeredHaptic = false
                                        }
                                    }
                                    .onEnded { gesture in
                                        handleSwipeEnd(translation: gesture.translation)
                                    }
                            )
                        }
                    } else if !viewModel.recentPhotos.isEmpty && currentIndex >= viewModel.recentPhotos.count {
                        // Completed View
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.16))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 46))
                                    .foregroundColor(.yellow)
                            }
                            
                            Text("Đã duyệt xong tất cả ảnh!")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Bạn đã chọn \(trashedAssets.count) ảnh để xóa.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if !trashedAssets.isEmpty {
                                Button {
                                    HapticManager.shared.impact(.medium)
                                    showingFinishSheet = true
                                } label: {
                                    Text("Xem và dọn dẹp (\(trashedAssets.count) ảnh)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 15)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                        .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
                                }
                            }
                        }
                    } else {
                        // Empty library
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 54))
                                .foregroundColor(.secondary)
                            Text("Không có ảnh để duyệt")
                                .font(.headline)
                            Text("Hãy cấp quyền thư viện ảnh hoặc tải thêm ảnh vào thiết bị.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Tải lại ảnh") {
                                reloadPhotos()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxHeight: 520)
                
                // Bottom Floating Control Buttons
                HStack(spacing: 32) {
                    // Undo
                    Button {
                        undoLastSwipe()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 56, height: 56)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.orange)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
                    }
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.4 : 1.0)
                    
                    // Discard / Trash button
                    Button {
                        simulateSwipe(direction: -1)
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 26, weight: .bold))
                            .frame(width: 72, height: 72)
                            .background(Color.red.opacity(0.14))
                            .foregroundColor(.red)
                            .clipShape(Circle())
                            .shadow(color: Color.red.opacity(0.2), radius: 10, y: 5)
                    }
                    .disabled(viewModel.recentPhotos.isEmpty || currentIndex >= viewModel.recentPhotos.count)
                    .opacity((viewModel.recentPhotos.isEmpty || currentIndex >= viewModel.recentPhotos.count) ? 0.4 : 1.0)
                    
                    // Keep button
                    Button {
                        simulateSwipe(direction: 1)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .bold))
                            .frame(width: 72, height: 72)
                            .background(Color.green.opacity(0.14))
                            .foregroundColor(.green)
                            .clipShape(Circle())
                            .shadow(color: Color.green.opacity(0.2), radius: 10, y: 5)
                    }
                    .disabled(viewModel.recentPhotos.isEmpty || currentIndex >= viewModel.recentPhotos.count)
                    .opacity((viewModel.recentPhotos.isEmpty || currentIndex >= viewModel.recentPhotos.count) ? 0.4 : 1.0)
                }
                .padding(.bottom, 12)
            }
            .task {
                if viewModel.recentPhotos.isEmpty {
                    reloadPhotos()
                }
            }
            .sheet(isPresented: $showingFinishSheet) {
                SwipeFinishSummarySheet(trashedAssets: $trashedAssets, isDeleting: $isDeleting) {
                    deleteTrashedAssets()
                }
            }
        }
    }
    
    private func reloadPhotos() {
        isLoadingPhotos = true
        let photos = PhotoLibraryService.shared.fetchAllPhotos()
        viewModel.recentPhotos = Array(photos.prefix(100))
        currentIndex = 0
        trashedAssets.removeAll()
        keptAssets.removeAll()
        isLoadingPhotos = false
    }
    
    private func handleSwipeEnd(translation: CGSize) {
        if translation.width > 120 {
            HapticManager.shared.impact(.medium)
            if let asset = currentAsset {
                keptAssets.append(asset)
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                offset = CGSize(width: 500, height: translation.height)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                nextCard()
            }
        } else if translation.width < -120 {
            HapticManager.shared.impact(.heavy)
            if let asset = currentAsset {
                trashedAssets.append(asset)
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                offset = CGSize(width: -500, height: translation.height)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                nextCard()
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                offset = .zero
            }
        }
    }
    
    private func simulateSwipe(direction: CGFloat) {
        HapticManager.shared.impact(direction > 0 ? .medium : .heavy)
        withAnimation(.easeOut(duration: 0.25)) {
            offset = CGSize(width: direction * 450, height: 0)
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
        hasTriggeredHaptic = false
        currentIndex += 1
    }
    
    private func undoLastSwipe() {
        guard currentIndex > 0 else { return }
        HapticManager.shared.impact(.medium)
        currentIndex -= 1
        if let lastAsset = viewModel.recentPhotos[safe: currentIndex] {
            trashedAssets.removeAll { $0.localIdentifier == lastAsset.localIdentifier }
            keptAssets.removeAll { $0.localIdentifier == lastAsset.localIdentifier }
        }
    }
    
    private func deleteTrashedAssets() {
        HapticManager.shared.impact(.heavy)
        Task {
            isDeleting = true
            let ids = trashedAssets.map { $0.localIdentifier }
            _ = try? await PhotoLibraryService.shared.deleteAssets(withIdentifiers: ids)
            trashedAssets.removeAll()
            showingFinishSheet = false
            isDeleting = false
            HapticManager.shared.notification(.success)
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
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.red)
                }
                .padding(.top, 24)
                
                Text("Xác nhận dọn dẹp")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("Bạn đã đánh dấu \(trashedAssets.count) bức ảnh để dọn dẹp. Các ảnh này sẽ được xóa khỏi Thư viện ảnh của iPhone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    onConfirmDelete()
                } label: {
                    HStack(spacing: 8) {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Xóa vĩnh viễn \(trashedAssets.count) ảnh")
                        }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
