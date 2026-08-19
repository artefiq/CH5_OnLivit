import SwiftUI

struct AppsListView: View {
    @ObservedObject var accountsStore: AccountsStore
    @State private var apps: [AppResource] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Your Apps").font(.title2.bold())
                Spacer()
                Button(isLoading ? "Loading..." : "Refresh") { Task { await loadApps() } }
                    .disabled(isLoading || accountsStore.selectedAccount == nil)
            }
            .padding([.horizontal, .top])

            if accountsStore.accounts.isEmpty {
                Text("No accounts yet. Add one from the Accounts tab first.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Picker("Account", selection: $accountsStore.selectedAccountId) 
                    ForEach(accountsStore.accounts) { account in
                        Text(account.label).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding(.horizontal)
            }

            if apps.isEmpty && !isLoading && errorMessage == nil && accountsStore.selectedAccount != nil {
                Text("No apps found yet — tap Refresh.")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            List(apps) { app in
                if let account = accountsStore.selectedAccount {
                    NavigationLink {
                        AppDetailView(app: app, account: account)
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
        }
        // Re-fetches whenever the selected account changes, including the first time one exists.
        .task(id: accountsStore.selectedAccountId) {
            apps = []
            errorMessage = nil
            if accountsStore.selectedAccount != nil {
                await loadApps()
            }
        }
    }

    private func loadApps() async {
        guard let account = accountsStore.selectedAccount else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            apps = try await accountsStore.makeClient(for: account).fetchAllApps()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
