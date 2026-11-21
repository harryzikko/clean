import SwiftUI
import PhotosUI

public struct SecretVaultView: View {
    @State private var isUnlocked = false
    @State private var isPINConfigured = PINCodeService.shared.isPINConfigured
    
    // PIN states
    @State private var enteredPIN = ""
    @State private var setupFirstPIN = ""
    @State private var setupStep = 1 // 1: Enter new PIN, 2: Confirm new PIN
    @State private var pinErrorMessage: String? = nil
    @State private var isShaking = false
    
    // Vault items
    @State private var vaultItems: [VaultItem] = []
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageForPreview: UIImage? = nil
    @State private var showPreview = false
    
    // Delete from public library alert
    @State private var showDeleteOriginalAlert = false
    @State private var pendingImportedAssetId: String? = nil
    @State private var showChangePINSheet = false
    
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
                    unlockedVaultContent
                } else {
                    pinLockScreen
                }
            }
            .navigationTitle(isUnlocked ? "Kho bí mật" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isUnlocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button {
                                showChangePINSheet = true
                            } label: {
                                Label("Đổi mã PIN", systemImage: "key.fill")
                            }
                            
                            Button(role: .destructive) {
                                lockVault()
                            } label: {
                                Label("Khóa kho ảnh", systemImage: "lock.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                handleImportPhoto(item: newItem)
            }
            .sheet(isPresented: $showPreview) {
                if let image = selectedImageForPreview {
                    VaultImagePreviewModal(image: image)
                }
            }
            .sheet(isPresented: $showChangePINSheet) {
                ChangePINView {
                    isPINConfigured = true
                    showChangePINSheet = false
                }
            }
            .alert("Đã cất vào Kho bí mật!", isPresented: $showDeleteOriginalAlert) {
                Button("Xóa khỏi Thư viện công khai", role: .destructive) {
                    deleteOriginalFromLibrary()
                }
                Button("Giữ lại ở Thư viện", role: .cancel) {
                    pendingImportedAssetId = nil
                }
            } message: {
                Text("Ảnh đã được lưu an toàn trong Kho bí mật (xóa ở thư viện vẫn không mất). Bạn có muốn xóa bức ảnh gốc khỏi Thư viện ảnh công khai của iPhone không?")
            }
        }
    }
    
    // MARK: - Unlocked Vault Content
    
    private var unlockedVaultContent: some View {
        VStack(spacing: 0) {
            if vaultItems.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Kho ảnh bí mật trống")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Ảnh trong này được bảo vệ bằng mã PIN riêng biệt và lưu trữ độc lập hoàn toàn với Thư viện ảnh iPhone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Thêm ảnh riêng tư ngay")
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
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
                                        Button {
                                            restorePhotoToLibrary(item)
                                        } label: {
                                            Label("Khôi phục về Thư viện", systemImage: "square.and.arrow.up")
                                        }
                                        
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
    }
    
    // MARK: - PIN Lock Screen (Custom Keypad)
    
    private var pinLockScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Header Lock Icon & Title
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                if !isPINConfigured {
                    Text(setupStep == 1 ? "Tạo mã PIN cho Kho bí mật" : "Xác nhận lại mã PIN")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(setupStep == 1 ? "Mã PIN này riêng biệt hoàn toàn với mật khẩu màn hình của iPhone." : "Nhập lại 4 số mã PIN bạn vừa chọn.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("Kho ảnh bí mật")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Nhập mã PIN riêng của kho ảnh để mở khóa.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            // PIN Dots Indicator
            HStack(spacing: 20) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index < enteredPIN.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }
            .offset(x: isShaking ? -10 : 0)
            .animation(.default, value: isShaking)
            .padding(.vertical, 8)
            
            if let error = pinErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            // Numeric Keypad
            VStack(spacing: 16) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 32) {
                        ForEach(row, id: \.self) { number in
                            KeypadButton(title: "\(number)") {
                                handleDigitPress("\(number)")
                            }
                        }
                    }
                }
                
                HStack(spacing: 32) {
                    // Empty space for layout balance
                    Spacer()
                        .frame(width: 75, height: 75)
                    
                    KeypadButton(title: "0") {
                        handleDigitPress("0")
                    }
                    
                    Button {
                        handleDeletePress()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.title2)
                            .frame(width: 75, height: 75)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .padding()
    }
    
    // MARK: - PIN Logic
    
    private func handleDigitPress(_ digit: String) {
        guard enteredPIN.count < 4 else { return }
        enteredPIN.append(digit)
        pinErrorMessage = nil
        
        if enteredPIN.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                processFullPIN()
            }
        }
    }
    
    private func handleDeletePress() {
        guard !enteredPIN.isEmpty else { return }
        enteredPIN.removeLast()
        pinErrorMessage = nil
    }
    
    private func processFullPIN() {
        if !isPINConfigured {
            // Setup flow
            if setupStep == 1 {
                setupFirstPIN = enteredPIN
                enteredPIN = ""
                setupStep = 2
            } else {
                if enteredPIN == setupFirstPIN {
                    _ = PINCodeService.shared.setPIN(enteredPIN)
                    isPINConfigured = true
                    unlockSuccess()
                } else {
                    shakeAndReset(error: "Mã PIN xác nhận không khớp. Hãy thử lại.")
                    setupStep = 1
                    setupFirstPIN = ""
                }
            }
        } else {
            // Verify flow
            if PINCodeService.shared.verifyPIN(enteredPIN) {
                unlockSuccess()
            } else {
                shakeAndReset(error: "Mã PIN không chính xác.")
            }
        }
    }
    
    private func unlockSuccess() {
        enteredPIN = ""
        pinErrorMessage = nil
        vaultItems = VaultService.shared.listVaultItems()
        isUnlocked = true
    }
    
    private func shakeAndReset(error: String) {
        isShaking = true
        pinErrorMessage = error
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShaking = false
            enteredPIN = ""
        }
    }
    
    private func lockVault() {
        isUnlocked = false
        enteredPIN = ""
    }
    
    // MARK: - Media Actions
    
    private func handleImportPhoto(item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if let newItem = try? await VaultService.shared.saveImageToVault(image: image) {
                    await MainActor.run {
                        self.vaultItems.insert(newItem, at: 0)
                        self.selectedPhotoItem = nil
                        self.pendingImportedAssetId = item.itemIdentifier
                        self.showDeleteOriginalAlert = true
                    }
                }
            }
        }
    }
    
    private func deleteOriginalFromLibrary() {
        guard let id = pendingImportedAssetId else { return }
        Task {
            _ = try? await PhotoLibraryService.shared.deleteAssets(withIdentifiers: [id])
            pendingImportedAssetId = nil
        }
    }
    
    private func restorePhotoToLibrary(_ item: VaultItem) {
        Task {
            try? await VaultService.shared.exportItemToPhotosLibrary(fileName: item.fileName)
        }
    }
    
    private func deleteItem(_ item: VaultItem) {
        VaultService.shared.deleteVaultItem(fileName: item.fileName)
        vaultItems.removeAll { $0.id == item.id }
    }
}

// MARK: - Keypad Button Component

struct KeypadButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .frame(width: 75, height: 75)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(Circle())
        }
    }
}

// MARK: - Change PIN Modal

struct ChangePINView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPIN = ""
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var step = 1 // 1: Verify Old, 2: Enter New, 3: Confirm New
    @State private var errorMessage: String? = nil
    @State private var input = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(stepTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 32)
                
                HStack(spacing: 16) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < input.count ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                        HStack(spacing: 32) {
                            ForEach(row, id: \.self) { num in
                                KeypadButton(title: "\(num)") {
                                    handlePress("\(num)")
                                }
                            }
                        }
                    }
                    HStack(spacing: 32) {
                        Spacer().frame(width: 75, height: 75)
                        KeypadButton(title: "0") { handlePress("0") }
                        Button {
                            if !input.isEmpty { input.removeLast() }
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.title2)
                                .frame(width: 75, height: 75)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationBarItems(leading: Button("Hủy") { dismiss() })
        }
    }
    
    private var stepTitle: String {
        switch step {
        case 1: return "Nhập mã PIN cũ"
        case 2: return "Nhập mã PIN mới"
        default: return "Xác nhận mã PIN mới"
        }
    }
    
    private func handlePress(_ digit: String) {
        guard input.count < 4 else { return }
        input.append(digit)
        errorMessage = nil
        
        if input.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                processStep()
            }
        }
    }
    
    private func processStep() {
        if step == 1 {
            if PINCodeService.shared.verifyPIN(input) {
                step = 2
                input = ""
            } else {
                errorMessage = "Mã PIN cũ không đúng."
                input = ""
            }
        } else if step == 2 {
            newPIN = input
            step = 3
            input = ""
        } else if step == 3 {
            if input == newPIN {
                _ = PINCodeService.shared.setPIN(newPIN)
                onComplete()
            } else {
                errorMessage = "Mã PIN không khớp. Hãy thử lại."
                step = 2
                input = ""
            }
        }
    }
}

// MARK: - Preview Modal

struct VaultImagePreviewModal: View {
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
