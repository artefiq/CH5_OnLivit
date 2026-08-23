//
//  PrivateKeyGuideSheet.swift
//  Trenics
//

import SwiftUI

/// Step-by-step for creating an App Store Connect API key, shown from the
/// credentials form. Static content — nothing here talks to the API.
struct PrivateKeyGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id: Int
        let title: String
        /// Markdown, so step one can carry a link.
        let detail: LocalizedStringKey
    }

    private let steps: [Step] = [
        Step(id: 1, title: "Open App Store Connect",
             detail: "Click [here](https://appstoreconnect.apple.com/access/integrations/api). Sign in with the Apple ID that manages your app."),
        Step(id: 2, title: "Go to Users and Access",
             detail: "It's in the menu at the top of the page."),
        Step(id: 3, title: "Open the Integrations tab",
             detail: "Then make sure “App Store Connect API” is selected on the left."),
        Step(id: 4, title: "Add a new key",
             detail: "Use the plus button above the key list. Give it a name — that's just for your own reference."),
        Step(id: 5, title: "Under Access, choose Admin",
             detail: "This is the role that unlocks the data this app needs. Other roles will fail, more on why above."),
        Step(id: 6, title: "Click Generate, then download the key file",
             detail: "You can only download it once. Save it somewhere safe before leaving the page."),
        Step(id: 7, title: "Copy your Key ID and Issuer ID",
             detail: "The Issuer ID is at the top of the page. The Key ID is shown next to your new key."),
        Step(id: 8, title: "Come back and paste them in",
             detail: "Return here, paste the .p8 file contents into the Private Key field, and fill in the two IDs.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    roleWarning

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(steps) { step in
                            stepRow(step)
                        }
                    }

                    note("Keep the downloaded key file somewhere safe — Apple won't let you download it a second time. If you lose it, you'll need to generate a new one.")

                    note("Getting a “not allowed” error even with Admin access? Apple sometimes takes 24–48 hours to activate analytics data on a brand-new key. Try again the next day before assuming something's wrong.")
                }
                .padding(20)
            }
            .background(Color("baseBGColor").ignoresSafeArea())
            .navigationTitle("How to get your token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    // MARK: Pieces

    /// Called out first, and in red, because the wrong role is the failure
    /// people hit most — and it fails after all eight steps, not during them.
    private var roleWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Role required: Admin", systemImage: "exclamationmark.circle")
                .font(.subheadline.bold())
                .foregroundStyle(.red)

            Text("You need to be the Account Holder, or already have the Admin role, to generate a key with the right access. Developer, App Manager and Marketing roles won't work here — Apple blocks them from this data. If you're not sure what role you have, ask whoever set up your App Store Connect account.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
        )
    }

    private func stepRow(_ step: Step) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(step.id).")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Color("primaryPurple"))
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .tint(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color("cardBGColor"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
