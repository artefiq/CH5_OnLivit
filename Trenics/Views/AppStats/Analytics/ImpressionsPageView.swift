import SwiftUI
import Charts
internal import Combine

// MARK: - Derived metrics

/// Everything the Impressions page renders, computed once when tables land so
/// the view body stays free of aggregation work.
struct DiscoveryMetrics: Sendable, Equatable {
    var impressions: Double = 0
    var pageViews: Double = 0
    var downloads: Double = 0
    var impressionSeries: [TrendPoint] = []
    var downloadSeries: [TrendPoint] = []
    var impressionsDelta: MetricDelta?
    var downloadsDelta: MetricDelta?
    var sourceBreakdown: [BreakdownItem] = []
    var territoryBreakdown: [BreakdownItem] = []
    var deviceBreakdown: [BreakdownItem] = []
    var downloadTypeBreakdown: [BreakdownItem] = []

    /// Impressions → downloads, the number developers mean by "conversion".
    var conversionRate: Double { impressions > 0 ? downloads / impressions : 0 }
    /// Page view → download, the store-listing-specific step.
    var pageConversionRate: Double { pageViews > 0 ? downloads / pageViews : 0 }

    var funnel: [FunnelStage] {
        var stages: [FunnelStage] = [FunnelStage(label: "Impressions", value: impressions)]
        if pageViews > 0 { stages.append(FunnelStage(label: "Product Page Views", value: pageViews)) }
        stages.append(FunnelStage(label: "Downloads", value: downloads))
        return stages
    }

    var hasData: Bool { impressions > 0 || downloads > 0 }

    // MARK: Computation

    /// Both tables are optional — if downloads 403s while impressions succeeds,
    /// half a page is better than a blank one.
    static func make(
        discovery: ReportTable?,
        downloads downloadsTable: ReportTable?,
        range: AnalyticsTimeRange
    ) -> DiscoveryMetrics {
        var metrics = DiscoveryMetrics()

        if let discovery, !discovery.isEmpty {
            let valueColumn = MetricExtractor.valueColumn(discovery)
            let dateColumn = MetricExtractor.dateColumn(discovery)
            let eventColumn = MetricExtractor.columnIndex(discovery, matching: ["event"])

            let impressionRows = eventRows(discovery, eventColumn: eventColumn, keyword: "impression")
            let pageViewRows = eventRows(discovery, eventColumn: eventColumn, keyword: "page view")

            metrics.impressions = MetricExtractor.total(impressionRows, valueColumn: valueColumn)
            metrics.pageViews = MetricExtractor.total(pageViewRows, valueColumn: valueColumn)

            let series = MetricExtractor.dailySeries(
                impressionRows, dateColumn: dateColumn, valueColumn: valueColumn
            )
            metrics.impressionSeries = MetricExtractor.within(series, range: range)
            let totals = MetricExtractor.periodTotals(series, days: range.days)
            metrics.impressionsDelta = .between(current: totals.current, previous: totals.previous)

            metrics.sourceBreakdown = MetricExtractor.breakdown(
                impressionRows,
                dimensionColumn: MetricExtractor.columnIndex(discovery, matching: ["source type", "source"]),
                valueColumn: valueColumn
            )
            metrics.territoryBreakdown = MetricExtractor.breakdown(
                impressionRows,
                dimensionColumn: MetricExtractor.columnIndex(discovery, matching: ["territory", "country"]),
                valueColumn: valueColumn
            )
            metrics.deviceBreakdown = MetricExtractor.breakdown(
                impressionRows,
                dimensionColumn: MetricExtractor.columnIndex(discovery, matching: ["device"]),
                valueColumn: valueColumn
            )
        }

        if let downloadsTable, !downloadsTable.isEmpty {
            let valueColumn = MetricExtractor.valueColumn(downloadsTable)
            let dateColumn = MetricExtractor.dateColumn(downloadsTable)

            metrics.downloads = MetricExtractor.total(downloadsTable.rows, valueColumn: valueColumn)

            let series = MetricExtractor.dailySeries(
                downloadsTable.rows, dateColumn: dateColumn, valueColumn: valueColumn
            )
            metrics.downloadSeries = MetricExtractor.within(series, range: range)
            let totals = MetricExtractor.periodTotals(series, days: range.days)
            metrics.downloadsDelta = .between(current: totals.current, previous: totals.previous)

            metrics.downloadTypeBreakdown = MetricExtractor.breakdown(
                downloadsTable.rows,
                dimensionColumn: MetricExtractor.columnIndex(downloadsTable, matching: ["download type", "type"]),
                valueColumn: valueColumn
            )
            if metrics.territoryBreakdown.isEmpty {
                metrics.territoryBreakdown = MetricExtractor.breakdown(
                    downloadsTable.rows,
                    dimensionColumn: MetricExtractor.columnIndex(downloadsTable, matching: ["territory", "country"]),
                    valueColumn: valueColumn
                )
            }
        }

        return metrics
    }

    /// Discovery reports encode impressions and page views as rows of one
    /// table, distinguished by an Event column. Unique-device variants are
    /// excluded so totals aren't counted twice.
    private static func eventRows(_ table: ReportTable, eventColumn: Int?, keyword: String) -> [[String]] {
        guard let eventColumn else {
            // Older/standard variants use dedicated columns instead of an Event column.
            return table.rows
        }
        return table.rows.filter { row in
            guard let event = MetricExtractor.cell(row, eventColumn)?.lowercased() else { return false }
            return event.contains(keyword) && !event.contains("unique")
        }
    }

    /// Compact fact sheet handed to the on-device model. Aggregates only —
    /// no raw rows, no identifiers.
    func factSheet(appName: String, range: AnalyticsTimeRange) -> String {
        var lines = [
            "App: \(appName)",
            "Period: \(range.longLabel)",
            "Impressions: \(Int(impressions))",
            "Product page views: \(Int(pageViews))",
            "Downloads: \(Int(downloads))",
            "Impression-to-download conversion: \(conversionRate.percentFormatted)"
        ]
        if pageViews > 0 {
            lines.append("Page-view-to-download conversion: \(pageConversionRate.percentFormatted)")
        }
        if let impressionsDelta {
            lines.append("Impressions change vs previous period: \(impressionsDelta.formatted)")
        }
        if let downloadsDelta {
            lines.append("Downloads change vs previous period: \(downloadsDelta.formatted)")
        }
        if !sourceBreakdown.isEmpty {
            let total = sourceBreakdown.reduce(0) { $0 + $1.value }
            let described = sourceBreakdown
                .map { "\($0.label) \($0.share(of: total).percentFormatted)" }
                .joined(separator: ", ")
            lines.append("Impressions by source: \(described)")
        }
        if !territoryBreakdown.isEmpty {
            let described = territoryBreakdown.prefix(3)
                .map { "\($0.label) \(Int($0.value))" }
                .joined(separator: ", ")
            lines.append("Top territories: \(described)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Page model

@MainActor
final class ImpressionsPageModel: ObservableObject {
    @Published private(set) var metrics = DiscoveryMetrics()
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var isGeneratingInsights = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var warnings: [String] = []
    @Published private(set) var summary: InsightSummary?
    @Published private(set) var suggestion: InsightSuggestion?
    @Published private(set) var insightUnavailableMessage: String?
    @Published var range: AnalyticsTimeRange = .month

    private let session: AnalyticsSession
    private let fetcher: AnalyticsReportFetcher
    private var discoveryTable: ReportTable?
    private var downloadsTable: ReportTable?
    private var loadedRange: AnalyticsTimeRange?

    init(session: AnalyticsSession) {
        self.session = session
        self.fetcher = AnalyticsReportFetcher(session: session)
    }

    /// Called from `.task`. A cache hit for today makes no network call at all.
    func loadIfNeeded() async {
        guard loadedRange != range else { return }
        await load(forceRefresh: false)
    }

    /// Called from pull-to-refresh. Always goes to the network.
    func refresh() async {
        await load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        warnings = []
        defer { isLoading = false }

        let range = self.range

        // The two reports are independent, so they're requested together
        // rather than one after the other.
        async let discovery = fetch(.discovery, range: range, forceRefresh: forceRefresh)
        async let downloads = fetch(.downloads, range: range, forceRefresh: forceRefresh)
        let (discoveryResult, downloadsResult) = await (discovery, downloads)

        var stamps: [Date] = []
        var failures: [String] = []

        switch discoveryResult {
        case .success(let dated):
            discoveryTable = dated.table
            stamps.append(dated.fetchedAt)
        case .failure(let error):
            failures.append(error.localizedDescription)
        }

        switch downloadsResult {
        case .success(let dated):
            downloadsTable = dated.table
            stamps.append(dated.fetchedAt)
        case .failure(let error):
            failures.append(error.localizedDescription)
        }

        // Each branch fails independently — one failure degrades the page
        // rather than blanking it.
        if stamps.isEmpty {
            errorMessage = failures.first
            loadedRange = nil
            return
        }
        warnings = failures
        lastUpdated = stamps.max()
        loadedRange = range

        metrics = DiscoveryMetrics.make(discovery: discoveryTable, downloads: downloadsTable, range: range)
        await generateInsights()
    }

    private func fetch(
        _ metric: ReportMetric,
        range: AnalyticsTimeRange,
        forceRefresh: Bool
    ) async -> Result<DatedTable, Error> {
        do {
            let dated = forceRefresh
                ? try await fetcher.refresh(metric: metric, range: range)
                : try await fetcher.table(for: metric, range: range)
            return .success(dated)
        } catch {
            return .failure(error)
        }
    }

    private func generateInsights() async {
        guard metrics.hasData else {
            summary = nil
            suggestion = nil
            return
        }
        let availability = await InsightGenerator.shared.availability
        guard availability.isAvailable else {
            insightUnavailableMessage = availability.message
            summary = nil
            suggestion = nil
            return
        }
        insightUnavailableMessage = nil
        isGeneratingInsights = true
        defer { isGeneratingInsights = false }

        let facts = metrics.factSheet(appName: session.app.attributes.name, range: range)
        // Summary and suggestion are independent generations — run them together.
        async let generatedSummary = InsightGenerator.shared.summary(
            instructions: InsightInstructions.discoverySummary, facts: facts
        )
        async let generatedSuggestion = InsightGenerator.shared.suggestion(
            instructions: InsightInstructions.discoverySuggestion, facts: facts
        )
        let (newSummary, newSuggestion) = await (generatedSummary, generatedSuggestion)
        summary = newSummary
        suggestion = newSuggestion
    }

    func rangeChanged() async {
        loadedRange = nil
        await loadIfNeeded()
    }
}

// MARK: - View

struct ImpressionsPageView: View {
    @StateObject private var model: ImpressionsPageModel

    init(session: AnalyticsSession) {
        _model = StateObject(wrappedValue: ImpressionsPageModel(session: session))
    }

    var body: some View {
        MainLayout {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let errorMessage = model.errorMessage {
                        ErrorBanner(message: errorMessage)
                    } else if model.isLoading && !model.metrics.hasData {
                        ProgressView("Loading discovery data…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if !model.metrics.hasData {
                        AnalyticsEmptyState(
                            systemImage: "chart.bar.doc.horizontal",
                            title: "No discovery data yet",
                            message: "Apple hasn't produced impression or download data for this app in the selected period."
                        )
                    } else {
                        content
                    }

                    ForEach(model.warnings, id: \.self) { warning in
                        ErrorBanner(message: warning)
                    }
                }
                .padding(20)
            }
            // Kept transparent so MainLayout's texture shows through.
            .scrollContentBackground(.hidden)
            .task { await model.loadIfNeeded() }
            .refreshable { await model.refresh() }
            .onChange(of: model.range) { _, _ in
                Task { await model.rangeChanged() }
            }
        }
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
        let metrics = model.metrics

        StatCardRow {
            StatCard(
                title: "Impressions",
                value: metrics.impressions.compactFormatted,
                delta: metrics.impressionsDelta
            )
            StatCard(
                title: "Downloads",
                value: metrics.downloads.compactFormatted,
                delta: metrics.downloadsDelta
            )
            StatCard(
                title: "Conversion",
                value: metrics.conversionRate.percentFormatted,
                caption: "Impression → download"
            )
        }

        SectionCard(title: "Discovery funnel", subtitle: "Where people drop off between seeing and installing") {
            FunnelView(stages: metrics.funnel)
        }

        AISummaryCard(
            summary: model.summary,
            range: model.range,
            isLoading: model.isGeneratingInsights,
            unavailableMessage: model.insightUnavailableMessage
        )
        AISuggestionCard(
            suggestion: model.suggestion,
            isLoading: model.isGeneratingInsights
        )

        if !metrics.impressionSeries.isEmpty || !metrics.downloadSeries.isEmpty {
            SectionCard(title: "Impressions vs downloads", subtitle: "Spikes and dips lined up on one timeline") {
                DiscoveryTrendChart(
                    impressions: metrics.impressionSeries,
                    downloads: metrics.downloadSeries
                )
            }
        }

        if !metrics.sourceBreakdown.isEmpty {
            SectionCard(title: "By source", subtitle: "Search, Browse, Referrer, Apple Ads") {
                BreakdownListView(items: metrics.sourceBreakdown)
            }
        }
        if !metrics.territoryBreakdown.isEmpty {
            SectionCard(title: "Top territories") {
                BreakdownListView(items: metrics.territoryBreakdown)
            }
        }
        if !metrics.deviceBreakdown.isEmpty {
            SectionCard(title: "By device") {
                BreakdownListView(items: metrics.deviceBreakdown)
            }
        }
        if !metrics.downloadTypeBreakdown.isEmpty {
            SectionCard(title: "Download type", subtitle: "First-time installs versus redownloads") {
                BreakdownListView(items: metrics.downloadTypeBreakdown)
            }
        }
    }
}

// MARK: - Chart

private struct DiscoveryTrendChart: View {
    let impressions: [TrendPoint]
    let downloads: [TrendPoint]

    var body: some View {
        Chart {
            ForEach(impressions) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Count", point.value),
                    series: .value("Metric", "Impressions")
                )
                .foregroundStyle(by: .value("Metric", "Impressions"))
                .interpolationMethod(.monotone)
            }
            ForEach(downloads) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Count", point.value),
                    series: .value("Metric", "Downloads")
                )
                .foregroundStyle(by: .value("Metric", "Downloads"))
                .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale([
            "Impressions": Color("primaryPurple"),
            "Downloads": Color.orange
        ])
        .chartLegend(position: .bottom)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.compactFormatted)
                    }
                }
            }
        }
        .frame(height: 200)
    }
}
