import SwiftUI

/// Reviews used to sit here as a sibling tab alongside analytics. They now live
/// inside `AnalyticsRootView` as the third lifecycle page, so this is just the
/// navigation entry point.
struct AppDetailView: View {
    let app: AppResource
    let account: APIAccount

    var body: some View {
        AnalyticsRootView(app: app, account: account)
    }
}
