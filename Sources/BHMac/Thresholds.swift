import Foundation

enum TempTier: String {
    case muted, normal, warm, hot
}

/// Tunable constants for the app. Boundary values come from spec §6:
/// temperature tiers and health label bands.
enum Thresholds {
    /// Menu bar refresh cadence in seconds.
    static let pollInterval: TimeInterval = 10

    /// Above this temperature (inclusive) is Warm; above it stays Normal.
    static let warmC: Double = 35.0

    /// Above this temperature (inclusive) is Hot.
    static let hotC: Double = 42.0

    /// Health percent at/above this is "Normal".
    static let healthNormalMin: Double = 80.0

    /// Health percent at/above this (below healthNormalMin) is "Replace Soon".
    static let healthReplaceMin: Double = 60.0

    /// Temperature tier for a battery temperature in degrees Celsius.
    /// Spec §6: ≤ 35.0 Normal, ≤ 42.0 Warm, above 42.0 Hot.
    static func temperatureTier(_ celsius: Double) -> TempTier {
        if celsius <= warmC { return .normal }
        if celsius <= hotC { return .warm }
        return .hot
    }

    /// Human label for battery health percent (FullChargeCapacity / DesignCapacity).
    static func healthLabel(_ percent: Double) -> String {
        if percent >= healthNormalMin { return "Normal" }
        if percent >= healthReplaceMin { return "Replace Soon" }
        return "Service"
    }
}
