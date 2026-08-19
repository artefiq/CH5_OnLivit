import SwiftUI

/// The one app most worth opening right now, ranked across every app's
/// impressions, retention and reviews.
struct NeedsAttentionCard: View {
    let metrics: AppDashboardMetrics
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Needs your attention")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 12) {
                AppIconTile(systemName: iconName, size: 44, tint: .white)
                Text(metrics.appName)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            Text(metrics.attentionSummary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x6155F5), Color(hex: 0x39328F)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: 0x39328F).opacity(0.35), radius: 12, y: 6)
    }
}

/// Placeholder shown while the ranking is still being worked out, so the card
/// doesn't pop in and shove the list down once metrics land.
struct NeedsAttentionPlaceholder: View {
    let message: String
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x6155F5), Color(hex: 0x39328F)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: 0x39328F).opacity(0.35), radius: 12, y: 6)
    }
}

/// Rounded app-icon stand-in. The App Store Connect API doesn't hand out icon
/// artwork, so this is a glyph rather than the real icon.
struct AppIconTile: View {
    var systemName: String = "circle.hexagongrid.fill"
    var size: CGFloat = 48
    var tint: Color = .orange

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24)
            .fill(tint.opacity(tint == .white ? 0.2 : 0.12))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(tint)
            )
    }
}

extension Color {
    /// Matches the gradient stops from the design file.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
