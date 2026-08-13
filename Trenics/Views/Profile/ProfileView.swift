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
    
    var body: some View {
        MainLayout {
            List {
                Section {
                    ForEach(viewModel.accounts) { account in
                        AccountRowView(
                            account: account,
                            isSelected: viewModel.selectedAccountID == account.id
                        )
                        .onTapGesture {
                            viewModel.selectAccount(id: account.id)
                        }
                    }
                    
                    AddAccountRowView()
                    
                } header: {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        ProfileHeaderInfoView(
                            initials: viewModel.userInitials,
                            name: viewModel.userName,
                            appCount: viewModel.totalApps,
                            avatarColor: Color("primaryPurple")
                        )
                        
                        HStack {
                            Text("Accounts")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Tap to change")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, -12)
                    .padding(.bottom, 8)
                }
                
                Section {
                    PreferenceToggleRowView(
                        title: "Dark Mode",
                        iconName: "moon.stars.fill",
                        iconColor: Color("primaryPurple"),
                        isOn: $viewModel.isDarkMode
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
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - PREVIEW
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
        }
    }
}
