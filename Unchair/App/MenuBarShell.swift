import Foundation
import Observation

enum MenuBarCommand: Equatable, Hashable {
    case nextBreakStatus
    case startBreakNow
    case settings
    case quit
}

@Observable
final class MenuBarShell {
    static let commands: [MenuBarCommand] = [
        .nextBreakStatus,
        .startBreakNow,
        .settings,
        .quit,
    ]

    private(set) var isSettingsPresented = false

    var nextBreakStatusText: String {
        // Scheduler lands in issue #2; keep an explicit unavailable placeholder.
        "Next break: —"
    }

    func startBreakNow() {
        // BreakEngine arrives in a later issue; command must remain invokable.
    }

    func openSettings() {
        isSettingsPresented = true
    }
}
