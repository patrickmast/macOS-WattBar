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

            FooterView()
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
            HStack(alignment: .center, spacing: 7) {
                if let icon = flowIcon {
                    Image(systemName: icon.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(icon.color)
                }
                Text(primaryText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// Direction of the power flow: green plus while charging (power coming
    /// in), orange minus while discharging (power going out).
    private var flowIcon: (name: String, color: Color)? {
        switch snapshot.state {
        case .charging:
            guard let watts = snapshot.chargingWatts, watts > 0 else { return nil }
            return ("plus.circle.fill", .green)
        case .onBattery:
            guard let watts = snapshot.batteryWatts, watts < 0 else { return nil }
            return ("minus.circle.fill", .orange)
        default:
            return nil
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
    @Environment(\.dismiss) private var dismiss

    @State private var isMenuPresented = false

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var body: some View {
        HStack {
            Text("build \(buildNumber)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                isMenuPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text("Menu")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityLabel("Menu")
            .popover(isPresented: $isMenuPresented, arrowEdge: .bottom) {
                FooterMenuPopover(
                    showAbout: {
                        isMenuPresented = false
                        dismiss()
                        Task { @MainActor in
                            AboutWindowController.shared.show()
                        }
                    },
                    quit: {
                        isMenuPresented = false
                        NSApplication.shared.terminate(nil)
                    }
                )
            }
        }
    }
}

private struct FooterMenuPopover: View {
    let showAbout: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuActionButton(
                title: "About WattBar",
                subtitle: "Version, build and website",
                systemImage: "info.circle",
                action: showAbout
            )

            Divider()
                .padding(.vertical, 3)

            MenuActionButton(
                title: "Quit WattBar",
                subtitle: "Stop the menu bar app",
                systemImage: "power",
                action: quit
            )
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 220)
    }
}

private struct MenuActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct AboutWattBarDialog: View {
    let close: () -> Void

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            VStack(spacing: 3) {
                Text("WattBar")
                    .font(.title2.weight(.semibold))
                Text("Version \(version) · build \(buildNumber)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text("A minimal macOS menu bar utility that shows live MacBook charging power.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("© 2026 Patrick Mast")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                Button("Website") {
                    if let url = URL(string: "https://wattbar.pm7.dev/") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Done") {
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .padding(24)
        .frame(width: 360)
    }
}

@MainActor
private final class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()

    private var window: NSPanel?

    func show() {
        if let window {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = AboutWattBarDialog { [weak self] in
            self?.close()
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "About WattBar"
        panel.contentViewController = NSHostingController(rootView: content)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
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
