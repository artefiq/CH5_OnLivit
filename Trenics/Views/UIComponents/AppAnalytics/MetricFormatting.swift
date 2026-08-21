import SwiftUI

extension Double {
    var compactFormatted: String {
        let value = abs(self)
        switch value {
        case 1_000_000_000...:
            return String(format: "%.1fB", self / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", self / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", self / 1_000)
        case 0..<10 where self != self.rounded():
            return String(format: "%.1f", self)
        default:
            return String(format: "%.0f", self)
        }
    }

    var percentFormatted: String { String(format: "%.1f%%", self * 100) }
}
