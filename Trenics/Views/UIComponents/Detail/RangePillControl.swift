//
//  RangePillControl.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI

/// The "4W / 8W / 12W" pill row. Selected pill is filled with the app's
/// primary purple; unselected pills are a soft gray, matching the design.
struct RangePillControl: View {
    @Binding var selected: MetricRange

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MetricRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = range }
                } label: {
                    Text(range.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(selected == range ? .white : .primary.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selected == range ? Color("primaryPurple") : Color.gray.opacity(0.13))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    RangePillControl(selected: .constant(.fourWeeks))
        .padding()
}
