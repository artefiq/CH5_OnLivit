//
//  AppIconBadgeView.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI

/// Rounded-square app icon badge shown in the App Detail header.
/// Falls back to a gradient + SF Symbol since there's no real app icon asset
/// yet — swap in a real `Image` once one is added to Assets.xcassets.
struct AppIconBadgeView: View {
    let iconName: String
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.9), Color("primaryPurple").opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: iconName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    AppIconBadgeView(iconName: "waveform.circle.fill")
        .padding()
}
