//
//  AppMetricsView.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//
//  Screen 2 — pushed when the user taps an app in "Your Apps" (Dashboard)
//  or in the full "All Apps" list. Shows the app identity header, then a
//  "Key Metrics" tab with tappable Rating / Downloads / Rankings cards
//  (each of which pushes Screen 3, MetricDetailView) and a "Review" tab
//  with recent reviews.
//

import SwiftUI

struct AppMetricsView: View {
    let app: AppItemModel

    @State private var selectedTab: AppDetailTab = .keyMetrics
    @State private var selectedRange: MetricRange = .fourWeeks

    private var allSeries: [MetricSeries] {
        MetricKind.allCases.map { kind in
            MetricDataStore.series(for: kind, range: selectedRange, appName: app.name)
        }
    }

    var body: some View {
        MainLayout {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    header

                    AppDetailTabControl(selected: $selectedTab)

                    switch selectedTab {
                    case .keyMetrics:
                        keyMetricsSection
                    case .review:
                        reviewSection
                    }
                }
                .padding(24)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            AppIconBadgeView(iconName: app.iconName, size: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.title2.bold())
                Text("Updated just now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Key Metrics tab

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Key metrics")
                    .font(.title3.bold())
                Spacer()
                RangePillControl(selected: $selectedRange)
            }

            VStack(spacing: 16) {
                ForEach(allSeries, id: \.kind) { series in
                    MetricChartCardView(series: series)
                }
            }
        }
    }

    // MARK: - Review tab

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent reviews")
                .font(.title3.bold())

            VStack(spacing: 12) {
                ForEach(ReviewMockData.reviews) { review in
                    ReviewRowView(review: review)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppMetricsView(app: AppItemModel(name: "Freeform", description: "A mobile game app that lets users feel the real experience and mechanics of...", iconName: "waveform.circle.fill"))
    }
}
