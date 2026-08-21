import SwiftUI

/// Toggles a section between its original text and an English translation.
struct TranslateButton: View {
    let isShowingTranslation: Bool
    let isTranslating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isTranslating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "translate")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(
                    isShowingTranslation
                        ? Color("primaryPurple").opacity(0.18)
                        : Color.secondary.opacity(0.12)
                )
            )
            .foregroundStyle(isShowingTranslation ? Color("primaryPurple") : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isTranslating)
        .accessibilityLabel(isShowingTranslation ? "Show original language" : "Translate to English")
    }
}

/// Marks text that is a translation rather than what the customer wrote, so a
/// developer quoting a review back knows it isn't their words verbatim.
struct TranslatedBadge: View {
    var body: some View {
        Label("Translated to English", systemImage: "translate")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
