//
//  PreferenceToggleRowView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 13/08/26.
//

import SwiftUI

struct PreferenceToggleRowView: View {
    let title: String
    let iconName: String
    let iconColor: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)
            
            Toggle(title, isOn: $isOn)
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}
