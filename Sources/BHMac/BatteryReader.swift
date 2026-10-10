import Foundation
import IOKit

/// Seam between the app and the IOKit registry. Protocol so the AppDelegate
/// (and future tests) can substitute a fake; the real implementation is the
/// only place that touches IOKit.
protocol BatteryReading {
    /// Returns nil when no battery service exists (desktop Mac).
    func readSnapshot() -> BatterySnapshot?
}

final class IOKitBatteryReader: BatteryReading {
    func readSnapshot() -> BatterySnapshot? {
        let serviceProperties = properties(of: "AppleSmartBattery")
        let packProperties = properties(of: "AppleSmartBatteryPack")
        guard serviceProperties != nil || packProperties != nil else {
            return nil
        }

        var merged = serviceProperties ?? [:]

        // The rich pack data (Temperature, VirtualTemperature, LifetimeData,
        // and the definitive DesignCapacity/FullChargeCapacity) lives on the
        // AppleSmartBatteryPack node, while live charge state (IsCharging,
        // CurrentCapacity, CycleCount, amperage...) lives on
        // AppleSmartBattery. Merge pack BatteryData over the service one —
        // values agree where both expose them.
        if let packBatteryData = packProperties?["BatteryData"] as? [String: Any] {
            var batteryData = merged["BatteryData"] as? [String: Any] ?? [:]
            for (key, value) in packBatteryData {
                batteryData[key] = value
            }
            merged["BatteryData"] = batteryData
        }

        return BatterySnapshot.parse(from: merged)
    }

    private func properties(of serviceName: String) -> [String: Any]? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceNameMatching(serviceName)
        )
        // 0 means no match (e.g. a desktop Mac).
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

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
