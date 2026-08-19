import Foundation

// MARK: - Time range

nonisolated enum AnalyticsTimeRange: Int, CaseIterable, Identifiable, Sendable, Codable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }
    var days: Int { rawValue }
    var label: String { "\(rawValue)D" }
    var longLabel: String { "Last \(rawValue) days" }

    /// Apple produces one report instance per granularity period. Asking for
    /// DAILY over 90 days would mean 90 instance downloads, so coarser ranges
    /// step up to weekly/monthly instances instead.
    var granularity: ReportGranularity {
        switch self {
        case .week: return .daily
        case .month: return .weekly
        case .quarter: return .monthly
        }
    }

    /// How many of the most recent instances to pull to cover the range.
    var instanceCount: Int {
        switch self {
        case .week: return 7
        case .month: return 5
        case .quarter: return 4
        }
    }

    /// Start of the window, and the start of the equal-length window before it
    /// (used for period-over-period deltas).
    func bounds(relativeTo now: Date = Date()) -> (current: Date, previous: Date) {
        let current = now.addingTimeInterval(-Double(days) * 86_400)
        let previous = now.addingTimeInterval(-Double(days) * 2 * 86_400)
        return (current, previous)
    }
}

nonisolated enum ReportGranularity: String, Sendable, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
}

// MARK: - Report metrics

/// A logical metric the UI needs, mapped onto whichever App Store Connect
/// analytics report actually carries it. Report names vary by account and by
/// what Apple has enabled, so matching is by name substring rather than by a
/// hardcoded identifier.
nonisolated enum ReportMetric: String, CaseIterable, Sendable, Codable {
    /// Impressions *and* product page views live in one report, keyed by an "Event" column.
    case discovery
    case downloads
    case installsAndDeletions
    case sessions
    case retention
    case crashes

    var displayName: String {
        switch self {
        case .discovery: return "Discovery & Engagement"
        case .downloads: return "Downloads"
        case .installsAndDeletions: return "Installs & Deletions"
        case .sessions: return "Sessions"
        case .retention: return "Retention"
        case .crashes: return "Crashes"
        }
    }

    /// Ordered best-match first; compared case-insensitively as substrings.
    var reportNameCandidates: [String] {
        switch self {
        case .discovery:
            return ["app store discovery and engagement detailed",
                    "app store discovery and engagement standard",
                    "discovery and engagement",
                    "app store discovery"]
        case .downloads:
            return ["app downloads detailed", "app downloads standard", "app downloads", "downloads"]
        case .installsAndDeletions:
            return ["app store installation and deletion detailed",
                    "app store installation and deletion standard",
                    "installation and deletion", "installs and deletions"]
        case .sessions:
            return ["app sessions detailed", "app sessions standard", "app sessions", "sessions"]
        case .retention:
            return ["app retention detailed", "app retention standard", "retention"]
        case .crashes:
            return ["app crashes expanded", "app crashes detailed", "app crashes", "crashes"]
        }
    }

    var category: String? {
        switch self {
        case .discovery, .downloads: return "APP_STORE_ENGAGEMENT"
        case .installsAndDeletions, .sessions, .retention: return "APP_USAGE"
        case .crashes: return "PERFORMANCE"
        }
    }
}

// MARK: - Derived series

nonisolated struct TrendPoint: Identifiable, Sendable, Equatable {
    var id: Date { date }
    let date: Date
    let value: Double
}

nonisolated struct BreakdownItem: Identifiable, Sendable, Equatable {
    var id: String { label }
    let label: String
    let value: Double

    func share(of total: Double) -> Double {
        total > 0 ? value / total : 0
    }
}

nonisolated struct FunnelStage: Identifiable, Sendable, Equatable {
    var id: String { label }
    let label: String
    let value: Double
}

nonisolated struct RetentionPoint: Identifiable, Sendable, Equatable {
    var id: Int { day }
    let day: Int
    /// 0...1
    let rate: Double
}

/// Period-over-period change, expressed as a fraction (0.12 == +12%).
nonisolated struct MetricDelta: Sendable, Equatable {
    let change: Double
    /// Some metrics are better when they fall (deletions, crashes).
    let lowerIsBetter: Bool

    var isPositive: Bool { lowerIsBetter ? change <= 0 : change >= 0 }
    var formatted: String {
        let pct = abs(change) * 100
        let sign = change >= 0 ? "+" : "−"
        return String(format: "%@%.1f%%", sign, pct)
    }

    static func between(current: Double, previous: Double, lowerIsBetter: Bool = false) -> MetricDelta? {
        guard previous > 0 else { return nil }
        return MetricDelta(change: (current - previous) / previous, lowerIsBetter: lowerIsBetter)
    }
}

// MARK: - Date handling

/// App Store Connect emits `yyyy-MM-dd`. Parsed by hand so the helper stays
/// `Sendable` and usable from detached parsing tasks (DateFormatter is not).
nonisolated enum ASCDate {
    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: "-")
        guard parts.count >= 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2].prefix(2)) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: components)
    }

    /// Reviews use full ISO-8601 timestamps.
    static func parseTimestamp(_ raw: String) -> Date? {
        ISO8601DateFormatter.shared.date(from: raw) ?? parse(raw)
    }
}

nonisolated extension ISO8601DateFormatter {
    nonisolated(unsafe) static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Column extraction

/// Everything the pages need to read a `ReportTable` without knowing the exact
/// column layout Apple happened to ship. Header names differ between the
/// "Standard" and "Detailed" variants of each report, so lookups are keyword
/// based: exact match wins, substring match is the fallback.
nonisolated enum MetricExtractor {

    // MARK: Column lookup

    static func columnIndex(_ table: ReportTable, matching keywords: [String]) -> Int? {
        let normalized = table.headers.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        for keyword in keywords {
            let needle = keyword.lowercased()
            if let exact = normalized.firstIndex(of: needle) { return exact }
        }
        for keyword in keywords {
            let needle = keyword.lowercased()
            if let partial = normalized.firstIndex(where: { $0.contains(needle) }) { return partial }
        }
        return nil
    }

    /// The column holding the numeric measurement for this report.
    static func valueColumn(_ table: ReportTable) -> Int? {
        columnIndex(table, matching: [
            "counts", "count", "sessions", "crashes", "units", "installations", "downloads", "value"
        ])
    }

    static func dateColumn(_ table: ReportTable) -> Int? {
        columnIndex(table, matching: ["date", "download date", "processing date"])
    }

    // MARK: Row access

    static func cell(_ row: [String], _ index: Int?) -> String? {
        guard let index, index >= 0, index < row.count else { return nil }
        return row[index]
    }

    static func number(_ row: [String], _ index: Int?) -> Double? {
        guard let raw = cell(row, index) else { return nil }
        // Reports may include thousands separators or a trailing % sign.
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    /// Keeps rows whose `column` value contains any of `values` (case-insensitive).
    static func rows(_ table: ReportTable, where column: Int?, matchesAny values: [String]) -> [[String]] {
        guard let column else { return table.rows }
        let needles = values.map { $0.lowercased() }
        return table.rows.filter { row in
            guard let raw = cell(row, column)?.lowercased() else { return false }
            return needles.contains { raw.contains($0) }
        }
    }

    static func rows(_ table: ReportTable, notMatching column: Int?, values: [String]) -> [[String]] {
        guard let column else { return table.rows }
        let needles = values.map { $0.lowercased() }
        return table.rows.filter { row in
            guard let raw = cell(row, column)?.lowercased() else { return true }
            return !needles.contains { raw.contains($0) }
        }
    }

    // MARK: Aggregation

    static func total(_ rows: [[String]], valueColumn: Int?) -> Double {
        rows.reduce(0) { $0 + (number($1, valueColumn) ?? 0) }
    }

    /// Sums the value column per calendar day, sorted ascending.
    static func dailySeries(_ rows: [[String]], dateColumn: Int?, valueColumn: Int?) -> [TrendPoint] {
        guard let dateColumn else { return [] }
        var buckets: [Date: Double] = [:]
        for row in rows {
            guard let raw = cell(row, dateColumn), let date = ASCDate.parse(raw) else { continue }
            buckets[date, default: 0] += number(row, valueColumn) ?? 0
        }
        return buckets
            .map { TrendPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Top-N grouped totals for a dimension such as Source Type or Territory.
    static func breakdown(
        _ rows: [[String]],
        dimensionColumn: Int?,
        valueColumn: Int?,
        limit: Int = 5
    ) -> [BreakdownItem] {
        guard let dimensionColumn else { return [] }
        var buckets: [String: Double] = [:]
        for row in rows {
            guard let key = cell(row, dimensionColumn), !key.isEmpty else { continue }
            buckets[key, default: 0] += number(row, valueColumn) ?? 0
        }
        return buckets
            .map { BreakdownItem(label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }

    /// Splits a series into the most recent `days` and the equal window before it.
    static func periodTotals(_ series: [TrendPoint], days: Int, now: Date = Date()) -> (current: Double, previous: Double) {
        let currentStart = now.addingTimeInterval(-Double(days) * 86_400)
        let previousStart = now.addingTimeInterval(-Double(days) * 2 * 86_400)
        let current = series
            .filter { (point: TrendPoint) in point.date >= currentStart }
            .reduce(0) { $0 + $1.value }
        let previous = series
            .filter { (point: TrendPoint) in point.date >= previousStart && point.date < currentStart }
            .reduce(0) { $0 + $1.value }
        return (current, previous)
    }

    static func within(_ series: [TrendPoint], range: AnalyticsTimeRange, now: Date = Date()) -> [TrendPoint] {
        let cutoff = range.bounds(relativeTo: now).current
        let filtered = series.filter { $0.date >= cutoff }
        // If the report's data is older than the window (common right after
        // creating an ONGOING request), show what exists rather than nothing.
        return filtered.isEmpty ? series : filtered
    }
}

// MARK: - Retention

nonisolated enum RetentionExtractor {
    /// Retention reports lay days out as columns ("Day 1", "Day 7", "Day 28").
    /// Values arrive either as percentages (0–100) or as 0–1 fractions.
    static let trackedDays = [1, 7, 14, 28]

    static func curve(from table: ReportTable) -> [RetentionPoint] {
        guard !table.headers.isEmpty, !table.rows.isEmpty else { return [] }
        var points: [RetentionPoint] = []
        for day in trackedDays {
            guard let column = dayColumn(table, day: day) else { continue }
            let values = table.rows.compactMap { MetricExtractor.number($0, column) }.filter { $0 > 0 }
            guard !values.isEmpty else { continue }
            let mean = values.reduce(0, +) / Double(values.count)
            points.append(RetentionPoint(day: day, rate: normalize(mean)))
        }
        return points
    }

    private static func dayColumn(_ table: ReportTable, day: Int) -> Int? {
        MetricExtractor.columnIndex(table, matching: [
            "day \(day)", "day\(day)", "d\(day)", "\(day) day", "\(day)-day"
        ])
    }

    /// Percentages come through as 0–100 in some report variants and 0–1 in others.
    private static func normalize(_ value: Double) -> Double {
        value > 1 ? min(value / 100, 1) : value
    }
}

// MARK: - Reviews

nonisolated enum ReviewSentiment: String, CaseIterable, Sendable, Codable {
    case positive, neutral, negative

    var label: String { rawValue.capitalized }

    /// Star-based fallback for when on-device classification is unavailable.
    static func fromRating(_ rating: Int) -> ReviewSentiment {
        switch rating {
        case 4...5: return .positive
        case 3: return .neutral
        default: return .negative
        }
    }
}

nonisolated struct RatingBucket: Identifiable, Sendable, Equatable {
    var id: Int { stars }
    let stars: Int
    let count: Int
}

nonisolated enum ReviewStatistics {
    static func average(_ reviews: [CustomerReview]) -> Double {
        guard !reviews.isEmpty else { return 0 }
        let sum = reviews.reduce(0) { $0 + $1.attributes.rating }
        return Double(sum) / Double(reviews.count)
    }

    static func histogram(_ reviews: [CustomerReview]) -> [RatingBucket] {
        (1...5).reversed().map { stars in
            RatingBucket(stars: stars, count: reviews.filter { $0.attributes.rating == stars }.count)
        }
    }

    static func sentimentCounts(_ reviews: [CustomerReview]) -> [ReviewSentiment: Int] {
        var counts: [ReviewSentiment: Int] = [:]
        for review in reviews {
            counts[.fromRating(review.attributes.rating), default: 0] += 1
        }
        return counts
    }

    /// Average rating and review volume per day, for the dual-axis trend chart.
    static func dailyTrend(_ reviews: [CustomerReview]) -> [(date: Date, average: Double, count: Int)] {
        var buckets: [Date: [Int]] = [:]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        for review in reviews {
            guard let parsed = ASCDate.parseTimestamp(review.attributes.createdDate) else { continue }
            let day = calendar.startOfDay(for: parsed)
            buckets[day, default: []].append(review.attributes.rating)
        }
        return buckets
            .map { (date: $0.key,
                    average: Double($0.value.reduce(0, +)) / Double($0.value.count),
                    count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    static func within(_ reviews: [CustomerReview], range: AnalyticsTimeRange, now: Date = Date()) -> [CustomerReview] {
        let cutoff = range.bounds(relativeTo: now).current
        let filtered = reviews.filter {
            guard let date = ASCDate.parseTimestamp($0.attributes.createdDate) else { return false }
            return date >= cutoff
        }
        return filtered.isEmpty ? reviews : filtered
    }
}
