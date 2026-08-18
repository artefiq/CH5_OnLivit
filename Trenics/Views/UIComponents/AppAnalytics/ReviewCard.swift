import SwiftUI

struct ReviewCard: View {
    let review: CustomerReview
    let response: String?
    let isLoadingResponse: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StarRatingView(rating: review.attributes.rating)
                if let territory = review.attributes.territory {
                    Text(territory)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Self.dateLabel(review.attributes.createdDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let title = review.attributes.title, !title.isEmpty {
                Text(title).font(.subheadline.bold())
            }
            if let body = review.attributes.body, !body.isEmpty {
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let nickname = review.attributes.reviewerNickname {
                Text("— \(nickname)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            responseFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    @ViewBuilder
    private var responseFooter: some View {
        if isLoadingResponse {
            Label("Checking for a response…", systemImage: "ellipsis.bubble")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else if let body = response, !body.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("Your response", systemImage: "arrowshape.turn.up.left.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color("primaryPurple"))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color("primaryPurple").opacity(0.08))
            )
        } else {
            Label("Not answered", systemImage: "bubble.left")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private static func dateLabel(_ raw: String) -> String {
        guard let date = ASCDate.parseTimestamp(raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
