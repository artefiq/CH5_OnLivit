//
//  AccountSwitchBanner.swift
//  Trenics
//

import SwiftUI

/// Confirms that tapping an account actually switched to it.
///
/// The header does update on selection, but people were missing it and leaving
/// the screen to check — so this says plainly what happened and that nothing
/// else is needed. It sits in an overlay and disappears on its own, so nothing
/// on the page moves.
struct AccountSwitchBanner: View {
    let accountName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color("primaryPurple"))

            VStack(alignment: .leading, spacing: 1) {
                Text("Now using \(accountName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("Your apps and stats have already switched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color("primaryPurple").opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}
