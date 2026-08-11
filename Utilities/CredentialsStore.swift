import Foundation
internal import Combine
import Security

final class CredentialsStore: ObservableObject {
    @Published var issuerId: String {
        didSet { UserDefaults.standard.set(issuerId, forKey: "issuerId") }
    }
    @Published var keyId: String {
        didSet { UserDefaults.standard.set(keyId, forKey: "keyId") }
    }
    @Published var privateKeyPEM: String {
        didSet { KeychainHelper.save(privateKeyPEM, service: "AppStoreStats", account: "p8key") }
    }

    init() {
        issuerId = UserDefaults.standard.string(forKey: "issuerId") ?? ""
        keyId = UserDefaults.standard.string(forKey: "keyId") ?? ""
        privateKeyPEM = KeychainHelper.load(service: "AppStoreStats", account: "p8key") ?? ""
    }

    var isComplete: Bool {
        !issuerId.isEmpty && !keyId.isEmpty && !privateKeyPEM.isEmpty
    }

    func makeClient() -> AppStoreConnectClient {
        AppStoreConnectClient(issuerId: issuerId, keyId: keyId, privateKeyPEM: privateKeyPEM)
    }
}

/// Stores the private key in the macOS Keychain rather than UserDefaults/plist.
enum KeychainHelper {
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
