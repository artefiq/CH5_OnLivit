//
//  NextStepCardView.swift
//  Trenics
//
//  Created by Hans Alexander on 14/08/26.
//

import SwiftUI

struct NextStepCardView: View {
    let step: NextStepItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(step.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("cardBGColor"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 3)
    }
}
