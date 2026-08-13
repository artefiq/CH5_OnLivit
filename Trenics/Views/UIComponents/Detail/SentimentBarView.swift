//
//  SentimentBarView.swift
//  Trenics
//
//  Created by Hans Alexander on 14/08/26.
//

import SwiftUI

struct SentimentBarView: View {
    let breakdown: SentimentBreakdown
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: segmentWidth(breakdown.positivePercent, totalWidth: geo.size.width))

                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: segmentWidth(breakdown.neutralPercent, totalWidth: geo.size.width))

                Rectangle()
                    .fill(Color.red)
                    .frame(width: segmentWidth(breakdown.negativePercent, totalWidth: geo.size.width))
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }

    private func segmentWidth(_ percent: Int, totalWidth: CGFloat) -> CGFloat {
        totalWidth * CGFloat(percent) / 100
    }
}
