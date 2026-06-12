import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var monitor: PowerMonitor
    @StateObject private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        let snapshot = monitor.snapshot
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(snapshot: snapshot)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if snapshot.state != .noBattery {
                BatteryGaugeView(snapshot: snapshot)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                Divider().padding(.horizontal, 12)

                DetailsView(snapshot: snapshot)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            Divider().padding(.horizontal, 12)

            HStack {
                Text("Launch at Login")
                    .font(.callout)
                Spacer()
                Toggle("", isOn: $launchAtLogin.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 12)

            FooterView(updatedAt: snapshot.updatedAt)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 300)
        .onAppear {
            monitor.setPopoverVisible(true)
            launchAtLogin.refresh()
        }
        .onDisappear { monitor.setPopoverVisible(false) }
    }
}

// MARK: - Header

private struct HeaderView: View {
    let snapshot: PowerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(primaryText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if snapshot.state == .charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            }
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var primaryText: String {
        switch snapshot.state {
        case .charging:
            if let watts = snapshot.chargingWatts {
                return String(format: "%.1f W", watts)
            }
            return "— W"
        case .onBattery:
            if let watts = snapshot.batteryWatts, watts < 0 {
                return String(format: "%.1f W", -watts)
            }
            return "— W"
        case .pluggedInNotCharging, .fullyCharged:
            return "0 W"
        case .noBattery:
            return "—"
        }
    }

    private var statusText: String {
        switch snapshot.state {
        case .charging:
            if let minutes = snapshot.minutesToFull {
                return "Charging · \(Formatters.duration(minutes: minutes)) until full"
            }
            return "Charging"
        case .pluggedInNotCharging:
            return "Plugged in, not charging"
        case .fullyCharged:
            return "Fully charged"
        case .onBattery:
            if let minutes = snapshot.minutesToEmpty {
                return "On battery · \(Formatters.duration(minutes: minutes)) remaining"
            }
            return "On battery"
        case .noBattery:
            return "No battery detected"
        }
    }
}

// MARK: - Battery gauge

private struct BatteryGaugeView: View {
    let snapshot: PowerSnapshot

    var body: some View {
        if let percentage = snapshot.percentage {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Battery")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(percentage)%")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                        Capsule()
                            .fill(fillColor)
                            .frame(width: max(6, proxy.size.width * CGFloat(percentage) / 100))
                    }
                }
                .frame(height: 6)
                .animation(.easeInOut(duration: 0.3), value: percentage)
            }
        }
    }

    private var fillColor: Color {
        guard let percentage = snapshot.percentage else { return .accentColor }
        if percentage <= 10 { return .red }
        if percentage <= 20 { return .orange }
        if snapshot.state == .charging || snapshot.state == .fullyCharged { return .green }
        return .accentColor
    }
}

// MARK: - Details

private struct DetailsView: View {
    let snapshot: PowerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            row("Power Source", powerSourceText)
            if let adapter = adapterText {
                row("Adapter", adapter)
            }
            if let voltage = snapshot.voltageMilliVolts {
                row("Voltage", String(format: "%.2f V", Double(voltage) / 1000))
            }
            if let amperage = snapshot.amperageMilliAmps {
                row("Current", String(format: "%.2f A", Double(amperage) / 1000))
            }
            if let cycles = snapshot.cycleCount {
                row("Cycle Count", "\(cycles)")
            }
            if let temperature = snapshot.temperatureCelsius {
                row("Temperature", String(format: "%.1f °C", temperature))
            }
        }
    }

    private var powerSourceText: String {
        switch snapshot.state {
        case .onBattery: return "Battery"
        case .noBattery: return "AC Power"
        default: return "Power Adapter"
        }
    }

    private var adapterText: String? {
        guard snapshot.state != .onBattery else { return nil }
        switch (snapshot.adapterName, snapshot.adapterMaxWatts) {
        case let (name?, watts?): return "\(name) · \(watts) W"
        case let (name?, nil): return name
        case let (nil, watts?): return "\(watts) W"
        default: return nil
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Footer

private struct FooterView: View {
    let updatedAt: Date

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var body: some View {
        HStack {
            Text("Updated \(updatedAt, format: .dateTime.hour().minute().second())")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("· build \(buildNumber)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
        }
    }
}

// MARK: - Formatters

enum Formatters {
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours) h \(mins) min" : "\(hours) h"
        }
        return "\(mins) min"
    }
}
