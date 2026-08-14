//
//  SentimentBarView.swift
//  Trenics
//
//  Created by Hans Alexander on 14/08/26.
//

import Foundation

struct SentimentBreakdown {
    let positivePercent: Int
    let neutralPercent: Int
    let negativePercent: Int
}

struct ComplaintTheme: Identifiable {
    let id = UUID()
    let title: String
    let mentionCount: Int
    let deltaText: String?
    let isDeltaNegative: Bool
}

struct NextStepItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

struct ReviewSummaryData {
    let updatedLabel: String
    let headline: String
    let sentiment: SentimentBreakdown
    let themes: [ComplaintTheme]
    let nextSteps: [NextStepItem]
}

enum ReviewSummaryMockData {
    static let data = ReviewSummaryData(
        updatedLabel: "Updated today",
        headline: "People are mostly happy, but complaints about \"crashes\" are rising.",
        sentiment: SentimentBreakdown(positivePercent: 48, neutralPercent: 22, negativePercent: 30),
        themes: [
            ComplaintTheme(title: "Crashes", mentionCount: 14, deltaText: "+9", isDeltaNegative: true),
            ComplaintTheme(title: "Slow loading", mentionCount: 6, deltaText: "+2", isDeltaNegative: true),
            ComplaintTheme(title: "Confusing UI", mentionCount: 3, deltaText: nil, isDeltaNegative: false)
        ],
        nextSteps: [
            NextStepItem(
                title: "Check your last update for bugs",
                description: "\"Crashes\" is your fastest-growing complaint in reviews, 14 mentions this week, up from 5. That usually lines up with a download drop like this."
            ),
            NextStepItem(
                title: "Reply to your 3 most recent reviews",
                description: "Users who feel heard are more likely to update their rating instead of leaving."
            )
        ]
    )
}
