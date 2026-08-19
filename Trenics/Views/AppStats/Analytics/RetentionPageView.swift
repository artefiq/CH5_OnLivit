import SwiftUI
import Charts
internal import Combine

// MARK: - Derived metrics

struct RetentionMetrics: Sendable, Equatable {
    var curve: [RetentionPoint] = []
    var sessions: Double = 0
    var activeDevices: Double = 0
    var installs: Double = 0
    var deletions: Double = 0
    var crashes: Double = 0
    var sessionSeries: [TrendPoint] = []
    var deletionSeries: [TrendPoint] = []
    var crashSeries: [TrendPoint] = []
    var sessionsDelta: MetricDelta?
    var deletionsDelta: MetricDelta?
    var crashesByVersion: [BreakdownItem] = []
    var deletionsByVersion: [BreakdownItem] = []

    var day1: Double? { curve.first { $0.day == 1 }?.rate }
    var day7: Double? { curve.first { $0.day == 7 }?.rate }
    var day28: Double? { curve.first { $0.day == 28 }?.rate }

    /// Deletions as a share of installs — the churn signal that pairs with the curve.
    var deletionRate: Double { installs > 0 ? deletions / installs : 0 }
    /// Crashes per session, the usual normalisation.
    var crashRate: Double { sessions > 0 ? crashes / sessions : 0 }

    var hasData: Bool {
        !curve.isEmpty || sessions > 0 || deletions > 0 || installs > 0
    }

    static func make(
        retention: ReportTable?,
        sessions sessionsTable: ReportTable?,
        installsAndDeletions: ReportTable?,
        crashes crashesTable: ReportTable?,
        range: AnalyticsTimeRange
    ) -> RetentionMetrics {
        var metrics = RetentionMetrics()

        if let retention, !retention.isEmpty {
            metrics.curve = RetentionExtractor.curve(from: retention)
        }

        if let sessionsTable, !sessionsTable.isEmpty {
            let valueColumn = MetricExtractor.columnIndex(sessionsTable, matching: ["sessions", "counts", "count"])
            let dateColumn = MetricExtractor.dateColumn(sessionsTable)
            metrics.sessions = MetricExtractor.total(sessionsTable.rows, valueColumn: valueColumn)
            let series = MetricExtractor.dailySeries(
                sessionsTable.rows, dateColumn: dateColumn, valueColumn: valueColumn
            )
            metrics.sessionSeries = MetricExtractor.within(series, range: range)
            let totals = MetricExtractor.periodTotals(series, days: range.days)
            metrics.sessionsDelta = .between(current: totals.current, previous: totals.previous)

            if let deviceColumn = MetricExtractor.columnIndex(sessionsTable, matching: ["unique devices", "active devices"]) {
                metrics.activeDevices = MetricExtractor.total(sessionsTable.rows, valueColumn: deviceColumn)
            }
        }

        if let installsAndDeletions, !installsAndDeletions.isEmpty {
            let valueColumn = MetricExtractor.valueColumn(installsAndDeletions)
            let dateColumn = MetricExtractor.dateColumn(installsAndDeletions)
            let eventColumn = MetricExtractor.columnIndex(installsAndDeletions, matching: ["event"])

            let installRows = MetricExtractor.rows(
                installsAndDeletions, where: eventColumn, matchesAny: ["install", "reinstall"]
            )
            let deletionRows = MetricExtractor.rows(
                installsAndDeletions, where: eventColumn, matchesAny: ["delete", "deletion", "uninstall"]
            )
            metrics.installs = MetricExtractor.total(installRows, valueColumn: valueColumn)
            metrics.deletions = MetricExtractor.total(deletionRows, valueColumn: valueColumn)

            let series = MetricExtractor.dailySeries(
                deletionRows, dateColumn: dateColumn, valueColumn: valueColumn
            )
            metrics.deletionSeries = MetricExtractor.within(series, range: range)
            let totals = MetricExtractor.periodTotals(series, days: range.days)
            metrics.deletionsDelta = .between(current: totals.current, previous: totals.previous, lowerIsBetter: true)

            metrics.deletionsByVersion = MetricExtractor.breakdown(
                deletionRows,
                dimensionColumn: MetricExtractor.columnIndex(installsAndDeletions, matching: ["app version", "version"]),
                valueColumn: valueColumn
            )
        }

        if let crashesTable, !crashesTable.isEmpty {
            let valueColumn = MetricExtractor.columnIndex(crashesTable, matching: ["crashes", "counts", "count"])
            let dateColumn = MetricExtractor.dateColumn(crashesTable)
            metrics.crashes = MetricExtractor.total(crashesTable.rows, valueColumn: valueColumn)
            let series = MetricExtractor.dailySeries(
                crashesTable.rows, dateColumn: dateColumn, valueColumn: valueColumn
            )
            metrics.crashSeries = MetricExtractor.within(series, range: range)
            metrics.crashesByVersion = MetricExtractor.breakdown(
                crashesTable.rows,
                dimensionColumn: MetricExtractor.columnIndex(crashesTable, matching: ["app version", "version"]),
                valueColumn: valueColumn
            )
        }

        return metrics
    }

    /// The model's job on this page is specifically to notice correlations
    /// across these numbers, so retention, churn, crashes and version are all
    /// presented side by side rather than one at a time.
    func factSheet(appName: String, range: AnalyticsTimeRange) -> String {
        var lines = [
            "App: \(appName)",
            "Period: \(range.longLabel)"
        ]
        for point in curve {
            lines.append("Day \(point.day) retention: \(point.rate.percentFormatted)")
        }
        if sessions > 0 { lines.append("Sessions: \(Int(sessions))") }
        if activeDevices > 0 { lines.append("Active devices: \(Int(activeDevices))") }
        if installs > 0 { lines.append("Installs: \(Int(installs))") }
        if deletions > 0 {
            lines.append("Deletions: \(Int(deletions)) (\(deletionRate.percentFormatted) of installs)")
        }
        if crashes > 0 {
            lines.append("Crashes: \(Int(crashes)) (\(crashRate.percentFormatted) per session)")
        }
        if let sessionsDelta {
            lines.append("Sessions change vs previous period: \(sessionsDelta.formatted)")
        }
        if let deletionsDelta {
            lines.append("Deletions change vs previous period: \(deletionsDelta.formatted)")
        }
        if !crashesByVersion.isEmpty {
            let described = crashesByVersion.prefix(3)
                .map { "\($0.label): \(Int($0.value))" }
                .joined(separator: ", ")
            lines.append("Crashes by app version: \(described)")
        }
        if !deletionsByVersion.isEmpty {
            let described = deletionsByVersion.prefix(3)
                .map { "\($0.label): \(Int($0.value))" }
                .joined(separator: ", ")
            lines.append("Deletions by app version: \(described)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Page model

@MainActor
final class RetentionPageModel: ObservableObject {
    @Published private(set) var metrics = RetentionMetrics()
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

    func rangeChanged() async {
        loadedRange = nil
        await loadIfNeeded()
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        warnings = []
        defer { isLoading = false }

        let range = self.range

        // Four independent reports, all requested at once when the tab opens.
        async let retention = fetch(.retention, range: range, forceRefresh: forceRefresh)
        async let sessions = fetch(.sessions, range: range, forceRefresh: forceRefresh)
        async let lifecycle = fetch(.installsAndDeletions, range: range, forceRefresh: forceRefresh)
        async let crashes = fetch(.crashes, range: range, forceRefresh: forceRefresh)
        let (retentionResult, sessionsResult, lifecycleResult, crashesResult) =
            await (retention, sessions, lifecycle, crashes)

        var stamps: [Date] = []
        var failures: [String] = []

        func unwrap(_ result: Result<DatedTable, Error>) -> ReportTable? {
            switch result {
            case .success(let dated):
                stamps.append(dated.fetchedAt)
                return dated.table
            case .failure(let error):
                failures.append(error.localizedDescription)
                return nil
            }
        }

        let retentionTable = unwrap(retentionResult)
        let sessionsTable = unwrap(sessionsResult)
        let lifecycleTable = unwrap(lifecycleResult)
        let crashesTable = unwrap(crashesResult)

        if stamps.isEmpty {
            errorMessage = failures.first
            loadedRange = nil
            return
        }
        // Retention reports in particular aren't enabled for every account, so
        // a partial page is the expected outcome rather than an error.
        warnings = failures
        lastUpdated = stamps.max()
        loadedRange = range

        metrics = RetentionMetrics.make(
            retention: retentionTable,
            sessions: sessionsTable,
            installsAndDeletions: lifecycleTable,
            crashes: crashesTable,
            range: range
        )
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
            instructions: InsightInstructions.retentionSummary, facts: facts
        )
        async let generatedActions = InsightGenerator.shared.actions(
            instructions: InsightInstructions.retentionSuggestion, facts: facts
        )
        let (newFindings, newActions) = await (generatedFindings, generatedActions)
        findings = newFindings
        actions = newActions
    }
}

// MARK: - View

struct RetentionPageView: View {
    @StateObject private var model: RetentionPageModel

    init(session: AnalyticsSession) {
        _model = StateObject(wrappedValue: RetentionPageModel(session: session))
    }

    var body: some View {
        MainLayout {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let errorMessage = model.errorMessage {
                        ErrorBanner(message: errorMessage)
                    } else if model.isLoading && !model.metrics.hasData {
                        ProgressView("Loading retention data…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if !model.metrics.hasData {
                        AnalyticsEmptyState(
                            systemImage: "arrow.trianglehead.counterclockwise",
                            title: "No usage data yet",
                            message: "Apple hasn't produced session, retention or deletion data for this app in the selected period."
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
        .navigationTitle("Retention")
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

        if !metrics.curve.isEmpty {
            AnalyticsSection(title: "Retention curve", subtitle: "Share of installs still active on each day") {
                RetentionCurveChart(points: metrics.curve)
                ExplainerRow(
                    facts: metrics.curve
                        .map { "Day \($0.day) retention: \($0.rate.percentFormatted)" }
                        .joined(separator: "\n"),
                    fallback: """
                    Each point is the share of people who installed your app and were still using \
                    it that many days later. The curve always falls; what matters is how fast. A \
                    sharp drop in the first day usually points at onboarding, while a slide later \
                    on points at whether the app stays useful.
                    """
                )
            }
        }

        AnalyticsSection(title: "Headline numbers", subtitle: "The period at a glance") {
            StatCardRow {
                StatCard(
                    title: "Day 1",
                    value: metrics.day1.map(\.percentFormatted) ?? "—",
                    caption: "Retained"
                )
                StatCard(
                    title: "Day 7",
                    value: metrics.day7.map(\.percentFormatted) ?? "—",
                    caption: "Retained"
                )
                StatCard(
                    title: "Day 28",
                    value: metrics.day28.map(\.percentFormatted) ?? "—",
                    caption: "Retained"
                )
                StatCard(
                    title: "Sessions",
                    value: metrics.sessions.compactFormatted,
                    delta: metrics.sessionsDelta
                )
                StatCard(
                    title: "Deletions",
                    value: metrics.deletions.compactFormatted,
                    delta: metrics.deletionsDelta
                )
                StatCard(
                    title: "Crash rate",
                    value: metrics.crashes > 0 ? metrics.crashRate.percentFormatted : "—",
                    caption: "Per session"
                )
            }
            ExplainerRow(
                facts: """
                Day 1 retention: \(metrics.day1?.percentFormatted ?? "not available")
                Day 7 retention: \(metrics.day7?.percentFormatted ?? "not available")
                Day 28 retention: \(metrics.day28?.percentFormatted ?? "not available")
                Sessions: \(Int(metrics.sessions))
                Deletions: \(Int(metrics.deletions)) out of \(Int(metrics.installs)) installs (\(metrics.deletionRate.percentFormatted))
                Crashes: \(Int(metrics.crashes)), which is \(metrics.crashRate.percentFormatted) per session
                Sessions change vs the previous period: \(metrics.sessionsDelta?.formatted ?? "not available")
                Deletions change vs the previous period: \(metrics.deletionsDelta?.formatted ?? "not available")
                """,
                fallback: """
                Day 1, 7 and 28 are the share of new users still active after that many days. \
                Sessions count how often the app was opened. Deletions are uninstalls — the \
                opposite of retention. Crash rate is crashes per session, and a rise here usually \
                shows up as a retention drop shortly afterwards.
                """
            )
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

        if !metrics.sessionSeries.isEmpty || !metrics.deletionSeries.isEmpty {
            AnalyticsSection(
                title: "Engagement vs churn",
                subtitle: "Deletions plotted against sessions over the same window"
            ) {
                ChurnChart(
                    sessions: metrics.sessionSeries,
                    deletions: metrics.deletionSeries
                )
                ExplainerRow(
                    facts: """
                    Sessions per day: \(Self.describeSeries(metrics.sessionSeries))
                    Deletions per day: \(Self.describeSeries(metrics.deletionSeries))
                    """,
                    fallback: """
                    The line is how much your app is being used; the bars are people removing it. \
                    Seen together they tell a fuller story than either alone — deletions climbing \
                    while sessions fall is churn, whereas both climbing usually just means growth.
                    """
                )
            }
        }

        if !metrics.crashSeries.isEmpty {
            AnalyticsSection(title: "Crashes over time") {
                CrashChart(points: metrics.crashSeries)
                ExplainerRow(
                    facts: "Crashes per day: \(Self.describeSeries(metrics.crashSeries))",
                    fallback: """
                    How often your app crashed on each day. A sudden spike almost always lines up \
                    with a release, so compare the date of a jump against when you last shipped.
                    """
                )
            }
        }

        if !metrics.crashesByVersion.isEmpty {
            AnalyticsSection(title: "Crashes by app version", subtitle: "A strong leading indicator for retention drops") {
                BreakdownListView(items: metrics.crashesByVersion)
                ExplainerRow(
                    facts: "Crashes by app version: \(Self.describeBreakdown(metrics.crashesByVersion))",
                    fallback: """
                    Crashes split by the version people were running. One version carrying most of \
                    them points at a regression you shipped in that release rather than a \
                    long-standing bug.
                    """
                )
            }
        }
        if !metrics.deletionsByVersion.isEmpty {
            AnalyticsSection(title: "Deletions by app version", showsDivider: false) {
                BreakdownListView(items: metrics.deletionsByVersion)
                ExplainerRow(
                    facts: "Deletions by app version: \(Self.describeBreakdown(metrics.deletionsByVersion))",
                    fallback: """
                    Uninstalls split by version. If one release is losing far more people than the \
                    others, whatever changed in it is worth a close look.
                    """
                )
            }
        }
    }

    // MARK: Fact sheets for the explainers

    private static func describeSeries(_ series: [TrendPoint]) -> String {
        guard !series.isEmpty else { return "no data" }
        let total = series.reduce(0) { $0 + $1.value }
        var parts = [
            "\(series.count) days",
            "total \(Int(total))",
            "average \(Int(total / Double(series.count)))",
            "first day \(Int(series.first?.value ?? 0))",
            "last day \(Int(series.last?.value ?? 0))"
        ]
        if let peak = series.max(by: { $0.value < $1.value }) {
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

// MARK: - Charts

private struct RetentionCurveChart: View {
    let points: [RetentionPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Day", point.day),
                y: .value("Retained", point.rate)
            )
            .foregroundStyle(Color("primaryPurple"))
            .interpolationMethod(.monotone)

            AreaMark(
                x: .value("Day", point.day),
                y: .value("Retained", point.rate)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color("primaryPurple").opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Day", point.day),
                y: .value("Retained", point.rate)
            )
            .foregroundStyle(Color("primaryPurple"))
            .annotation(position: .top) {
                Text(point.rate.percentFormatted)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map(\.day)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text("D\(day)")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text(rate.percentFormatted)
                    }
                }
            }
        }
        .chartYScale(domain: 0...1)
        .frame(height: 200)
    }
}

private struct ChurnChart: View {
    let sessions: [TrendPoint]
    let deletions: [TrendPoint]

    var body: some View {
        Chart {
            ForEach(sessions) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Count", point.value),
                    series: .value("Metric", "Sessions")
                )
                .foregroundStyle(by: .value("Metric", "Sessions"))
                .interpolationMethod(.monotone)
            }
            ForEach(deletions) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Count", point.value)
                )
                .foregroundStyle(by: .value("Metric", "Deletions"))
                .opacity(0.6)
            }
        }
        .chartForegroundStyleScale([
            "Sessions": Color("primaryPurple"),
            "Deletions": Color.red
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

private struct CrashChart: View {
    let points: [TrendPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date),
                y: .value("Crashes", point.value)
            )
            .foregroundStyle(.red.opacity(0.7))
        }
        .frame(height: 160)
    }
}
