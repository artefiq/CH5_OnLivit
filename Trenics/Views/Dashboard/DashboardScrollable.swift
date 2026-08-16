import SwiftUI
import UIKit
internal import Combine

// MARK: - Haptics

enum HapticManager {
    private static let generator = UIImpactFeedbackGenerator(style: .medium)
    
    static func prepare() {
        generator.prepare()
    }
    
    static func selectionChanged() {
        generator.impactOccurred()
        generator.prepare()
    }
}

// MARK: - Model

struct AppItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let iconColor: Color
    let iconSystemName: String
}

extension AppItem {
    static let sample: [AppItem] = [
        AppItem(name: "Catch of Fishing",
                description: "Track your catches and favorite fishing spots.",
                iconColor: .gray.opacity(0.4),
                iconSystemName: "fish.fill"),
        AppItem(name: "Fih-Together",
                description: "A mobile game app that lets users feel the real experience and mechanics of fishing.",
                iconColor: Color(red: 0.78, green: 0.65, blue: 0.93),
                iconSystemName: "gamecontroller.fill"),
        AppItem(name: "Reel Planner",
                description: "Plan your next fishing trip with tide charts and weather.",
                iconColor: .gray.opacity(0.4),
                iconSystemName: "map.fill"),
        AppItem(name: "Bait Buddy",
                description: "Find the best bait for the season and location.",
                iconColor: .gray.opacity(0.4),
                iconSystemName: "leaf.fill")
    ]
}

// MARK: - View Model

final class DashboardScrollableViewModel: ObservableObject {
    @Published var apps: [AppItem] = AppItem.sample
    @Published var selectedApp: AppItem?
    
    init() {
        selectedApp = apps[safe: apps.count / 2]
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Dashboard Screen

struct DashboardScrollableView: View {
    @StateObject private var viewModel = DashboardScrollableViewModel()
    
    var body: some View {
        ZStack {
            MainLayout{
                HStack {
                    Text("Hello, Onlivit")
                        .font(Font.title.bold())
                    Spacer()
                    Button(action: {
                        HapticManager.selectionChanged()
                    }) {
                        Text("ON")
                            .font(Font.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.purple)
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
                
                QuickSummaryCard(app: viewModel.selectedApp)
                    .padding(.horizontal, 16)
                
                MyAppsCarousel(apps: viewModel.apps, selectedApp: $viewModel.selectedApp)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Quick Summary Card

struct QuickSummaryCard: View {
    let app: AppItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Summary")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Divider()
            
            if let app = app {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(app.iconColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: app.iconSystemName)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Download trends")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Text("-20%")
                        .font(Font.title3.bold())
                        .foregroundColor(Color(UIColor.systemRed))
                    Image(systemName: "arrow.down.right")
                        .font(Font.title3.bold())
                        .foregroundColor(Color(UIColor.systemRed))
                }
                .padding(.top, 4)
                
                Divider()
                
                DownloadTrendChart()
                    .padding(.top, 12)
                
                Text("Downloads showed a strong upward trend, rising from around 40 to nearly 100. After reaching a peak, downloads declined by 20% in the latest period, suggesting a recent slowdown in growth. Overall, the app is still performing well, but the recent decline may be worth monitoring closely.")
                    .padding(.top, 4)
                    .font(.caption)
                
                
                // Animate the swap whenever the selected app changes.
                .id(app.id)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Scroll to select an app")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("cardBGColor"))
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .animation(.easeInOut(duration: 0.25), value: app?.id)
    }
}

// MARK: - My Apps Carousel

struct MyAppsCarousel: View {
    let apps: [AppItem]
    @Binding var selectedApp: AppItem?
    
    private let cardHeight: CGFloat = 96
    private let cardSpacing: CGFloat = 8
    private var itemHeight: CGFloat { cardHeight + cardSpacing }
    
    @State private var selectedIndex: Int
    @State private var dragOffset: CGFloat = 0
    
    init(apps: [AppItem], selectedApp: Binding<AppItem?>) {
        self.apps = apps
        self._selectedApp = selectedApp
        self._selectedIndex = State(initialValue: apps.count / 2)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Apps")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            GeometryReader { outerGeo in
                let containerHeight = outerGeo.size.height
                let baseOffset = (containerHeight / 2) - (cardHeight / 2)
                - (CGFloat(selectedIndex) * itemHeight)
                let continuousIndex = CGFloat(selectedIndex) - (dragOffset / itemHeight)
                
                VStack(spacing: cardSpacing) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        let distance = abs(CGFloat(index) - continuousIndex)
                        let proximity = max(0, 1 - min(distance, 1))
                        let isSelected = distance < 0.5
                        
                        AppCardView(app: app, proximity: proximity, isSelected: isSelected)
                            .frame(height: cardHeight)
                    }
                }
                .padding(.horizontal, 16)
                .offset(y: baseOffset + dragOffset)
                .frame(maxWidth: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let projected = value.predictedEndTranslation.height
                            let indexShift = Int((-projected / itemHeight).rounded())
                            let newIndex = min(max(selectedIndex + indexShift, 0), apps.count - 1)
                            
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
                                dragOffset = 0
                                selectedIndex = newIndex
                            }
                            
                            if selectedApp?.id != apps[newIndex].id {
                                selectedApp = apps[newIndex]
                                HapticManager.selectionChanged()
                            }
                        }
                )
            }
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 264)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("cardBGColor"))
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .onAppear {
            HapticManager.prepare()
            if selectedApp == nil {
                selectedApp = apps[safe: selectedIndex]
            }
        }
    }
}

// MARK: - Individual App Card

struct AppCardView: View {
    let app: AppItem
    let proximity: CGFloat
    let isSelected: Bool
    
    private var scale: CGFloat {
        isSelected ? 1.0 : 0.9 + (0.1 * proximity)
    }
    
    private var opacity: Double {
        isSelected ? 1.0 : 0.5 + (0.45 * Double(proximity))
    }
    
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(app.iconColor)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: app.iconSystemName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? Color("primaryPurple") : .primary)
                
                Text(app.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("cardColor"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isSelected ? Color("primaryPurple") : Color.gray.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0), radius: 8, y: 4)
        .scaleEffect(scale)
        .opacity(opacity)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Preview

struct DashboardScrollableView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardScrollableView()
    }
}
