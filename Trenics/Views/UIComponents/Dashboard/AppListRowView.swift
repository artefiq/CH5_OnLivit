//
//  AppListRowView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct AppListRowView: View {
    let app: AppItemModel
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(.orange)
                    .font(.title)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                
                Text(app.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 16)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.cardBG)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 3)
    }
}
