//
//  ProfileView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 13/08/26.
//

import SwiftUI
internal import Combine

// MARK: - VIEW MODEL
class ProfileViewModel: ObservableObject {
    @Published var userName: String = "Onlivit"
    @Published var userInitials: String = "ON"
    @Published var totalApps: Int = 3
    
    @Published var accounts: [AccountModel] = []
    @Published var selectedAccountID: UUID?
    
    @Published var isDarkMode: Bool = false
    
    init() {
        loadDummyData()
    }
    
    private func loadDummyData() {
        let account1 = AccountModel(initials: "ON", name: "Onlivit", appCount: 3, syncStatus: "Synced just now", avatarColor: Color("primaryPurple"))
        let account2 = AccountModel(initials: "AL", name: "Aline", appCount: 10, syncStatus: "Synced 2 days ago", avatarColor: Color("primaryPurple"))
        let account3 = AccountModel(initials: "AD", name: "Adi", appCount: 9, syncStatus: "Synced 5 days ago", avatarColor: Color("primaryPurple"))
        
        self.accounts = [account1, account2, account3]
        self.selectedAccountID = account1.id
    }
    
    func selectAccount(id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedAccountID = id
        }
    }
}

// MARK: - MAIN VIEW
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @ObservedObject var accountsStore: AccountsStore

    /// Name of the account just switched to, shown briefly then cleared.
    @State private var switchedToName: String?
    @State private var accountToEdit: APIAccount?
    @State private var accountToDelete: APIAccount?
    @State private var isConfirmingLogOut = false
    @State private var bannerDismissTask: Task<Void, Never>?
    
    var body: some View {
        MainLayout {
            List {
                Section {
                    if accountsStore.accounts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title2)
                                .foregroundStyle(Color("primaryPurple"))

                            Text("No accounts yet")
                                .font(.headline)

                            Text("Add your first App Store Connect account to start viewing your app statistics.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(Color("cardBGColor"))
                    } else {
                        ForEach(accountsStore.accounts) { account in
                            AccountRowView(
                                account: account,
                                isSelected: accountsStore.selectedAccountId == account.id
                            )
                            .onTapGesture {
                                select(account)
                            }
                            // Swipe rather than always-visible buttons, so the
                            // row looks exactly as it did before.
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    accountToDelete = account
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    accountToEdit = account
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color("primaryPurple"))
                            }
                        }
                    }

                    AddAccountRowView(accountsStore: accountsStore)

                    if let selected = accountsStore.selectedAccount {
                        Button {
                            isConfirmingLogOut = true
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.12))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                        .font(.body)
                                        .bold()
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Log Out")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Text(selected.label.isEmpty ? "Unnamed Account" : selected.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                } header: {
                    VStack(alignment: .leading, spacing: 16) {

                        ProfileHeaderInfoView(
                            initials: String(accountsStore.selectedAccount?.label.prefix(2) ?? "?"),
                            name: accountsStore.selectedAccount?.label ?? "No Account",
                            appCount: accountsStore.selectedAccount?.issuerId ?? "",
                            avatarColor: Color("primaryPurple")
                        )

                        HStack {
                            Text("Accounts")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("Tap to change")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, -12)
                    .padding(.bottom, 8)
                }
                .listRowBackground(Color("cardBGColor"))
                
                Section {
                    PreferenceToggleRowView(
                        title: "Dark Mode",
                        iconName: isDarkMode ? "sun.max.fill":"moon.stars.fill",
                        iconColor: isDarkMode ? Color.orange : Color("primaryPurple"),
                        isOn: $isDarkMode
                    )
                } header: {
                    Text("Preferences")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .textCase(nil)
                        .padding(.horizontal, -12)
                        .padding(.bottom, 8)
                }
                .listRowBackground(Color("cardBGColor"))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let switchedToName {
                AccountSwitchBanner(accountName: switchedToName)
            }
        }
        .navigationDestination(item: $accountToEdit) { account in
            CredentialsView(accountsStore: accountsStore, existingAccount: account)
        }
        .confirmationDialog(
            "Delete \(accountToDelete?.label ?? "this account")?",
            isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                if let accountToDelete {
                    accountsStore.deleteAccount(accountToDelete)
                }
                accountToDelete = nil
            }
            Button("Cancel", role: .cancel) { accountToDelete = nil }
        } message: {
            Text("Its API key will be removed from this device. Your apps and data in App Store Connect are not affected.")
        }
        .confirmationDialog(
            "Log out of \(accountsStore.selectedAccount?.label ?? "this account")?",
            isPresented: $isConfirmingLogOut,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) { logOutSelected() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Its API key will be removed from this device. You can add it again at any time.")
        }
        .onDisappear { bannerDismissTask?.cancel() }
    }

    // MARK: Actions

    private func select(_ account: APIAccount) {
        guard accountsStore.selectedAccountId != account.id else { return }
        accountsStore.selectedAccountId = account.id
        HapticManager.selectionChanged()
        showBanner(for: account.label.isEmpty ? "Unnamed Account" : account.label)
    }

    private func logOutSelected() {
        guard let current = accountsStore.selectedAccount else { return }
        accountsStore.deleteAccount(current)
        // Deleting the selected account promotes the next one, so say which,
        // rather than leaving the header to change silently again.
        if let next = accountsStore.selectedAccount {
            showBanner(for: next.label.isEmpty ? "Unnamed Account" : next.label)
        }
    }

    private func showBanner(for name: String) {
        bannerDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) { switchedToName = name }
        bannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { switchedToName = nil }
        }
    }
}

// MARK: - PREVIEW
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(accountsStore: AccountsStore())
        }
    }
}
