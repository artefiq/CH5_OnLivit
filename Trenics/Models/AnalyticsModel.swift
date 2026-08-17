import SwiftUI

// MARK: - Dashboard categories

/// Each case maps to one tab in the dashboard. The analytics categories
/// (impressions/downloads/retention/deletions) all pull from Apple's
/// Analytics Reports pipeline; `.reviews` uses the Customer Reviews API.
enum AnalyticsCategory: String, CaseIterable, Identifiable {
    case impressions
    case downloads
    case retention
    case deletions
    case reviews

    var id: String { rawValue }

    var title: String {
        switch self {
        case .impressions: return "Impressions"
        case .downloads: return "Downloads"
        case .retention: return "Retention"
        case .deletions: return "Deletions"
        case .reviews: return "Reviews & Ratings"
        }
    }

    var systemImage: String {
        switch self {
        case .impressions: return "eye.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .retention: return "arrow.triangle.2.circlepath"
        case .deletions: return "trash.fill"
        case .reviews: return "star.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .impressions: return .blue
        case .downloads: return .green
        case .retention: return .purple
        case .deletions: return .red
        case .reviews: return .orange
        }
    }

    /// Keywords used to find the right report(s) inside the full list
    /// returned by `/v1/analyticsReportRequests/{id}/reports`. As of 2026
    /// Apple's standard reports are named things like "App Store Discovery
    /// and Engagement Report" (impressions + downloads) and "App Store
    /// Installation and Deletion Standard/Detailed" (installs + deletions).
    /// Matching by keyword instead of an exact name keeps this working even
    /// if Apple tweaks report names.
    var reportNameKeywords: [String] {
        switch self {
        case .impressions: return ["impression", "discovery and engagement"]
        case .downloads: return ["download", "discovery and engagement", "installation and deletion"]
        case .retention: return ["retention"]
        case .deletions: return ["deletion", "uninstall", "installation and deletion"]
        case .reviews: return []
        }
    }

    /// Keywords used to guess which numeric column in the parsed TSV holds
    /// the metric we want to chart for this category.
    var metricColumnKeywords: [String] {
        switch self {
        case .impressions: return ["impression"]
        case .downloads: return ["download", "install", "units", "count"]
        case .retention: return ["retain", "retention", "rate"]
        case .deletions: return ["delet", "uninstall"]
        case .reviews: return []
        }
    }
}

// MARK: - Customer reviews (GET /v1/apps/{appId}/customerReviews,
// GET /v1/appStoreVersions/{versionId}/customerReviews)

struct CustomerReviewResource: Identifiable, Hashable, Codable {
    let id: String
    let attributes: Attributes

    struct Attributes: Hashable, Codable {
        let rating: Int
        let title: String?
        let body: String
        let reviewerNickname: String?
        let createdDate: Date
        let territory: String?
    }
}

// MARK: - Developer response (GET /v1/customerReviews/{reviewId}/response)

struct CustomerReviewResponseResource: Identifiable, Hashable, Codable {
    let id: String
    let attributes: Attributes

    struct Attributes: Hashable, Codable {
        let responseBody: String
        let lastModifiedDate: Date
        let state: String
    }
}

/// Drives the summary card + star histogram on the Reviews & Ratings tab.
struct ReviewsSummary {
    let reviews: [CustomerReviewResource]

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.attributes.rating }
        return Double(total) / Double(reviews.count)
    }

    var countsByStar: [Int: Int] {
        var counts: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in reviews {
            counts[review.attributes.rating, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Chart-friendly aggregation of a parsed analytics report

struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum ReportAggregation {

    /// Sums the best-matching metric column per calendar day so it can be
    /// plotted as a trend line, regardless of which extra dimension columns
    /// (country, device, app version, etc.) the raw report includes.
    static func dailyMetrics(from table: ReportTable, category: AnalyticsCategory) -> [DailyMetric] {
        guard let dateIndex = table.headers.firstIndex(where: { $0.lowercased().contains("date") }),
              let metricIndex = bestMetricColumnIndex(table, category: category) else {
            return []
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = TimeZone(identifier: "UTC")
        let isoFormatter = ISO8601DateFormatter()

        var sums: [Date: Double] = [:]
        for row in table.rows {
            guard let dateString = element(row, dateIndex) else { continue }
            let date = dayFormatter.date(from: dateString) ?? isoFormatter.date(from: dateString)
            guard let date else { continue }
            let rawValue = element(row, metricIndex) ?? "0"
            sums[date, default: 0] += Double(rawValue) ?? 0
        }
        return sums.map { DailyMetric(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    static func bestMetricColumnIndex(_ table: ReportTable, category: AnalyticsCategory) -> Int? {
        let keywords = category.metricColumnKeywords
        for (index, header) in table.headers.enumerated() {
            let lower = header.lowercased()
            if keywords.contains(where: { lower.contains($0) }) {
                return index
            }
        }
        // Fall back to the first column that actually parses as a number.
        guard let firstRow = table.rows.first else { return nil }
        return firstRow.indices.first { Double(firstRow[$0]) != nil }
    }

    private static func element(_ row: [String], _ index: Int) -> String? {
        guard row.indices.contains(index) else { return nil }
        return row[index]
    }
}
