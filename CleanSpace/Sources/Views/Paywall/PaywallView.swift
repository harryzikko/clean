import SwiftUI
import StoreKit

public struct PaywallView: View {
    @ObservedObject var subManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlanIndex = 1 // Default to Yearly (Best value)
    
    public init() {}
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Top Dismiss Button
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Crown Badge & App Title
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 86, height: 86)
                            .shadow(color: Color.blue.opacity(0.4), radius: 14, y: 6)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                    }
                    
                    Text("CleanSpace PRO")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    
                    Text("Giải phóng tối đa dung lượng iPhone của bạn")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Social Proof Rating
                    HStack(spacing: 4) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                        Text("4.9 • 24.000+ người dùng tin tưởng")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.yellow.opacity(0.12)))
                    .padding(.top, 2)
                }
                
                // Value Propositions
                VStack(alignment: .leading, spacing: 14) {
                    FeatureRow(icon: "sparkles", gradient: [Color.blue, Color.cyan], title: "Dọn dẹp ảnh trùng thông minh", subtitle: "Tự động chọn bức ảnh đẹp nhất và xóa ảnh thừa")
                    FeatureRow(icon: "arrow.down.right.and.arrow.up.left", gradient: [Color.purple, Color.indigo], title: "Nén video không giới hạn", subtitle: "Tiết kiệm tới 80% dung lượng video 4K/HD")
                    FeatureRow(icon: "hand.draw.fill", gradient: [Color.orange, Color.red], title: "Vuốt dọn ảnh siêu tốc", subtitle: "Duyệt và dọn hàng nghìn ảnh chỉ trong vài phút")
                    FeatureRow(icon: "key.fill", gradient: [Color.green, Color.mint], title: "Kho ảnh bí mật mã PIN riêng", subtitle: "Bảo vệ các ảnh nhạy cảm an toàn tuyệt đối")
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)
                
                // Pricing Plans
                VStack(spacing: 12) {
                    PlanCard(
                        title: "Gói 1 Năm (Khuyên dùng)",
                        price: "499.000 đ / năm (~41.000 đ/tháng)",
                        badge: "TIẾT KIỆM 70%",
                        isSelected: selectedPlanIndex == 1
                    ) {
                        HapticManager.shared.selection()
                        selectedPlanIndex = 1
                    }
                    
                    PlanCard(
                        title: "Gói Hàng Tuần",
                        price: "69.000 đ / tuần (Dùng thử 3 ngày)",
                        badge: nil,
                        isSelected: selectedPlanIndex == 0
                    ) {
                        HapticManager.shared.selection()
                        selectedPlanIndex = 0
                    }
                }
                .padding(.horizontal, 20)
                
                // CTA Button
                VStack(spacing: 10) {
                    Button {
                        HapticManager.shared.impact(.heavy)
                        handleSubscribe()
                    } label: {
                        HStack {
                            if subManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(selectedPlanIndex == 0 ? "Bắt đầu dùng thử 3 ngày miễn phí" : "Nâng cấp lên PRO ngay")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(color: Color.blue.opacity(0.35), radius: 10, y: 5)
                    }
                    .disabled(subManager.isLoading)
                    
                    Text("Hủy bất kỳ lúc nào trong Cài đặt Apple ID • Không trừ tiền nếu hủy trước hạn")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Footer
                HStack(spacing: 16) {
                    Button("Khôi phục gói mua") {
                        HapticManager.shared.selection()
                        Task { await subManager.restorePurchases() }
                    }
                    Text("•")
                    Link("Điều khoản", destination: URL(string: "https://apple.com")!)
                    Text("•")
                    Link("Bảo mật", destination: URL(string: "https://apple.com")!)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func handleSubscribe() {
        if let product = subManager.products.first {
            Task {
                let success = await subManager.purchase(product)
                if success {
                    HapticManager.shared.notification(.success)
                    dismiss()
                }
            }
        } else {
            subManager.debugUnlockPro = true
            HapticManager.shared.notification(.success)
            dismiss()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.orange))
                                .foregroundColor(.white)
                        }
                    }
                    Text(price)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
