import SwiftUI
import Photos

public struct LargeVideosView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isDeleting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.heavyVideos.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 90, height: 90)
                        Image(systemName: "video.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                    }
                    Text("Không có video quá nặng!")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Tất cả video của bạn đều có dung lượng hợp lý.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($viewModel.heavyVideos) { $item in
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                ThumbnailView(asset: item.asset, targetSize: CGSize(width: 160, height: 160))
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(12)
                                    .clipped()
                                
                                Text(item.formattedDuration)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(5)
                                    .padding(4)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.formattedSize)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("\(item.pixelWidth) × \(item.pixelHeight)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Compress action shortcut
                            if let asset = item.asset {
                                NavigationLink(destination: VideoCompressorView(preselectedAsset: asset)) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                                            .font(.caption)
                                        Text("Nén")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.14))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Delete Toggle
                            Button {
                                HapticManager.shared.selection()
                                item.isSelectedForDeletion.toggle()
                            } label: {
                                Image(systemName: item.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(item.isSelectedForDeletion ? .red : .gray.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(.secondarySystemBackground))
                    }
                }
                .listStyle(.insetGrouped)
                
                // Bottom Delete Bar
                let selectedCount = viewModel.heavyVideos.filter { $0.isSelectedForDeletion }.count
                let selectedBytes = viewModel.heavyVideos.filter { $0.isSelectedForDeletion }.reduce(0) { $0 + $1.fileSize }
                
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Đã chọn \(selectedCount) video")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Button {
                            deleteSelectedVideos()
                        } label: {
                            HStack(spacing: 6) {
                                if isDeleting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Xóa video đã chọn")
                                }
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .background(selectedCount > 0 ? Color.red : Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(isDeleting || selectedCount == 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle("Video dung lượng lớn")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thông báo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func deleteSelectedVideos() {
        HapticManager.shared.impact(.heavy)
        Task {
            isDeleting = true
            let idsToDelete = viewModel.heavyVideos.filter { $0.isSelectedForDeletion }.map { $0.id }
            do {
                let success = try await PhotoLibraryService.shared.deleteAssets(withIdentifiers: idsToDelete)
                if success {
                    let set = Set(idsToDelete)
                    viewModel.heavyVideos.removeAll { set.contains($0.id) }
                    viewModel.refreshStorage()
                    HapticManager.shared.notification(.success)
                    alertMessage = "Đã xóa thành công \(idsToDelete.count) video!"
                    showingAlert = true
                }
            } catch {
                HapticManager.shared.notification(.error)
                alertMessage = "Lỗi khi xóa: \(error.localizedDescription)"
                showingAlert = true
            }
            isDeleting = false
        }
    }
}
