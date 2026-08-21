import Foundation

/// Loads the three dashboard figures for one app.
///
/// This is the expensive path: impressions and retention each mean walking
/// Apple's analytics pipeline (request → reports → instances → segments → gzip)
/// for that app, so results are cached for the calendar day and callers are
/// expected to bound how many apps they load at once.
///
/// Each metric is fetched independently and allowed to fail on its own. Missing
/// beats wrong here — retention isn't exposed for every account, and an app
/// with a fresh ONGOING request has nothing for up to 48 hours.
@MainActor
enum DashboardMetricsLoader {
    /// The window the dashboard figures describe, and the one they're compared against.
    static let range: AnalyticsTimeRange = .week
    /// Reviews come back newest first; two pages is plenty for an average.
    static let reviewPages = 2

    static func load(
        app: AppResource,
        account: APIAccount,
        forceRefresh: Bool = false,
        cache: AnalyticsCacheStore = .shared
    ) async -> AppDashboardMetrics {
        let key = "\(app.id)-dashboard-metrics"
        if !forceRefresh,
           let cached = await cache.load(AppDashboardMetrics.self, key: key),
           AnalyticsCacheStore.isFreshForToday(cached.fetchedAt) {
            return cached.value
        }

        let session = AnalyticsSession(app: app, account: account)
        let fetcher = AnalyticsReportFetcher(session: session)

        var metrics = AppDashboardMetrics(id: app.id, appName: app.attributes.name)
        var failures: [String] = []

        // The three are independent, so one stalling doesn't hold up the others.
        async let discovery = table(fetcher, .discovery)
        async let retention = table(fetcher, .retention)
        async let reviews = reviewStats(session: session, appId: app.id)

        let (discoveryResult, retentionResult, reviewResult) = await (discovery, retention, reviews)

        switch discoveryResult {
        case .success(let table):
            let impressions = impressionTotals(table)
            metrics.impressions = impressions.current
            metrics.impressionsDelta = MetricDelta.between(
                current: impressions.current, previous: impressions.previous
            )?.change
        case .failure(let error):
            failures.append(error.localizedDescription)
        }

        switch retentionResult {
        case .success(let table):
            let split = retentionDay7(table)
            metrics.retention = split.current
            if let current = split.current, let previous = split.previous {
                metrics.retentionDeltaPoints = (current - previous) * 100
            }
        case .failure(let error):
            failures.append(error.localizedDescription)
        }

        switch reviewResult {
        case .success(let stats):
            metrics.reviewAverage = stats.average
            metrics.reviewDelta = stats.delta
        case .failure(let error):
            failures.append(error.localizedDescription)
        }

        // Only surface an error when nothing at all came back; a partial card is
        // more useful than an error message.
        if !metrics.hasAnyValue {
            metrics.errorMessage = failures.first ?? "No data available for this app yet."
        }

        await cache.save(metrics, key: key)
        return metrics
    }

    // MARK: Per-metric fetches

    private static func table(
        _ fetcher: AnalyticsReportFetcher,
        _ metric: ReportMetric
    ) async -> Result<ReportTable, Error> {
        do {
            return .success(try await fetcher.table(for: metric, range: range).table)
        } catch {
            return .failure(error)
        }
    }

    private static func reviewStats(
        session: AnalyticsSession,
        appId: String
    ) async -> Result<(average: Double, delta: Double?), Error> {
        do {
            let client = try session.makeClient()
            let reviews = try await client.fetchAllReviews(appId: appId, maxPages: reviewPages)
            guard !reviews.isEmpty else {
                return .success((0, nil))
            }
            let bounds = range.bounds()
            var recent: [Int] = []
            var previous: [Int] = []
            for review in reviews {
                guard let date = ASCDate.parseTimestamp(review.attributes.createdDate) else { continue }
                if date >= bounds.current {
                    recent.append(review.attributes.rating)
                } else if date >= bounds.previous {
                    previous.append(review.attributes.rating)
                }
            }
            // Fall back to the lifetime average when nothing landed this week,
            // so the card shows the app's standing rather than a blank.
            let average = recent.isEmpty
                ? ReviewStatistics.average(reviews)
                : Double(recent.reduce(0, +)) / Double(recent.count)
            var delta: Double?
            if !recent.isEmpty, !previous.isEmpty {
                let previousAverage = Double(previous.reduce(0, +)) / Double(previous.count)
                delta = average - previousAverage
            }
            return .success((average, delta))
        } catch {
            return .failure(error)
        }
    }

    // MARK: Extraction

    private static func impressionTotals(_ table: ReportTable) -> (current: Double, previous: Double) {
        guard !table.isEmpty else { return (0, 0) }
        let valueColumn = MetricExtractor.valueColumn(table)
        let dateColumn = MetricExtractor.dateColumn(table)
        let eventColumn = MetricExtractor.columnIndex(table, matching: ["event"])

        let rows: [[String]]
        if let eventColumn {
            rows = table.rows.filter { row in
                guard let event = MetricExtractor.cell(row, eventColumn)?.lowercased() else { return false }
                return event.contains("impression") && !event.contains("unique")
            }
        } else {
            rows = table.rows
        }

        let series = MetricExtractor.dailySeries(rows, dateColumn: dateColumn, valueColumn: valueColumn)
        return MetricExtractor.periodTotals(series, days: range.days)
    }

    /// Mean day-7 retention for the current window and the one before it.
    /// The comparison is only possible when the report carries a date column;
    /// without one the value stands alone rather than inventing a trend.
    private static func retentionDay7(_ table: ReportTable) -> (current: Double?, previous: Double?) {
        guard !table.isEmpty else { return (nil, nil) }
        guard let column = MetricExtractor.columnIndex(table, matching: [
            "day 7", "day7", "d7", "7 day", "7-day"
        ]) else { return (nil, nil) }

        func mean(_ rows: [[String]]) -> Double? {
            let values = rows.compactMap { MetricExtractor.number($0, column) }.filter { $0 > 0 }
            guard !values.isEmpty else { return nil }
            let average = values.reduce(0, +) / Double(values.count)
            // Some report variants use 0-100, others 0-1.
            return average > 1 ? min(average / 100, 1) : average
        }

        guard let dateColumn = MetricExtractor.dateColumn(table) else {
            return (mean(table.rows), nil)
        }
        let bounds = range.bounds()
        var currentRows: [[String]] = []
        var previousRows: [[String]] = []
        for row in table.rows {
            guard let raw = MetricExtractor.cell(row, dateColumn),
                  let date = ASCDate.parse(raw) else { continue }
            if date >= bounds.current {
                currentRows.append(row)
            } else if date >= bounds.previous {
                previousRows.append(row)
            }
        }
        // Undated or out-of-window data still deserves a value.
        let current = currentRows.isEmpty ? mean(table.rows) : mean(currentRows)
        return (current, mean(previousRows))
    }
}
