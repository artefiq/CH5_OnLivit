import SwiftUI
import Charts
internal import Combine

// MARK: - Derived metrics

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

    var conversionRate: Double { impressions > 0 ? downloads / impressions : 0 }
    var pageConversionRate: Double { pageViews > 0 ? downloads / pageViews : 0 }

    var funnel: [FunnelStage] {
        var stages: [FunnelStage] = [FunnelStage(label: "Impressions", value: impressions)]
        if pageViews > 0 { stages.append(FunnelStage(label: "Product Page Views", value: pageViews)) }
        stages.append(FunnelStage(label: "Downloads", value: downloads))
        return stages
    }

    var hasData: Bool { impressions > 0 || downloads > 0 }

    // MARK: Computation

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

    private static func eventRows(_ table: ReportTable, eventColumn: Int?, keyword: String) -> [[String]] {
        guard let eventColumn else {
            return table.rows
        }
        return table.rows.filter { row in
            guard let event = MetricExtractor.cell(row, eventColumn)?.lowercased() else { return false }
            return event.contains(keyword) && !event.contains("unique")
        }
    }

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
    @Published private(set) var findings: [InsightFinding] = []
    @Published private(set) var actions: [InsightAction] = []
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

    func loadIfNeeded() async {
        guard loadedRange != range else { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        warnings = []
        defer { isLoading = false }

        let range = self.range

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
            findings = []
            actions = []
            return
        }
        let availability = await InsightGenerator.shared.availability
        guard availability.isAvailable else {
            insightUnavailableMessage = availability.message
            findings = []
            actions = []
            return
        }
        insightUnavailableMessage = nil
        isGeneratingInsights = true
        defer { isGeneratingInsights = false }

        let facts = metrics.factSheet(appName: session.app.attributes.name, range: range)
        
        async let generatedFindings = InsightGenerator.shared.findings(
            instructions: InsightInstructions.discoverySummary, facts: facts
        )
        async let generatedActions = InsightGenerator.shared.actions(
            instructions: InsightInstructions.discoverySuggestion, facts: facts
        )
        let (newFindings, newActions) = await (generatedFindings, generatedActions)
        findings = newFindings
        actions = newActions
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
                        DataLoadingView(symbol: "chart.bar.fill", text: "Loading discovery data…")
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
            .scrollContentBackground(.hidden)
            .task { await model.loadIfNeeded() }
            .refreshable { await model.refresh() }
            .onChange(of: model.range) { _, _ in
                Task { await model.rangeChanged() }
            }
        }
        .navigationTitle("Impressions")
        .navigationBarTitleDisplayMode(.inline)
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

        AnalyticsSection(title: "Headline numbers", subtitle: "The period at a glance", showsDivider: false) {
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
        }
           
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

        AnalyticsSection(title: "Discovery funnel", subtitle: "Where people drop off between seeing and installing") {
            FunnelView(stages: metrics.funnel)
            ExplainerRow(
                facts: """
                Impressions: \(Int(metrics.impressions))
                Product page views: \(Int(metrics.pageViews))
                Downloads: \(Int(metrics.downloads))
                Impression to download conversion: \(metrics.conversionRate.percentFormatted)
                Product page view to download conversion: \(metrics.pageConversionRate.percentFormatted)
                """,
                fallback: """
                The funnel follows one journey: your app is seen, someone opens the product page, \
                and then installs. The percentage between each bar is how many people carried on to \
                the next step. A steep drop tells you which step is losing people.
                """
            )
        }
        
        if !metrics.impressionSeries.isEmpty || !metrics.downloadSeries.isEmpty {
            AnalyticsSection(title: "Impressions vs downloads", subtitle: "Spikes and dips lined up on one timeline") {
                DiscoveryTrendChart(
                    impressions: metrics.impressionSeries,
                    downloads: metrics.downloadSeries
                )
                ExplainerRow(
                    facts: """
                    Impressions per day: \(Self.describeSeries(metrics.impressionSeries))
                    Downloads per day: \(Self.describeSeries(metrics.downloadSeries))
                    """,
                    fallback: """
                    Both lines share one timeline so you can see whether downloads follow \
                    impressions. When impressions rise and downloads stay flat, more people are \
                    seeing your app without being convinced by it.
                    """
                )
            }
        }

        if !metrics.sourceBreakdown.isEmpty {
            AnalyticsSection(title: "By source", subtitle: "Search, Browse, Referrer, Apple Ads") {
                BreakdownListView(items: metrics.sourceBreakdown)
                ExplainerRow(
                    facts: "Impressions by source: \(Self.describeBreakdown(metrics.sourceBreakdown))",
                    fallback: """
                    Where people were when they saw your app. Search means they typed something, \
                    Browse means the App Store surfaced you, and Referrer means another app or site \
                    sent them. Search-heavy traffic usually rewards keywords; browse-heavy traffic \
                    rewards your icon and screenshots.
                    """
                )
            }
        }
        if !metrics.territoryBreakdown.isEmpty {
            AnalyticsSection(title: "Top territories") {
                BreakdownListView(items: metrics.territoryBreakdown)
                ExplainerRow(
                    facts: "Impressions by territory: \(Self.describeBreakdown(metrics.territoryBreakdown))",
                    fallback: """
                    The countries your app is being seen in most. A country high here but low on \
                    downloads is often a localisation gap rather than a lack of interest.
                    """
                )
            }
        }
        if !metrics.deviceBreakdown.isEmpty {
            AnalyticsSection(title: "By device") {
                BreakdownListView(items: metrics.deviceBreakdown)
                ExplainerRow(
                    facts: "Impressions by device: \(Self.describeBreakdown(metrics.deviceBreakdown))",
                    fallback: """
                    Which devices your audience is on. It tells you which screen sizes your \
                    screenshots and layout most need to look right on.
                    """
                )
            }
        }
        if !metrics.downloadTypeBreakdown.isEmpty {
            AnalyticsSection(
                title: "Download type",
                subtitle: "First-time installs versus redownloads",
                showsDivider: false
            ) {
                BreakdownListView(items: metrics.downloadTypeBreakdown)
                ExplainerRow(
                    facts: "Downloads by type: \(Self.describeBreakdown(metrics.downloadTypeBreakdown))",
                    fallback: """
                    First-time downloads are new people. Redownloads are people who had your app \
                    before and came back. Growth comes from the first number; the second is a sign \
                    of how well you are remembered.
                    """
                )
            }
        }
    }

    // MARK: Fact sheets for the explainers

    /// Series are summarised rather than listed — a 90-day series would swamp
    /// the model's context and it only needs the shape.
    private static func describeSeries(_ series: [TrendPoint]) -> String {
        guard !series.isEmpty else { return "no data" }
        let total = series.reduce(0) { $0 + $1.value }
        let peak = series.max { $0.value < $1.value }
        let first = series.first?.value ?? 0
        let last = series.last?.value ?? 0
        var parts = [
            "\(series.count) days",
            "total \(Int(total))",
            "average \(Int(total / Double(series.count)))",
            "first day \(Int(first))",
            "last day \(Int(last))"
        ]
        if let peak {
            parts.append("peak \(Int(peak.value))")
        }
        return parts.joined(separator: ", ")
    }

    private static func describeBreakdown(_ items: [BreakdownItem]) -> String {
        guard !items.isEmpty else { return "no data" }
        let total = items.reduce(0) { $0 + $1.value }
        return items
            .map { "\($0.label) \(Int($0.value)) (\($0.share(of: total).percentFormatted))" }
            .joined(separator: ", ")
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
