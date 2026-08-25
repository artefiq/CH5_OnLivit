//
//  AIThinkingIndicator.swift
//  Trenics
//

import SwiftUI

/// Shown while the on-device model is producing something.
///
/// A plain spinner reads as "loading data"; this reads as "thinking", which is
/// what is actually happening and what separates these waits from a network
/// fetch. The two styles match the blocks they belong to — purple sparkles for
/// what the numbers show, an orange lamp for what to do about it.
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

        var orbitSymbols: [String] {
            switch self {
            case .insight: return ["sparkle", "sparkle", "sparkle"]
            case .action: return ["sparkle", "sparkle", "sparkle"]
            }
        }

        var tint: Color {
            switch self {
            case .insight: return Color("primaryPurple")
            case .action: return .orange
            }
        }

        /// Orbiting marks alternate through these so the ring reads as more
        /// than one repeated glyph.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// radius multiplier, revolutions per second, starting phase, scale
    private let orbits: [(radius: Double, speed: Double, phase: Double, scale: Double)] = [
        (0.42, 0.55, 0.0, 0.30),
        (0.34, -0.75, 2.1, 0.24),
        (0.46, 0.40, 4.0, 0.20)
    ]

    var body: some View {
        Group {
            if reduceMotion {
                // Still says "working", without anything moving in a circle.
                pulsingCenter
            } else {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        glow(at: time)
                        ForEach(Array(orbits.enumerated()), id: \.offset) { index, orbit in
                            satellite(index: index, orbit: orbit, time: time)
                        }
                        center(at: time)
                            .zIndex(0)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Working on it")
    }

    // MARK: Parts

    private func center(at time: TimeInterval) -> some View {
        let pulse = 1 + 0.08 * sin(time * 2.4)
        return Image(systemName: style.centerSymbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(style.tint)
            .scaleEffect(pulse)
            // A slow turn on the sparkle catches the light; the lamp stays
            // upright, because a rotating bulb just looks broken.
            .rotationEffect(.degrees(style == .insight ? time * 18 : 0))
    }

    private func glow(at time: TimeInterval) -> some View {
        let breathe = 0.85 + 0.15 * sin(time * 1.6)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [style.tint.opacity(0.22), style.tint.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .scaleEffect(breathe)
    }

    private func satellite(
        index: Int,
        orbit: (radius: Double, speed: Double, phase: Double, scale: Double),
        time: TimeInterval
    ) -> some View {
        let angle = time * orbit.speed * 2 * .pi + orbit.phase
        let x = cos(angle) * orbit.radius * size
        // Squashed vertically so the ring reads as a tilted orbit rather than
        // a flat circle.
        let y = sin(angle) * orbit.radius * size * 0.55
        // Front half larger and brighter, back half smaller and dimmer.
        let depth = sin(angle)
        let scale = 1 + 0.35 * depth
        let opacity = 0.45 + 0.55 * (depth + 1) / 2

        return Image(systemName: style.orbitSymbols[index % style.orbitSymbols.count])
            .font(.system(size: size * orbit.scale, weight: .semibold))
            .foregroundStyle(style.palette[index % style.palette.count])
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: x, y: y)
            .zIndex(depth)
    }

    private var pulsingCenter: some View {
        Image(systemName: style.centerSymbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(style.tint)
            .symbolEffect(.pulse)
    }
}

/// The indicator plus a line of text, for use inside a row.
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
