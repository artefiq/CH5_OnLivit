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
                            AccountRow2View(
                                account: account,
                                isSelected: accountsStore.selectedAccountId == account.id
                            )
                            .onTapGesture {
                                accountsStore.selectedAccountId = account.id
                            }
                        }
                    }

                    AddAccountRowView(accountsStore: accountsStore)
                    
                    NavigationLink {
                        AppsListView(accountsStore: accountsStore)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "text.justify")
                                    .foregroundColor(.blue)
                                    .font(.body)
                                    .bold()
                            }

                            Text("Apps list")
                                .font(.body)
                                .foregroundColor(.blue)
                                .bold()

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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
                        iconName: !isDarkMode ? "sun.max.fill":"moon.stars.fill",
                        iconColor: !isDarkMode ? Color.orange : Color("primaryPurple"),
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
