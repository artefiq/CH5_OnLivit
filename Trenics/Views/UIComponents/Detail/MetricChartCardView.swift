//
//  MetricChartCardView.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI

/// One metric card in the "Key Metrics" tab (Rating, Downloads, Rankings).
/// Tapping anywhere on the card pushes the full Metric Detail screen for
/// that metric, carrying over the currently selected time range.
struct MetricChartCardView: View {
    let series: MetricSeries

    var body: some View {
        NavigationLink {
            MetricDetailView(kind: series.kind, initialRange: series.range)
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(series.kind.accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Text(series.kind.rawValue)
                        .font(.headline)
                        .foregroundColor(series.kind.accentColor)

                    Spacer()

                    Text(series.deltaText)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(series.isDeltaPositive ? .green : .red)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.gray.opacity(0.55))
                }

                MetricLineChartView(
                    points: series.points,
                    color: series.kind.accentColor,
                    yAxisMax: series.yAxisMax,
                    height: 150
                )

                Divider()

                HStack {
                    MetricStatColumn(label: "Current", value: series.cardCurrentValue)
                    Spacer()
                    MetricStatColumn(
                        label: "vs previous \(series.range.label)",
                        value: series.vsPreviousText,
                        valueColor: series.isVsPreviousPositive ? .green : .red
                    )
                    Spacer()
                    MetricStatColumn(
                        label: "avg change",
                        value: series.avgChangeText,
                        valueColor: series.isAvgChangePositive ? .green : .red
                    )
                }
            }
            .padding(16)
        }
        .background(Color("cardBGColor"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                MetricChartCardView(series: MetricDataStore.series(for: .rating, range: .fourWeeks, appName: "Freeform"))
                MetricChartCardView(series: MetricDataStore.series(for: .downloads, range: .fourWeeks, appName: "Freeform"))
            }
            .padding()
        }
    }
}
