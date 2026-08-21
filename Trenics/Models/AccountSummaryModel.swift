import Foundation

/// Per-app review figures, cached so the dashboard doesn't refetch every appearance.
///
/// Note this is derived from *written reviews* only. The App Store Connect API
/// exposes no lifetime star-rating distribution, so `average` is the mean of the
/// reviews actually fetched — not the rating shown on the App Store. The UI
/// labels it accordingly.
nonisolated struct AppRatingSnapshot: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let appName: String
    let average: Double
    let reviewCount: Int
    /// Mean over the window before `periodDays`, when there were reviews then.
    let previousAverage: Double?
    /// Reviews created inside the recent window.
    let recentReviewCount: Int

    var delta: MetricDelta? {
        guard let previousAverage else { return nil }
        return .between(current: average, previous: previousAverage)
    }
}

/// Account-wide roll-up shown in the dashboard's overview card.
nonisolated struct AccountSummary: Sendable, Equatable {
    var snapshots: [AppRatingSnapshot] = []
    var fetchedAt: Date?
    /// Apps whose reviews could not be loaded, so the card can be honest about
    /// covering less than the whole account.
    var failedAppNames: [String] = []

    var appCount: Int { snapshots.count }
    var totalReviews: Int { snapshots.reduce(0) { $0 + $1.reviewCount } }
    var recentReviews: Int { snapshots.reduce(0) { $0 + $1.recentReviewCount } }

    /// Weighted by review count, so a 5.0 from one review doesn't outrank a 4.6
    /// from four hundred.
    var averageRating: Double {
        let rated = snapshots.filter { $0.reviewCount > 0 }
        let totalWeight = rated.reduce(0) { $0 + $1.reviewCount }
        guard totalWeight > 0 else { return 0 }
        let weighted = rated.reduce(0.0) { $0 + $1.average * Double($1.reviewCount) }
        return weighted / Double(totalWeight)
    }

    /// Only apps with enough reviews to be worth ranking.
    private var rankable: [AppRatingSnapshot] {
        snapshots.filter { $0.reviewCount >= 3 }
    }

    var bestApp: AppRatingSnapshot? { rankable.max { $0.average < $1.average } }
    var worstApp: AppRatingSnapshot? { rankable.min { $0.average < $1.average } }

    var hasData: Bool { !snapshots.isEmpty && totalReviews > 0 }

    /// Aggregates only — no review text — handed to the on-device model.
    func factSheet(accountLabel: String, periodDays: Int) -> String {
        var lines = [
            "Account: \(accountLabel)",
            "Apps: \(appCount)",
            String(format: "Average review score across all apps: %.2f out of 5", averageRating),
            "Total reviews: \(totalReviews)",
            "Reviews in the last \(periodDays) days: \(recentReviews)"
        ]
        for snapshot in snapshots.sorted(by: { $0.average > $1.average }) where snapshot.reviewCount > 0 {
            var line = String(
                format: "%@: %.2f from %d reviews",
                snapshot.appName, snapshot.average, snapshot.reviewCount
            )
            if let delta = snapshot.delta {
                line += " (\(delta.formatted) vs the previous period)"
            }
            lines.append(line)
        }
        if !failedAppNames.isEmpty {
            lines.append("Not included because their reviews failed to load: \(failedAppNames.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }
}
