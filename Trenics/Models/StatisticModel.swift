import Foundation

// MARK: - Generic JSON:API envelopes

nonisolated struct JSONAPIResponse<T: Codable>: Codable {
    let data: [T]
    let links: PagingLinks?
}

nonisolated struct JSONAPISingleResponse<T: Codable>: Codable {
    let data: T
}

/// Relationship endpoints (e.g. a review's developer response) return
/// `{"data": null}` rather than a 404 when nothing exists yet.
nonisolated struct JSONAPIOptionalSingleResponse<T: Codable>: Codable {
    let data: T?
}

nonisolated struct PagingLinks: Codable {
    let next: String?
}

// MARK: - Apps

nonisolated struct AppResource: Codable, Identifiable, Hashable {
    let id: String
    let attributes: AppAttributes

    static func == (lhs: AppResource, rhs: AppResource) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

nonisolated struct AppAttributes: Codable, Hashable {
    let name: String
    let bundleId: String?
    let sku: String?
}

// MARK: - Customer Reviews

nonisolated struct CustomerReview: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let attributes: ReviewAttributes

    static func == (lhs: CustomerReview, rhs: CustomerReview) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

nonisolated struct ReviewAttributes: Codable, Hashable, Sendable {
    let rating: Int
    let title: String?
    let body: String?
    let reviewerNickname: String?
    let createdDate: String
    let territory: String?
}

// MARK: - Developer Responses

nonisolated struct CustomerReviewResponseResource: Codable, Identifiable, Sendable {
    let id: String
    let attributes: CustomerReviewResponseAttributes?
}

nonisolated struct CustomerReviewResponseAttributes: Codable, Sendable {
    let responseBody: String?
    let lastModifiedDate: String?
    let state: String?
}

// MARK: - Analytics Report Requests

nonisolated struct AnalyticsReportRequestResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportRequestAttributes?
}

nonisolated struct AnalyticsReportRequestAttributes: Codable {
    let accessType: String
}

// MARK: - Analytics Reports

nonisolated struct AnalyticsReportResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportAttributes
}

nonisolated struct AnalyticsReportAttributes: Codable {
    let name: String
    let category: String
}

nonisolated extension AnalyticsReportResource: Hashable {
    static func == (lhs: AnalyticsReportResource, rhs: AnalyticsReportResource) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Analytics Report Instances

nonisolated struct AnalyticsReportInstanceResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportInstanceAttributes
}

nonisolated struct AnalyticsReportInstanceAttributes: Codable {
    let granularity: String
    let processingDate: String
}

// MARK: - Analytics Report Segments

nonisolated struct AnalyticsReportSegmentResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportSegmentAttributes
}

nonisolated struct AnalyticsReportSegmentAttributes: Codable {
    let url: String
    let sizeInBytes: Int?
    let checksum: String?
}

// MARK: - Parsed report table

nonisolated struct ReportTable: Codable, Sendable, Equatable {
    let headers: [String]
    let rows: [[String]]

    static let empty = ReportTable(headers: [], rows: [])
    var isEmpty: Bool { rows.isEmpty }
}

nonisolated enum ReportParser {
    /// App Store Connect analytics reports are tab-separated.
    static func parseTSV(_ data: Data) -> ReportTable {
        guard let text = String(data: data, encoding: .utf8) else { return .empty }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let headerLine = lines.first else { return .empty }
        let headers = headerLine.components(separatedBy: "\t").map(Self.trim)
        let rows = lines.dropFirst().map { $0.components(separatedBy: "\t").map(Self.trim) }
        return ReportTable(headers: headers, rows: rows)
    }

    /// Segments of the same instance share a header row, so only the rows are merged.
    static func merge(_ tables: [ReportTable]) -> ReportTable {
        guard let first = tables.first(where: { !$0.headers.isEmpty }) else { return .empty }
        return ReportTable(headers: first.headers, rows: tables.flatMap(\.rows))
    }

    private static func trim(_ field: String) -> String {
        field.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
