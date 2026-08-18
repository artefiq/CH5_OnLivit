import SwiftUI

struct BreakdownListView: View {
    let items: [BreakdownItem]
    var emptyMessage: String = "No breakdown available in this report."

    private var total: Double { items.reduce(0) { $0 + $1.value } }

    var body: some View {
        if items.isEmpty {
            Text(emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    VStack(spacing: 4) {
                        HStack {
                            Text(item.label)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(item.value.compactFormatted)
                                .font(.subheadline.bold())
                            Text(item.share(of: total).percentFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        ProgressView(value: item.share(of: total))
                            .tint(Color("primaryPurple"))
                    }
                }
            }
        }
    }
}
