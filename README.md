# WattBar ⚡

A minimal, native macOS menu bar utility that shows the current charging power
of your MacBook in watts — e.g. `42W`. No Dock icon, no windows, just a calm
little status item with a detailed popover.

**[→ wattbar.pm7.dev](https://wattbar.pm7.dev/)** ·
**[Download the latest .dmg](https://github.com/patrickmast/macOS-WattBar/releases/latest/download/WattBar-latest.dmg)** ·
[Releases](https://github.com/patrickmast/macOS-WattBar/releases)

## Install (prebuilt)

1. Download [`WattBar-latest.dmg`](https://github.com/patrickmast/macOS-WattBar/releases/latest/download/WattBar-latest.dmg)
2. Open it and drag **WattBar** into **Applications**
3. Launch WattBar — it lives only in your menu bar

> **First launch:** WattBar is open source and isn't signed with a paid Apple
> Developer ID, so Gatekeeper will hesitate. Right-click **WattBar.app → Open**
> the first time, or run
> `xattr -dr com.apple.quarantine /Applications/WattBar.app`.

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

## Build & run from source

```bash
./§build      # bump build number → generate project → Release build → install to /Applications → launch
./§package    # package /Applications/WattBar.app into dist/WattBar-<version>.dmg
```

`§build` bumps the build number, generates the Xcode project, builds the
Release configuration, installs the app into `/Applications/WattBar.app`, and
launches it. `§package` wraps the installed app into a distributable DMG.

The landing page lives in [`docs/`](docs/) and is deployed to Cloudflare Pages
at <https://wattbar.pm7.dev/> via `./§deploy-site` (also mirrored on GitHub
Pages at <https://patrickmast.github.io/macOS-WattBar/>).

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
