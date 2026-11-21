# CleanSpace - Ứng dụng dọn dẹp bộ nhớ & tối ưu thư viện ảnh iOS

Ứng dụng dọn dẹp thông minh cho iOS được viết hoàn toàn bằng **Swift & SwiftUI Native**, sử dụng framework **Apple Vision** để phát hiện ảnh tương đồng và **AVFoundation** để nén video dung lượng lớn.

---

## 📱 Tính năng nổi bật

1. **AI Quét ảnh tương đồng & Trùng lặp (Duplicate & Similar Photos):**
   - Sử dụng `Vision` framework (`VNGenerateImageFeaturePrintRequest`) để tính toán vector đặc trưng hình ảnh.
   - So sánh khoảng cách tương đồng (similarity distance threshold <= 0.42).
   - Tự động gắn nhãn và giữ lại bức ảnh đẹp nhất (**Best Photo**) dựa trên độ phân giải và chất lượng, gợi ý xóa các ảnh chụp liên tiếp thừa.
2. **Dọn dẹp Ảnh chụp màn hình (Screenshots Cleaner):**
   - Tự động phân loại album ảnh chụp màn hình.
   - Hỗ trợ chọn nhanh tất cả và xóa hàng loạt chỉ với 1 chạm.
3. **Quét & Nén Video dung lượng lớn (Video Compressor):**
   - Lọc các video nặng hàng trăm MB / GB.
   - Hỗ trợ nén với 3 mức chất lượng: 1080p, 720p, 540p (tiết kiệm đến 80% dung lượng).
   - Cho phép lưu video nén và xóa ngay video gốc để giải phóng bộ nhớ.
4. **Vuốt dọn ảnh siêu tốc (Tinder-style Swipe Cleaner):**
   - Vuốt sang trái để đưa vào thùng rác, vuốt sang phải để giữ lại.
   - Hỗ trợ nút hoàn tác (Undo) và màn hình duyệt tổng hợp trước khi xóa vĩnh viễn.
5. **Kho ảnh bí mật (Secret Vault):**
   - Khóa và bảo vệ ảnh/video riêng tư bằng **Face ID / Touch ID / Passcode** (`LocalAuthentication`).
   - Lưu trữ trong thư mục mã hóa độc lập trong sandbox của app.
6. **Mô hình kiếm tiền & Paywall (StoreKit 2 / Subscription):**
   - Thiết kế Paywall tối ưu tỷ lệ chuyển đổi: Gói tuần (3 ngày Free Trial) và Gói năm (tiết kiệm 70%).
   - Tích hợp sẵn StoreKit 2 và chế độ Demo Mode để chạy thử trên Simulator.

---

## 🏗 Cấu trúc dự án

```text
CleanSpace/
├── Sources/
│   ├── App/
│   │   └── CleanSpaceApp.swift           # Điểm khởi chạy ứng dụng (TabView chính)
│   ├── Core/
│   │   ├── StorageService.swift          # Đo dung lượng bộ nhớ thực tế của iPhone
│   │   ├── PhotoLibraryService.swift     # Xử lý quyền và thao tác thư viện ảnh
│   │   ├── DuplicateDetector.swift       # Thuật toán AI Vision tìm ảnh trùng lặp
│   │   ├── VideoCompressorService.swift  # Xử lý nén video (AVAssetExportSession)
│   │   ├── VaultService.swift            # Quản lý kho ảnh bí mật & Face ID
│   │   └── SubscriptionManager.swift     # Quản lý gói mua In-App Purchase (StoreKit 2)
│   ├── Models/
│   │   ├── StorageInfo.swift             # Model thông tin dung lượng
│   │   ├── MediaItem.swift               # Model wrapper cho PHAsset
│   │   └── DuplicateGroup.swift          # Nhóm các ảnh tương đồng
│   ├── ViewModels/
│   │   └── DashboardViewModel.swift      # Quản lý luồng quét & dọn dẹp tổng thể
│   └── Views/
│       ├── Dashboard/DashboardView.swift # Màn hình chính (Storage ring, nút quét thông minh)
│       ├── Cleaning/
│       │   ├── SimilarPhotosView.swift   # Giao diện duyệt & xóa ảnh trùng
│       │   ├── ScreenshotsCleanView.swift# Giao diện dọn ảnh chụp màn hình
│       │   ├── LargeVideosView.swift     # Giao diện danh sách video nặng
│       │   └── SwipeCleanView.swift      # Giao diện quẹt thẻ dọn ảnh (Tinder style)
│       ├── Compressor/
│       │   └── VideoCompressorView.swift # Giao diện chọn mức nén video
│       ├── Vault/SecretVaultView.swift   # Giao diện khóa Face ID & kho ảnh ẩn
│       ├── Paywall/PaywallView.swift     # Giao diện đăng ký gói PRO
│       └── Components/                   # StorageRingView, ThumbnailView
├── Resources/
│   └── Info.plist                        # Mô tả quyền truy cập (Photos, Face ID)
├── project.yml                           # Cấu hình tự động sinh file Xcode (.xcodeproj)
├── Package.swift                         # Hỗ trợ mở dạng Swift Package
└── .github/workflows/build.yml           # CI/CD tự động build trên GitHub Actions
```

---

## 🚀 Cách mở và chạy dự án

### Cách 1: Tạo dự án Xcode bằng XcodeGen (Khuyên dùng khi có Mac)
1. Cài đặt XcodeGen trên Mac (nếu chưa có):
   ```bash
   brew install xcodegen
   ```
2. Trong thư mục dự án, chạy lệnh:
   ```bash
   xcodegen generate
   ```
   Lệnh này sẽ tự động tạo file `CleanSpace.xcodeproj`.
3. Mở file `CleanSpace.xcodeproj` bằng Xcode 15 trở lên và nhấn **Run (Cmd + R)** để chạy trên iPhone hoặc Simulator.

### Cách 2: Mở trực tiếp dưới dạng Swift Package
1. Mở Xcode -> Chọn **File** -> **Open...**
2. Chọn thư mục dự án `clean` (nơi có file `Package.swift`).

### Cách 3: Build tự động trên Cloud (GitHub Actions) từ Windows
Nếu hiện tại bạn đang làm việc trên máy Windows:
1. Tạo một repository mới trên GitHub và push mã nguồn này lên.
2. Tab **Actions** trên GitHub sẽ tự động kích hoạt workflow `.github/workflows/build.yml` chạy trên máy ảo macOS của GitHub để biên dịch toàn bộ dự án.

---

## 🔒 Quyền riêng tư & App Store Review
Ứng dụng đã được cấu hình đầy đủ các chuỗi giải thích quyền theo quy định của Apple trong [Info.plist](file:///e:/VTC%20Game/project/clean/CleanSpace/Resources/Info.plist):
- `NSPhotoLibraryUsageDescription`: Cho phép quét và dọn dẹp ảnh.
- `NSPhotoLibraryAddUsageDescription`: Cho phép lưu video sau khi nén.
- `NSFaceIDUsageDescription`: Cho phép xác thực mở khóa kho ảnh bí mật.
