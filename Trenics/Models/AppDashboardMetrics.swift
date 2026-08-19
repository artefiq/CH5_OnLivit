import Foundation

/// The three headline figures the dashboard shows per app, plus how many of
/// them are moving the wrong way.
///
/// Every figure is optional: retention in particular is not exposed for every
/// account, and an app whose ONGOING analytics request is under 48 hours old
/// has no report data at all. A missing figure renders as a dash rather than a
/// zero, because zero is a real value here and would read as a catastrophe.
nonisolated struct AppDashboardMetrics: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let appName: String

    var impressions: Double?
    /// Fraction, so 0.15 is +15%.
    var impressionsDelta: Double?

    /// Day 7 retention as 0...1.
    var retention: Double?
    /// Change in percentage points, so 6 is "+6pt".
    var retentionDeltaPoints: Double?

    var reviewAverage: Double?
    /// Change in stars, so -0.2 is "−0.2".
    var reviewDelta: Double?

    /// Set when every metric failed to load, so the card can say why.
    var errorMessage: String?

    // MARK: Attention

    /// Metrics that both loaded and are declining, named for the summary line.
    var decliningMetrics: [String] {
        var names: [String] = []
        if let impressionsDelta, impressionsDelta < 0 { names.append("impressions") }
        if let retentionDeltaPoints, retentionDeltaPoints < 0 { names.append("retention") }
        if let reviewDelta, reviewDelta < 0 { names.append("reviews") }
        return names
    }

    /// Metrics with a usable direction. Ranking only counts what actually loaded,
    /// so an app missing two reports can't look healthier than one that loaded.
    var comparableCount: Int {
        [impressionsDelta != nil, retentionDeltaPoints != nil, reviewDelta != nil]
            .filter { $0 }.count
    }

    var hasAnyValue: Bool {
        impressions != nil || retention != nil || reviewAverage != nil
    }

    /// How badly this app is doing, for picking the one that needs attention.
    /// Declining metric count dominates; severity breaks ties. Normalised so
    /// the three metrics, which are on very different scales, contribute
    /// comparably.
    var attentionScore: Double {
        guard comparableCount > 0 else { return 0 }
        var score = Double(decliningMetrics.count) * 10
        if let impressionsDelta, impressionsDelta < 0 { score += min(-impressionsDelta, 1) }
        if let retentionDeltaPoints, retentionDeltaPoints < 0 { score += min(-retentionDeltaPoints / 20, 1) }
        if let reviewDelta, reviewDelta < 0 { score += min(-reviewDelta / 2, 1) }
        return score
    }

    var isDeclining: Bool { !decliningMetrics.isEmpty }

    /// Higher is healthier. Only used to choose a subject when nothing is
    /// declining, so the section always points at an app.
    var standingScore: Double {
        var total = 0.0
        var counted = 0
        if let retention { total += retention; counted += 1 }
        if let reviewAverage { total += reviewAverage / 5; counted += 1 }
        return counted > 0 ? total / Double(counted) : 0
    }

    /// "3 of 3 metrics need attention this week. Impressions, retention, and reviews are down."
    var attentionSummary: String {
        let declining = decliningMetrics
        guard !declining.isEmpty else {
            guard comparableCount > 0 else {
                return "No week-on-week comparison yet, so there is nothing to flag."
            }
            let noun = comparableCount == 1 ? "metric is" : "metrics are"
            return "All \(comparableCount) \(noun) steady or improving this week."
        }
        let list: String
        switch declining.count {
        case 1: list = declining[0].capitalizedFirst
        case 2: list = "\(declining[0].capitalizedFirst) and \(declining[1])"
        default:
            list = declining.dropLast().map(\.self).joined(separator: ", ").capitalizedFirst
                + ", and \(declining[declining.count - 1])"
        }
        let verb = declining.count == 1 ? "is" : "are"
        return "\(declining.count) of \(comparableCount) metrics need attention this week. \(list) \(verb) down."
    }
}

nonisolated extension String {
    fileprivate var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

nonisolated extension Array where Element == AppDashboardMetrics {
    /// The app most worth looking at. Falls back to the weakest performer when
    /// nothing is declining, so the section always names an app rather than
    /// collapsing to an empty slot.
    var needingMostAttention: AppDashboardMetrics? {
        let withData = filter(\.hasAnyValue)
        guard !withData.isEmpty else { return nil }
        if let worst = withData.filter(\.isDeclining).max(by: { $0.attentionScore < $1.attentionScore }) {
            return worst
        }
        return withData.min { $0.standingScore < $1.standingScore }
    }
}
