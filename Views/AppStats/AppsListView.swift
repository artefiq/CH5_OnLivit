import SwiftUI

struct AppsListView: View {
    @ObservedObject var credentials: CredentialsStore
    @State private var apps: [AppResource] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Your Apps").font(.title2.bold())
                Spacer()
                Button(isLoading ? "Loading..." : "Refresh") { Task { await loadApps() } }
                    .disabled(isLoading || !credentials.isComplete)
            }
            .padding([.horizontal, .top])

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding(.horizontal)
            }

            if apps.isEmpty && !isLoading && errorMessage == nil {
                Text("No apps found yet — tap Refresh.")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            List(apps) { app in
                NavigationLink {
                    AppDetailView(app: app, credentials: credentials)
                } label: {
                    VStack(alignment: .leading) {
                        Text(app.attributes.name).font(.headline)
                        if let bundleId = app.attributes.bundleId {
                            Text(bundleId).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task { if apps.isEmpty { await loadApps() } }
    }

    private func loadApps() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            apps = try await credentials.makeClient().fetchAllApps()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
