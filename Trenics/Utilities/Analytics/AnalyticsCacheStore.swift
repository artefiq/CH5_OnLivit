import Foundation

/// A cached value plus the moment it was fetched.
nonisolated struct CachedPayload<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let fetchedAt: Date
}

actor AnalyticsCacheStore {
    static let shared = AnalyticsCacheStore()

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryName: String = "AnalyticsCache") {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = caches.appendingPathComponent(directoryName, isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: Freshness

    /// True when the value was fetched earlier today — the rule for report data.
    nonisolated static func isFreshForToday(_ fetchedAt: Date) -> Bool {
        Calendar.current.isDateInToday(fetchedAt)
    }

    /// True when the value is younger than `interval` — used for reviews, which
    /// post at any hour rather than on Apple's nightly schedule.
    nonisolated static func isFresh(_ fetchedAt: Date, within interval: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < interval
    }

    // MARK: Read / write

    func load<Value: Codable & Sendable>(_ type: Value.Type, key: String) -> CachedPayload<Value>? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(CachedPayload<Value>.self, from: data)
    }

    @discardableResult
    func save<Value: Codable & Sendable>(_ value: Value, key: String) -> Date {
        let stampedAt = Date()
        let payload = CachedPayload(value: value, fetchedAt: stampedAt)
        if let data = try? encoder.encode(payload) {
            try? data.write(to: fileURL(for: key), options: .atomic)
        }
        return stampedAt
    }

    func invalidate(key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    /// Drops every cached entry for one app — used when credentials change.
    func invalidateAll(appId: String) {
        let prefix = sanitize(appId)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where url.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Keys

    nonisolated static func key(appId: String, metric: ReportMetric, range: AnalyticsTimeRange) -> String {
        "\(appId)-\(metric.rawValue)-\(range.rawValue)"
    }

    nonisolated static func reviewsKey(appId: String) -> String {
        "\(appId)-reviews"
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(sanitize(key)).json")
    }

    private nonisolated func sanitize(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }
}
