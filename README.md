# WattBar ⚡

A minimal, native macOS menu bar utility that shows the current charging power
of your MacBook in watts — e.g. `⚡ 42W`. No Dock icon, no windows, just a calm
little status item with a detailed popover.

## How it works

WattBar reads the `AppleSmartBattery` entry in the I/O Registry through the
public IOKit C API (`IOServiceGetMatchingService` +
`IORegistryEntryCreateCFProperties`). The displayed wattage is the real power
flowing into the battery, computed from the battery's live telemetry:

```
watts = Voltage (mV) × Amperage (mA) / 1 000 000
```

Updates come from two sources:

- `IOPSNotificationCreateRunLoopSource` — instant refresh when you plug or
  unplug the adapter or the charge state changes.
- A light timer (5 s in the background, 2 s while the popover is open) to keep
  the live amperage reading current.

No subprocesses, no private frameworks, no third-party dependencies.

## Menu bar states

| State                    | Label |
|--------------------------|-------|
| Charging                 | `⚡ 42W` |
| Plugged in, not charging | plug icon |
| Fully charged            | full-battery icon |
| On battery               | `⚡̸ —` |
| No battery (desktop Mac) | plug icon |

The popover shows live wattage, battery percentage with a gauge, power source,
adapter name and rated wattage, voltage, amperage, cycle count, temperature,
time until full / remaining, last-updated time, and a Quit button.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ and [xcodegen](https://github.com/yonaskolb/XcodeGen) to build

## Build & run

```bash
./§build
```

This bumps the build number, generates the Xcode project, builds the Release
configuration, installs the app into `/Applications/WattBar.app`, and launches
it.

To start WattBar automatically at login: System Settings → General →
Login Items → add **WattBar**.

## Project structure

```
project.yml                  xcodegen project definition (version lives here)
WattBar/
  WattBarApp.swift           @main entry, MenuBarExtra + status item label
  PowerMonitor.swift         IOKit reader + refresh scheduling
  PowerSnapshot.swift        immutable power state model
  PopoverView.swift          SwiftUI popover UI
§build                       build & install script
```
