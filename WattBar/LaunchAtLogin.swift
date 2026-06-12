import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService for the "Launch at Login" toggle.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published var isEnabled: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            guard isEnabled != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert the toggle if the system call failed.
                isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }

    func refresh() {
        let actual = SMAppService.mainApp.status == .enabled
        if isEnabled != actual { isEnabled = actual }
    }
}
