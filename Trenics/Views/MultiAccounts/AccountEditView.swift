//
//  AccountEditView.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 14/08/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct AccountEditView: View {
    @ObservedObject var accountsStore: AccountsStore
    @Environment(\.dismiss) private var dismiss

    private let existingAccount: APIAccount?

    @State private var label: String
    @State private var issuerId: String
    @State private var keyId: String
    @State private var privateKeyPEM: String
    @State private var isImporterPresented = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    init(accountsStore: AccountsStore, existingAccount: APIAccount? = nil) {
        self.accountsStore = accountsStore
        self.existingAccount = existingAccount
        _label = State(initialValue: existingAccount?.label ?? "")
        _issuerId = State(initialValue: existingAccount?.issuerId ?? "")
        _keyId = State(initialValue: existingAccount?.keyId ?? "")
        _privateKeyPEM = State(initialValue: existingAccount?.privateKeyPEM ?? "")
    }

    private var p8Type: UTType { UTType(filenameExtension: "p8") ?? .data }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && !issuerId.trimmingCharacters(in: .whitespaces).isEmpty
            && !keyId.trimmingCharacters(in: .whitespaces).isEmpty
            && !privateKeyPEM.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Account") {
                TextField("Label (e.g. \"Acme Inc\")", text: $label)
            }

            Section("App Store Connect API Key") {
                TextField("Issuer ID", text: $issuerId)
                TextField("Key ID", text: $keyId)

                VStack(alignment: .leading) {
                    Text("Private Key (.p8 contents)")
                    TextEditor(text: $privateKeyPEM)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 160)
                        .border(Color.gray.opacity(0.3))
                    Button("Import .p8 File...") { isImporterPresented = true }
                }
            }

            if let statusMessage {
                Text(statusMessage).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            Text("The label is just for telling accounts apart in this app — it isn't sent to Apple. Create the key itself in App Store Connect under Users and Access > Integrations > App Store Connect API. Private keys never leave this device — they're stored in the Keychain and used only to sign requests locally.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(existingAccount == nil ? "Add Account" : "Edit Account")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(!isValid)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [p8Type, .data, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func save() {
        let account = APIAccount(
            id: existingAccount?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            issuerId: issuerId.trimmingCharacters(in: .whitespaces),
            keyId: keyId.trimmingCharacters(in: .whitespaces),
            privateKeyPEM: privateKeyPEM
        )
        if existingAccount != nil {
            accountsStore.updateAccount(account)
        } else {
            accountsStore.addAccount(account)
        }
        dismiss()
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                privateKeyPEM = content
                statusMessage = "Loaded key from \(url.lastPathComponent)"
            } catch {
                errorMessage = "Couldn't read that file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
