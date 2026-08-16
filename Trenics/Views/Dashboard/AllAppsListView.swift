//
//  AllAppsListView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

struct AllAppsListView: View {
    let apps: [AppItemModel]
    
    @State private var searchText: String = ""
    
    var filteredApps: [AppItemModel] {
        if searchText.isEmpty {
            return apps
        } else {
            return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        MainLayout {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(filteredApps) { app in
                        NavigationLink {
                            AppMetricsView(app: app)
                        } label: {
                            AppListRowView(app: app)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if filteredApps.isEmpty {
                        Text("No apps found")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("All Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search apps...")
    }
}
