import SwiftUI

/// Icon, name and when the figures were last pulled, above the metric cards.
struct AppDetailHeader: View {
    let app: AppResource
    let account: APIAccount?
    let lastUpdated: Date?

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(appId: app.id, account: account, size: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.attributes.name)
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                // Real freshness rather than a fixed "just now" — the figures
                // behind these cards are cached for the day, so claiming they
                // were updated this second would be untrue most of the time.
                Text(Self.freshness(lastUpdated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func freshness(_ date: Date?) -> String {
        guard let date else { return "Not loaded yet" }
        if Date().timeIntervalSince(date) < 120 { return "Updated just now" }
        if Calendar.current.isDateInToday(date) {
            return "Updated today at " + date.formatted(date: .omitted, time: .shortened)
        }
        return "Updated " + date.formatted(.relative(presentation: .named))
    }
}
