import SwiftUI
import Photos

public struct SimilarPhotosView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isDeleting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.duplicateGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text("Không có ảnh trùng lặp nào!")
                        .font(.headline)
                    Text("Thư viện ảnh của bạn rất gọn gàng.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach($viewModel.duplicateGroups) { $group in
                            DuplicateGroupCard(group: $group)
                        }
                    }
                    .padding()
                }
                
                // Bottom Action Bar
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Giải phóng:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.formattedCleanableSize)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button {
                            performClean()
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Dọn dẹp ảnh đã chọn")
                                }
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(isDeleting || viewModel.totalCleanableBytes == 0)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Ảnh tương đồng & Trùng lặp")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thông báo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func performClean() {
        Task {
            isDeleting = true
            do {
                let saved = try await viewModel.cleanSelectedItems()
                let formatted = ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)
                alertMessage = "Đã giải phóng thành công \(formatted) bộ nhớ!"
                showingAlert = true
            } catch {
                alertMessage = "Không thể xóa: \(error.localizedDescription)"
                showingAlert = true
            }
            isDeleting = false
        }
    }
}

struct DuplicateGroupCard: View {
    @Binding var group: DuplicateGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(group.items.count) ảnh tương đồng")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Tiết kiệm: \(group.formattedSavings)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach($group.items) { $item in
                        let isBest = (item.id == group.bestItemId)
                        
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                ThumbnailView(asset: item.asset, targetSize: CGSize(width: 140, height: 140))
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isBest ? Color.green : (item.isSelectedForDeletion ? Color.red : Color.clear), lineWidth: 2.5)
                                    )
                                
                                // Tag or Checkmark
                                if isBest {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                        Text("Đẹp nhất")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .padding(6)
                                } else {
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
                            
                            Text(item.formattedSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
