import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
            }
        }
        .foregroundStyle(.yellow)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}

struct RatingHistogramView: View {
    let buckets: [RatingBucket]

    private var total: Int { max(buckets.reduce(0) { $0 + $1.count }, 1) }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(buckets) { bucket in
                HStack(spacing: 8) {
                    Text("\(bucket.stars)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 10)
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    ProgressView(value: Double(bucket.count) / Double(total))
                        .tint(Color("primaryPurple"))
                    Text("\(bucket.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

struct SentimentDonutView: View {
    let counts: [ReviewSentiment: Int]

    private var total: Double {
        Double(counts.values.reduce(0, +))
    }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text("\(Int(total))")
                        .font(.headline)
                    Text("reviews")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ReviewSentiment.allCases, id: \.self) { sentiment in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Self.color(for: sentiment))
                            .frame(width: 8, height: 8)
                        Text(sentiment.label)
                            .font(.caption)
                        Spacer()
                        Text("\(counts[sentiment] ?? 0)")
                            .font(.caption.bold().monospacedDigit())
                    }
                }
            }
        }
    }

    private var segments: [(start: Double, end: Double, color: Color)] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return ReviewSentiment.allCases.compactMap { sentiment in
            let share = Double(counts[sentiment] ?? 0) / total
            guard share > 0 else { return nil }
            let segment = (start: cursor, end: cursor + share, color: Self.color(for: sentiment))
            cursor += share
            return segment
        }
    }

    static func color(for sentiment: ReviewSentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}
