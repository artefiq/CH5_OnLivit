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
    
    var body: some View {
        HStack(spacing: 16) {
            Text("Hello, \(userName)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            NavigationLink {
                ProfileView(accountsStore: AccountsStore())
            } label: {
                Text(initials)
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

