//
//  MetricLineChartView.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI
import Charts

/// Reusable weekly line chart used on both the App Detail mini-cards and the
/// Metric Detail screen — light grid, rounded line, small dot markers.
struct MetricLineChartView: View {
    let points: [MetricChartPoint]
    let color: Color
    let yAxisMax: Double
    var height: CGFloat = 170

    private var yStride: Double {
        max(yAxisMax / 4, 1)
    }

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Week", point.week),
                y: .value("Value", point.value)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .foregroundStyle(color)

            PointMark(
                x: .value("Week", point.week),
                y: .value("Value", point.value)
            )
            .symbolSize(30)
            .foregroundStyle(color)
        }
        .chartYScale(domain: 0...yAxisMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: yStride)) { _ in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.18))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map(\.week)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.12))
                AxisValueLabel {
                    if let week = value.as(Int.self) {
                        Text("\(week)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: height)
    }
}

#Preview {
    MetricLineChartView(
        points: [1.9, 1.8, 3.6, 3.7, 2.9].enumerated().map { MetricChartPoint(week: $0.offset, value: $0.element) },
        color: Color("primaryPurple"),
        yAxisMax: 4
    )
    .padding()
}
