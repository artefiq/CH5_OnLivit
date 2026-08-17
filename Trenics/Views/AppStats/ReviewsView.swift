import SwiftUI

struct ReviewsView: View {
    let app: AppResource
    let account: APIAccount
    @State private var reviews: [CustomerReview] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let sum = reviews.reduce(0) { $0 + $1.attributes.rating }
        return Double(sum) / Double(reviews.count)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Ratings & Reviews — \(app.attributes.name)").font(.title2.bold())
                Spacer()
                Button(isLoading ? "Loading..." : "Fetch Reviews") { Task { await fetchReviews() } }
                    .disabled(isLoading)
            }

            if !reviews.isEmpty {
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("Average Rating").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.2f ★", averageRating)).font(.title.bold())
                    }
                    VStack(alignment: .leading) {
                        Text("Reviews Fetched").font(.caption).foregroundStyle(.secondary)
                        Text("\(reviews.count)").font(.title.bold())
                    }
                }
                .padding(.vertical, 8)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            List(reviews) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(repeating: "★", count: review.attributes.rating)
                             + String(repeating: "☆", count: max(0, 5 - review.attributes.rating)))
                            .foregroundStyle(.yellow)
                        if let territory = review.attributes.territory {
                            Text(territory).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(review.attributes.createdDate).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let title = review.attributes.title, !title.isEmpty {
                        Text(title).font(.headline)
                    }
                    if let body = review.attributes.body {
                        Text(body).font(.body)
                    }
                    if let nickname = review.attributes.reviewerNickname {
                        Text("- \(nickname)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .task(id: app.id) { if reviews.isEmpty { await fetchReviews() } }
    }

    private func fetchReviews() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = AppStoreConnectClient(issuerId: account.issuerId, keyId: account.keyId, privateKeyPEM: account.privateKeyPEM)
            reviews = try await client.fetchAllReviews(appId: app.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
