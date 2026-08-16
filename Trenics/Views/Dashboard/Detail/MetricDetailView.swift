//
//  MetricDetailView.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//
//  Screen 3 — pushed when the user taps a metric card on the App Detail
//  screen (Rating, Downloads, or Rankings). Fully generic over `MetricKind`
//  so the same screen renders all three components; only the accent color,
//  copy, and numbers change.
//

import SwiftUI

struct MetricDetailView: View {
    let kind: MetricKind

    @State private var selectedRange: MetricRange

    init(kind: MetricKind, initialRange: MetricRange = .fourWeeks) {
        self.kind = kind
        self._selectedRange = State(initialValue: initialRange)
    }

    private var series: MetricSeries {
        MetricDataStore.series(for: kind, range: selectedRange, appName: "")
    }

    var body: some View {
        MainLayout {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    heroCard

                    insightCard

                    RangePillControl(selected: $selectedRange)

                    chartCard
                }
                .padding(24)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.rawValue)
                .font(.headline)
                .foregroundColor(.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(series.heroCurrentValue)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)

                Text(series.deltaText)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.25)))
            }

            Text(series.heroPeriodLabel)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(kind.accentColor.gradient)
        )
        .shadow(color: kind.accentColor.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    // MARK: - Insight

    private var insightCard: some View {
        Text(series.insightText)
            .font(.subheadline)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("cardBGColor"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 3)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(kind.rawValue), last \(selectedRange.label)")
                    .font(.headline)
                Text(series.chartSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            MetricLineChartView(
                points: series.points,
                color: kind.accentColor,
                yAxisMax: series.yAxisMax,
                height: 180
            )

            Divider()

            HStack(alignment: .top, spacing: 16) {
                MetricStatColumn(
                    label: "vs previous \(selectedRange.label)",
                    value: series.vsPreviousText,
                    valueColor: series.isVsPreviousPositive ? .green : .red
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                MetricStatColumn(
                    label: "avg change",
                    value: series.avgChangeText,
                    valueColor: series.isAvgChangePositive ? .green : .red
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color("cardBGColor"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview("Rating") {
    NavigationStack {
        MetricDetailView(kind: .rating)
    }
}

#Preview("Downloads") {
    NavigationStack {
        MetricDetailView(kind: .downloads)
    }
}

#Preview("Rankings") {
    NavigationStack {
        MetricDetailView(kind: .rankings)
    }
}
