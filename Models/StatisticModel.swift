import Foundation

// MARK: - Generic JSON:API envelopes

struct JSONAPIResponse<T: Codable>: Codable {
    let data: [T]
    let links: PagingLinks?
}

struct JSONAPISingleResponse<T: Codable>: Codable {
    let data: T
}

struct PagingLinks: Codable {
    let next: String?
}

// MARK: - Apps

struct AppResource: Codable, Identifiable, Hashable {
    let id: String
    let attributes: AppAttributes

    static func == (lhs: AppResource, rhs: AppResource) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AppAttributes: Codable, Hashable {
    let name: String
    let bundleId: String?
    let sku: String?
}

// MARK: - Customer Reviews

struct CustomerReview: Codable, Identifiable {
    let id: String
    let attributes: ReviewAttributes
}

struct ReviewAttributes: Codable {
    let rating: Int
    let title: String?
    let body: String?
    let reviewerNickname: String?
    let createdDate: String
    let territory: String?
}

// MARK: - Analytics Report Requests

struct AnalyticsReportRequestResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportRequestAttributes?
}

struct AnalyticsReportRequestAttributes: Codable {
    let accessType: String
}

// MARK: - Analytics Reports

struct AnalyticsReportResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportAttributes
}

struct AnalyticsReportAttributes: Codable {
    let name: String
    let category: String
}

extension AnalyticsReportResource: Hashable {
    static func == (lhs: AnalyticsReportResource, rhs: AnalyticsReportResource) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Analytics Report Instances

struct AnalyticsReportInstanceResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportInstanceAttributes
}

struct AnalyticsReportInstanceAttributes: Codable {
    let granularity: String
    let processingDate: String
}

// MARK: - Analytics Report Segments

struct AnalyticsReportSegmentResource: Codable, Identifiable {
    let id: String
    let attributes: AnalyticsReportSegmentAttributes
}

struct AnalyticsReportSegmentAttributes: Codable {
    let url: String
    let sizeInBytes: Int?
    let checksum: String?
}

// MARK: - Parsed report table

struct ReportTable {
    let headers: [String]
    let rows: [[String]]
}

enum ReportParser {
    /// App Store Connect analytics reports are tab-separated.
    static func parseTSV(_ data: Data) -> ReportTable {
        guard let text = String(data: data, encoding: .utf8) else {
            return ReportTable(headers: [], rows: [])
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let headerLine = lines.first else { return ReportTable(headers: [], rows: []) }
        let headers = headerLine.components(separatedBy: "\t")
        let rows = lines.dropFirst().map { $0.components(separatedBy: "\t") }
        return ReportTable(headers: headers, rows: rows)
    }
}
