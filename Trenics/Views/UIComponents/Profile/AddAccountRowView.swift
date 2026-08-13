//
//  AddAccountRowView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 13/08/26.
//

import SwiftUI

struct AddAccountRowView: View {
    @StateObject private var credentials = AccountsStore()

    var body: some View {
        NavigationLink {
            CredentialsView(accountsStore: credentials)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .font(.body)
                        .bold()
                }

                Text("Add another account")
                    .font(.body)
                    .foregroundColor(.blue)
                    .bold()

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
