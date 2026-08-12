//
//  AppTheme.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 11/08/26.
//

import SwiftUI
internal import Combine

// MARK: - MODELS
struct MetricModel: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let isPositive: Bool
    let description: String
    let accentColor: Color
    let valueColor: Color
}

struct AppItemModel: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let iconName: String 
}

// MARK: - VIEW MODEL
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

// MARK: - MAIN VIEW
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
                                    AppListRowView(app: app)
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

// MARK: - COMPONENTS

struct HeaderView: View {
    let userName: String
    let initials: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text("Hello, \(userName)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Text(initials)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color("primaryPurple"))
                .clipShape(Circle())
        }
    }
}

struct AppDropdownView: View {
    let selectedApp: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundColor(.orange)
            
            Text(selectedApp)
                .font(.headline)
            
            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cardBG)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}

struct CustomDropdownPopupView: View {
    let apps: [AppItemModel]
    @Binding var selectedAppName: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        Button(action: {
                            selectedAppName = app.name
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isShowing = false
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "circle.hexagongrid.fill")
                                        .foregroundColor(.orange)
                                        .font(.body)
                                }
                                
                                Text(app.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedAppName == app.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("primaryPurple"))
                                        .font(.headline)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                        }
                        
                        if app.id != apps.last?.id {
                            Divider()
                                .padding(.horizontal, 20)
                                .opacity(0.5)
                        }
                    }
                }
            }
            .frame(maxHeight: 350)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
    }
}

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

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.headline)
            
            Spacer()
        }
    }
}

struct AppListRowView: View {
    let app: AppItemModel
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(.orange)
                    .font(.title)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                
                Text(app.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 16)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.cardBG)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 3)
    }
}

// MARK: - PREVIEW
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
