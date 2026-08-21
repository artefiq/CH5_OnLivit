import Foundation
internal import Combine
#if canImport(Translation)
import Translation
#endif

/// Holds English translations of review text, keyed by a caller-supplied id.
///
/// Reviews arrive in whatever language the customer wrote them, and the theme
/// clustering quotes them verbatim, so a developer reading their own reviews
/// can hit text they can't read. This translates on demand rather than up
/// front: most reviews are already readable, and translating everything on
/// every load would be work nobody asked for.
///
/// Translation runs through Apple's on-device Translation framework, so review
/// text stays on the device — the same reason theme extraction is on-device.
@MainActor
final class ReviewTranslationStore: ObservableObject {
    /// Whether translated text should be shown in place of the original.
    @Published private(set) var isShowingTranslation = false
    @Published private(set) var isTranslating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var translations: [String: String] = [:]

    /// Batches beyond this are dropped: a long review list would otherwise
    /// queue hundreds of requests behind a single tap.
    static let maxItems = 120

    /// The translated text when translation is on and one exists, otherwise
    /// the original. Callers can use this everywhere and stay ignorant of state.
    func display(_ original: String, id: String) -> String {
        guard isShowingTranslation else { return original }
        return translations[id] ?? original
    }

    func hasTranslation(id: String) -> Bool {
        isShowingTranslation && translations[id] != nil
    }

    /// True when a translation pass has already covered these items, so
    /// toggling back on doesn't re-run it.
    func isCovered(_ items: [TranslatableItem]) -> Bool {
        !items.isEmpty && items.allSatisfy { translations[$0.id] != nil }
    }

    func showOriginal() {
        isShowingTranslation = false
        errorMessage = nil
    }

    func showTranslation() {
        isShowingTranslation = true
    }

    func beginTranslating() {
        isTranslating = true
        errorMessage = nil
    }

    func finish(with results: [String: String]) {
        translations.merge(results) { _, new in new }
        isTranslating = false
        isShowingTranslation = true
    }

    func fail(_ message: String) {
        isTranslating = false
        isShowingTranslation = false
        errorMessage = message
    }
}

/// One piece of text to translate, with the id the UI will look it up by.
struct TranslatableItem: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
}

#if canImport(Translation)
extension ReviewTranslationStore {
    /// Runs a batch through the session opened by `.translationTask`.
    ///
    /// Empty and whitespace-only strings are skipped rather than sent, and
    /// duplicates are collapsed — the same quote often appears both as a theme
    /// quote and inside a review body.
    func translate(items: [TranslatableItem], using session: TranslationSession) async {
        let pending = items
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { translations[$0.id] == nil }
            .prefix(Self.maxItems)

        guard !pending.isEmpty else {
            isTranslating = false
            isShowingTranslation = true
            return
        }

        let requests = pending.map {
            TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id)
        }
        do {
            var results: [String: String] = [:]
            for try await response in session.translate(batch: requests) {
                if let id = response.clientIdentifier {
                    results[id] = response.targetText
                }
            }
            finish(with: results)
        } catch {
            fail("Couldn't translate these reviews: \(error.localizedDescription)")
        }
    }
}
#endif
