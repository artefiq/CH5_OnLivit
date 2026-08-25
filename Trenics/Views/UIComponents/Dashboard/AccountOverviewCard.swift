import SwiftUI

/// Account-wide overview, shown above the app selector so the scope reads
/// top-down: this card covers every app, everything below it is scoped by the
/// pill underneath.
struct AccountOverviewCard: View {
    let summary: AccountSummary
    let insight: InsightSummary?
    let isLoading: Bool
    let isGeneratingInsight: Bool
    let insightUnavailableMessage: String?
    let hasAccount: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !hasAccount {
                message("Add an account from your profile to see an overview of your apps.")
            } else if isLoading && !summary.hasData {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if !summary.hasData {
                message("No reviews yet across your apps, so there's nothing to summarise.")
            } else {
                statRow
                Divider()
                narrative
                if summary.bestApp != nil || summary.worstApp != nil {
                    standouts
                }
                footnote
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 3)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Overview")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            if isLoading && summary.hasData {
                ProgressView().controlSize(.small)
            } else if let fetchedAt = summary.fetchedAt {
                LastUpdatedLabel(date: fetchedAt)
            }
        }
    }

    private var statRow: some View {
        HStack(alignment: .top, spacing: 0) {
            stat(
                value: "\(summary.appCount)",
                label: summary.appCount == 1 ? "App" : "Apps"
            )
            divider
            stat(
                value: String(format: "%.2f", summary.averageRating),
                label: "Avg. score",
                accent: Color("primaryPurple")
            )
            divider
            stat(
                value: "\(summary.totalReviews)",
                label: "Reviews"
            )
        }
    }

    private func stat(value: String, label: String, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(accent ?? .primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var narrative: some View {
        if isGeneratingInsight {
            AIThinkingRow(style: .insight, text: "Looking across your apps…")
        } else if let insight {
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            // Falls back to a plain factual sentence when Apple Intelligence
            // isn't available, so the card is never just numbers.
            Text(fallbackNarrative)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fallbackNarrative: String {
        var sentence = String(
            format: "Across %d %@ you have %d reviews averaging %.2f out of 5.",
            summary.appCount,
            summary.appCount == 1 ? "app" : "apps",
            summary.totalReviews,
            summary.averageRating
        )
        if summary.recentReviews > 0 {
            sentence += " \(summary.recentReviews) arrived in the last \(AccountSummaryLoader.periodDays) days."
        }
        if let message = insightUnavailableMessage {
            sentence += " \(message)"
        }
        return sentence
    }

    @ViewBuilder
    private var standouts: some View {
        VStack(spacing: 8) {
            if let best = summary.bestApp {
                standoutRow(
                    icon: "arrow.up.right",
                    tint: .green,
                    label: "Best rated",
                    snapshot: best
                )
            }
            // Only worth showing when it's a different app from the best.
            if let worst = summary.worstApp, worst.id != summary.bestApp?.id {
                standoutRow(
                    icon: "arrow.down.right",
                    tint: .orange,
                    label: "Needs attention",
                    snapshot: worst
                )
            }
        }
    }

    private func standoutRow(
        icon: String,
        tint: Color,
        label: String,
        snapshot: AppRatingSnapshot
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(tint)
                .frame(width: 20, height: 20)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(snapshot.appName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(String(format: "%.2f", snapshot.average))
                .font(.subheadline.bold().monospacedDigit())
            Text("(\(snapshot.reviewCount))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var footnote: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The API exposes written reviews, not the App Store's lifetime
            // star distribution, so the number is labelled for what it is.
            Text("Scores are averaged from written reviews, not the App Store's overall rating.")
                .font(.caption2)
                .foregroundColor(.secondary)
            if !summary.failedAppNames.isEmpty {
                Text("Couldn't load reviews for \(summary.failedAppNames.joined(separator: ", ")).")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            if insight != nil {
                OnDeviceBadge()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
