import Foundation
internal import Combine

/// Resolves and remembers each app's icon URL.
///
/// The icon comes from the app's newest build, so finding it costs a request
/// per app. Icons change at most once a release, so the resolved URL is cached
/// on disk for a week rather than for the day like the analytics figures.
///
/// A nil result is cached too: an app with no uploaded build will never have
/// artwork, and retrying that on every scroll would be a request per card.
@MainActor
final class AppIconStore: ObservableObject {
    static let shared = AppIconStore()

    /// App id → resolved URL, or nil when the app has no artwork.
    @Published private(set) var urls: [String: URL?] = [:]

    private var inFlight: Set<String> = []
    private let cache = AnalyticsCacheStore.shared
    private let freshness: TimeInterval = 7 * 24 * 60 * 60
    /// Comfortably above @3x for the 48pt tiles, and small enough to stay cheap.
    private let pixelSize = 180

    func url(for appId: String) -> URL? {
        urls[appId] ?? nil
    }

    func isResolved(_ appId: String) -> Bool {
        urls[appId] != nil
    }

    func loadIfNeeded(appId: String, account: APIAccount) async {
        guard urls[appId] == nil, !inFlight.contains(appId) else { return }
        inFlight.insert(appId)
        defer { inFlight.remove(appId) }

        let key = "\(appId)-icon-url"
        if let cached = await cache.load(String.self, key: key),
           AnalyticsCacheStore.isFresh(cached.fetchedAt, within: freshness) {
            // An empty string is how "checked, no artwork" is stored.
            urls[appId] = cached.value.isEmpty ? URL?.none : URL(string: cached.value)
            return
        }

        let client = AppStoreConnectClient(
            issuerId: account.issuerId,
            keyId: account.keyId,
            privateKeyPEM: account.privateKeyPEM
        )
        do {
            let asset = try await client.fetchAppIcon(appId: appId)
            let resolved = asset?.url(size: pixelSize)
            urls[appId] = resolved
            await cache.save(resolved?.absoluteString ?? "", key: key)
        } catch {
            // Leave it unresolved so a later pull-to-refresh can retry, but
            // don't hammer the endpoint in the meantime.
            urls[appId] = URL?.none
        }
    }
}
