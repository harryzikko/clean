import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showPaywall = false
    @State private var isCleaning = false
    @State private var showCleanSuccessAlert = false
    @State private var successCleanMessage = ""
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Permission Banner (if not authorized)
                    if !viewModel.isAuthorized {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text("Cần quyền truy cập Thư viện ảnh")
                                    .font(.headline)
                            }
                            Text("Để tìm kiếm và gợi ý dọn dẹp các bức ảnh trùng lặp, CleanSpace cần bạn cấp quyền truy cập toàn bộ thư viện ảnh.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                Task { await viewModel.requestPermission() }
                            } label: {
                                Text("Cấp quyền truy cập")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Storage Gauge Ring
                    StorageRingView(
                        usedPercentage: viewModel.storageInfo.usedPercentage,
                        usedText: viewModel.storageInfo.formattedUsed,
                        totalText: viewModel.storageInfo.formattedTotal,
                        cleanableText: viewModel.totalCleanableBytes > 0 ? viewModel.formattedCleanableSize : nil
                    )
                    .padding(.top, 8)
                    
                    // Scanning Status / Scan Button
                    VStack(spacing: 12) {
                        if viewModel.isScanning {
                            VStack(spacing: 8) {
                                ProgressView(value: viewModel.scanProgress, total: 1.0)
                                    .tint(.blue)
                                Text(viewModel.statusMessage)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 32)
                        } else {
                            Button {
                                Task { await viewModel.startFullScan() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                    Text("Quét bộ nhớ thông minh")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(24)
                                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                            }
                        }
                    }
                    
                    // Categories Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Mục có thể dọn dẹp")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // 1. Similar Photos
                            NavigationLink(destination: SimilarPhotosView(viewModel: viewModel)) {
                                CategoryRowCard(
                                    icon: "photo.stack.fill",
                                    color: .blue,
                                    title: "Ảnh tương đồng & Trùng lặp",
                                    countText: "\(viewModel.duplicateGroups.count) nhóm ảnh",
                                    savingsText: ByteCountFormatter.string(
                                        fromByteCount: viewModel.duplicateGroups.reduce(0) { $0 + $1.potentialSavingsBytes },
                                        countStyle: .file
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // 2. Screenshots
                            NavigationLink(destination: ScreenshotsCleanView(viewModel: viewModel)) {
                                CategoryRowCard(
                                    icon: "camera.viewfinder",
                                    color: .purple,
                                    title: "Ảnh chụp màn hình",
                                    countText: "\(viewModel.screenshots.count) ảnh",
                                    savingsText: ByteCountFormatter.string(
                                        fromByteCount: viewModel.screenshots.reduce(0) { $0 + $1.fileSize },
                                        countStyle: .file
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // 3. Heavy Videos
                            NavigationLink(destination: LargeVideosView(viewModel: viewModel)) {
                                CategoryRowCard(
                                    icon: "video.fill",
                                    color: .orange,
                                    title: "Video dung lượng lớn",
                                    countText: "\(viewModel.heavyVideos.count) video",
                                    savingsText: ByteCountFormatter.string(
                                        fromByteCount: viewModel.heavyVideos.reduce(0) { $0 + $1.fileSize },
                                        countStyle: .file
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Quick 1-Tap Clean Button (if cleanable items detected)
                    if viewModel.totalCleanableBytes > 0 {
                        Button {
                            performQuickClean()
                        } label: {
                            HStack {
                                if isCleaning {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Dọn nhanh \(viewModel.formattedCleanableSize)")
                                }
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                        }
                        .padding(.horizontal)
                        .disabled(isCleaning)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("CleanSpace")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("PRO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Hoàn tất dọn dẹp!", isPresented: $showCleanSuccessAlert) {
                Button("Tuyệt vời") {}
            } message: {
                Text(successCleanMessage)
            }
            .task {
                if viewModel.isAuthorized && viewModel.duplicateGroups.isEmpty && !viewModel.isScanning {
                    await viewModel.startFullScan()
                }
            }
        }
    }
    
    private func performQuickClean() {
        Task {
            isCleaning = true
            do {
                let saved = try await viewModel.cleanSelectedItems()
                let formatted = ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)
                successCleanMessage = "Bạn vừa giải phóng thành công \(formatted) bộ nhớ cho iPhone!"
                showCleanSuccessAlert = true
            } catch {
                successCleanMessage = "Lỗi khi dọn dẹp: \(error.localizedDescription)"
                showCleanSuccessAlert = true
            }
            isCleaning = false
        }
    }
}

struct CategoryRowCard: View {
    let icon: String
    let color: Color
    let title: String
    let countText: String
    let savingsText: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(countText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(savingsText)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
