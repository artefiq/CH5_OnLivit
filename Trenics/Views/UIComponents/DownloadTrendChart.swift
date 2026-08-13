//
//  DownloadTrendChart.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 13/08/26.
//

import SwiftUI
import Charts

struct DownloadTrendChart: View {

    private let data: [ChartData] = [
        .init(day: 0, value: 46),
        .init(day: 1, value: 40),
        .init(day: 2, value: 87),
        .init(day: 3, value: 100),
        .init(day: 4, value: 59)
    ]

    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("Day", item.day),
                y: .value("Downloads", item.value)
            )
            .interpolationMethod(.linear)
            .lineStyle(
                StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .foregroundStyle(Color("primaryPurple"))

            PointMark(
                x: .value("Day", item.day),
                y: .value("Downloads", item.value)
            )
            .symbol {
                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle()
                            .stroke(Color("primaryPurple"), lineWidth: 3)
                    }
                    .frame(width: 12, height: 12)
            }
        }
        .chartXScale(domain: 0...4)
        .chartYScale(domain: 0...100)

        // X Axis
        .chartXAxis {
            AxisMarks(values: [0, 1, 2, 3, 4]) {
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.35))

                AxisTick()

                AxisValueLabel()
                    .font(.system(size: 12))
            }
        }

        // Y Axis
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) {
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.35))

                AxisTick()

                AxisValueLabel()
                    .font(.system(size: 12))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
        .frame(height: 156)
        .padding(.horizontal, 16)
    }
}

// MARK: - Model

private struct ChartData: Identifiable {
    let id = UUID()
    let day: Int
    let value: Double
}

#Preview {
    DownloadTrendChart()
        .padding()
}
