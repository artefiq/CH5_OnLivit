import SwiftUI

/// Where an app row goes when tapped, shared by the dashboard's "Your Apps"
/// list and the full "All Apps" list so both behave identically.
///
/// Apps fetched from App Store Connect open the three analytics pages for that
/// specific app. Sample rows — previews, and anything constructed without an
/// `AppResource` — fall back to the static metrics screen, since there's no
/// real app behind them to query.
struct AppRowDestination: View {
    let app: AppItemModel
    let account: APIAccount?

    var body: some View {
        if let resource = app.resource, let account {
            AnalyticsRootView(app: resource, account: account)
        } else {
            AppMetricsView(app: app)
        }
    }
}
