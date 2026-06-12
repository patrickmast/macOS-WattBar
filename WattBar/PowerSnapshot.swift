import Foundation

/// Immutable view of the battery / power state at one moment in time.
struct PowerSnapshot: Equatable {
    enum State: Equatable {
        case charging
        case pluggedInNotCharging
        case fullyCharged
        case onBattery
        case noBattery
    }

    var state: State = .noBattery

    /// Battery terminal voltage in millivolts.
    var voltageMilliVolts: Int?
    /// Signed current in milliamps. Positive = into the battery (charging).
    var amperageMilliAmps: Int?
    /// Battery charge percentage 0–100.
    var percentage: Int?
    /// Minutes until fully charged, if known.
    var minutesToFull: Int?
    /// Minutes of battery runtime remaining, if known.
    var minutesToEmpty: Int?
    var cycleCount: Int?
    /// Battery temperature in degrees Celsius.
    var temperatureCelsius: Double?

    var adapterName: String?
    var adapterMaxWatts: Int?

    var updatedAt: Date = .distantPast

    /// Instantaneous battery power in watts. Positive while charging,
    /// negative while discharging, nil when unknown.
    var batteryWatts: Double? {
        guard let v = voltageMilliVolts, let a = amperageMilliAmps else { return nil }
        return Double(v) * Double(a) / 1_000_000
    }

    /// Power flowing into the battery, only meaningful while charging.
    /// Clamped to zero: near 100% the controller still reports "charging"
    /// while the net battery current briefly dips negative (top-off).
    var chargingWatts: Double? {
        guard state == .charging, let watts = batteryWatts else { return nil }
        return max(watts, 0)
    }

    static let empty = PowerSnapshot()
}
