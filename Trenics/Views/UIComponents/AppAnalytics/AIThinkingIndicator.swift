//
//  AIThinkingIndicator.swift
//  Trenics
//

import SwiftUI

// MARK: - The orbit

/// A symbol with smaller symbols orbiting it.
///
/// Driven by TimelineView rather than repeating animations: each satellite
/// keeps a steady angular speed, where chained animations drift out of phase
/// as they restart.
struct OrbitLoader: View {
    let centerSymbol: String
    let satelliteSymbol: String
    let tint: Color
    let palette: [Color]
    var size: CGFloat = 34
    /// The sparkle catches the light as it turns; a rotating lamp or bar chart
    /// just looks broken.
    var rotatesCenter: Bool = false
    /// Shrinks the orbiting marks. Solid dots need to be much smaller than
    /// sparkles or they read as part of the centre symbol rather than around it.
    var satelliteScale: CGFloat = 1
    /// Widens the ring, to keep the marks clear of a bulky centre symbol.
    var radiusScale: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// radius multiplier, revolutions per second, starting phase, symbol scale
    private let orbits: [(radius: Double, speed: Double, phase: Double, scale: Double)] = [
        (0.42, 0.55, 0.0, 0.30),
        (0.34, -0.75, 2.1, 0.24),
        (0.46, 0.40, 4.0, 0.20)
    ]

    var body: some View {
        Group {
            if reduceMotion {
                // Still says "working", without anything circling.
                Image(systemName: centerSymbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse)
            } else {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        glow(at: time)
                        ForEach(Array(orbits.enumerated()), id: \.offset) { index, orbit in
                            satellite(index: index, orbit: orbit, time: time)
                        }
                        center(at: time).zIndex(0)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Working on it")
    }

    private func center(at time: TimeInterval) -> some View {
        Image(systemName: centerSymbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .scaleEffect(1 + 0.08 * sin(time * 2.4))
            .rotationEffect(.degrees(rotatesCenter ? time * 18 : 0))
    }

    private func glow(at time: TimeInterval) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [tint.opacity(0.22), tint.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .scaleEffect(0.85 + 0.15 * sin(time * 1.6))
    }

    private func satellite(
        index: Int,
        orbit: (radius: Double, speed: Double, phase: Double, scale: Double),
        time: TimeInterval
    ) -> some View {
        let angle = time * orbit.speed * 2 * .pi + orbit.phase
        let radius = orbit.radius * radiusScale
        // Squashed vertically so the ring reads as tilted rather than flat.
        let x = cos(angle) * radius * size
        let y = sin(angle) * radius * size * 0.55
        // Front half larger and brighter, back half smaller and dimmer.
        let depth = sin(angle)

        return Image(systemName: satelliteSymbol)
            .font(.system(size: size * orbit.scale * satelliteScale, weight: .semibold))
            .foregroundStyle(palette[index % palette.count])
            .scaleEffect(1 + 0.35 * depth)
            .opacity(0.45 + 0.55 * (depth + 1) / 2)
            .offset(x: x, y: y)
            .zIndex(depth)
    }
}

// MARK: - AI

/// Shown while the on-device model is composing something. A plain spinner
/// reads as "fetching data"; this reads as "thinking", which is the difference
/// that matters here.
struct AIThinkingIndicator: View {
    enum Style {
        /// Summaries, explanations, themes.
        case insight
        /// Recommended next steps.
        case action

        var centerSymbol: String {
            switch self {
            case .insight: return "sparkle"
            case .action: return "lightbulb.fill"
            }
        }

        var tint: Color {
            switch self {
            case .insight: return Color("primaryPurple")
            case .action: return .orange
            }
        }

        var palette: [Color] {
            switch self {
            case .insight:
                return [Color("primaryPurple"), Color("primaryPurple").opacity(0.55), .indigo]
            case .action:
                return [.orange, .orange.opacity(0.55), Color(hex: 0xF5A524)]
            }
        }
    }

    var style: Style = .insight
    var size: CGFloat = 34

    var body: some View {
        OrbitLoader(
            centerSymbol: style.centerSymbol,
            satelliteSymbol: "sparkle",
            tint: style.tint,
            palette: style.palette,
            size: size,
            rotatesCenter: style == .insight
        )
    }
}

/// Indicator and text side by side, for a single row inside a card.
struct AIThinkingRow: View {
    var style: AIThinkingIndicator.Style = .insight
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            AIThinkingIndicator(style: style, size: 30)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

/// Indicator above its text, centred and larger. Used where the block has room
/// and the wait is the only thing in it.
struct AIThinkingBlock: View {
    var style: AIThinkingIndicator.Style = .insight
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            AIThinkingIndicator(style: style, size: 76)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Data

/// The same orbit for waits that are a network fetch rather than the model
/// composing an answer. Dots instead of sparkles, and a symbol for whatever is
/// being fetched, so it doesn't claim to be doing something it isn't.
struct DataLoadingView: View {
    let symbol: String
    let text: String
    var size: CGFloat = 76

    var body: some View {
        VStack(spacing: 12) {
            OrbitLoader(
                centerSymbol: symbol,
                satelliteSymbol: "circle.fill",
                tint: Color("primaryPurple"),
                palette: [
                    Color("primaryPurple"),
                    Color("primaryPurple").opacity(0.5),
                    .indigo.opacity(0.7)
                ],
                size: size,
                satelliteScale: 0.4,
                radiusScale: 1.15
            )
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
