import SwiftUI

/// One of the three entry points on an app's analytics hub. The description is
/// fixed copy explaining what the metric is, not a figure — the numbers live
/// on the page behind it, and this screen's job is to say which page to open.
struct MetricNavCard: View {
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.primaryPurple.opacity(0.1), radius: 6, y: 1)
    }
}
