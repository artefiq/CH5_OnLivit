//
//  AppDropdownView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct AppDropdownView: View {
    let selectedApp: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundColor(.orange)
            
            Text(selectedApp)
                .font(.headline)
            
            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cardBG)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}
