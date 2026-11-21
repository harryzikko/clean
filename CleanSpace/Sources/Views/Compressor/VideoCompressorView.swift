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
        ScrollView {
            VStack(spacing: 24) {
                // Video Preview Card
                if let asset = selectedAsset ?? preselectedAsset {
                    VStack(spacing: 12) {
                        ThumbnailView(asset: asset, targetSize: CGSize(width: 320, height: 200))
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(16)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dung lượng gốc:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file))
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Thời lượng:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let minutes = Int(asset.duration) / 60
                                let seconds = Int(asset.duration) % 60
                                Text(String(format: "%02d:%02d", minutes, seconds))
                                    .font(.headline)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                }
                
                // Quality Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chọn mức độ nén:")
                        .font(.headline)
                    
                    Picker("Độ phân giải", selection: $selectedQuality) {
                        ForEach(CompressionQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Savings estimation
                    let estimatedSavings = Int64(Double(originalSize) * selectedQuality.estimatedReductionPercentage)
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("Dự kiến tiết kiệm ~\(ByteCountFormatter.string(fromByteCount: estimatedSavings, countStyle: .file))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                // Progress or Compress Button
                if isCompressing {
                    VStack(spacing: 12) {
                        ProgressView(value: compressionProgress, total: 1.0)
                            .tint(.blue)
                        Text("Đang nén video: \(Int(compressionProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                } else if let result = compressionResult {
                    // Result Card
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("Nén hoàn tất!")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("Gốc")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: result.originalSize, countStyle: .file))
                                    .font(.subheadline)
                                    .strikethrough()
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            
                            VStack {
                                Text("Sau khi nén")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: result.compressedSize, countStyle: .file))
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button {
                            saveAndReplace(result: result)
                        } label: {
                            Text("Lưu vào thư viện & Xóa video gốc")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                } else {
                    Button {
                        startCompression()
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Bắt đầu nén")
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(originalSize > 0 ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(originalSize == 0)
                }
            }
            .padding()
        }
        .navigationTitle("Nén Video")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let asset = preselectedAsset {
                self.selectedAsset = asset
                self.originalSize = await PhotoLibraryService.shared.getAssetSize(for: asset)
            } else {
                // Pick largest video by default
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
                self.compressionResult = result
            } catch {
                alertMessage = "Lỗi khi nén: \(error.localizedDescription)"
                showAlert = true
            }
            isCompressing = false
        }
    }
    
    private func saveAndReplace(result: CompressionResult) {
        guard let asset = selectedAsset ?? preselectedAsset else { return }
        Task {
            do {
                try await VideoCompressorService.shared.saveCompressedVideoToLibrary(
                    url: result.outputURL,
                    deleteOriginalAssetId: asset.localIdentifier
                )
                alertMessage = "Đã lưu video nén và giải phóng \(result.formattedSavedSize)!"
                showAlert = true
                compressionResult = nil
            } catch {
                alertMessage = "Không thể lưu: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}
