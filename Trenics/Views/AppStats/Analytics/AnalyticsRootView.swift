import SwiftUI
internal import Combine

/// The screen behind an app card: what each metric means, and a way into each
/// of the three detail pages.
///
/// Replaces the tab bar that used to sit under these pages. The three pages are
/// now pushed individually, so each owns its own title and back button and the
/// detail screens are free of chrome that repeated on every one of them.
struct AnalyticsRootView: View {
    let app: AppResource
    let account: APIAccount
    @StateObject private var session: AnalyticsSession
    @State private var lastUpdated: Date?

    init(app: AppResource, account: APIAccount) {
        self.app = app
        self.account = account
        _session = StateObject(wrappedValue: AnalyticsSession(app: app, account: account))
    }

    var body: some View {
        Group {
            if account.isUsable {
                hub
            } else {
                missingCredentials
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFreshness() }
    }

    private var hub: some View {
        MainLayout {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    AppDetailHeader(app: app, account: account, lastUpdated: lastUpdated)
                        .padding(.bottom, 4)

                    NavigationLink {
                        ImpressionsPageView(session: session)
                    } label: {
                        MetricNavCard(
                            title: "Impressions",
                            description: "How many people saw and downloaded your app."
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink {
                        RetentionPageView(session: session)
                    } label: {
                        MetricNavCard(
                            title: "Retention",
                            description: "The % of users still using your app days after installing."
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink {
                        ReviewsPageView(session: session)
                    } label: {
                        MetricNavCard(
                            title: "Reviews",
                            description: "Your star rating and what people say about your app."
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(20)
            }
        }
    }

    private var missingCredentials: some View {
        MainLayout {
            AnalyticsEmptyState(
                systemImage: "key.horizontal",
                title: "API key needed",
                message: "The account \"\(account.label)\" is missing an issuer ID, key ID or .p8 private key. Add them from the Accounts screen to load analytics."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Reads when the dashboard last pulled this app's figures, so the header
    /// reports real freshness without fetching anything itself.
    private func loadFreshness() async {
        let cached = await AnalyticsCacheStore.shared.load(
            AppDashboardMetrics.self,
            key: "\(app.id)-dashboard-metrics"
        )
        lastUpdated = cached?.fetchedAt
    }
}
