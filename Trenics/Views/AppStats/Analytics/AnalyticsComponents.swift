import SwiftUI

// MARK: - Formatting

extension Double {
    /// 1_234 → "1.2K", 3_400_000 → "3.4M"
    var compactFormatted: String {
        let value = abs(self)
        switch value {
        case 1_000_000_000...:
            return String(format: "%.1fB", self / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", self / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", self / 1_000)
        case 0..<10 where self != self.rounded():
            return String(format: "%.1f", self)
        default:
            return String(format: "%.0f", self)
        }
    }

    var percentFormatted: String { String(format: "%.1f%%", self * 100) }
}

// MARK: - Containers

/// The standard card chrome used by every section on every page.
struct SectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    var delta: MetricDelta?
    var caption: String?
    /// Fixed so a row of cards in a horizontal scroller stays aligned.
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
            } else if let caption {
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
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

/// Horizontally scrolling row of `StatCard`s that bleeds to the screen edges
/// while the surrounding page keeps its 20pt gutter.
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

// MARK: - AI cards

/// "What happened." Deliberately distinct from `AISuggestionCard` — conflating
/// description with prescription makes the whole thing read as overconfident.
struct AISummaryCard: View {
    let summary: InsightSummary?
    let range: AnalyticsTimeRange
    var isLoading: Bool = false
    var unavailableMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color("primaryPurple"))
                Text("Summary")
                    .font(.subheadline.bold())
                Spacer()
                Text(range.longLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                InsightPlaceholder()
            } else if let summary {
                Text(summary.headline)
                    .font(.callout.weight(.semibold))
                Text(summary.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !summary.highlight.isEmpty {
                    Label(summary.highlight, systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(Color("primaryPurple"))
                }
            } else {
                Text(unavailableMessage ?? "Not enough data to summarise this period yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            OnDeviceBadge()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("primaryPurple").opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color("primaryPurple").opacity(0.2), lineWidth: 1)
        )
    }
}

/// "What to do." Different icon and colour on purpose.
struct AISuggestionCard: View {
    let suggestion: InsightSuggestion?
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                Text("Suggested next step")
                    .font(.subheadline.bold())
                Spacer()
                if let confidence = suggestion?.confidence, !confidence.isEmpty {
                    Text(confidence.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                        .foregroundStyle(.orange)
                }
            }

            if isLoading {
                InsightPlaceholder()
            } else if let suggestion {
                Text(suggestion.action)
                    .font(.callout.weight(.semibold))
                Text(suggestion.rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No recommendation for this period.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            OnDeviceBadge()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Matches how Apple's own apps disclose on-device generation.
struct OnDeviceBadge: View {
    var body: some View {
        Label("Generated on-device", systemImage: "iphone.gen3")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

private struct InsightPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            bar()
            bar()
            HStack(spacing: 0) {
                bar(width: 140)
                Spacer(minLength: 0)
            }
        }
        .accessibilityLabel("Generating summary")
    }

    @ViewBuilder
    private func bar(width: CGFloat? = nil) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: width, height: 12)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
    }
}

// MARK: - Funnel

struct FunnelView: View {
    let stages: [FunnelStage]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                FunnelBar(
                    stage: stage,
                    widthFraction: fraction(for: stage),
                    tint: tint(for: index)
                )
                if index < stages.count - 1 {
                    ConversionConnector(rate: conversionRate(from: index))
                }
            }
        }
    }

    private var peak: Double { stages.map(\.value).max() ?? 0 }

    private func fraction(for stage: FunnelStage) -> Double {
        guard peak > 0 else { return 0 }
        // Floor the width so a tiny final stage is still readable.
        return max(0.18, stage.value / peak)
    }

    private func conversionRate(from index: Int) -> Double? {
        guard index + 1 < stages.count, stages[index].value > 0 else { return nil }
        return stages[index + 1].value / stages[index].value
    }

    private func tint(for index: Int) -> Color {
        let shades = [Color("primaryPurple"), Color("primaryPurple").opacity(0.75), .orange]
        return shades[min(index, shades.count - 1)]
    }
}

private struct FunnelBar: View {
    let stage: FunnelStage
    let widthFraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint)
                    .frame(width: geo.size.width * widthFraction)
                HStack {
                    Text(stage.label)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.leading, 12)
                    Spacer()
                    Text(stage.value.compactFormatted)
                        .font(.subheadline.bold())
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 44)
    }
}

private struct ConversionConnector: View {
    let rate: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down")
                .font(.caption2)
            Text(rate.map { "\($0.percentFormatted) convert" } ?? "—")
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }
}

// MARK: - Breakdowns

struct BreakdownListView: View {
    let items: [BreakdownItem]
    var emptyMessage: String = "No breakdown available in this report."

    private var total: Double { items.reduce(0) { $0 + $1.value } }

    var body: some View {
        if items.isEmpty {
            Text(emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    VStack(spacing: 4) {
                        HStack {
                            Text(item.label)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(item.value.compactFormatted)
                                .font(.subheadline.bold())
                            Text(item.share(of: total).percentFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        ProgressView(value: item.share(of: total))
                            .tint(Color("primaryPurple"))
                    }
                }
            }
        }
    }
}

// MARK: - Controls & status

struct TimeRangePicker: View {
    @Binding var range: AnalyticsTimeRange

    var body: some View {
        Picker("Time range", selection: $range) {
            ForEach(AnalyticsTimeRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct LastUpdatedLabel: View {
    let date: Date?

    var body: some View {
        if let date {
            Text("Updated \(Self.phrase(for: date))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private static func phrase(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "today at " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.relative(presentation: .named))
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
    }
}

struct AnalyticsEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Reviews

struct StarRatingView: View {
    let rating: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
            }
        }
        .foregroundStyle(.yellow)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}

struct RatingHistogramView: View {
    let buckets: [RatingBucket]

    private var total: Int { max(buckets.reduce(0) { $0 + $1.count }, 1) }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(buckets) { bucket in
                HStack(spacing: 8) {
                    Text("\(bucket.stars)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 10)
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    ProgressView(value: Double(bucket.count) / Double(total))
                        .tint(Color("primaryPurple"))
                    Text("\(bucket.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

struct SentimentDonutView: View {
    let counts: [ReviewSentiment: Int]

    private var total: Double {
        Double(counts.values.reduce(0, +))
    }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text("\(Int(total))")
                        .font(.headline)
                    Text("reviews")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ReviewSentiment.allCases, id: \.self) { sentiment in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Self.color(for: sentiment))
                            .frame(width: 8, height: 8)
                        Text(sentiment.label)
                            .font(.caption)
                        Spacer()
                        Text("\(counts[sentiment] ?? 0)")
                            .font(.caption.bold().monospacedDigit())
                    }
                }
            }
        }
    }

    private var segments: [(start: Double, end: Double, color: Color)] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return ReviewSentiment.allCases.compactMap { sentiment in
            let share = Double(counts[sentiment] ?? 0) / total
            guard share > 0 else { return nil }
            let segment = (start: cursor, end: cursor + share, color: Self.color(for: sentiment))
            cursor += share
            return segment
        }
    }

    static func color(for sentiment: ReviewSentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}

struct ThemeTagsView: View {
    let themes: [ReviewThemeInsight]
    @Binding var selected: String?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(themes) { theme in
                Button {
                    selected = (selected == theme.theme) ? nil : theme.theme
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(SentimentDonutView.color(for: theme.sentiment))
                            .frame(width: 6, height: 6)
                        Text(theme.theme)
                            .font(.caption.weight(selected == theme.theme ? .bold : .regular))
                        Text("\(theme.reviewCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            selected == theme.theme
                                ? Color("primaryPurple").opacity(0.18)
                                : Color.secondary.opacity(0.1)
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wraps tag chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = origin.y + lineHeight
        }
        return CGSize(width: maxWidth == .infinity ? origin.x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct ReviewCard: View {
    let review: CustomerReview
    /// The developer's reply body, or nil when there isn't one.
    let response: String?
    let isLoadingResponse: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StarRatingView(rating: review.attributes.rating)
                if let territory = review.attributes.territory {
                    Text(territory)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Self.dateLabel(review.attributes.createdDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let title = review.attributes.title, !title.isEmpty {
                Text(title).font(.subheadline.bold())
            }
            if let body = review.attributes.body, !body.isEmpty {
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let nickname = review.attributes.reviewerNickname {
                Text("— \(nickname)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            responseFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    @ViewBuilder
    private var responseFooter: some View {
        if isLoadingResponse {
            Label("Checking for a response…", systemImage: "ellipsis.bubble")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else if let body = response, !body.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("Your response", systemImage: "arrowshape.turn.up.left.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color("primaryPurple"))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color("primaryPurple").opacity(0.08))
            )
        } else {
            Label("Not answered", systemImage: "bubble.left")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private static func dateLabel(_ raw: String) -> String {
        guard let date = ASCDate.parseTimestamp(raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Raw data

/// The underlying TSV, kept available for anything the curated sections don't cover.
struct DataTableView: View {
    let table: ReportTable
    var rowLimit: Int = 100

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(.caption.bold())
                            .frame(width: 130, alignment: .leading)
                    }
                }
                Divider()
                ForEach(Array(table.rows.prefix(rowLimit).enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption2)
                                .frame(width: 130, alignment: .leading)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxHeight: 260)
    }
}
