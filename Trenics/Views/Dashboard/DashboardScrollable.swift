import SwiftUI
import UIKit
internal import Combine

// MARK: - Haptics

/// Centralized haptic feedback so the generator can be prepped ahead of time
/// (reduces the trigger latency) and reused across the carousel.
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

final class DashboardViewModel: ObservableObject {
    @Published var apps: [AppItem] = AppItem.sample
    @Published var selectedApp: AppItem?
    
    init() {
        // Default selection: the middle-most app, matching initial scroll position.
        selectedApp = apps[safe: apps.count / 2]
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Dashboard Screen

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ZStack {
            MainLayout{
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
                .foregroundColor(.black)
            
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
                            .foregroundColor(.black)
                        Text(app.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.top, 4)
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
                .fill(Color(red: 0.98, green: 0.97, blue: 1.0))
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .animation(.easeInOut(duration: 0.25), value: app?.id)
    }
}

// MARK: - My Apps Carousel

/// A vertically scrolling list where the item nearest the visual center of
/// the scroll container is emphasized (scaled up, full opacity, highlighted
/// border) and becomes the `selectedApp`.
struct MyAppsCarousel: View {
    let apps: [AppItem]
    @Binding var selectedApp: AppItem?
    
    // Card metrics
    private let cardHeight: CGFloat = 96
    private let cardSpacing: CGFloat = 8
    private var itemHeight: CGFloat { cardHeight + cardSpacing }
    
    // The index currently locked to the center position.
    @State private var selectedIndex: Int
    // Live finger-drag offset, added on top of the locked position while dragging.
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
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            GeometryReader { outerGeo in
                let containerHeight = outerGeo.size.height
                // Offset that places `selectedIndex`'s card exactly at the
                // vertical center of the container — this is the fixed
                // "snap" position every card settles into.
                let baseOffset = (containerHeight / 2) - (cardHeight / 2)
                - (CGFloat(selectedIndex) * itemHeight)
                // Fractional index representing the current visual position
                // (used for smooth scale/opacity while dragging).
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
                            // How many full cards did the drag/flick cross?
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
                .fill(Color(red: 0.98, green: 0.97, blue: 1.0))
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
    /// 1.0 when perfectly centered, tapering to 0.0 at the edges.
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
                    .foregroundColor(isSelected ? Color(red: 0.42, green: 0.2, blue: 0.65) : .black)
                
                Text(app.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? Color(red: 0.6, green: 0.5, blue: 0.75) : .gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isSelected ? Color(red: 0.72, green: 0.55, blue: 0.93) : Color.gray.opacity(0.15),
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

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
