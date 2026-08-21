import SwiftUI

struct FunnelView: View {
    let stages: [FunnelStage]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                FunnelBar(
                    stage: stage,
                    widthFraction: fraction(for: stage),
                    tint: tint(for: index)
                )
                if index < stages.count - 1 {
                    ConversionConnector(rate: conversionRate(from: index))
                }
            }
        }
    }

    private var peak: Double { stages.map(\.value).max() ?? 0 }

    private func fraction(for stage: FunnelStage) -> Double {
        guard peak > 0 else { return 0 }
        // Floor the width so a tiny final stage is still readable.
        return max(0.18, stage.value / peak)
    }

    private func conversionRate(from index: Int) -> Double? {
        guard index + 1 < stages.count, stages[index].value > 0 else { return nil }
        return stages[index + 1].value / stages[index].value
    }

    private func tint(for index: Int) -> Color {
        let shades = [
            Color("primaryPurple"),
            Color("primaryPurple").opacity(0.75),
            Color("primaryPurple").opacity(0.55)
        ]
        return shades[min(index, shades.count - 1)]
    }
}

private struct FunnelBar: View {
    let stage: FunnelStage
    let widthFraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint)
                    .frame(width: geo.size.width * widthFraction)
                HStack {
                    Text(stage.label)
                        .font(.caption.bold())
                        // A narrow fill can't contain the label, and white text
                        // on the pale track is unreadable.
                        .foregroundStyle(widthFraction > 0.45 ? Color.white : Color.primary)
                        .padding(.leading, 12)
                    Spacer()
                    Text(stage.value.compactFormatted)
                        .font(.subheadline.bold())
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 44)
    }
}

private struct ConversionConnector: View {
    let rate: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down")
                .font(.caption2)
            Text(rate.map { "\($0.percentFormatted) convert" } ?? "—")
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }
}
