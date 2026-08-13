import SwiftUI
import UniformTypeIdentifiers

struct CredentialsView: View {
    @ObservedObject var credentials: CredentialsStore
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isImporterPresented = false

    private var p8Type: UTType {
        UTType(filenameExtension: "p8") ?? .data
    }

    var body: some View {
        MainLayout(){
            VStack(alignment: .center, spacing: 16) {
            
                Image(.appstoreLogo)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                Text("Connect your App Store account")
                    .frame(width: 248)
                    .font(Font.title.bold())
                    .multilineTextAlignment(.center)
                
                Text("We'll use this to read your own app's numbers. Nothing is shared publicly.")
                    .foregroundColor(Color.gray)
                    .multilineTextAlignment(.center)
                
                Form {
                    Section("Issuer ID") {
                        TextField("Issuer ID", text: $credentials.issuerId)
                    }
                    
                    Section("Key ID") {
                        TextField("Key ID", text: $credentials.keyId)
                    }
                    
                    Section("Private Key (.p8 contents)") {
                        VStack(alignment: .leading) {
                            TextEditor(text: $credentials.privateKeyPEM)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 72)
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
                
                VStack(spacing: 16){
                    Button("􀁜 How do I get my Private Key?") { isImporterPresented = true }
                        .padding(.top, 12)
                    
                    PrimaryButton(title: "Save"){
                        
                    }
                }
                .background(Color.baseBG)
                .padding(.top, -132)
                .padding(.horizontal, 16)
            }
            
        }
        
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Files picked via the document picker are security-scoped on iOS;
            // you must call startAccessingSecurityScopedResource() before reading.
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                credentials.privateKeyPEM = content
                statusMessage = "Loaded key from \(url.lastPathComponent)"
            } catch {
                errorMessage = "Couldn't read that file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
private extension CredentialsStore {
    static var preview: CredentialsStore {
        let store = CredentialsStore()
        store.issuerId = "69a6de70-03db-47e3-e053-5b8c7c11a4d1"
        store.keyId = "ABCD1234EF"
        store.privateKeyPEM = """
        -----BEGIN PRIVATE KEY-----
        MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...sample...key
        -----END PRIVATE KEY-----
        """
        return store
    }
}

struct CredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CredentialsView(credentials: CredentialsStore())
                .previewDisplayName("Empty")

            CredentialsView(credentials: .preview)
                .previewDisplayName("Filled in")
        }
    }
}
#endif
