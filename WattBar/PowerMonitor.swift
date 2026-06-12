import Foundation
import IOKit
import IOKit.ps

/// Reads battery and charging data from the AppleSmartBattery entry in the
/// I/O Registry. Refreshes on a light timer and immediately whenever macOS
/// reports a power-source change (plug/unplug, charge state).
@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var snapshot = PowerSnapshot.empty

    private var timer: Timer?
    private var powerSource: CFRunLoopSource?

    /// Unknown-time sentinel used by the smart battery controller.
    private static let unknownMinutes = 65535

    init() {
        refresh()
        startTimer(interval: 5)
        installPowerSourceNotification()
    }

    deinit {
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
        }
    }

    func refresh() {
        snapshot = Self.readSnapshot()
    }

    /// Faster cadence while the popover is visible, relaxed otherwise.
    func setPopoverVisible(_ visible: Bool) {
        startTimer(interval: visible ? 2 : 5)
        if visible { refresh() }
    }

    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func installPowerSourceNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in monitor.refresh() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSource = source
    }

    // MARK: - I/O Registry

    private static func readSnapshot() -> PowerSnapshot {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            // Desktop Mac or battery service unavailable.
            var snapshot = PowerSnapshot.empty
            snapshot.state = .noBattery
            snapshot.updatedAt = Date()
            return snapshot
        }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            var snapshot = PowerSnapshot.empty
            snapshot.state = .noBattery
            snapshot.updatedAt = Date()
            return snapshot
        }

        var snapshot = PowerSnapshot()
        snapshot.updatedAt = Date()

        let externalConnected = props["ExternalConnected"] as? Bool ?? false
        let isCharging = props["IsCharging"] as? Bool ?? false
        let fullyCharged = props["FullyCharged"] as? Bool ?? false

        if isCharging {
            snapshot.state = .charging
        } else if externalConnected {
            snapshot.state = fullyCharged ? .fullyCharged : .pluggedInNotCharging
        } else {
            snapshot.state = .onBattery
        }

        snapshot.voltageMilliVolts = props["Voltage"] as? Int
        snapshot.amperageMilliAmps = props["Amperage"] as? Int
        snapshot.cycleCount = props["CycleCount"] as? Int

        if let current = props["CurrentCapacity"] as? Int,
           let max = props["MaxCapacity"] as? Int, max > 0 {
            // On Apple Silicon these are already normalized to 0–100.
            snapshot.percentage = Int((Double(current) / Double(max) * 100).rounded())
        }

        if isCharging, let toFull = props["AvgTimeToFull"] as? Int, toFull != unknownMinutes {
            snapshot.minutesToFull = toFull
        }
        if !externalConnected, let toEmpty = props["AvgTimeToEmpty"] as? Int, toEmpty != unknownMinutes {
            snapshot.minutesToEmpty = toEmpty
        }

        if let rawTemperature = props["Temperature"] as? Int {
            snapshot.temperatureCelsius = Double(rawTemperature) / 100
        }

        if externalConnected, let adapter = props["AdapterDetails"] as? [String: Any] {
            snapshot.adapterName = adapter["Name"] as? String
            snapshot.adapterMaxWatts = adapter["Watts"] as? Int
        }

        return snapshot
    }
}
