import Foundation

/// A report table together with the moment it was retrieved, so pages can show
/// "Updated today at 9:41 AM" without tracking freshness separately.
struct DatedTable: Sendable, Equatable {
    let table: ReportTable
    let fetchedAt: Date

    static let empty = DatedTable(table: .empty, fetchedAt: .distantPast)
}

@MainActor
final class AnalyticsReportFetcher {
    private let session: AnalyticsSession
    private let cache: AnalyticsCacheStore

    init(session: AnalyticsSession, cache: AnalyticsCacheStore = .shared) {
        self.session = session
        self.cache = cache
    }

    private var appId: String { session.app.id }

    /// Returns cached data when it was fetched today, otherwise refetches.
    func table(for metric: ReportMetric, range: AnalyticsTimeRange) async throws -> DatedTable {
        let key = AnalyticsCacheStore.key(appId: appId, metric: metric, range: range)
        if let cached = await cache.load(ReportTable.self, key: key),
           AnalyticsCacheStore.isFreshForToday(cached.fetchedAt) {
            return DatedTable(table: cached.value, fetchedAt: cached.fetchedAt)
        }
        return try await refresh(metric: metric, range: range)
    }

    /// Always hits the network, bypassing the freshness check.
    @discardableResult
    func refresh(metric: ReportMetric, range: AnalyticsTimeRange) async throws -> DatedTable {
        let client = try session.makeClient()
        let report = try await session.report(for: metric)

        let instances = try await client.fetchInstances(
            reportId: report.id,
            granularity: range.granularity,
            limit: max(range.instanceCount * 2, 10)
        )
        guard !instances.isEmpty else { throw AnalyticsError.noInstances(metric) }

        // Newest instances first, capped so a 90-day view doesn't fan out into
        // dozens of downloads.
        let selected = instances
            .sorted { $0.attributes.processingDate > $1.attributes.processingDate }
            .prefix(range.instanceCount)

        var payloads: [Data] = []
        for instance in selected {
            let segments = try await client.fetchSegments(instanceId: instance.id)
            guard !segments.isEmpty else { continue }
            let downloaded = try await withThrowingTaskGroup(of: Data.self) { group -> [Data] in
                for segment in segments {
                    let url = segment.attributes.url
                    group.addTask { try await client.downloadSegment(url: url) }
                }
                var collected: [Data] = []
                for try await data in group { collected.append(data) }
                return collected
            }
            payloads.append(contentsOf: downloaded)
        }
        guard !payloads.isEmpty else { throw AnalyticsError.noInstances(metric) }

        let merged = try await Self.decodeAndMerge(payloads)
        let key = AnalyticsCacheStore.key(appId: appId, metric: metric, range: range)
        let fetchedAt = await cache.save(merged, key: key)
        return DatedTable(table: merged, fetchedAt: fetchedAt)
    }

    /// Gunzip + TSV parsing are CPU-bound and the reports run to tens of
    /// thousands of rows, so they run off the main actor.
    private nonisolated static func decodeAndMerge(_ payloads: [Data]) async throws -> ReportTable {
        try await Task.detached(priority: .userInitiated) {
            var tables: [ReportTable] = []
            for payload in payloads {
                let decompressed = try Gzip.decompress(payload)
                tables.append(ReportParser.parseTSV(decompressed))
            }
            return ReportParser.merge(tables)
        }.value
    }

    // MARK: Reviews

    /// Reviews post at any hour rather than on Apple's nightly batch, so this
    /// uses a short freshness window and leans on pull-to-refresh.
    static let reviewFreshnessWindow: TimeInterval = 3 * 60 * 60

    func reviews(forceRefresh: Bool = false) async throws -> (reviews: [CustomerReview], fetchedAt: Date) {
        let key = AnalyticsCacheStore.reviewsKey(appId: appId)
        if !forceRefresh,
           let cached = await cache.load([CustomerReview].self, key: key),
           AnalyticsCacheStore.isFresh(cached.fetchedAt, within: Self.reviewFreshnessWindow) {
            return (cached.value, cached.fetchedAt)
        }
        let client = try session.makeClient()
        let fetched = try await client.fetchAllReviews(appId: appId)
        let fetchedAt = await cache.save(fetched, key: key)
        return (fetched, fetchedAt)
    }
}
