import SwiftUI
import Charts
internal import Combine
#if canImport(Translation)
import Translation
#endif

// MARK: - Derived metrics

struct ReviewMetrics: Sendable, Equatable {
    var total: Int = 0
    var average: Double = 0
    var histogram: [RatingBucket] = []
    var sentimentCounts: [ReviewSentiment: Int] = [:]
    var averageDelta: MetricDelta?
    var unansweredCount: Int = 0

    var hasData: Bool { total > 0 }

    static func make(_ reviews: [CustomerReview], range: AnalyticsTimeRange) -> ReviewMetrics {
        let scoped = ReviewStatistics.within(reviews, range: range)
        var metrics = ReviewMetrics()
        metrics.total = scoped.count
        metrics.average = ReviewStatistics.average(scoped)
        metrics.histogram = ReviewStatistics.histogram(scoped)
        metrics.sentimentCounts = ReviewStatistics.sentimentCounts(scoped)

        // Compare this window's average against the equal window before it.
        let bounds = range.bounds()
        let previous = reviews.filter {
            guard let date = ASCDate.parseTimestamp($0.attributes.createdDate) else { return false }
            return date >= bounds.previous && date < bounds.current
        }
        if !previous.isEmpty {
            metrics.averageDelta = .between(
                current: metrics.average,
                previous: ReviewStatistics.average(previous)
            )
        }
        return metrics
    }

    func factSheet(appName: String, range: AnalyticsTimeRange, themes: [ReviewThemeInsight]) -> String {
        var lines = [
            "App: \(appName)",
            "Period: \(range.longLabel)",
            "Reviews: \(total)",
            String(format: "Average rating: %.2f", average)
        ]
        for bucket in histogram where bucket.count > 0 {
            lines.append("\(bucket.stars)-star reviews: \(bucket.count)")
        }
        for sentiment in ReviewSentiment.allCases {
            lines.append("\(sentiment.label) reviews: \(sentimentCounts[sentiment] ?? 0)")
        }
        if let averageDelta {
            lines.append("Average rating change vs previous period: \(averageDelta.formatted)")
        }
        if !themes.isEmpty {
            let described = themes
                .map { "\($0.theme) (\($0.reviewCount) reviews, \($0.sentiment.rawValue))" }
                .joined(separator: "; ")
            lines.append("Recurring themes: \(described)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Filtering

struct ReviewFilter: Equatable {
    var stars: Int?
    var sentiment: ReviewSentiment?
    var theme: String?

    var isActive: Bool { stars != nil || sentiment != nil || theme != nil }

    func matches(_ review: CustomerReview) -> Bool {
        if let stars, review.attributes.rating != stars { return false }
        if let sentiment, ReviewSentiment.fromRating(review.attributes.rating) != sentiment { return false }
        if let theme {
            let haystack = [review.attributes.title, review.attributes.body]
                .compactMap { $0 }
                .joined(separator: " ")
            // Match on any significant word in the theme so "subscription
            // pricing" still catches a review that only says "pricing".
            let words = theme.split(separator: " ").map(String.init).filter { $0.count > 3 }
            let needles: [String] = words.isEmpty ? [theme] : words
            guard needles.contains(where: { haystack.localizedCaseInsensitiveContains($0) }) else {
                return false
            }
        }
        return true
    }
}

// MARK: - Page model

@MainActor
final class ReviewsPageModel: ObservableObject {
    @Published private(set) var metrics = ReviewMetrics()
    @Published private(set) var reviews: [CustomerReview] = []
    @Published private(set) var themes: [ReviewThemeInsight] = []
    /// Review id → developer reply body. A stored `nil` means "checked, no reply".
    @Published private(set) var responses: [String: String?] = [:]
    @Published private(set) var loadingResponses: Set<String> = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var isGeneratingInsights = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var findings: [InsightFinding] = []
    @Published private(set) var actions: [InsightAction] = []
    @Published private(set) var insightUnavailableMessage: String?
    @Published var range: AnalyticsTimeRange = .month
    @Published var filter = ReviewFilter()

    private let session: AnalyticsSession
    private let fetcher: AnalyticsReportFetcher
    private var hasLoaded = false

    init(session: AnalyticsSession) {
        self.session = session
        self.fetcher = AnalyticsReportFetcher(session: session)
    }

    var filteredReviews: [CustomerReview] {
        let scoped = ReviewStatistics.within(reviews, range: range)
        guard filter.isActive else { return scoped }
        return scoped.filter(filter.matches)
    }

    var trend: [(date: Date, average: Double, count: Int)] {
        ReviewStatistics.dailyTrend(ReviewStatistics.within(reviews, range: range))
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    func rangeChanged() {
        metrics = ReviewMetrics.make(reviews, range: range)
        Task { await generateInsights() }
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await fetcher.reviews(forceRefresh: forceRefresh)
            reviews = result.reviews
            lastUpdated = result.fetchedAt
            hasLoaded = true
            metrics = ReviewMetrics.make(reviews, range: range)
            // Theme extraction only needs review bodies, so it starts as soon
            // as the list lands — it never waits on developer responses.
            await generateInsights()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetched per review as its card scrolls into view. Eagerly calling
    /// `/response` for every review would be an N+1 — 100 reviews means 100
    /// extra requests before anything renders.
    func loadResponseIfNeeded(for review: CustomerReview) async {
        let id = review.id
        guard responses[id] == nil, !loadingResponses.contains(id) else { return }
        loadingResponses.insert(id)
        defer { loadingResponses.remove(id) }
        do {
            let response = try await session.makeAnalyticsClient().fetchReviewResponse(reviewId: id)
            responses[id] = .some(response?.attributes.responseBody)
        } catch {
            // A failed lookup just leaves the card showing "Not answered".
            responses[id] = .some(nil)
        }
    }

    func isLoadingResponse(_ review: CustomerReview) -> Bool {
        loadingResponses.contains(review.id)
    }

    func response(for review: CustomerReview) -> String? {
        responses[review.id] ?? nil
    }

    private func generateInsights() async {
        let scoped = ReviewStatistics.within(reviews, range: range)
        guard !scoped.isEmpty else {
            themes = []
            findings = []
            actions = []
            return
        }
        let availability = await InsightGenerator.shared.availability
        guard availability.isAvailable else {
            insightUnavailableMessage = availability.message
            themes = []
            findings = []
            actions = []
            return
        }
        insightUnavailableMessage = nil
        isGeneratingInsights = true
        defer { isGeneratingInsights = false }

        // Themes first — the summary and suggestion are meaningfully better
        // when they can reference the extracted themes.
        let extracted = await InsightGenerator.shared.reviewThemes(from: scoped)
        themes = extracted

        let facts = metrics.factSheet(
            appName: session.app.attributes.name,
            range: range,
            themes: extracted
        )
        async let generatedFindings = InsightGenerator.shared.findings(
            instructions: InsightInstructions.reviewsSummary, facts: facts
        )
        async let generatedActions = InsightGenerator.shared.actions(
            instructions: InsightInstructions.reviewsSuggestion, facts: facts
        )
        let (newFindings, newActions) = await (generatedFindings, generatedActions)
        findings = newFindings
        actions = newActions
    }
}

// MARK: - View

struct ReviewsPageView: View {
    @StateObject private var model: ReviewsPageModel
    @StateObject private var translation = ReviewTranslationStore()
    #if canImport(Translation)
    /// Setting this is what starts a pass — `.translationTask` opens a session
    /// whenever the configuration changes.
    @State private var translationConfiguration: TranslationSession.Configuration?
    #endif

    init(session: AnalyticsSession) {
        _model = StateObject(wrappedValue: ReviewsPageModel(session: session))
    }

    private func toggleTranslation() {
        if translation.isShowingTranslation {
            translation.showOriginal()
            return
        }
        let items = translatableItems
        guard !items.isEmpty else { return }
        // Already translated once, so just switch back to it.
        if translation.isCovered(items) {
            translation.showTranslation()
            return
        }
        #if canImport(Translation)
        translation.beginTranslating()
        // A fresh configuration each time, otherwise an unchanged value would
        // not retrigger the task after an earlier failure.
        translationConfiguration = TranslationSession.Configuration(
            source: nil,
            target: Locale.Language(identifier: "en")
        )
        #else
        translation.fail("Translation isn't available on this device.")
        #endif
    }

    var body: some View {
        MainLayout {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header

                    if let errorMessage = model.errorMessage {
                        ErrorBanner(message: errorMessage)
                    } else if model.isLoading && !model.metrics.hasData {
                        ProgressView("Loading reviews…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if !model.metrics.hasData {
                        AnalyticsEmptyState(
                            systemImage: "star.bubble",
                            title: "No reviews yet",
                            message: "This app has no customer reviews in the selected period."
                        )
                    } else {
                        content
                    }
                }
                .padding(20)
            }
            // Kept transparent so MainLayout's texture shows through.
            .scrollContentBackground(.hidden)
            .task { await model.loadIfNeeded() }
            .refreshable { await model.refresh() }
            .onChange(of: model.range) { _, _ in
                model.rangeChanged()
            }
        }
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        #if canImport(Translation)
        .translationTask(translationConfiguration) { session in
            await translation.translate(items: translatableItems, using: session)
        }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimeRangePicker(range: $model.range)
            HStack {
                LastUpdatedLabel(date: model.lastUpdated)
                Spacer()
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ratingHero
        AISummaryDisclosure(
            findings: model.findings,
            isLoading: model.isGeneratingInsights,
            unavailableMessage: model.insightUnavailableMessage
        )
        AINextStepDisclosure(
            actions: model.actions,
            isLoading: model.isGeneratingInsights
        )

        Divider()
        sentimentSection
        trendSection
        themesAndReviews
    }

    private var ratingHero: some View {
        AnalyticsSection(title: "Ratings") {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", model.metrics.average))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    StarRatingView(rating: Int(model.metrics.average.rounded()), size: 14)
                    Text("\(model.metrics.total) reviews")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let delta = model.metrics.averageDelta {
                        HStack(spacing: 3) {
                            Image(systemName: delta.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(delta.formatted)
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(delta.isPositive ? .green : .red)
                    }
                }
                .frame(width: 110)

                RatingHistogramView(buckets: model.metrics.histogram)
            }
            ExplainerRow(
                facts: """
                Average review score: \(String(format: "%.2f", model.metrics.average)) out of 5
                Total reviews in this period: \(model.metrics.total)
                Star breakdown: \(model.metrics.histogram.map { "\($0.stars) star: \($0.count)" }.joined(separator: ", "))
                Change vs the previous period: \(model.metrics.averageDelta?.formatted ?? "not available")
                """,
                fallback: """
                The big number is the average of the written reviews in this period, and the bars \
                show how many landed on each star. A healthy app is usually top-heavy; a bulge at \
                one star means a specific complaint rather than general dissatisfaction.
                """
            )
        }
    }

    private var sentimentSection: some View {
        AnalyticsSection(title: "Sentiment", subtitle: "Tap a filter below to narrow the list") {
            SentimentDonutView(counts: model.metrics.sentimentCounts)
            ExplainerRow(
                facts: ReviewSentiment.allCases
                    .map { "\($0.label): \(model.metrics.sentimentCounts[$0] ?? 0) reviews" }
                    .joined(separator: ", "),
                fallback: """
                Reviews grouped by tone: four and five stars count as positive, three as neutral, \
                and one or two as negative. The split matters more than the average — a mix of \
                fives and ones averages the same as a pile of threes but means something very \
                different.
                """
            )
        }
    }

    @ViewBuilder
    private var trendSection: some View {
        let trend = model.trend
        if trend.count > 1 {
            AnalyticsSection(
                title: "Rating over time",
                subtitle: "A rating dip alongside a volume spike usually means a release regression"
            ) {
                ReviewTrendChart(points: trend)
                ExplainerRow(
                    facts: {
                        let averages = trend.map(\.average)
                        let counts = trend.map(\.count)
                        let mean = averages.reduce(0, +) / Double(averages.count)
                        return """
                        Days covered: \(trend.count)
                        Average rating across those days: \(String(format: "%.2f", mean))
                        First day average: \(String(format: "%.2f", averages.first ?? 0))
                        Last day average: \(String(format: "%.2f", averages.last ?? 0))
                        Lowest day average: \(String(format: "%.2f", averages.min() ?? 0))
                        Total reviews: \(counts.reduce(0, +)), busiest day \(counts.max() ?? 0)
                        """
                    }(),
                    fallback: """
                    The line is your average rating per day and the bars are how many reviews \
                    arrived. A dip in the line at the same time as a jump in the bars usually means \
                    a release upset people, because unhappy users write reviews in bursts.
                    """
                )
            }
        }
    }

    /// Themes and the reviews they were drawn from, in one section. They are
    /// the same material — a theme is a summary of these reviews — so a divider
    /// between them implied a separation that isn't there.
    @ViewBuilder
    private var themesAndReviews: some View {
        AnalyticsSection(
            title: "Themes",
            subtitle: "Extracted on-device from your review text — tap one to filter",
            showsDivider: false
        ) {
            themeContent
            reviewContent
        } accessory: {
            TranslateButton(
                isShowingTranslation: translation.isShowingTranslation,
                isTranslating: translation.isTranslating,
                action: toggleTranslation
            )
        }
    }

    @ViewBuilder
    private var themeContent: some View {
        if model.isGeneratingInsights && model.themes.isEmpty {
            ProgressView().controlSize(.small)
        } else if !model.themes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ThemeTagsView(
                    themes: displayThemes,
                    selected: $model.filter.theme
                )
                if let selected = model.filter.theme,
                   let index = model.themes.firstIndex(where: { $0.theme == selected }),
                   !model.themes[index].representativeQuote.isEmpty {
                    let quoteId = Self.quoteId(model.themes[index])
                    VStack(alignment: .leading, spacing: 4) {
                        Text("“\(translation.display(model.themes[index].representativeQuote, id: quoteId))”")
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if translation.hasTranslation(id: quoteId) {
                            TranslatedBadge()
                        }
                    }
                }
                if let message = translation.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                OnDeviceBadge()
            }
        }
    }

    @ViewBuilder
    private var reviewContent: some View {
        let filtered = model.filteredReviews

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                filterBar
                if model.filter.isActive {
                    Button("Clear") { model.filter = ReviewFilter() }
                        .font(.caption)
                }
            }

            if filtered.isEmpty {
                AnalyticsEmptyState(
                    systemImage: "line.3.horizontal.decrease.circle",
                    title: "Nothing matches",
                    message: "No reviews in this period match the current filters."
                )
            } else {
                ForEach(filtered) { review in
                    ReviewCard(
                        review: review,
                        response: model.response(for: review),
                        isLoadingResponse: model.isLoadingResponse(review),
                        displayTitle: translation.display(
                            review.attributes.title ?? "", id: "\(review.id)-title"
                        ),
                        displayBody: translation.display(
                            review.attributes.body ?? "", id: "\(review.id)-body"
                        ),
                        isTranslated: translation.hasTranslation(id: "\(review.id)-body")
                            || translation.hasTranslation(id: "\(review.id)-title")
                    )
                    .task { await model.loadResponseIfNeeded(for: review) }
                }
            }
        }
    }

    /// Theme names go through translation too, so a filter chip reads in the
    /// same language as the quote it belongs to.
    private var displayThemes: [ReviewThemeInsight] {
        guard translation.isShowingTranslation else { return model.themes }
        return model.themes.map { theme in
            ReviewThemeInsight(
                theme: translation.display(theme.theme, id: Self.themeId(theme)),
                sentiment: theme.sentiment,
                reviewCount: theme.reviewCount,
                representativeQuote: theme.representativeQuote
            )
        }
    }

    static func themeId(_ theme: ReviewThemeInsight) -> String { "theme-\(theme.theme)" }
    static func quoteId(_ theme: ReviewThemeInsight) -> String { "quote-\(theme.theme)" }

    /// Everything visible in this section, so one pass covers the themes, their
    /// quotes and the reviews underneath.
    private var translatableItems: [TranslatableItem] {
        var items: [TranslatableItem] = []
        for theme in model.themes {
            items.append(TranslatableItem(id: Self.themeId(theme), text: theme.theme))
            if !theme.representativeQuote.isEmpty {
                items.append(TranslatableItem(id: Self.quoteId(theme), text: theme.representativeQuote))
            }
        }
        for review in model.filteredReviews {
            if let title = review.attributes.title, !title.isEmpty {
                items.append(TranslatableItem(id: "\(review.id)-title", text: title))
            }
            if let body = review.attributes.body, !body.isEmpty {
                items.append(TranslatableItem(id: "\(review.id)-body", text: body))
            }
        }
        return items
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach((1...5).reversed(), id: \.self) { stars in
                    FilterChip(
                        label: "\(stars)★",
                        isSelected: model.filter.stars == stars
                    ) {
                        model.filter.stars = model.filter.stars == stars ? nil : stars
                    }
                }
                Divider().frame(height: 20)
                ForEach(ReviewSentiment.allCases, id: \.self) { sentiment in
                    FilterChip(
                        label: sentiment.label,
                        isSelected: model.filter.sentiment == sentiment,
                        tint: SentimentDonutView.color(for: sentiment)
                    ) {
                        model.filter.sentiment = model.filter.sentiment == sentiment ? nil : sentiment
                    }
                }
            }
        }
    }
}

// MARK: - Supporting views

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var tint: Color = Color("primaryPurple")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? tint.opacity(0.2) : Color.secondary.opacity(0.1))
                )
                .foregroundStyle(isSelected ? tint : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewTrendChart: View {
    let points: [(date: Date, average: Double, count: Int)]

    var body: some View {
        Chart {
            ForEach(points, id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Reviews", point.count)
                )
                .foregroundStyle(Color.secondary.opacity(0.25))
            }
            ForEach(points, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.average)
                )
                .foregroundStyle(Color("primaryPurple"))
                .interpolationMethod(.monotone)
                .symbol(.circle)
            }
        }
        .chartYScale(domain: 0...5)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 3, 4, 5]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rating = value.as(Int.self) {
                        Text("\(rating)★")
                    }
                }
            }
        }
        .frame(height: 180)
    }
}
