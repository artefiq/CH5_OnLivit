import SwiftUI

struct AppDetailView: View {
    let app: AppResource
    let account: APIAccount
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Ratings & Reviews").tag(0)
                Text("App Analytics").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                ReviewsView(app: app, account: account)
            } else {
                AnalyticsView(app: app, account: account)
            }
        }
        .navigationTitle(app.attributes.name)
    }
}
