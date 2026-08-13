//
//  ComplaintThemeRowView.swift
//  Trenics
//
//  Created by Hans Alexander on 14/08/26.
//

import SwiftUI

struct ComplaintThemeRowView: View {
    let theme: ComplaintTheme

    var body: some View {
        HStack(spacing: 8) {
            Text(theme.title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text("\(theme.mentionCount) mentions")
                .font(.body)
                .foregroundColor(.secondary)

            if let deltaText = theme.deltaText {
                Text(deltaText)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.isDeltaNegative ? .red : .green)
            }
        }
        .padding(.vertical, 8)
    }
}
