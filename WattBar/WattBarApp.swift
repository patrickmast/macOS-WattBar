import SwiftUI

@main
struct WattBarApp: App {
    @StateObject private var monitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Compact status-item label: a bolt with the live wattage while charging,
/// a quiet glyph otherwise.
struct MenuBarLabel: View {
    @ObservedObject var monitor: PowerMonitor

    var body: some View {
        let snapshot = monitor.snapshot
        switch snapshot.state {
        case .charging:
            if let watts = snapshot.chargingWatts {
                Text("\(Image(systemName: "bolt.fill")) \(Int(watts.rounded()))W")
                    .monospacedDigit()
            } else {
                Image(systemName: "bolt.fill")
            }
        case .pluggedInNotCharging:
            Image(systemName: "powerplug.fill")
        case .fullyCharged:
            Image(systemName: "battery.100percent.bolt")
        case .onBattery:
            Text("\(Image(systemName: "bolt.slash")) —")
        case .noBattery:
            Image(systemName: "powerplug")
        }
    }
}
