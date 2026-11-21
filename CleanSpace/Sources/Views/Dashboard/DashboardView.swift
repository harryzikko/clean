import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showPaywall = false
    @State private var isCleaning = false
    @State private var showCleanSuccessAlert = false
    @State private var successCleanMessage = ""
    @State private var pulseAnimation = false
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    // Permission Banner (if not authorized)
                    if !viewModel.isAuthorized {
                        permissionBanner
                    }
                    
                    // Central Storage Gauge
                    ZStack {
                        if viewModel.isScanning {
                            // Pulsing radar animation behind ring
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 270, height: 270)
                                .scaleEffect(pulseAnimation ? 1.15 : 0.95)
                                .opacity(pulseAnimation ? 0.3 : 0.8)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
                                .onAppear { pulseAnimation = true }
                        }
                        
                        StorageRingView(
                            usedPercentage: viewModel.storageInfo.usedPercentage,
                            usedText: viewModel.storageInfo.formattedUsed,
                            totalText: viewModel.storageInfo.formattedTotal,
                            cleanableText: viewModel.totalCleanableBytes > 0 ? viewModel.formattedCleanableSize : nil
                        )
                    }
                    .padding(.top, 10)
                    
                    // Action / Scan Button
                    scanSection
                    
                    // Categories Section
                    categoriesSection
                    
                    // 1-Tap Quick Clean Button (if cleanable items detected)
                    if viewModel.totalCleanableBytes > 0 {
                        quickCleanButton
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("CleanSpace")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.selection()
                        showPaywall = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("PRO")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                                )
                        )
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
    
    // MARK: - Subviews
    
    private var permissionBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Cần quyền truy cập Thư viện ảnh")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Text("Để tìm kiếm và gợi ý dọn dẹp các bức ảnh trùng lặp, CleanSpace cần bạn cấp quyền truy cập toàn bộ thư viện ảnh.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                HapticManager.shared.impact(.medium)
                Task { await viewModel.requestPermission() }
            } label: {
                Text("Cấp quyền truy cập")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var scanSection: some View {
        VStack(spacing: 12) {
            if viewModel.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.scanProgress, total: 1.0)
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)
                        .cornerRadius(4)
                    
                    HStack {
                        Text(viewModel.statusMessage)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.scanProgress * 100))%")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 36)
            } else {
                Button {
                    HapticManager.shared.impact(.heavy)
                    Task { await viewModel.startFullScan() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text("Quét bộ nhớ thông minh")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(26)
                    .shadow(color: Color.blue.opacity(0.35), radius: 10, y: 5)
                }
            }
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Danh mục dọn dẹp")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                NavigationLink(destination: SimilarPhotosView(viewModel: viewModel)) {
                    CategoryRowCard(
                        icon: "photo.stack.fill",
                        gradient: [Color.blue, Color.cyan],
                        title: "Ảnh tương đồng & Trùng lặp",
                        countText: "\(viewModel.duplicateGroups.count) nhóm ảnh cần lọc",
                        savingsText: ByteCountFormatter.string(
                            fromByteCount: viewModel.duplicateGroups.reduce(0) { $0 + $1.potentialSavingsBytes },
                            countStyle: .file
                        )
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: ScreenshotsCleanView(viewModel: viewModel)) {
                    CategoryRowCard(
                        icon: "camera.viewfinder",
                        gradient: [Color.purple, Color.indigo],
                        title: "Ảnh chụp màn hình",
                        countText: "\(viewModel.screenshots.count) ảnh đã phát hiện",
                        savingsText: ByteCountFormatter.string(
                            fromByteCount: viewModel.screenshots.reduce(0) { $0 + $1.fileSize },
                            countStyle: .file
                        )
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: LargeVideosView(viewModel: viewModel)) {
                    CategoryRowCard(
                        icon: "video.fill",
                        gradient: [Color.orange, Color.red],
                        title: "Video dung lượng lớn",
                        countText: "\(viewModel.heavyVideos.count) video nặng",
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
    }
    
    private var quickCleanButton: some View {
        Button {
            performQuickClean()
        } label: {
            HStack(spacing: 8) {
                if isCleaning {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                    Text("Dọn nhanh \(viewModel.formattedCleanableSize)")
                }
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.green, Color(red: 0.1, green: 0.75, blue: 0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(18)
            .shadow(color: Color.green.opacity(0.3), radius: 10, y: 5)
        }
        .padding(.horizontal)
        .disabled(isCleaning)
    }
    
    private func performQuickClean() {
        HapticManager.shared.impact(.heavy)
        Task {
            isCleaning = true
            do {
                let saved = try await viewModel.cleanSelectedItems()
                let formatted = ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)
                successCleanMessage = "Bạn vừa giải phóng thành công \(formatted) bộ nhớ cho iPhone!"
                HapticManager.shared.notification(.success)
                showCleanSuccessAlert = true
            } catch {
                successCleanMessage = "Lỗi khi dọn dẹp: \(error.localizedDescription)"
                HapticManager.shared.notification(.error)
                showCleanSuccessAlert = true
            }
            isCleaning = false
        }
    }
}

struct CategoryRowCard: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let countText: String
    let savingsText: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 6, y: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(countText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(savingsText)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
        )
    }
}
