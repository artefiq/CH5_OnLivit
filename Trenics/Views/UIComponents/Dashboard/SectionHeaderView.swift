//
//  SectionHeaderView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.headline)
            
            Spacer()
        }
    }
}
