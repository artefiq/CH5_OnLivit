//
//  ProfileHeaderInfoView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 13/08/26.
//

import SwiftUI

struct ProfileHeaderInfoView: View {
    let initials: String
    let name: String
    let appCount: String
    let avatarColor: Color
    
    var body: some View {
        HStack() {
            Text(initials)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.primaryPurple)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.primary)
                
                Text("\(appCount) Apps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
