import SwiftUI
internal import Combine

struct AnalyticsRootView: View {
    let app: AppResource
    let account: APIAccount
    @StateObject private var session: AnalyticsSession
    @State private var selection: AnalyticsPage = .impressions

    init(app: AppResource, account: APIAccount) {
        self.app = app
        self.account = account
        _session = StateObject(wrappedValue: AnalyticsSession(app: app, account: account))
    }

    enum AnalyticsPage: Hashable {
        case impressions, retention, reviews
    }

    var body: some View {
        Group {
            if account.isUsable {
                TabView(selection: $selection) {
                    ImpressionsPageView(session: session)
                        .tabItem { Label("Impressions", systemImage: "eye") }
                        .tag(AnalyticsPage.impressions)

                    RetentionPageView(session: session)
                        .tabItem { Label("Retention", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }
                        .tag(AnalyticsPage.retention)

                    ReviewsPageView(session: session)
                        .tabItem { Label("Reviews", systemImage: "star.bubble") }
                        .tag(AnalyticsPage.reviews)
                }
            } else {
                missingCredentials
            }
        }
        .navigationTitle(app.attributes.name)
        .navigationBarTitleDisplayMode(.inline)
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
}
