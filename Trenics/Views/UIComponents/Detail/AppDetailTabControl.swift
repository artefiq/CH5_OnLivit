//
//  AppDetailTabControl.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//

import SwiftUI

/// Which section of the App Detail screen is showing.
enum AppDetailTab: String, CaseIterable, Identifiable {
    case keyMetrics = "Key Metrics"
    case review = "Review"

    var id: String { rawValue }
}

/// Capsule tab switcher — the selected tab gets a floating white pill,
/// matching the "Key Metrics / Review" control in the design.
struct AppDetailTabControl: View {
    @Binding var selected: AppDetailTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppDetailTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(selected == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selected == tab {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color("cardBGColor"))
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .matchedGeometryEffect(id: "appDetailTab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    AppDetailTabControl(selected: .constant(.keyMetrics))
        .padding()
}
