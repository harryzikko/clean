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
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 90, height: 90)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                    }
                    Text("Không có ảnh trùng lặp nào!")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Thư viện ảnh của bạn rất gọn gàng và ngăn nắp.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        ForEach($viewModel.duplicateGroups) { $group in
                            DuplicateGroupCard(group: $group)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                
                // Floating Bottom Action Bar
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dung lượng giải phóng")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.formattedCleanableSize)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button {
                            performClean()
                        } label: {
                            HStack(spacing: 6) {
                                if isDeleting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Dọn ảnh đã chọn")
                                }
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .background(viewModel.totalCleanableBytes > 0 ? Color.blue : Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(isDeleting || viewModel.totalCleanableBytes == 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle("Ảnh tương đồng & Trùng")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thông báo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func performClean() {
        HapticManager.shared.impact(.heavy)
        Task {
            isDeleting = true
            do {
                let saved = try await viewModel.cleanSelectedItems()
                let formatted = ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)
                alertMessage = "Đã giải phóng thành công \(formatted) bộ nhớ!"
                HapticManager.shared.notification(.success)
                showingAlert = true
            } catch {
                alertMessage = "Không thể xóa: \(error.localizedDescription)"
                HapticManager.shared.notification(.error)
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
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(group.items.count) ảnh liên tiếp")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Text("Tiết kiệm ~\(group.formattedSavings)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.14)))
                    .foregroundColor(.green)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach($group.items) { $item in
                        let isBest = (item.id == group.bestItemId)
                        
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                ThumbnailView(asset: item.asset, targetSize: CGSize(width: 160, height: 160))
                                    .frame(width: 110, height: 110)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isBest ? Color.green : (item.isSelectedForDeletion ? Color.red : Color.clear), lineWidth: 2)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if !isBest {
                                            HapticManager.shared.selection()
                                            item.isSelectedForDeletion.toggle()
                                        }
                                    }
                                
                                if isBest {
                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 9))
                                        Text("Đẹp nhất")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .padding(5)
                                } else {
                                    Button {
                                        HapticManager.shared.selection()
                                        item.isSelectedForDeletion.toggle()
                                    } label: {
                                        Image(systemName: item.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(item.isSelectedForDeletion ? .red : .white)
                                            .background(Circle().fill(Color.black.opacity(0.35)))
                                    }
                                    .padding(5)
                                }
                            }
                            
                            Text(item.formattedSize)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
    }
}
