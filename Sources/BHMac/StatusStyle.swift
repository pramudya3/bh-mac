import AppKit

/// Status-bar title colors per tier, and the health band colors, per spec §6.
/// The menu-bar item itself takes no tier color (see `statusItemColor`).
/// Pure mappings — semantic system colors only, so they follow Dark Mode and
/// increased contrast without a hand-tuned hex anywhere — so they can be
/// tested without rendering anything.
@MainActor
enum StatusStyle {
    /// The status item's single color, for every tier including muted. The
    /// menu bar is glanced at dozens of times a day — the traffic light lives
    /// one click deep in the dropdown instead; the alarm never rides on the
    /// menu bar's color at a glance.
    static let statusItemColor = NSColor.labelColor

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

    /// A health band takes the same three alarm colors as the temperature
    /// tiers — one accent in the whole interface, spent where state is.
    static func color(for condition: HealthCondition) -> NSColor {
        switch condition {
        case .normal:
            return .systemGreen
        case .replaceSoon:
            return .systemOrange
        case .service:
            return .systemRed
        }
    }

    private struct CacheKey: Hashable {
        let name: String
        let pointSize: CGFloat
    }

    private static var symbolCache: [CacheKey: NSImage] = [:]

    /// The status item's glyph, baked in the neutral status color so the
    /// symbol and the reading read as one object. Cached to avoid
    /// rasterizing a new bitmap on every poll. Non-template: the color
    /// has to survive.
    static func statusSymbol(named name: String, pointSize: CGFloat) -> NSImage? {
        let key = CacheKey(name: name, pointSize: pointSize)
        if let cached = symbolCache[key] {
            return cached
        }
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium))
        else { return nil }
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSGraphicsContext.current?.compositingOperation = .sourceAtop
            statusItemColor.set()
            NSBezierPath(rect: rect).fill()
            return true
        }
        tinted.isTemplate = false
        symbolCache[key] = tinted
        return tinted
    }
}
