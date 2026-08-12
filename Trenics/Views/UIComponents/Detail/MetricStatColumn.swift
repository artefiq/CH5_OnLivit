//
//  MetricStatColumn.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI

/// Small "LABEL / value" column used in the stats row under each chart,
/// e.g. "CURRENT — 4.4", "VS PREVIOUS 4W — -1%", "AVG CHANGE — -0.03/week".
struct MetricStatColumn: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HStack {
        MetricStatColumn(label: "Current", value: "4.4")
        MetricStatColumn(label: "vs previous 4W", value: "-1%", valueColor: .red)
        MetricStatColumn(label: "avg change", value: "-0.03/week", valueColor: .red)
    }
    .padding()
}
