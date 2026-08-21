import Foundation

/// Builds the dashboard's account-wide overview.
///
/// Deliberately reviews-only. An account-wide roll-up of impressions or
/// downloads would mean running the whole analytics pipeline — request →
/// reports → instances → segments → gzip download — once per app, and would
/// read as zero for any app whose ONGOING request is less than 48 hours old.
/// Reviews are one paginated call per app and have data immediately.
@MainActor
enum AccountSummaryLoader {
    /// Reviews come back newest-first, so a couple of pages is plenty for an
    /// overview and keeps the dashboard fast on accounts with many apps.
    static let maxPagesPerApp = 2
    /// How many apps to fetch at once. Bounded so a large account doesn't open
    /// dozens of simultaneous connections.
    static let concurrentAppFetches = 4
    /// Window used for "recent" counts and the period-over-period comparison.
    static let periodDays = 30

    static func load(
        account: APIAccount,
        apps: [AppResource],
        forceRefresh: Bool = false,
        cache: AnalyticsCacheStore = .shared
    ) async -> AccountSummary {
        guard !apps.isEmpty else { return AccountSummary() }

        let client = AppStoreConnectClient(
            issuerId: account.issuerId,
            keyId: account.keyId,
            privateKeyPEM: account.privateKeyPEM
        )

        var snapshots: [AppRatingSnapshot] = []
        var failedAppNames: [String] = []
        var stamps: [Date] = []

        // Chunked rather than one big group so the number of in-flight requests
        // stays bounded regardless of how many apps the account has.
        for chunk in apps.chunked(into: concurrentAppFetches) {
            let results = await withTaskGroup(
                of: (AppRatingSnapshot?, String, Date?).self
            ) { group -> [(AppRatingSnapshot?, String, Date?)] in
                for app in chunk {
                    group.addTask {
                        await snapshot(
                            for: app,
                            client: client,
                            forceRefresh: forceRefresh,
                            cache: cache
                        )
                    }
                }
                var collected: [(AppRatingSnapshot?, String, Date?)] = []
                for await result in group { collected.append(result) }
                return collected
            }
            for (snapshot, appName, stamp) in results {
                if let snapshot {
                    snapshots.append(snapshot)
                    if let stamp { stamps.append(stamp) }
                } else {
                    failedAppNames.append(appName)
                }
            }
        }

        return AccountSummary(
            snapshots: snapshots.sorted { $0.appName < $1.appName },
            fetchedAt: stamps.max(),
            failedAppNames: failedAppNames
        )
    }

    /// Cached under its own key rather than sharing the Reviews page's cache:
    /// that entry holds the full review list, and writing a two-page subset
    /// there would silently truncate what the Reviews tab shows.
    private static func snapshot(
        for app: AppResource,
        client: AppStoreConnectClient,
        forceRefresh: Bool,
        cache: AnalyticsCacheStore
    ) async -> (AppRatingSnapshot?, String, Date?) {
        let key = "\(app.id)-rating-snapshot"
        if !forceRefresh,
           let cached = await cache.load(AppRatingSnapshot.self, key: key),
           AnalyticsCacheStore.isFreshForToday(cached.fetchedAt) {
            return (cached.value, app.attributes.name, cached.fetchedAt)
        }
        do {
            let reviews = try await client.fetchAllReviews(appId: app.id, maxPages: maxPagesPerApp)
            let snapshot = makeSnapshot(app: app, reviews: reviews)
            let fetchedAt = await cache.save(snapshot, key: key)
            return (snapshot, app.attributes.name, fetchedAt)
        } catch {
            return (nil, app.attributes.name, nil)
        }
    }

    static func makeSnapshot(app: AppResource, reviews: [CustomerReview], now: Date = Date()) -> AppRatingSnapshot {
        let currentStart = now.addingTimeInterval(-Double(periodDays) * 86_400)
        let previousStart = now.addingTimeInterval(-Double(periodDays) * 2 * 86_400)

        var recent: [Int] = []
        var previous: [Int] = []
        for review in reviews {
            guard let date = ASCDate.parseTimestamp(review.attributes.createdDate) else { continue }
            if date >= currentStart {
                recent.append(review.attributes.rating)
            } else if date >= previousStart {
                previous.append(review.attributes.rating)
            }
        }

        return AppRatingSnapshot(
            id: app.id,
            appName: app.attributes.name,
            average: ReviewStatistics.average(reviews),
            reviewCount: reviews.count,
            previousAverage: previous.isEmpty
                ? nil
                : Double(previous.reduce(0, +)) / Double(previous.count),
            recentReviewCount: recent.count
        )
    }
}

extension Array {
    /// Splits into fixed-size batches, used to bound request concurrency.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
