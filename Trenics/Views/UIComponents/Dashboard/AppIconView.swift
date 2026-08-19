import SwiftUI

/// An app's real icon, falling back to a glyph tile.
///
/// Not every app has artwork — an app with no uploaded build has none — so the
/// fallback is the normal case rather than an error state, and it renders at
/// the same size so the row never changes height.
struct AppIconView: View {
    let appId: String
    let account: APIAccount?
    var fallbackSystemName: String = "circle.hexagongrid.fill"
    var size: CGFloat = 48
    var tint: Color = .orange

    @StateObject private var store = AppIconStore.shared

    private var cornerRadius: CGFloat { size * 0.24 }

    var body: some View {
        Group {
            if let url = store.url(for: appId) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        placeholder
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: appId) {
            guard let account else { return }
            await store.loadIfNeeded(appId: appId, account: account)
        }
    }

    private var fallback: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(tint.opacity(tint == .white ? 0.2 : 0.12))
            .overlay(
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(tint)
            )
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.secondary.opacity(0.15))
    }
}
