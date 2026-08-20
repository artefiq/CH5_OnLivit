import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var delta: MetricDelta?
    var caption: String?
    var width: CGFloat? = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            if let delta {
                HStack(spacing: 3) {
                    Image(systemName: delta.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.bold())
                    Text(delta.formatted)
                        .font(.caption.bold())
                }
                .foregroundStyle(delta.isPositive ? Color.green : Color.red)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.right")
                        .font(.caption2.bold())
                    Text("0%")
                        .font(.caption.bold())
                }
                .foregroundStyle(Color.gray)
            }
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .padding(14)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct StatCardRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }
}
