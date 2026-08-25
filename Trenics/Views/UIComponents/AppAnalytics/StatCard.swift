import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var delta: MetricDelta?
    var caption: String?
    /// Sized so a third card always peeks past the edge. At the previous 150
    /// the card came to 178pt with its padding, which meant exactly two filled
    /// the screen and the next sat entirely out of sight — nothing on screen
    /// suggested there was more to scroll to.
    var width: CGFloat? = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            if let delta {
                HStack(spacing: 3) {
                    Image(systemName: delta.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.bold())
                    Text(delta.formatted)
                        .font(.caption.bold())
                }
                .foregroundStyle(delta.isPositive ? Color.green : Color.red)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.right")
                        .font(.caption2.bold())
                    Text("0%")
                        .font(.caption.bold())
                }
                .foregroundStyle(Color.gray)
            }
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .padding(14)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

/// Horizontally scrolling row of `StatCard`s that bleeds to the screen edges
/// while the surrounding page keeps its gutter.
///
/// People were not realising this scrolled, so it now says so in three ways
/// that cost no layout: cards snap as you swipe, the edge that has more cards
/// behind it fades out, and the row nudges itself once on first appearance.
struct StatCardRow<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var edges = ScrollEdges()
    @State private var nudge: CGFloat = 0
    @State private var hasNudged = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fadeWidth: CGFloat = 28

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                content
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
            .offset(x: nudge)
        }
        // Cards come to rest aligned rather than mid-card, which is what makes
        // it feel like a carousel rather than a clipped row.
        .scrollTargetBehavior(.viewAligned)
        .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
            ScrollEdges(
                atStart: geometry.contentOffset.x <= geometry.contentInsets.leading + 1,
                atEnd: geometry.contentOffset.x + geometry.containerSize.width
                    >= geometry.contentSize.width - 1
            )
        } action: { _, new in
            edges = new
        }
        .mask(fade)
        .padding(.horizontal, -20)
        .task { await nudgeOnce() }
    }

    /// Fades only the side that actually has more cards behind it, so a fully
    /// scrolled row doesn't dim its own last card for no reason.
    private var fade: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let leading = edges.atStart ? 0 : fadeWidth / width
            let trailing = edges.atEnd ? 0 : fadeWidth / width

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: leading),
                    .init(color: .black, location: 1 - trailing),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// A single small shift and settle, shortly after the row appears. Motion
    /// is the one cue people reliably read as "this moves".
    private func nudgeOnce() async {
        guard !hasNudged, !reduceMotion else { return }
        hasNudged = true
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.easeInOut(duration: 0.32)) { nudge = -22 }
        try? await Task.sleep(for: .milliseconds(340))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { nudge = 0 }
    }
}

struct ScrollEdges: Equatable {
    var atStart = true
    var atEnd = false
}
