import SwiftUI
import Photos

public struct ScreenshotsCleanView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isDeleting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    private var selectedCount: Int {
        viewModel.screenshots.filter { $0.isSelectedForDeletion }.count
    }
    
    private var selectedBytes: Int64 {
        viewModel.screenshots.filter { $0.isSelectedForDeletion }.reduce(0) { $0 + $1.fileSize }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text("\(viewModel.screenshots.count) ảnh chụp màn hình")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(selectedCount == viewModel.screenshots.count ? "Bỏ chọn tất cả" : "Chọn tất cả") {
                    let selectAll = (selectedCount != viewModel.screenshots.count)
                    for index in viewModel.screenshots.indices {
                        viewModel.screenshots[index].isSelectedForDeletion = selectAll
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if viewModel.screenshots.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    Text("Không có ảnh chụp màn hình nào")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach($viewModel.screenshots) { $item in
                            ZStack(alignment: .topTrailing) {
                                ThumbnailView(asset: item.asset, targetSize: CGSize(width: 200, height: 200))
                                    .aspectRatio(1, contentMode: .fill)
                                    .cornerRadius(10)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        item.isSelectedForDeletion.toggle()
                                    }
                                
                                Button {
                                    item.isSelectedForDeletion.toggle()
                                } label: {
                                    Image(systemName: item.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(item.isSelectedForDeletion ? .red : .white)
                                        .background(Circle().fill(Color.black.opacity(0.3)))
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
            }
            
            // Bottom Action Bar
            VStack(spacing: 8) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Đã chọn: \(selectedCount) ảnh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button {
                        deleteScreenshots()
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Xóa ảnh chụp màn hình")
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
        .navigationTitle("Ảnh chụp màn hình")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thông báo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func deleteScreenshots() {
        Task {
            isDeleting = true
            let idsToDelete = viewModel.screenshots.filter { $0.isSelectedForDeletion }.map { $0.id }
            do {
                let success = try await PhotoLibraryService.shared.deleteAssets(withIdentifiers: idsToDelete)
                if success {
                    let set = Set(idsToDelete)
                    viewModel.screenshots.removeAll { set.contains($0.id) }
                    viewModel.refreshStorage()
                    alertMessage = "Đã xóa thành công \(idsToDelete.count) ảnh chụp màn hình!"
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
