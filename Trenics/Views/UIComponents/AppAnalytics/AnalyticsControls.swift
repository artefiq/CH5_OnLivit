import SwiftUI

struct TimeRangePicker: View {
    @Binding var range: AnalyticsTimeRange

    var body: some View {
        Picker("Time range", selection: $range) {
            ForEach(AnalyticsTimeRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct LastUpdatedLabel: View {
    let date: Date?

    var body: some View {
        if let date {
            Text("Updated \(Self.phrase(for: date))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private static func phrase(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "today at " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.relative(presentation: .named))
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
    }
}

struct AnalyticsEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
