import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .httpError(let code, let message): return "HTTP \(code): \(message)"
        case .decodingError(let err): return "Failed to decode response: \(err.localizedDescription)"
        case .noData: return "No data returned."
        }
    }
}

final class AppStoreConnectClient {
    private let issuerId: String
    private let keyId: String
    private let privateKeyPEM: String
    private let baseURL = "https://api.appstoreconnect.apple.com/v1"

    init(issuerId: String, keyId: String, privateKeyPEM: String) {
        self.issuerId = issuerId
        self.keyId = keyId
        self.privateKeyPEM = privateKeyPEM
    }

    private func makeToken() throws -> String {
        try AppStoreConnectJWT.generate(issuerId: issuerId, keyId: keyId, privateKeyPEM: privateKeyPEM)
    }

    private func request(_ urlString: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(http.statusCode, message)
        }
        return data
    }

    // MARK: Apps

    func fetchAllApps(maxPages: Int = 10) async throws -> [AppResource] {
        var results: [AppResource] = []
        var urlString: String? = "\(baseURL)/apps?limit=200&sort=name"
        var page = 0
        while let current = urlString, page < maxPages {
            let data = try await request(current)
            let decoded = try decode(JSONAPIResponse<AppResource>.self, from: data)
            results.append(contentsOf: decoded.data)
            urlString = decoded.links?.next
            page += 1
        }
        return results
    }

    // MARK: Ratings & Reviews

    func fetchAllReviews(appId: String, maxPages: Int = 10) async throws -> [CustomerReview] {
        var results: [CustomerReview] = []
        var urlString: String? = "\(baseURL)/apps/\(appId)/customerReviews?limit=200&sort=-createdDate"
        var page = 0
        while let current = urlString, page < maxPages {
            let data = try await request(current)
            let decoded = try decode(JSONAPIResponse<CustomerReview>.self, from: data)
            results.append(contentsOf: decoded.data)
            urlString = decoded.links?.next
            page += 1
        }
        return results
    }

    // MARK: App Analytics
    // Flow per Apple's docs: create/reuse an ONGOING analyticsReportRequest for the app,
    // list the reports it makes available, list instances (dated report runs) for a report,
    // then list & download the (gzip, tab-separated) segments for the latest instance.

    func findOrCreateOngoingRequest(appId: String) async throws -> String {
        let listData = try await request("\(baseURL)/apps/\(appId)/analyticsReportRequests")
        let existing = try decode(JSONAPIResponse<AnalyticsReportRequestResource>.self, from: listData)
        if let ongoing = existing.data.first(where: { $0.attributes?.accessType == "ONGOING" }) {
            return ongoing.id
        }

        let body: [String: Any] = [
            "data": [
                "type": "analyticsReportRequests",
                "attributes": ["accessType": "ONGOING"],
                "relationships": [
                    "app": ["data": ["type": "apps", "id": appId]]
                ]
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let created = try await request("\(baseURL)/analyticsReportRequests", method: "POST", body: bodyData)
        let decoded = try decode(JSONAPISingleResponse<AnalyticsReportRequestResource>.self, from: created)
        return decoded.data.id
    }

    func fetchReports(requestId: String) async throws -> [AnalyticsReportResource] {
        let data = try await request("\(baseURL)/analyticsReportRequests/\(requestId)/reports?limit=200")
        return try decode(JSONAPIResponse<AnalyticsReportResource>.self, from: data).data
    }

    func fetchInstances(
        reportId: String,
        granularity: ReportGranularity = .daily,
        limit: Int = 30
    ) async throws -> [AnalyticsReportInstanceResource] {
        let data = try await request(
            "\(baseURL)/analyticsReports/\(reportId)/instances?filter[granularity]=\(granularity.rawValue)&limit=\(limit)"
        )
        return try decode(JSONAPIResponse<AnalyticsReportInstanceResource>.self, from: data).data
    }

    func fetchSegments(instanceId: String) async throws -> [AnalyticsReportSegmentResource] {
        let data = try await request("\(baseURL)/analyticsReportInstances/\(instanceId)/segments")
        return try decode(JSONAPIResponse<AnalyticsReportSegmentResource>.self, from: data).data
    }

    func downloadSegment(url: String) async throws -> Data {
        // Segment URLs are pre-signed; no Authorization header needed or wanted here.
        guard let u = URL(string: url) else { throw APIError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: u)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, "Segment download failed")
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
