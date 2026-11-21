import SwiftUI
import Photos

public struct LargeVideosView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isDeleting = false
    @State private var selectedVideoToCompress: PHAsset? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.heavyVideos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "video.badge.checkmark")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text("Không có video quá nặng!")
                        .font(.headline)
                    Text("Tất cả video đều có dung lượng hợp lý.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($viewModel.heavyVideos) { $item in
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                ThumbnailView(asset: item.asset, targetSize: CGSize(width: 120, height: 120))
                                    .frame(width: 75, height: 75)
                                    .cornerRadius(10)
                                
                                Text(item.formattedDuration)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .padding(4)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.formattedSize)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(item.pixelWidth)x\(item.pixelHeight)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Compress action
                            if let asset = item.asset {
                                NavigationLink(destination: VideoCompressorView(preselectedAsset: asset)) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        Text("Nén")
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Delete Toggle
                            Button {
                                item.isSelectedForDeletion.toggle()
                            } label: {
                                Image(systemName: item.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(item.isSelectedForDeletion ? .red : .gray.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                
                // Bottom Delete Bar
                let selectedCount = viewModel.heavyVideos.filter { $0.isSelectedForDeletion }.count
                let selectedBytes = viewModel.heavyVideos.filter { $0.isSelectedForDeletion }.reduce(0) { $0 + $1.fileSize }
                
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Đã chọn \(selectedCount) video")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Button {
                            deleteSelectedVideos()
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Xóa video")
                                }
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(selectedCount > 0 ? Color.red : Color.gray.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(isDeleting || selectedCount == 0)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
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
        Task {
            isDeleting = true
            let idsToDelete = viewModel.heavyVideos.filter { $0.isSelectedForDeletion }.map { $0.id }
            do {
                let success = try await PhotoLibraryService.shared.deleteAssets(withIdentifiers: idsToDelete)
                if success {
                    let set = Set(idsToDelete)
                    viewModel.heavyVideos.removeAll { set.contains($0.id) }
                    viewModel.refreshStorage()
                    alertMessage = "Đã xóa thành công \(idsToDelete.count) video!"
                    showingAlert = true
                }
            } catch {
                alertMessage = "Lỗi khi xóa: \(error.localizedDescription)"
                showingAlert = true
            }
            isDeleting = false
        }
    }
}
