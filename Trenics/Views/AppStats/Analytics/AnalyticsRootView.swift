import SwiftUI
internal import Combine

/// Entry point for an app's analytics, replacing the old single `AnalyticsView`.
///
/// The three tabs follow the user lifecycle rather than the shape of Apple's
/// API: Impressions (first contact), Retention (inside the app), Reviews (after
/// using it). Downloads live inside Impressions because they're the same
/// funnel; deletions live inside Retention because churn is retention inverted.
///
/// All three share one `AnalyticsSession`, so the per-app handshake with App
/// Store Connect happens once no matter how often the user switches tabs.
struct AnalyticsRootView: View {
    let app: AppResource
    @ObservedObject var credentials: CredentialsStore
    @StateObject private var session: AnalyticsSession
    @State private var selection: AnalyticsPage = .impressions

    init(app: AppResource, credentials: CredentialsStore) {
        self.app = app
        self.credentials = credentials
        _session = StateObject(wrappedValue: AnalyticsSession(app: app, credentials: credentials))
    }

    enum AnalyticsPage: Hashable {
        case impressions, retention, reviews
    }

    var body: some View {
        Group {
            if credentials.isComplete {
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
        // A credential change invalidates the cached handshake and client.
        .onChange(of: credentials.keyId) { _, _ in session.reset() }
        .onChange(of: credentials.issuerId) { _, _ in session.reset() }
    }

    private var missingCredentials: some View {
        VStack(spacing: 16) {
            AnalyticsEmptyState(
                systemImage: "key.horizontal",
                title: "API key needed",
                message: "Add your App Store Connect issuer ID, key ID and .p8 private key to load analytics for this app."
            )
            NavigationLink("Open Credentials") {
                CredentialsView(credentials: credentials)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("baseBGColor").ignoresSafeArea())
    }
}
