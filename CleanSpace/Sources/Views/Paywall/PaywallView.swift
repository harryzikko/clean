import SwiftUI
import StoreKit

public struct PaywallView: View {
    @ObservedObject var subManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlanIndex = 1 // Default to Yearly (Best value)
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                
                // Header Icon & Title
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.yellow)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    
                    Text("CleanSpace PRO")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("Giải phóng tối đa dung lượng iPhone của bạn")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Feature List
                VStack(alignment: .leading, spacing: 14) {
                    FeatureRow(icon: "sparkles", color: .blue, title: "Dọn dẹp ảnh trùng thông minh", subtitle: "Tự động chọn ảnh đẹp nhất và xóa ảnh thừa")
                    FeatureRow(icon: "arrow.down.right.and.arrow.up.left", color: .purple, title: "Nén video không giới hạn", subtitle: "Tiết kiệm tới 80% dung lượng video 4K/HD")
                    FeatureRow(icon: "hand.draw.fill", color: .orange, title: "Vuốt dọn ảnh siêu tốc", subtitle: "Duyệt và dọn dẹp hàng nghìn ảnh chỉ trong vài phút")
                    FeatureRow(icon: "faceid", color: .green, title: "Kho ảnh bí mật Face ID", subtitle: "Bảo vệ các ảnh nhạy cảm an toàn tuyệt đối")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(18)
                .padding(.horizontal)
                
                // Pricing Plans
                VStack(spacing: 12) {
                    // Yearly Option (Best Value)
                    PlanCard(
                        title: "Gói 1 Năm (Khuyên dùng)",
                        price: "499.000 đ / năm (~41.000 đ/tháng)",
                        badge: "TIẾT KIỆM 70%",
                        isSelected: selectedPlanIndex == 1
                    ) {
                        selectedPlanIndex = 1
                    }
                    
                    // Weekly Option
                    PlanCard(
                        title: "Gói Hàng Tuần",
                        price: "69.000 đ / tuần (Dùng thử 3 ngày)",
                        badge: nil,
                        isSelected: selectedPlanIndex == 0
                    ) {
                        selectedPlanIndex = 0
                    }
                }
                .padding(.horizontal)
                
                // Main CTA Button
                VStack(spacing: 12) {
                    Button {
                        handleSubscribe()
                    } label: {
                        HStack {
                            if subManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(selectedPlanIndex == 0 ? "Bắt đầu dùng thử 3 ngày miễn phí" : "Nâng cấp lên PRO ngay")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                    }
                    .disabled(subManager.isLoading)
                    
                    Text("Hủy bất kỳ lúc nào trong Cài đặt Apple ID • Không tính phí nếu hủy trước hạn")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Footer: Restore, Terms, Privacy
                HStack(spacing: 16) {
                    Button("Khôi phục gói mua") {
                        Task { await subManager.restorePurchases() }
                    }
                    Text("•")
                    Link("Điều khoản", destination: URL(string: "https://apple.com")!)
                    Text("•")
                    Link("Bảo mật", destination: URL(string: "https://apple.com")!)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func handleSubscribe() {
        if let product = subManager.products.first {
            Task {
                let success = await subManager.purchase(product)
                if success {
                    dismiss()
                }
            }
        } else {
            // Simulator or Demo Mode: unlock directly
            subManager.debugUnlockPro = true
            dismiss()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PlanCard: View {
    let title: String
    let price: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    Text(price)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.4))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
