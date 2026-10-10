import Foundation
import IOKit

/// Seam between the app and the IOKit registry. Protocol so the AppDelegate
/// (and future tests) can substitute a fake; the real implementation is the
/// only place that touches IOKit.
protocol BatteryReading {
    /// Returns nil only when no battery service exists at all (desktop Mac).
    /// A present-but-unreadable battery yields an all-nil snapshot instead,
    /// so the UI shows "—" / N/A rows rather than a false "No Battery".
    func readSnapshot() -> BatterySnapshot?
}

final class IOKitBatteryReader: BatteryReading {
    func readSnapshot() -> BatterySnapshot? {
        let battery = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceNameMatching("AppleSmartBattery")
        )
        let pack = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceNameMatching("AppleSmartBatteryPack")
        )
        defer {
            if battery != 0 { IOObjectRelease(battery) }
            if pack != 0 { IOObjectRelease(pack) }
        }
        // 0 handle = no match — genuinely no battery on this machine.
        guard battery != 0 || pack != 0 else {
            return nil
        }

        let merged = Self.mergedProperties(
            service: battery != 0 ? properties(of: battery) : nil,
            pack: pack != 0 ? properties(of: pack) : nil
        )
        return BatterySnapshot.parse(from: merged)
    }

    /// Merges the pack's `BatteryData` over the service's. Pure and internal
    /// so the merge rules (pack wins; service-only keys survive) are testable
    /// without touching the registry.
    static func mergedProperties(
        service: [String: Any]?,
        pack: [String: Any]?
    ) -> [String: Any] {
        var merged = service ?? [:]
        if let packBatteryData = pack?["BatteryData"] as? [String: Any] {
            var batteryData = merged["BatteryData"] as? [String: Any] ?? [:]
            for (key, value) in packBatteryData {
                batteryData[key] = value
            }
            merged["BatteryData"] = batteryData
        }
        return merged
    }

    private func properties(of service: io_service_t) -> [String: Any]? {
        var rawProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service, &rawProperties, kCFAllocatorDefault, 0
        )
        guard result == KERN_SUCCESS,
              let properties = rawProperties?.takeRetainedValue() as? [String: Any]
        else {
            return nil
        }
        return properties
    }
}
