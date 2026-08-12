//
//  AppMetricDetailModel.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//
//  Data layer that powers the "App Detail" screen (Key Metrics + Review tabs)
//  and the "Metric Detail" screen (Rating / Downloads / Rankings drill-down).
//
//  Everything here is PLACEHOLDER data so the UI can be reviewed end to end.
//  Swap `MetricDataStore.series(for:range:appName:)` for a real fetch once the
//  App Store Connect analytics + ratings pipeline is wired up — the shape of
//  `MetricSeries` is intentionally the only thing the views depend on.
//

import SwiftUI

// MARK: - Time range (4W / 8W / 12W)

enum MetricRange: String, CaseIterable, Identifiable, Hashable {
    case fourWeeks = "4W"
    case eightWeeks = "8W"
    case twelveWeeks = "12W"

    var id: String { rawValue }
    var label: String { rawValue }

    /// Number of weekly points plotted (week 0 ... N).
    var pointCount: Int {
        switch self {
        case .fourWeeks: return 5
        case .eightWeeks: return 9
        case .twelveWeeks: return 13
        }
    }

    /// Number of weeks spanned by the range (used in copy, e.g. "last 4 weeks").
    var weekSpan: Int { pointCount - 1 }
}

// MARK: - Metric kind (Rating / Downloads / Rankings)

enum MetricKind: String, CaseIterable, Identifiable, Hashable {
    case rating = "Rating"
    case downloads = "Downloads"
    case rankings = "Rankings"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .rating: return Color("primaryPurple")
        case .downloads: return .orange
        case .rankings: return .blue
        }
    }

    var systemImage: String {
        switch self {
        case .rating: return "star.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .rankings: return "chart.bar.fill"
        }
    }
}

// MARK: - Chart point

struct MetricChartPoint: Identifiable, Hashable {
    let id = UUID()
    let week: Int
    let value: Double
}

// MARK: - Series (one metric, one range) — everything a screen needs to render

struct MetricSeries {
    let kind: MetricKind
    let range: MetricRange

    let points: [MetricChartPoint]
    let yAxisMax: Double

    /// Value shown in the "Key Metrics" mini card on the App Detail screen.
    let cardCurrentValue: String
    /// Value shown in the big hero on the Metric Detail screen.
    let heroCurrentValue: String

    /// Small badge next to the title, e.g. "-0.1", "-67", "+9".
    let deltaText: String
    let isDeltaPositive: Bool

    let vsPreviousText: String
    let isVsPreviousPositive: Bool

    let avgChangeText: String
    let isAvgChangePositive: Bool

    let heroPeriodLabel: String
    let chartSubtitle: String
    let insightText: String
}

// MARK: - Mock data provider

enum MetricDataStore {

    static func series(for kind: MetricKind, range: MetricRange, appName: String) -> MetricSeries {
        switch kind {
        case .rating: return ratingSeries(for: range)
        case .downloads: return downloadsSeries(for: range)
        case .rankings: return rankingsSeries(for: range)
        }
    }

    // MARK: Rating

    private static func ratingSeries(for range: MetricRange) -> MetricSeries {
        let points = buildPoints(range: range, recentTail: [1.9, 1.8, 3.6, 3.7, 2.9], base: 2.6, amplitude: 1.0, clamp: 0...4)

        switch range {
        case .fourWeeks:
            return MetricSeries(
                kind: .rating, range: range, points: points, yAxisMax: 4,
                cardCurrentValue: "4.4", heroCurrentValue: "4.1",
                deltaText: "-0.1", isDeltaPositive: false,
                vsPreviousText: "-1%", isVsPreviousPositive: false,
                avgChangeText: "-0.03/week", isAvgChangePositive: false,
                heroPeriodLabel: "Over the last 4W",
                chartSubtitle: "Each point is a weekly total",
                insightText: "Slipped from 4.4 to 4.1 over the last 4 weeks. The timing lines up with your last update, recent reviews increasingly mention crashes."
            )
        case .eightWeeks:
            return MetricSeries(
                kind: .rating, range: range, points: points, yAxisMax: 4,
                cardCurrentValue: "4.4", heroCurrentValue: "4.2",
                deltaText: "-0.2", isDeltaPositive: false,
                vsPreviousText: "-3%", isVsPreviousPositive: false,
                avgChangeText: "-0.02/week", isAvgChangePositive: false,
                heroPeriodLabel: "Over the last 8W",
                chartSubtitle: "Each point is a weekly total",
                insightText: "Down from 4.4 to 4.2 over the last 8 weeks — a slower slide than the last month alone. Worth watching the newest reviews for recurring themes."
            )
        case .twelveWeeks:
            return MetricSeries(
                kind: .rating, range: range, points: points, yAxisMax: 4,
                cardCurrentValue: "4.4", heroCurrentValue: "4.3",
                deltaText: "-0.1", isDeltaPositive: false,
                vsPreviousText: "-2%", isVsPreviousPositive: false,
                avgChangeText: "-0.01/week", isAvgChangePositive: false,
                heroPeriodLabel: "Over the last 12W",
                chartSubtitle: "Each point is a weekly total",
                insightText: "Fairly stable across the last 12 weeks, hovering around 4.3–4.4 with only a mild dip recently."
            )
        }
    }

    // MARK: Downloads

    private static func downloadsSeries(for range: MetricRange) -> MetricSeries {
        let points = buildPoints(range: range, recentTail: [190, 150, 350, 380, 200], base: 220, amplitude: 90, clamp: 0...400)

        switch range {
        case .fourWeeks:
            return MetricSeries(
                kind: .downloads, range: range, points: points, yAxisMax: 400,
                cardCurrentValue: "1,024", heroCurrentValue: "958",
                deltaText: "-67", isDeltaPositive: false,
                vsPreviousText: "-8%", isVsPreviousPositive: false,
                avgChangeText: "-17/week", isAvgChangePositive: false,
                heroPeriodLabel: "Over the last 4W",
                chartSubtitle: "Each point is a weekly total",
                insightText: "Downloads dropped 8% over the last 4 weeks. This tracks with fewer featured placements and a dip in search visibility."
            )
        case .eightWeeks:
            return MetricSeries(
                kind: .downloads, range: range, points: points, yAxisMax: 400,
                cardCurrentValue: "1,024", heroCurrentValue: "1,090",
                deltaText: "+132", isDeltaPositive: true,
                vsPreviousText: "+6%", isVsPreviousPositive: true,
                avgChangeText: "+16/week", isAvgChangePositive: true,
                heroPeriodLabel: "Over the last 8W",
                chartSubtitle: "Each point is a weekly total",
                insightText: "Downloads are up 6% over the last 8 weeks, driven mostly by a strong stretch mid-period before the recent pullback."
            )
        case .twelveWeeks:
            return MetricSeries(
                kind: .downloads, range: range, points: points, yAxisMax: 400,
                cardCurrentValue: "1,024", heroCurrentValue: "1,150",
                deltaText: "+205", isDeltaPositive: true,
                vsPreviousText: "+11%", isVsPreviousPositive: true,
                avgChangeText: "+17/week", isAvgChangePositive: true,
                heroPeriodLabel: "Over the last 12W",
                chartSubtitle: "Each point is a weekly total",
                insightText: "Steady growth across the last 12 weeks despite the recent 4-week dip — the longer trend is still pointed up."
            )
        }
    }

    // MARK: Rankings (category ranking — lower number is better)

    private static func rankingsSeries(for range: MetricRange) -> MetricSeries {
        let points = buildPoints(range: range, recentTail: [142, 138, 126, 119, 128], base: 128, amplitude: 20, clamp: 1...220)

        switch range {
        case .fourWeeks:
            return MetricSeries(
                kind: .rankings, range: range, points: points, yAxisMax: 200,
                cardCurrentValue: "#128", heroCurrentValue: "#128",
                deltaText: "+9", isDeltaPositive: false,
                vsPreviousText: "+8%", isVsPreviousPositive: false,
                avgChangeText: "+2 spots/week", isAvgChangePositive: false,
                heroPeriodLabel: "Over the last 4W",
                chartSubtitle: "Each point is a weekly category rank",
                insightText: "Category rank slipped from #119 to #128 over the last 4 weeks after a strong mid-period push. Still comfortably better than 8 weeks ago."
            )
        case .eightWeeks:
            return MetricSeries(
                kind: .rankings, range: range, points: points, yAxisMax: 200,
                cardCurrentValue: "#128", heroCurrentValue: "#128",
                deltaText: "-11", isDeltaPositive: true,
                vsPreviousText: "-8%", isVsPreviousPositive: true,
                avgChangeText: "-1 spot/week", isAvgChangePositive: true,
                heroPeriodLabel: "Over the last 8W",
                chartSubtitle: "Each point is a weekly category rank",
                insightText: "Climbed 11 spots over the last 8 weeks. The mid-period surge in downloads pushed you into a stronger category position before easing off recently."
            )
        case .twelveWeeks:
            return MetricSeries(
                kind: .rankings, range: range, points: points, yAxisMax: 200,
                cardCurrentValue: "#128", heroCurrentValue: "#128",
                deltaText: "-20", isDeltaPositive: true,
                vsPreviousText: "-14%", isVsPreviousPositive: true,
                avgChangeText: "-2 spots/week", isAvgChangePositive: true,
                heroPeriodLabel: "Over the last 12W",
                chartSubtitle: "Each point is a weekly category rank",
                insightText: "Solid overall improvement across the last 12 weeks — down from roughly #150 to #128, even with some give-back in the most recent stretch."
            )
        }
    }

    // MARK: - Helpers

    /// Builds a full point series for a range. The most recent points always
    /// equal `recentTail` (so the last week matches the reference design
    /// exactly); earlier weeks are filled in with a gentle deterministic wave
    /// so 8W/12W look continuous with 4W instead of just being cut off.
    private static func buildPoints(
        range: MetricRange,
        recentTail: [Double],
        base: Double,
        amplitude: Double,
        clamp: ClosedRange<Double>
    ) -> [MetricChartPoint] {
        let count = range.pointCount
        var values: [Double]

        if count <= recentTail.count {
            values = Array(recentTail.suffix(count))
        } else {
            let historicalCount = count - recentTail.count
            let historical = (0..<historicalCount).map { i -> Double in
                let radians = Double(i) * 0.55
                let raw = base + amplitude * sin(radians + 0.6)
                return min(max(raw, clamp.lowerBound), clamp.upperBound)
            }
            values = historical + recentTail
        }

        return values.enumerated().map { MetricChartPoint(week: $0.offset, value: $0.element) }
    }
}
