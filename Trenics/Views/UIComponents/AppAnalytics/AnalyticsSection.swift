import SwiftUI

struct AnalyticsSection<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String?
    var showsDivider: Bool = true
    @ViewBuilder var content: Content
    /// Sits at the trailing edge of the header, level with the title.
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsDivider = showsDivider
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                accessory
            }
            content
            if showsDivider {
                Divider()
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension AnalyticsSection where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            showsDivider: showsDivider,
            content: content,
            accessory: { EmptyView() }
        )
    }
}
