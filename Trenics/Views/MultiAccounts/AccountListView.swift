//
//  AccountListView.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 14/08/26.
//

import SwiftUI

struct AccountsListView: View {
    @ObservedObject var accountsStore: AccountsStore

    var body: some View {
        ZStack {
            List {
                ForEach(accountsStore.accounts) { account in
                    NavigationLink {
                        AccountEditView(accountsStore: accountsStore, existingAccount: account)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(account.label).font(.headline)
                                if accountsStore.selectedAccountId == account.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                }
                            }
                            Text("Issuer: \(account.issuerId)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        accountsStore.deleteAccount(accountsStore.accounts[index])
                    }
                }
            }

            if accountsStore.accounts.isEmpty {
                VStack(spacing: 8) {
                    Text("No accounts yet").font(.headline)
                    Text("Tap + to add your first App Store Connect API key.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem {
                NavigationLink {
                    AccountEditView(accountsStore: accountsStore)
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountsListView(
            accountsStore: AccountsStore()
        )
    }
}
