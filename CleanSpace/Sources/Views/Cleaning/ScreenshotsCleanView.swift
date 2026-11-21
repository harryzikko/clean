import SwiftUI
import Photos

public struct ScreenshotsCleanView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isDeleting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
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
            // Header stats
            HStack {
                Text("\(viewModel.screenshots.count) ảnh chụp màn hình")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    HapticManager.shared.selection()
                    let selectAll = (selectedCount != viewModel.screenshots.count)
                    for index in viewModel.screenshots.indices {
                        viewModel.screenshots[index].isSelectedForDeletion = selectAll
                    }
                } label: {
                    Text(selectedCount == viewModel.screenshots.count ? "Bỏ chọn tất cả" : "Chọn tất cả")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            if viewModel.screenshots.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 90, height: 90)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)
                    }
                    Text("Không có ảnh chụp màn hình nào")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach($viewModel.screenshots) { $item in
                            ZStack(alignment: .topTrailing) {
                                ThumbnailView(asset: item.asset, targetSize: CGSize(width: 250, height: 250))
                                    .aspectRatio(1, contentMode: .fill)
                                    .cornerRadius(10)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticManager.shared.selection()
                                        item.isSelectedForDeletion.toggle()
                                    }
                                
                                Button {
                                    HapticManager.shared.selection()
                                    item.isSelectedForDeletion.toggle()
                                } label: {
                                    Image(systemName: item.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(item.isSelectedForDeletion ? .red : .white)
                                        .background(Circle().fill(Color.black.opacity(0.35)))
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 100)
                }
            }
            
            // Bottom Action Bar
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Đã chọn \(selectedCount) ảnh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button {
                        deleteScreenshots()
                    } label: {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Xóa ảnh đã chọn")
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
        .navigationTitle("Ảnh chụp màn hình")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thông báo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func deleteScreenshots() {
        HapticManager.shared.impact(.heavy)
        Task {
            isDeleting = true
            let idsToDelete = viewModel.screenshots.filter { $0.isSelectedForDeletion }.map { $0.id }
            do {
                let success = try await PhotoLibraryService.shared.deleteAssets(withIdentifiers: idsToDelete)
                if success {
                    let set = Set(idsToDelete)
                    viewModel.screenshots.removeAll { set.contains($0.id) }
                    viewModel.refreshStorage()
                    HapticManager.shared.notification(.success)
                    alertMessage = "Đã xóa thành công \(idsToDelete.count) ảnh chụp màn hình!"
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
