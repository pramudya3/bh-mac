import AppKit

/// Menu-bar title colors per temperature tier (spec §6). Pure mapping so
/// it can be tested without rendering anything.
enum StatusStyle {
    static func color(for tier: TempTier) -> NSColor {
        switch tier {
        case .muted:
            return .secondaryLabelColor
        case .normal:
            return .systemGreen
        case .warm:
            return .systemOrange
        case .hot:
            return .systemRed
        }
    }
}
