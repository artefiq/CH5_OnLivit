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

/// Native segmented control tab switcher
struct AppDetailTabControl: View {
    @Binding var selected: AppDetailTab

    var body: some View {
        Picker("Select a tab", selection: $selected) {
            ForEach(AppDetailTab.allCases) { tab in
                // Gunakan .tag() agar SwiftUI tahu opsi mana yang sedang dipilih
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented) // Ini kunci untuk mengubah dropdown menjadi tab switcher native
    }
}

#Preview {
    AppDetailTabControl(selected: .constant(.keyMetrics))
        .padding()
}
