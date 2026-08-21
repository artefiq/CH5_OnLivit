//
//  AccountsStore.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 14/08/26.
//

import Foundation
internal import Combine
import Security

struct APIAccount: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var label: String
    var issuerId: String
    var keyId: String
    var privateKeyPEM: String
}

final class AccountsStore: ObservableObject {
    @Published var accounts: [APIAccount] {
        didSet { persistAccounts() }
    }

    @Published var selectedAccountId: UUID? {
        didSet { UserDefaults.standard.set(selectedAccountId?.uuidString, forKey: "selectedAccountId") }
    }

    private let keychainService = "AppStoreStats"
    private let keychainAccount = "accounts_v1"

    init() {
        if let json = KeychainHelper.load(service: keychainService, account: keychainAccount),
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([APIAccount].self, from: data) {
            accounts = decoded
        } else {
            accounts = []
        }

        if let idString = UserDefaults.standard.string(forKey: "selectedAccountId"),
           let uuid = UUID(uuidString: idString),
           accounts.contains(where: { $0.id == uuid }) {
            selectedAccountId = uuid
        } else {
            selectedAccountId = accounts.first?.id
        }
    }

    var selectedAccount: APIAccount? {
        accounts.first { $0.id == selectedAccountId }
    }

    func addAccount(_ account: APIAccount) {
        accounts.append(account)
        if selectedAccountId == nil {
            selectedAccountId = account.id
        }
    }

    func updateAccount(_ account: APIAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
    }

    func deleteAccount(_ account: APIAccount) {
        accounts.removeAll { $0.id == account.id }
        if selectedAccountId == account.id {
            selectedAccountId = accounts.first?.id
        }
    }

    func makeClient(for account: APIAccount) -> AppStoreConnectClient {
        AppStoreConnectClient(issuerId: account.issuerId, keyId: account.keyId, privateKeyPEM: account.privateKeyPEM)
    }

    private func persistAccounts() {
        guard let data = try? JSONEncoder().encode(accounts),
              let json = String(data: data, encoding: .utf8) else { return }
        KeychainHelper.save(json, service: keychainService, account: keychainAccount)
    }
}

enum KeychainHelper2 {
    static func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
