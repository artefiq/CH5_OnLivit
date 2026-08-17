import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - View-facing results
nonisolated struct InsightSummary: Sendable, Equatable {
    let headline: String
    let detail: String
    let highlight: String
}

nonisolated struct InsightSuggestion: Sendable, Equatable {
    let action: String
    let rationale: String
    let confidence: String
}

nonisolated struct ReviewThemeInsight: Identifiable, Sendable, Equatable {
    var id: String { theme }
    let theme: String
    let sentiment: ReviewSentiment
    let reviewCount: Int
    let representativeQuote: String
}

nonisolated enum InsightAvailability: Sendable, Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool { self == .available }
    var message: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

// MARK: - Generable schemas

#if canImport(FoundationModels)

@Generable
nonisolated struct InsightSummaryOutput {
    @Guide(description: "One short sentence stating the single most important change in the numbers. No greeting, no preamble.")
    var headline: String

    @Guide(description: "One or two sentences explaining what likely drove that change, referencing the specific figures given. Never invent numbers that were not provided.")
    var detail: String

    @Guide(description: "The one dimension that stands out most — a source, territory, version, or theme. A few words only.")
    var highlight: String
}

@Generable
nonisolated struct InsightSuggestionOutput {
    @Guide(description: "A single concrete action the developer should take next, phrased as an imperative. One sentence.")
    var action: String

    @Guide(description: "One sentence tying the action back to the specific numbers provided.")
    var rationale: String

    @Guide(description: "How well the data supports this action. Exactly one of: High, Medium, Low.")
    var confidence: String
}

@Generable
nonisolated struct ReviewThemeOutput {
    @Guide(description: "A recurring topic in two or three words, lowercase — for example 'subscription pricing' or 'sync reliability'.")
    var theme: String

    @Guide(description: "Overall sentiment of reviews on this theme. Exactly one of: positive, neutral, negative.")
    var sentiment: String

    @Guide(description: "How many of the supplied reviews mention this theme.")
    var reviewCount: Int

    @Guide(description: "A short verbatim phrase from one of the supplied reviews that captures this theme. Do not paraphrase.")
    var representativeQuote: String
}

@Generable
nonisolated struct ReviewThemesOutput {
    @Guide(description: "The three to five most frequently recurring themes, ordered by how often they appear.")
    var themes: [ReviewThemeOutput]
}

#endif

// MARK: - Generator

actor InsightGenerator {
    static let shared = InsightGenerator()

    private let maxReviewsForThemes = 40
    private let maxReviewCharacters = 280

    var availability: InsightAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(Self.describe(reason))
        @unknown default:
            return .unavailable("On-device summaries aren't available on this device.")
        }
        #else
        return .unavailable("On-device summaries require iOS 26 or later.")
        #endif
    }

    // MARK: Summary & suggestion

    func summary(instructions: String, facts: String) async -> InsightSummary? {
        #if canImport(FoundationModels)
        guard availability.isAvailable else { return nil }
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: Self.summaryPrompt(facts: facts),
                generating: InsightSummaryOutput.self
            )
            let output = response.content
            return InsightSummary(
                headline: output.headline,
                detail: output.detail,
                highlight: output.highlight
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    func suggestion(instructions: String, facts: String) async -> InsightSuggestion? {
        #if canImport(FoundationModels)
        guard availability.isAvailable else { return nil }
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: Self.suggestionPrompt(facts: facts),
                generating: InsightSuggestionOutput.self
            )
            let output = response.content
            return InsightSuggestion(
                action: output.action,
                rationale: output.rationale,
                confidence: output.confidence
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: Review themes

    func reviewThemes(from reviews: [CustomerReview]) async -> [ReviewThemeInsight] {
        #if canImport(FoundationModels)
        guard availability.isAvailable else { return [] }
        let corpus = Self.corpus(
            from: reviews,
            maxReviews: maxReviewsForThemes,
            maxCharacters: maxReviewCharacters
        )
        guard !corpus.isEmpty else { return [] }
        do {
            let session = LanguageModelSession(instructions: Self.reviewThemeInstructions)
            let response = try await session.respond(
                to: """
                Identify the recurring themes across these App Store reviews. Each line is one \
                review, prefixed with its star rating.

                \(corpus)
                """,
                generating: ReviewThemesOutput.self
            )
            return response.content.themes.map { output in
                ReviewThemeInsight(
                    theme: output.theme,
                    sentiment: ReviewSentiment(rawValue: output.sentiment.lowercased()) ?? .neutral,
                    reviewCount: max(0, output.reviewCount),
                    representativeQuote: output.representativeQuote
                )
            }
        } catch {
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: Prompt construction

    private static func summaryPrompt(facts: String) -> String {
        """
        Summarise what happened, based only on these figures:

        \(facts)

        Describe what the numbers show. Do not recommend any action — a separate \
        card handles recommendations.
        """
    }

    private static func suggestionPrompt(facts: String) -> String {
        """
        Based only on these figures, recommend the single highest-value next step:

        \(facts)

        Prescribe an action. Do not restate the numbers as a summary.
        """
    }

    private static let reviewThemeInstructions = """
    You cluster App Store review text into recurring themes for an app developer. \
    Only use themes actually present in the supplied reviews. Quote verbatim. \
    If a theme appears in fewer than two reviews, leave it out.
    """

    private static func corpus(from reviews: [CustomerReview], maxReviews: Int, maxCharacters: Int) -> String {
        reviews
            .prefix(maxReviews)
            .compactMap { review -> String? in
                let title = review.attributes.title ?? ""
                let body = review.attributes.body ?? ""
                let text = [title, body]
                    .filter { !$0.isEmpty }
                    .joined(separator: " — ")
                    .replacingOccurrences(of: "\n", with: " ")
                guard !text.isEmpty else { return nil }
                return "\(review.attributes.rating)★ \(String(text.prefix(maxCharacters)))"
            }
            .joined(separator: "\n")
    }

    #if canImport(FoundationModels)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support on-device summaries."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to see on-device summaries."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "On-device summaries aren't available right now."
        }
    }
    #endif
}

// MARK: - Per-page instructions

nonisolated enum InsightInstructions {
    static let discoverySummary = """
    You analyse App Store discovery funnels for an app developer. Be specific and \
    quantitative. Reference only the figures supplied. Two or three sentences total, \
    plain language, no marketing tone.
    """

    static let discoverySuggestion = """
    You advise app developers on App Store product page optimisation. Recommend one \
    concrete, testable action grounded in the supplied conversion figures.
    """

    static let retentionSummary = """
    You analyse mobile app retention for an app developer. Look for correlations \
    across the supplied metrics — a retention drop next to a crash spike or a version \
    release matters more than either alone. State the correlation if one exists.
    """

    static let retentionSuggestion = """
    You advise app developers on retention and churn. Recommend one concrete \
    investigation or intervention grounded in the supplied figures.
    """

    static let reviewsSummary = """
    You analyse App Store review sentiment for an app developer. Be specific about \
    which themes drive which ratings, and over what period.
    """

    static let accountOverview = """
    You summarise an app portfolio for its developer, for a dashboard card they \
    glance at. Two short sentences, plain language, no jargon. Say which app \
    stands out and why. Reference only the figures supplied, and never invent a \
    number. Describe the state of things — do not recommend actions.
    """

    static let reviewsSuggestion = """
    You advise app developers on responding to review feedback. Recommend one \
    concrete change to the app, its paywall copy, or its store listing.
    """
}
