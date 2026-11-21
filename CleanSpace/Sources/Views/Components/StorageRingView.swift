import SwiftUI

public struct StorageRingView: View {
    public let usedPercentage: Double
    public let usedText: String
    public let totalText: String
    public let cleanableText: String?
    
    public init(
        usedPercentage: Double,
        usedText: String,
        totalText: String,
        cleanableText: String? = nil
    ) {
        self.usedPercentage = min(max(usedPercentage, 0.0), 1.0)
        self.usedText = usedText
        self.totalText = totalText
        self.cleanableText = cleanableText
    }
    
    public var body: some View {
        ZStack {
            // Background track with glassmorphism
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 20)
            
            // Soft glow behind progress
            Circle()
                .trim(from: 0.0, to: CGFloat(usedPercentage))
                .stroke(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 8)
                .opacity(0.35)
            
            // Foreground progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(usedPercentage))
                .stroke(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan, Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: usedPercentage)
            
            // Inner stats container
            VStack(spacing: 5) {
                Text(String(format: "%.0f%%", usedPercentage * 100))
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(usedText) / \(totalText)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if let cleanable = cleanableText, !cleanable.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("Dọn được \(cleanable)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.16))
                            .overlay(
                                Capsule()
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.green)
                    .padding(.top, 4)
                }
            }
        }
        .frame(width: 230, height: 230)
    }
}
