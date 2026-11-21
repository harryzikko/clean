import SwiftUI
import Photos

public struct VideoCompressorView: View {
    public let preselectedAsset: PHAsset?
    
    @State private var selectedAsset: PHAsset?
    @State private var selectedQuality: CompressionQuality = .medium
    @State private var originalSize: Int64 = 0
    @State private var isCompressing = false
    @State private var compressionProgress: Float = 0.0
    @State private var compressionResult: CompressionResult?
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    public init(preselectedAsset: PHAsset? = nil) {
        self.preselectedAsset = preselectedAsset
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                // Video Preview Card
                if let asset = selectedAsset ?? preselectedAsset {
                    VStack(spacing: 14) {
                        ThumbnailView(asset: asset, targetSize: CGSize(width: 400, height: 260))
                            .frame(height: 190)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(18)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Dung lượng gốc")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Thời lượng")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let minutes = Int(asset.duration) / 60
                                let seconds = Int(asset.duration) % 60
                                Text(String(format: "%02d:%02d", minutes, seconds))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                
                // Quality Selector
                VStack(alignment: .leading, spacing: 14) {
                    Text("Chọn chất lượng nén")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    
                    Picker("Độ phân giải", selection: $selectedQuality) {
                        ForEach(CompressionQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedQuality) { _ in
                        HapticManager.shared.selection()
                    }
                    
                    // Savings estimation badge
                    let estimatedSavings = Int64(Double(originalSize) * selectedQuality.estimatedReductionPercentage)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text("Dự kiến tiết kiệm ~\(ByteCountFormatter.string(fromByteCount: estimatedSavings, countStyle: .file))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                )
                
                // Progress or Compress Button
                if isCompressing {
                    VStack(spacing: 14) {
                        ProgressView(value: compressionProgress, total: 1.0)
                            .tint(.blue)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        HStack {
                            Text("Đang nén video...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(compressionProgress * 100))%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemBackground))
                    )
                } else if let result = compressionResult {
                    // Result Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 70, height: 70)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                        }
                        
                        Text("Nén hoàn tất!")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        
                        HStack(spacing: 24) {
                            VStack(spacing: 3) {
                                Text("Gốc")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: result.originalSize, countStyle: .file))
                                    .font(.subheadline)
                                    .strikethrough()
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 3) {
                                Text("Sau khi nén")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: result.compressedSize, countStyle: .file))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button {
                            saveAndReplace(result: result)
                        } label: {
                            Text("Lưu vào thư viện & Xóa video gốc")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.secondarySystemBackground))
                    )
                } else {
                    Button {
                        startCompression()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                            Text("Bắt đầu nén video")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            originalSize > 0 ?
                            LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(color: originalSize > 0 ? Color.blue.opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(originalSize == 0)
                }
            }
            .padding(18)
        }
        .navigationTitle("Nén Video")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let asset = preselectedAsset {
                self.selectedAsset = asset
                self.originalSize = await PhotoLibraryService.shared.getAssetSize(for: asset)
            } else {
                let videos = PhotoLibraryService.shared.fetchVideos()
                if let first = videos.first {
                    self.selectedAsset = first
                    self.originalSize = await PhotoLibraryService.shared.getAssetSize(for: first)
                }
            }
        }
        .alert("Thông báo", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func startCompression() {
        guard let asset = selectedAsset ?? preselectedAsset else { return }
        HapticManager.shared.impact(.heavy)
        isCompressing = true
        compressionProgress = 0.0
        
        Task {
            do {
                let result = try await VideoCompressorService.shared.compressVideo(
                    asset: asset,
                    quality: selectedQuality,
                    progressHandler: { prog in
                        Task { @MainActor in
                            self.compressionProgress = prog
                        }
                    }
                )
                HapticManager.shared.notification(.success)
                self.compressionResult = result
            } catch {
                HapticManager.shared.notification(.error)
                alertMessage = "Lỗi khi nén: \(error.localizedDescription)"
                showAlert = true
            }
            isCompressing = false
        }
    }
    
    private func saveAndReplace(result: CompressionResult) {
        guard let asset = selectedAsset ?? preselectedAsset else { return }
        HapticManager.shared.impact(.heavy)
        Task {
            do {
                try await VideoCompressorService.shared.saveCompressedVideoToLibrary(
                    url: result.outputURL,
                    deleteOriginalAssetId: asset.localIdentifier
                )
                HapticManager.shared.notification(.success)
                alertMessage = "Đã lưu video nén và giải phóng \(result.formattedSavedSize)!"
                showAlert = true
                compressionResult = nil
            } catch {
                HapticManager.shared.notification(.error)
                alertMessage = "Không thể lưu: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}
