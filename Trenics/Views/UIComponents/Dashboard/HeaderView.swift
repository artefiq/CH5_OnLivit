//
//  HeaderView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct HeaderView: View {
    let userName: String
    let initials: String
    /// Must be the app's single store, not a fresh one. Creating one here gave
    /// ProfileView a different instance to mutate, so switching accounts there
    /// never reached the dashboard — the header and app list kept showing the
    /// previously selected account until the next launch.
    @ObservedObject var accountsStore: AccountsStore

    var body: some View {
        HStack(spacing: 16) {
            Text("Hello, \(userName)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            NavigationLink {
                ProfileView(accountsStore: accountsStore)
            } label: {
                Text(initials)
                    .textCase(.uppercase)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color("primaryPurple"))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

