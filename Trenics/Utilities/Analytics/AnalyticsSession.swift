import Foundation
internal import Combine

extension APIAccount {
    /// All three fields are needed before any request can be signed.
    var isUsable: Bool {
        !issuerId.isEmpty && !keyId.isEmpty && !privateKeyPEM.isEmpty
    }
}

enum AnalyticsError: LocalizedError {
    case credentialsIncomplete
    case reportUnavailable(ReportMetric)
    case noInstances(ReportMetric)

    var errorDescription: String? {
        switch self {
        case .credentialsIncomplete:
            return "Add your App Store Connect API key before loading analytics."
        case .reportUnavailable(let metric):
            return "Apple isn't exposing a \"\(metric.displayName)\" report for this app yet. A newly created ONGOING request can take up to 48 hours to start producing data."
        case .noInstances(let metric):
            return "No \(metric.displayName.lowercased()) data has been generated yet for this app."
        }
    }
}

/// One per app, shared by all three analytics pages.
///
/// The "find or create the ONGOING request" and "list every report for this
/// app" calls are per-app, not per-metric — without this, bouncing between
/// Impressions → Retention → Impressions would redo the whole handshake each
/// time. Caching it here means a tab switch only costs the instance/segment
/// download, and even that is usually served from disk.
@MainActor
final class AnalyticsSession: ObservableObject {
    let app: AppResource
    let account: APIAccount

    private var client: AppStoreConnectClient?
    private var handshake: Task<Handshake, Error>?

    struct Handshake: Sendable {
        let requestId: String
        let reports: [AnalyticsReportResource]
    }

    init(app: AppResource, account: APIAccount) {
        self.app = app
        self.account = account
    }

    /// Reuses a single client so the JWT-signing inputs stay consistent.
    func makeClient() throws -> AppStoreConnectClient {
        guard account.isUsable else { throw AnalyticsError.credentialsIncomplete }
        if let client { return client }
        let created = AppStoreConnectClient(
            issuerId: account.issuerId,
            keyId: account.keyId,
            privateKeyPEM: account.privateKeyPEM
        )
        client = created
        return created
    }

    /// The reviews endpoints live on the account-scoped client.
    func makeAnalyticsClient() -> AnalyticsAPIClient {
        AnalyticsAPIClient(account: account)
    }

    /// Concurrent callers share one in-flight handshake rather than racing to
    /// create duplicate ONGOING requests.
    func ensureHandshake() async throws -> Handshake {
        if let handshake { return try await handshake.value }
        let client = try makeClient()
        let appId = app.id
        let task = Task<Handshake, Error> {
            let requestId = try await client.findOrCreateOngoingRequest(appId: appId)
            let reports = try await client.fetchReports(requestId: requestId)
            return Handshake(requestId: requestId, reports: reports)
        }
        handshake = task
        do {
            return try await task.value
        } catch {
            // Don't cache a failed handshake — the next attempt should retry.
            handshake = nil
            throw error
        }
    }

    /// Picks the report that best matches a metric, preferring earlier
    /// candidates (the "Detailed" variants carry the dimension columns the
    /// breakdown sections need).
    func report(for metric: ReportMetric) async throws -> AnalyticsReportResource {
        let reports = try await ensureHandshake().reports
        let scoped = reports.filter { report in
            guard let category = metric.category else { return true }
            return report.attributes.category.caseInsensitiveCompare(category) == .orderedSame
        }
        let pool = scoped.isEmpty ? reports : scoped

        for candidate in metric.reportNameCandidates {
            let needle = candidate.lowercased()
            if let match = pool.first(where: { $0.attributes.name.lowercased() == needle }) {
                return match
            }
            if let match = pool.first(where: { $0.attributes.name.lowercased().contains(needle) }) {
                return match
            }
        }
        throw AnalyticsError.reportUnavailable(metric)
    }

    /// Clears the handshake so the next load re-runs it (after a credential change).
    func reset() {
        handshake?.cancel()
        handshake = nil
        client = nil
    }
}
