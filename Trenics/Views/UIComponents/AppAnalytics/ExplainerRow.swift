import SwiftUI

struct ExplainerRow: View {
    let facts: String
    let fallback: String
    var instructions: String = InsightInstructions.statExplainer

    @State private var isExpanded = false
    @State private var generated: String?
    @State private var generatedFrom: String?
    @State private var isGenerating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                if isExpanded { Task { await generateIfNeeded() } }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.sparkles.inverse")
                        .font(.subheadline)
                        .foregroundStyle(Color("primaryPurple"))
                    Text("What does it mean?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Group {
                    if isGenerating {
                        AIThinkingRow(style: .insight, text: "Reading your numbers…")
                    } else {
                        Text(generated ?? fallback)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Figures changed underneath, so any explanation of the old ones is stale.
        .onChange(of: facts) { _, _ in
            guard generatedFrom != facts else { return }
            generated = nil
            generatedFrom = nil
            if isExpanded { Task { await generateIfNeeded() } }
        }
    }

    private func generateIfNeeded() async {
        guard generatedFrom != facts, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        let text = await InsightGenerator.shared.explanation(
            instructions: instructions,
            facts: facts
        )
        generated = text
        // Records the input even when generation failed, so expanding again
        // doesn't retry endlessly against an unavailable model.
        generatedFrom = facts
    }
}
