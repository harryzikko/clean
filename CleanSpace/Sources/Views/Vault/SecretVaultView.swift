import SwiftUI
import PhotosUI

public struct SecretVaultView: View {
    @State private var isUnlocked = false
    @State private var vaultItems: [VaultItem] = []
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var authenticationError: String? = nil
    @State private var selectedImageForPreview: UIImage? = nil
    @State private var showPreview = false
    
    public init() {}
    
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    
    public var body: some View {
        NavigationStack {
            ZStack {
                if isUnlocked {
                    // Unlocked Vault Content
                    VStack(spacing: 0) {
                        if vaultItems.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "lock.open.trianglebadge.exclamationmark")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue)
                                Text("Kho ảnh bảo mật trống")
                                    .font(.headline)
                                Text("Thêm ảnh riêng tư để khóa bằng Face ID.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(vaultItems) { item in
                                        if let image = VaultService.shared.loadVaultImage(fileName: item.fileName) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(1, contentMode: .fill)
                                                .frame(minWidth: 0, maxWidth: .infinity)
                                                .cornerRadius(8)
                                                .clipped()
                                                .onTapGesture {
                                                    selectedImageForPreview = image
                                                    showPreview = true
                                                }
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        deleteItem(item)
                                                    } label: {
                                                        Label("Xóa vĩnh viễn", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                }
                                .padding(8)
                            }
                        }
                    }
                    .navigationTitle("Kho bí mật")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Khóa") {
                                isUnlocked = false
                            }
                        }
                    }
                } else {
                    // Lock Screen
                    VStack(spacing: 24) {
                        Image(systemName: "faceid")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Kho ảnh bảo mật")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Bảo vệ các ảnh và video riêng tư của bạn bằng Face ID hoặc Mã khóa.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        if let error = authenticationError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        
                        Button {
                            unlockVault()
                        } label: {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                Text("Mở khóa với Face ID")
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                handleImportPhoto(item: newItem)
            }
            .sheet(isPresented: $showPreview) {
                if let image = selectedImageForPreview {
                    ImagePreviewModal(image: image)
                }
            }
        }
    }
    
    private func unlockVault() {
        Task {
            let result = await VaultService.shared.authenticateWithBiometrics()
            if result.success {
                self.isUnlocked = true
                self.vaultItems = VaultService.shared.listVaultItems()
                self.authenticationError = nil
            } else {
                self.authenticationError = result.error
            }
        }
    }
    
    private func handleImportPhoto(item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if let newItem = try? await VaultService.shared.saveImageToVault(image: image) {
                    await MainActor.run {
                        self.vaultItems.insert(newItem, at: 0)
                        self.selectedPhotoItem = nil
                    }
                }
            }
        }
    }
    
    private func deleteItem(_ item: VaultItem) {
        VaultService.shared.deleteVaultItem(fileName: item.fileName)
        vaultItems.removeAll { $0.id == item.id }
    }
}

struct ImagePreviewModal: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .navigationBarItems(trailing: Button("Đóng") { dismiss() })
        }
    }
}
