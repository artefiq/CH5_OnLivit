//
//  MainButton.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 12/08/26.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 60)
                        .fill(
                            Color.primaryPurple
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 60)
                        .stroke(
                            Color.blue.opacity(0.3),
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
