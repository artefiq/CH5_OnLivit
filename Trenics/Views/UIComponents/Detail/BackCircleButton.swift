//
//  BackCircleButton.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI

/// The round white "‹" back button used at the top of detail screens.
/// Uses the environment dismiss action, so it works whether the screen was
/// pushed from a NavigationStack or presented as a sheet.
struct BackCircleButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color("cardBGColor")))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BackCircleButton()
        .padding()
}
