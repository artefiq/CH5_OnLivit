//
//  MetricCardView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct MetricCardView: View {
    let metric: MetricModel
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(metric.accentColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(metric.title)
                    .font(.headline)
                    .foregroundColor(metric.accentColor)
                
                HStack(spacing: 8) {
                    Text(metric.value)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(metric.valueColor)
                    
                    Image(systemName: metric.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.title2)
                        .bold()
                        .foregroundColor(metric.valueColor)
                }
                
                Text(metric.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
        }
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 1)
    }
}
