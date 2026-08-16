//
//  CustomDropdownPopupView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct CustomDropdownPopupView: View {
    let apps: [AppItemModel]
    @Binding var selectedAppName: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        Button(action: {
                            selectedAppName = app.name
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isShowing = false
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "circle.hexagongrid.fill")
                                        .foregroundColor(.orange)
                                        .font(.body)
                                }
                                
                                Text(app.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedAppName == app.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("primaryPurple"))
                                        .font(.headline)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                        }
                        
                        if app.id != apps.last?.id {
                            Divider()
                                .padding(.horizontal, 20)
                                .opacity(0.5)
                        }
                    }
                }
            }
            .frame(maxHeight: 350)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
    }
}
