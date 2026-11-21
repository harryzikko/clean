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
            // Background track
            Circle()
                .stroke(Color.gray.opacity(0.18), lineWidth: 18)
            
            // Progress gradient
            Circle()
                .trim(from: 0.0, to: CGFloat(usedPercentage))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.blue, Color.cyan, Color.indigo]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: usedPercentage)
            
            // Center info
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", usedPercentage * 100))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(usedText) / \(totalText)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if let cleanable = cleanableText, !cleanable.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Có thể dọn \(cleanable)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                    .padding(.top, 4)
                }
            }
        }
        .frame(width: 220, height: 220)
    }
}
