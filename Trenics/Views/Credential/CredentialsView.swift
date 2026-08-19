//
//  CredentialsView.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 14/08/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct CredentialsView: View {
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

    init(
        accountsStore: AccountsStore,
        existingAccount: APIAccount? = nil
    ) {
        self.accountsStore = accountsStore
        self.existingAccount = existingAccount

        _label = State(initialValue: existingAccount?.label ?? "")
        _issuerId = State(initialValue: existingAccount?.issuerId ?? "")
        _keyId = State(initialValue: existingAccount?.keyId ?? "")
        _privateKeyPEM = State(initialValue: existingAccount?.privateKeyPEM ?? "")
    }

    private var p8Type: UTType {
        UTType(filenameExtension: "p8") ?? .data
    }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !issuerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !keyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        MainLayout {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 16) {
                        Image(.appstoreLogo)
                            .resizable()
                            .frame(width: 64, height: 64)

                        Text("Connect your App Store account")
                            .frame(width: 248)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text("We'll use this to read your own app's numbers. Nothing is shared publicly.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Account Label") {
                    TextField(
                        "Label for this account",
                        text: $label
                    )
                }
                .listRowBackground(Color("cardBGColor"))

                Section("Issuer ID") {
                    TextField(
                        "Issuer ID",
                        text: $issuerId
                    )
                }
                .listRowBackground(Color("cardBGColor"))

                Section("Key ID") {
                    TextField(
                        "Key ID",
                        text: $keyId
                    )
                }
                .listRowBackground(Color("cardBGColor"))

                Section("Private Key (.p8 contents)") {
                    VStack(alignment: .leading) {
                        TextEditor(text: $privateKeyPEM)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.3))

                        Button("Import .p8 File...") {
                            isImporterPresented = true
                        }
                    }
                }
                .listRowBackground(Color("cardBGColor"))

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Section {
                    VStack(spacing: 16) {
                        Button("􀁜 How do I get my Private Key?") {
                            isImporterPresented = true
                        }

                        PrimaryButton(title: "Save") {
                            save()
                        }
                        .disabled(!isValid)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color("cardBGColor"))
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [p8Type, .data, .text],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
        }
    }

    private func save() {
        let account = APIAccount(
            id: existingAccount?.id ?? UUID(),
            label: label.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            issuerId: issuerId.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            keyId: keyId.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            privateKeyPEM: privateKeyPEM
        )

        if existingAccount != nil {
            accountsStore.updateAccount(account)
        } else {
            accountsStore.addAccount(account)
        }

        dismiss()
    }

    private func handleImportResult(
        _ result: Result<[URL], Error>
    ) {
        errorMessage = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didStartAccess =
                url.startAccessingSecurityScopedResource()

            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let content = try String(
                    contentsOf: url,
                    encoding: .utf8
                )

                privateKeyPEM = content
                statusMessage =
                    "Loaded key from \(url.lastPathComponent)"

            } catch {
                errorMessage =
                    "Couldn't read that file: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG

private extension AccountsStore {
    static var preview: AccountsStore {
        let store = AccountsStore()

        store.accounts = [
            APIAccount(
                id: UUID(),
                label: "My App Store Account",
                issuerId: "69a6de70-03db-47e3-e053-5b8c7c11a4d1",
                keyId: "ABCD1234EF",
                privateKeyPEM: """
                -----BEGIN PRIVATE KEY-----
                MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg
                ...sample...key
                -----END PRIVATE KEY-----
                """
            )
        ]

        return store
    }
}

struct CredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                CredentialsView(
                    accountsStore: AccountsStore()
                )
            }
            .previewDisplayName("Add Account")

            NavigationStack {
                CredentialsView(
                    accountsStore: .preview,
                    existingAccount: AccountsStore.preview.accounts.first
                )
            }
            .previewDisplayName("Edit Account")
        }
    }
}

#endif
