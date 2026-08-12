//
//  AllAppsListView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct AllAppsListView: View {
    let apps: [AppItemModel]
    
    var body: some View {
        MainLayout {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(apps) { app in
                        AppListRowView(app: app)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("All Apps")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
