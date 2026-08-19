//
//  AccountRowView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 13/08/26.
//

import SwiftUI

struct AccountRowView: View {
    let account: AccountModel
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(account.initials)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(account.avatarColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(account.appCount) Apps • \(account.syncStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? Color("primaryPurple") : .gray.opacity(0.5))
                .font(.title2)
        }
        .padding(0)
        .listRowBackground(isSelected ? Color.gray.opacity(0.1) : Color("cardBGColor"))
        .contentShape(Rectangle())
    }
}
