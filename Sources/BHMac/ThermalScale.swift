import Foundation

/// Where a live temperature sits against the app's two thresholds, as pure
/// geometry: the ruler's domain, the needle's fraction, the boundary ticks,
/// the lit band. Strings and numbers only — the AppKit ruler that draws this
/// is a separate layer (see `ThermalScaleRowView`), and every number here is
/// unit-tested.
enum ThermalScale {
    /// Ruler domain in °C. Wide enough that a charging MacBook (30–45 °C)
    /// always lands inside it, narrow enough that the 35 and 42 °C boundaries
    /// stay visibly apart.
    static let domainLow: Double = 20
    static let domainHigh: Double = 50

    /// Position of a reading inside the ruler: 0 at the left edge, 1 at the
    /// right. Readings outside the domain clamp to the nearer end rather than
    /// disappearing off the track.
    static func fraction(_ celsius: Double) -> Double {
        let span = domainHigh - domainLow
        guard span > 0 else { return 0 }
        return min(max((celsius - domainLow) / span, 0), 1)
    }

    /// The two threshold ticks, in ruler order, each drawn as: the value it
    /// marks, its position on the ruler, and the label under it.
    static var ticks: [(value: Double, fraction: Double, label: String)] {
        let warm = Thresholds.warmC
        let hot = Thresholds.hotC
        return [
            (warm, fraction(warm), "\(Int(warm))°"),
            (hot, fraction(hot), "\(Int(hot))°"),
        ]
    }

    /// The stretch of ruler a tier owns: its fraction from its lower threshold
    /// to its upper one (the hot tier runs to the right edge, and anything
    /// above still reads inside it). The muted tier owns nothing — an
    /// unavailable reading lights no band.
    static func band(_ tier: TempTier) -> ClosedRange<Double> {
        switch tier {
        case .normal: return 0 ... fraction(Thresholds.warmC)
        case .warm: return fraction(Thresholds.warmC) ... fraction(Thresholds.hotC)
        case .hot: return fraction(Thresholds.hotC) ... 1
        case .muted: return fraction(domainHigh) ... fraction(domainHigh)
        }
    }
}
