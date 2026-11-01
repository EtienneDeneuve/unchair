import Foundation

/// Fail-safe presentation / call guard (issue #13).
///
/// Blocks break overlays and camera activation when any strong signal is active.
/// Does not require Screen Recording permission.
final class PresentationGuard: PresentationGuarding {
    private let signals: [any PresentationSignalSource]
    private let manualMode: ManualPresentationMode

    var isBlocking: Bool {
        manualMode.tick()
        return signals.contains { $0.isActive }
    }

    var isScreenLockedOrAsleep: Bool {
        activeReasons.contains(.screenLockedOrAsleep)
    }

    var activeReasons: [PresentationBlockReason] {
        manualMode.tick()
        return signals.filter(\.isActive).map(\.reason)
    }

    var isManualPresentationModeEnabled: Bool {
        manualMode.tick()
        return manualMode.isActive
    }

    var manualPresentationMode: ManualPresentationMode { manualMode }

    init(
        signals: [any PresentationSignalSource],
        manualMode: ManualPresentationMode
    ) {
        self.signals = signals
        self.manualMode = manualMode
    }

    /// Production wiring — no Screen Recording permission.
    @MainActor
    static func makeSystem(clock: BreakClock) -> PresentationGuard {
        let devices = AVMediaDeviceInspector()
        let manual = ManualPresentationMode(clock: clock)
        let screen = WorkspaceScreenSessionInspector()
        let apps = WorkspaceRunningApplicationInspector()
        return PresentationGuard(
            signals: [
                manual,
                CameraInUseSignal(inspector: devices),
                MicrophoneInUseSignal(inspector: devices),
                ScreenLockSignal(inspector: screen),
                MeetingAppWithDeviceUseSignal(apps: apps, devices: devices),
            ],
            manualMode: manual
        )
    }
}
