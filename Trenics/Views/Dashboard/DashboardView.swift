//
//  DashboardView.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI
internal import Combine

class DashboardViewModel: ObservableObject {
    @Published var userName: String = "Onlivit"
    @Published var userInitials: String = "ON"
    @Published var selectedAppName: String = "Freeform"
    
    @Published var metrics: [MetricModel] = [
        MetricModel(title: "Rating", value: "4.4", isPositive: true, description: "Your rating climbed to 4.4 from 4.1, people are liking what they see.", accentColor: Color("primaryPurple"), valueColor: .green),
        MetricModel(title: "Downloads", value: "-8%", isPositive: false, description: "Down compared to previous weeks, your efforts are worthwhile.", accentColor: .orange, valueColor: .red)
    ]
    
    @Published var apps: [AppItemModel] = [
        AppItemModel(name: "Freeform", description: "A mobile game app...", iconName: "waveform.circle.fill"),
        AppItemModel(name: "Pages", description: "A word processor app...", iconName: "doc.circle.fill"),
        AppItemModel(name: "Keynote", description: "A presentation app...", iconName: "play.rectangle.fill")
    ]
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var isDropdownOpen: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MainLayout {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            HeaderView(userName: viewModel.userName, initials: viewModel.userInitials)
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isDropdownOpen.toggle()
                                }
                            }) {
                                AppDropdownView(selectedApp: viewModel.selectedAppName)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.metrics) { metric in
                                        MetricCardView(metric: metric)
                                    }
                                }
                                .padding(.vertical, 0)
                            }
                            .padding(.horizontal, -16)
                            .padding(.leading, 16)
                            
                            NavigationLink {
                                AllAppsListView(apps: viewModel.apps)
                            } label: {
                                SectionHeaderView(title: "Your Apps")
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            VStack(spacing: 16) {
                                ForEach(viewModel.apps) { app in
                                    NavigationLink {
                                        AppMetricsView(app: app)
                                    } label: {
                                        AppListRowView(app: app)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            Text("This list updates automatically from your connected account. Tap the arrow to open full detail.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .padding(24)
                    }
                }
                .blur(radius: isDropdownOpen ? 3 : 0)
                
                if isDropdownOpen {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDropdownOpen = false
                            }
                        }
                    
                    CustomDropdownPopupView(
                        apps: viewModel.apps,
                        selectedAppName: $viewModel.selectedAppName,
                        isShowing: $isDropdownOpen
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(1)
                    .offset(y: -50)
                }
            }
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .previewDisplayName("Dashboard")
        
        NavigationStack {
            AllAppsListView(apps: [
                AppItemModel(name: "Freeform", description: "A mobile game app...", iconName: "waveform.circle.fill"),
                AppItemModel(name: "Pages", description: "A word processor app...", iconName: "doc.circle.fill"),
                AppItemModel(name: "Keynote", description: "A presentation app...", iconName: "play.rectangle.fill"),
                AppItemModel(name: "Numbers", description: "A spreadsheet app...", iconName: "tablecells.fill")
            ])
        }
        .previewDisplayName("All Apps List")
    }
}
