import Foundation
import CryptoKit

/// Covers the App Store Connect endpoints this dashboard needs beyond the
/// Analytics Reports pipeline your `AppStoreConnectClient` already
/// implements (report requests → reports → instances → segments):
///
///   GET  /v1/apps/{appId}/customerReviews
///   GET  /v1/appStoreVersions/{versionId}/customerReviews
///   GET  /v1/customerReviews/{reviewId}/response
///   GET  /v1/salesReports
///
/// It signs its own ES256 JWT so it doesn't depend on `AppStoreConnectClient`'s
/// private internals. If your existing client already exposes a shared
/// authorized-request helper, swap the auth/networking code below for that
/// and keep just the endpoint-specific methods.
struct AnalyticsAPIClient {
    let account: APIAccount

    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let session = URLSession.shared

    // MARK: - JWT auth

    private func makeToken() throws -> String {
        let header: [String: Any] = ["alg": "ES256", "kid": account.keyId, "typ": "JWT"]
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": account.issuerId,
            "iat": now,
            "exp": now + 1200,
            "aud": "appstoreconnect-v1"
        ]
        let headerJSON = try JSONSerialization.data(withJSONObject: header)
        let payloadJSON = try JSONSerialization.data(withJSONObject: payload)
        let signingInput = "\(base64URL(headerJSON)).\(base64URL(payloadJSON))"
        let key = try P256.Signing.PrivateKey(pemRepresentation: account.privateKeyPEM)
        let signature = try key.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(base64URL(signature.rawRepresentation))"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Customer reviews

    /// GET /v1/apps/{appId}/customerReviews
    func fetchAppReviews(appId: String, limit: Int = 200) async throws -> [CustomerReviewResource] {
        try await fetchAllPages(
            path: "v1/apps/\(appId)/customerReviews",
            queryItems: [
                URLQueryItem(name: "sort", value: "-createdDate"),
                URLQueryItem(name: "limit", value: "\(min(limit, 200))")
            ],
            limit: limit
        )
    }

    /// GET /v1/appStoreVersions/{versionId}/customerReviews
    func fetchVersionReviews(versionId: String, limit: Int = 200) async throws -> [CustomerReviewResource] {
        try await fetchAllPages(
            path: "v1/appStoreVersions/\(versionId)/customerReviews",
            queryItems: [
                URLQueryItem(name: "sort", value: "-createdDate"),
                URLQueryItem(name: "limit", value: "\(min(limit, 200))")
            ],
            limit: limit
        )
    }

    /// GET /v1/customerReviews/{reviewId}/response — returns nil if the
    /// developer hasn't responded yet (Apple returns an empty `data`).
    func fetchReviewResponse(reviewId: String) async throws -> CustomerReviewResponseResource? {
        let response: AnalyticsJSONAPISingleResponse<CustomerReviewResponseResource>? =
            try await jsonAPISingleRequest(path: "v1/customerReviews/\(reviewId)/response")
        return response?.data
    }

    private func fetchAllPages(
        path: String,
        queryItems: [URLQueryItem],
        limit: Int
    ) async throws -> [CustomerReviewResource] {
        var results: [CustomerReviewResource] = []
        var nextPath: String? = path
        var nextQuery: [URLQueryItem]? = queryItems

        while let currentPath = nextPath, results.count < limit {
            let page: AnalyticsJSONAPIListResponse<CustomerReviewResource> = try await jsonAPIListRequest(
                path: currentPath,
                queryItems: nextQuery ?? []
            )
            results.append(contentsOf: page.data)

            if let nextURLString = page.links?.next, let url = URL(string: nextURLString) {
                nextPath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
                nextQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            } else {
                nextPath = nil
            }
        }
        return Array(results.prefix(limit))
    }

    // MARK: - Sales reports (GET /v1/salesReports)

    /// Downloads the gzip-compressed TSV sales report and parses it into a
    /// `ReportTable`, same shape as the analytics reports use. Not wired
    /// into the dashboard UI yet — hook it up to a "Revenue" tab the same
    /// way the analytics categories are wired, if/when you need it.
    func fetchSalesReport(
        vendorNumber: String,
        reportDate: String,          // "2026-08-14" for DAILY, "2026-08" for MONTHLY
        frequency: String = "DAILY",
        reportType: String = "SALES",
        reportSubType: String = "SUMMARY",
        version: String = "1_0"
    ) async throws -> ReportTable {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v1/salesReports"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "filter[frequency]", value: frequency),
            URLQueryItem(name: "filter[reportDate]", value: reportDate),
            URLQueryItem(name: "filter[reportType]", value: reportType),
            URLQueryItem(name: "filter[reportSubType]", value: reportSubType),
            URLQueryItem(name: "filter[vendorNumber]", value: vendorNumber),
            URLQueryItem(name: "filter[version]", value: version)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/a-gzip", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)

        let decompressed = try Gzip.decompress(data)
        return ReportParser.parseTSV(decompressed)
    }

    // MARK: - Generic JSON:API plumbing

    private func jsonAPIListRequest<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> AnalyticsJSONAPIListResponse<T> {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)

        do {
            return try makeDecoder().decode(AnalyticsJSONAPIListResponse<T>.self, from: data)
        } catch {
            throw AnalyticsAPIError.decoding(error)
        }
    }

    private func jsonAPISingleRequest<T: Decodable>(path: String) async throws -> AnalyticsJSONAPISingleResponse<T>? {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return nil
        }
        try validate(response, data: data)

        do {
            return try makeDecoder().decode(AnalyticsJSONAPISingleResponse<T>.self, from: data)
        } catch {
            throw AnalyticsAPIError.decoding(error)
        }
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnalyticsAPIError.http(code, body)
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum AnalyticsAPIError: LocalizedError {
    case http(Int, String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            return "App Store Connect API error (\(code)): \(body)"
        case .decoding(let error):
            return "Couldn't decode the API response: \(error.localizedDescription)"
        }
    }
}

// MARK: - JSON:API envelope helpers

struct AnalyticsJSONAPIListResponse<T: Decodable>: Decodable {
    let data: [T]
    let links: Links?

    struct Links: Decodable {
        let next: String?
    }
}

struct AnalyticsJSONAPISingleResponse<T: Decodable>: Decodable {
    let data: T
}
