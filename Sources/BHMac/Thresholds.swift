import Foundation

enum TempTier: String {
    case muted, normal, warm, hot

    /// The tier as a word, for VoiceOver and for the menu's own copy — the
    /// color is the alarm, never the message.
    var name: String {
        switch self {
        case .muted: return "No reading"
        case .normal: return "Normal"
        case .warm: return "Warm"
        case .hot: return "Hot"
        }
    }
}

/// Health band, from FullChargeCapacity / DesignCapacity. Separate from the
/// temperature tier because the two signals never share a reading: a cold
/// battery can still be worn out, and a fresh one can run hot.
enum HealthCondition: String, CaseIterable {
    case normal, replaceSoon, service

    /// The word the menu shows for this band.
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .replaceSoon: return "Replace Soon"
        case .service: return "Service"
        }
    }
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

    /// Health band for a battery health percent (FullChargeCapacity / DesignCapacity).
    static func healthCondition(_ percent: Double) -> HealthCondition {
        if percent >= healthNormalMin { return .normal }
        if percent >= healthReplaceMin { return .replaceSoon }
        return .service
    }

    /// Human band name for battery health percent (FullChargeCapacity / DesignCapacity).
    static func healthLabel(_ percent: Double) -> String {
        healthCondition(percent).label
    }
}
