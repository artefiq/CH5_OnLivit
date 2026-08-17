//
//  DashboardView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI
internal import Combine

class DashboardViewModel: ObservableObject {
    @Published var userName: String = "Onlivit"
    @Published var userInitials: String = "ON"
    @Published var selectedAppName: String = ""

    @Published var metrics: [MetricModel] = [
        MetricModel(title: "Rating", value: "4.4", isPositive: true, description: "Your rating climbed to 4.4 from 4.1, people are liking what they see.", accentColor: Color("primaryPurple"), valueColor: .green),
        MetricModel(title: "Downloads", value: "-8%", isPositive: false, description: "Down compared to previous weeks, your efforts are worthwhile.", accentColor: .orange, valueColor: .red)
    ]

    /// Populated from the selected App Store Connect account rather than hardcoded.
    @Published var apps: [AppItemModel] = []
    @Published var isLoadingApps = false
    @Published var appsErrorMessage: String?

    func loadApps(using store: AccountsStore) async {
        guard let account = store.selectedAccount else {
            apps = []
            selectedAppName = ""
            appsErrorMessage = nil
            return
        }
        isLoadingApps = true
        appsErrorMessage = nil
        defer { isLoadingApps = false }
        do {
            let fetched = try await store.makeClient(for: account).fetchAllApps()
            apps = fetched.map(AppItemModel.init(app:))
            // Keep the dropdown pointing at something that still exists.
            if !apps.contains(where: { $0.name == selectedAppName }) {
                selectedAppName = apps.first?.name ?? ""
            }
        } catch {
            appsErrorMessage = error.localizedDescription
            apps = []
            selectedAppName = ""
        }
    }
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    // Reads the same Keychain/UserDefaults state as the other screens, so the
    // account picked on the Accounts screen is the one used here.
    @StateObject private var accountsStore = AccountsStore()
    @State private var isDropdownOpen: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                MainLayout {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            HeaderView(userName: viewModel.userName, initials: viewModel.userInitials)
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isDropdownOpen.toggle()
                                }
                            }) {
                                // Placeholder keeps the pill from collapsing to
                                // just its icon before any app has loaded.
                                AppDropdownView(
                                    selectedApp: viewModel.selectedAppName.isEmpty
                                        ? "Select an app"
                                        : viewModel.selectedAppName
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.metrics) { metric in
                                        MetricCardView(metric: metric)
                                    }
                                }
                                .padding(.vertical, 0)
                            }
                            .padding(.horizontal, -12)
                            .padding(.leading, 12)
                            
                            NavigationLink {
                                AllAppsListView(
                                    apps: viewModel.apps,
                                    account: accountsStore.selectedAccount
                                )
                            } label: {
                                SectionHeaderView(title: "Your Apps")
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            VStack(spacing: 16) {
                                ForEach(viewModel.apps) { app in
                                    NavigationLink {
                                        AppRowDestination(
                                            app: app,
                                            account: accountsStore.selectedAccount
                                        )
                                    } label: {
                                        AppListRowView(app: app)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                if viewModel.isLoadingApps && viewModel.apps.isEmpty {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 24)
                                } else if let appsErrorMessage = viewModel.appsErrorMessage {
                                    Text(appsErrorMessage)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else if viewModel.apps.isEmpty {
                                    Text(accountsStore.selectedAccount == nil
                                         ? "No account selected yet. Add one from your profile to see your apps here."
                                         : "No apps found for this account.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Text("This list updates automatically from your connected account. Tap the arrow to open full detail.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .padding(24)
                    }
                }
                .blur(radius: isDropdownOpen ? 3 : 0)
                
                if isDropdownOpen {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDropdownOpen = false
                            }
                        }
                    
                    CustomDropdownPopupView(
                        apps: viewModel.apps,
                        selectedAppName: $viewModel.selectedAppName,
                        isShowing: $isDropdownOpen
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(1)
                    .offset(y: -50)
                }
            }
            // Re-fetches when the selected account changes, including the first
            // time one exists.
            .task(id: accountsStore.selectedAccountId) {
                await viewModel.loadApps(using: accountsStore)
            }
            .refreshable {
                await viewModel.loadApps(using: accountsStore)
            }
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .previewDisplayName("Dashboard")
        
        NavigationStack {
            AllAppsListView(apps: [
                AppItemModel(name: "Freeform", description: "A mobile game app...", iconName: "waveform.circle.fill"),
                AppItemModel(name: "Pages", description: "A word processor app...", iconName: "doc.circle.fill"),
                AppItemModel(name: "Keynote", description: "A presentation app...", iconName: "play.rectangle.fill"),
                AppItemModel(name: "Numbers", description: "A spreadsheet app...", iconName: "tablecells.fill")
            ])
        }
        .previewDisplayName("All Apps List")
    }
}
