//
//  ReviewRowView.swift
//  Trenics
//
//  Created by Hans Alexander on 12/08/26.
//
//  Placeholder reviews for the "Review" tab on the App Detail screen.
//  Replace `ReviewMockData.reviews` with real App Store Connect customer
//  reviews once that's wired up (see Views/AppStats/ReviewsView.swift for
//  the live-data version of this concept).
//

import SwiftUI

struct MockReview: Identifiable {
    let id = UUID()
    let author: String
    let rating: Int
    let date: String
    let body: String
}

enum ReviewMockData {
    static let reviews: [MockReview] = [
        MockReview(author: "julesv_", rating: 2, date: "2 days ago",
                   body: "Loving the new update overall, but it crashed twice on me while switching modes. Hope this gets patched soon."),
        MockReview(author: "mikaonline", rating: 5, date: "4 days ago",
                   body: "Best free-form sketching app I've used. Smooth, fast, and the new tools are genuinely useful."),
        MockReview(author: "priya.codes", rating: 3, date: "1 week ago",
                   body: "Great concept, but I've had a couple of crashes right after opening large canvases."),
        MockReview(author: "dan_r", rating: 5, date: "1 week ago",
                   body: "Exactly what I needed for quick brainstorming. Clean UI, no clutter.")
    ]
}

struct ReviewRowView: View {
    let review: MockReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < review.rating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Text(review.date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(review.body)
                .font(.subheadline)
                .foregroundColor(.primary)

            Text("— \(review.author)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("cardBGColor"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 3)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(ReviewMockData.reviews) { review in
                ReviewRowView(review: review)
            }
        }
        .padding()
    }
}
