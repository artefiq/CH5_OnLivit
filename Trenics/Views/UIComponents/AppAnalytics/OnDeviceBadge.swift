import SwiftUI

struct OnDeviceBadge: View {
    var body: some View {
        Label("Generated on-device", systemImage: "iphone.gen3")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
