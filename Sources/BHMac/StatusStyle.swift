import AppKit

/// Status-bar title colors per tier, and the health band colors, per spec §6.
/// Pure mappings — semantic system colors only, so they follow Dark Mode and
/// increased contrast without a hand-tuned hex anywhere — so they can be
/// tested without rendering anything.
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

    /// The status item's glyph, baked in its tier's color so the symbol and
    /// the number read as one object rather than a system icon next to a
    /// colored string. Non-template: the accent has to survive.
    static func statusSymbol(named name: String, tier: TempTier, pointSize: CGFloat) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium))
        else { return nil }
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSGraphicsContext.current?.compositingOperation = .sourceAtop
            color(for: tier).set()
            NSBezierPath(rect: rect).fill()
            return true
        }
        tinted.isTemplate = false
        return tinted
    }
}
