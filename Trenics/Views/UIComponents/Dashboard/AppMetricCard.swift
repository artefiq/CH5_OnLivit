import SwiftUI

/// One row in "Your Apps": the app, then its three headline figures.
///
/// Figures arrive per app rather than with the list, so the card renders in
/// three states — loading, loaded (whole or partial), and failed — without
/// changing height enough to make the list jump.
struct AppMetricCard: View {
    let app: AppItemModel
    let metrics: AppDashboardMetrics?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                AppIconTile(systemName: app.iconName)
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let message = metrics?.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    MetricColumn(
                        value: metrics?.impressions.map { $0.compactFormatted },
                        delta: metrics?.impressionsDelta.map { DeltaLabel.percent($0) },
                        label: "Impressions",
                        isLoading: isLoading
                    )
                    MetricColumn(
                        value: metrics?.retention.map { String(format: "%.0f%%", $0 * 100) },
                        delta: metrics?.retentionDeltaPoints.map { DeltaLabel.points($0) },
                        label: "Retention",
                        isLoading: isLoading
                    )
                    MetricColumn(
                        value: metrics?.reviewAverage.map { String(format: "%.1f", $0) },
                        delta: metrics?.reviewDelta.map { DeltaLabel.stars($0) },
                        label: "Reviews",
                        isLoading: isLoading
                    )
                }
            }
        }
        .padding(16)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

/// A formatted change plus whether it is good news, so the column doesn't have
/// to know that falling deletions are good and falling reviews are not.
struct DeltaLabel: Equatable {
    let text: String
    let isPositive: Bool

    static func percent(_ change: Double) -> DeltaLabel {
        DeltaLabel(
            text: String(format: "%@%.0f%%", change >= 0 ? "+" : "−", abs(change) * 100),
            isPositive: change >= 0
        )
    }

    static func points(_ change: Double) -> DeltaLabel {
        DeltaLabel(
            text: String(format: "%@%.0fpt", change >= 0 ? "+" : "−", abs(change)),
            isPositive: change >= 0
        )
    }

    static func stars(_ change: Double) -> DeltaLabel {
        DeltaLabel(
            text: String(format: "%@%.1f", change >= 0 ? "+" : "−", abs(change)),
            isPositive: change >= 0
        )
    }
}

private struct MetricColumn: View {
    let value: String?
    let delta: DeltaLabel?
    let label: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let value {
                    Text(value)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if isLoading {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 44, height: 17)
                } else {
                    // A dash, not a zero — zero is a real value for these.
                    Text("—")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let delta {
                    Text(delta.text)
                        .font(.caption.bold())
                        .foregroundStyle(delta.isPositive ? Color.green : Color.red)
                        .lineLimit(1)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
