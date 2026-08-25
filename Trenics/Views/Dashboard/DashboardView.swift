//
//  DashboardView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI
internal import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var apps: [AppItemModel] = []
    @Published var isLoadingApps = false
    @Published var appsErrorMessage: String?
    @Published var searchText: String = ""

    /// Keyed by app id. Fills in progressively as each app's figures land.
    @Published private(set) var metricsByApp: [String: AppDashboardMetrics] = [:]
    @Published private(set) var isLoadingMetrics = false

    /// Two at a time: each app costs a full analytics pipeline walk, and a
    /// large account would otherwise open a dozen simultaneous downloads.
    private let concurrentMetricLoads = 2
    private var metricsTask: Task<Void, Never>?

    var filteredApps: [AppItemModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    /// Ranked across whatever has loaded so far, so the card can appear before
    /// every app has finished.
    var appNeedingAttention: AppDashboardMetrics? {
        Array(metricsByApp.values).needingMostAttention
    }

    var loadedMetricsCount: Int { metricsByApp.count }

    func metrics(for app: AppItemModel) -> AppDashboardMetrics? {
        metricsByApp[app.id]
    }

    func loadApps(using store: AccountsStore) async {
        metricsTask?.cancel()
        guard let account = store.selectedAccount else {
            apps = []
            metricsByApp = [:]
            appsErrorMessage = nil
            return
        }
        isLoadingApps = true
        appsErrorMessage = nil
        defer { isLoadingApps = false }
        do {
            let fetched = try await store.makeClient(for: account).fetchAllApps()
            apps = fetched.map(AppItemModel.init(app:))
            metricsByApp = [:]
            startLoadingMetrics(for: fetched, account: account)
        } catch {
            appsErrorMessage = error.localizedDescription
            apps = []
            metricsByApp = [:]
        }
    }

    func refresh(using store: AccountsStore) async {
        await loadApps(using: store)
    }

    /// Runs in the background so the app list renders immediately; each card
    /// fills in as its own figures arrive.
    private func startLoadingMetrics(for apps: [AppResource], account: APIAccount) {
        guard !apps.isEmpty else { return }
        isLoadingMetrics = true
        metricsTask = Task { [concurrentMetricLoads] in
            for chunk in apps.chunked(into: concurrentMetricLoads) {
                if Task.isCancelled { break }
                await withTaskGroup(of: AppDashboardMetrics.self) { group in
                    for app in chunk {
                        group.addTask {
                            await DashboardMetricsLoader.load(app: app, account: account)
                        }
                    }
                    for await result in group {
                        if Task.isCancelled { break }
                        metricsByApp[result.id] = result
                    }
                }
            }
            isLoadingMetrics = false
        }
    }
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject var accountsStore: AccountsStore

    var body: some View {
        NavigationStack {
            MainLayout {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        HeaderView(
                            userName: accountsStore.selectedAccount?.label ?? "No Account",
                            initials: String(accountsStore.selectedAccount?.label.prefix(2) ?? "?"),
                            accountsStore: accountsStore
                        )

                        DashboardSearchBar(text: $viewModel.searchText)

                        attentionSection

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Apps")
                                .font(.title2.bold())
                            if !viewModel.apps.isEmpty {
                                Text(viewModel.isLoadingMetrics
                                     ? "Loading metrics \(viewModel.loadedMetricsCount) of \(viewModel.apps.count)"
                                     : "Updated just now")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        appList
                    }
                    .padding(24)
                }
            }
            .task(id: accountsStore.selectedAccountId) {
                await viewModel.loadApps(using: accountsStore)
            }
            .refreshable {
                await viewModel.refresh(using: accountsStore)
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var attentionSection: some View {
        if accountsStore.selectedAccount == nil || !viewModel.appsErrorMessage.isNilOrEmpty {
            EmptyView()
        } else if let attention = viewModel.appNeedingAttention {
            NavigationLink {
                destination(forAppId: attention.id)
            } label: {
                NeedsAttentionCard(
                    metrics: attention,
                    account: accountsStore.selectedAccount,
                    // The flagged app's own glyph, so the card never names one
                    // app while picturing another.
                    iconName: viewModel.apps.first { $0.id == attention.id }?.iconName
                        ?? "circle.hexagongrid.fill"
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else if viewModel.isLoadingMetrics || (!viewModel.apps.isEmpty && viewModel.metricsByApp.isEmpty) {
            NeedsAttentionPlaceholder(message: "Checking which app needs your attention…", isLoading: true)
        }
    }

    @ViewBuilder
    private var appList: some View {
        if let errorMessage = viewModel.appsErrorMessage {
            ErrorStateView(message: errorMessage) {
                Task { await viewModel.refresh(using: accountsStore) }
            }
        } else if accountsStore.selectedAccount == nil {
            DashboardEmptyState(
                systemImage: "person.crop.circle.badge.plus",
                title: "No account yet",
                message: "Add an App Store Connect account from your profile to see your apps here."
            )
        } else if viewModel.isLoadingApps && viewModel.apps.isEmpty {
            DataLoadingView(symbol: "square.stack.3d.up.fill", text: "Loading your apps…")
        } else if viewModel.apps.isEmpty {
            DashboardEmptyState(
                systemImage: "square.stack.3d.up.slash",
                title: "No apps found",
                message: "This account has no apps in App Store Connect."
            )
        } else if viewModel.filteredApps.isEmpty {
            DashboardEmptyState(
                systemImage: "magnifyingglass",
                title: "No matches",
                message: "No app matches “\(viewModel.searchText)”."
            )
        } else {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredApps) { app in
                    NavigationLink {
                        AppRowDestination(app: app, account: accountsStore.selectedAccount)
                    } label: {
                        AppMetricCard(
                            app: app,
                            metrics: viewModel.metrics(for: app),
                            isLoading: viewModel.isLoadingMetrics && viewModel.metrics(for: app) == nil,
                            account: accountsStore.selectedAccount
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func destination(forAppId id: String) -> some View {
        if let app = viewModel.apps.first(where: { $0.id == id }) {
            AppRowDestination(app: app, account: accountsStore.selectedAccount)
        } else {
            EmptyView()
        }
    }
}

// MARK: - States

struct DashboardEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't load your apps")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Color("primaryPurple"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}
