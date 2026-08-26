//
//  AccountRow2View.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 14/08/26.
//

import SwiftUI

struct AccountRowView: View {
    let account: APIAccount
    let isSelected: Bool

    private var initials: String {
        let trimmedLabel = account.label
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let letters = trimmedLabel.prefix(2)

        return String(letters).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color("primaryPurple"))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(account.label.isEmpty ? "Unnamed Account" : account.label)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    // Spelled out rather than left to the checkmark alone,
                    // which people were not reading as "this one is in use".
                    if isSelected {
                        Text("Active")
                            .font(.caption2.bold())
                            .foregroundStyle(Color("primaryPurple"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color("primaryPurple").opacity(0.15))
                            )
                    }

                    Text(
                        account.issuerId.isEmpty
                        ? "No Issuer ID"
                        : "Issuer: \(account.issuerId)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Spacer()

            Image(
                systemName: isSelected
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .foregroundStyle(
                isSelected
                    ? Color("primaryPurple")
                    : .gray.opacity(0.5)
            )
            .font(.title2)
        }
        .contentShape(Rectangle())
        .listRowBackground(
            isSelected
                ? Color.gray.opacity(0.1)
                : Color("cardBGColor")
        )
    }
}
