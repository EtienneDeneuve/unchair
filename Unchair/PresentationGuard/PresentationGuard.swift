import Foundation

/// Fail-safe presentation / call guard (issue #13).
///
/// Blocks break overlays and camera activation when any strong signal is active.
/// Does not require Screen Recording permission.
///
/// HID idle freezes the desk clock but does **not** block presentation — an idle
/// unlocked Mac is "away", not "in a meeting".
final class PresentationGuard: PresentationGuarding {
    private let signals: [any PresentationSignalSource]
    private let manualMode: ManualPresentationMode
    private let idleInspector: (any UserIdleInspecting)?
    /// Cheap lock/sleep latch — must not scan AVCapture / process lists.
    private let screenSession: (any ScreenSessionInspecting)?

    /// Seconds without HID input before `isUserIdle`. `<= 0` disables idle freeze.
    var idleFreezeThresholdSeconds: TimeInterval

    var isBlocking: Bool {
        manualMode.tick()
        return signals.contains { $0.isActive }
    }

    var isScreenLockedOrAsleep: Bool {
        if let screenSession {
            return screenSession.isScreenLockedOrAsleep
        }
        return activeReasons.contains(.screenLockedOrAsleep)
    }

    var isUserIdle: Bool {
        guard let idleInspector, idleFreezeThresholdSeconds > 0 else { return false }
        return idleInspector.idleSeconds >= idleFreezeThresholdSeconds
    }

    var shouldFreezeDeskClock: Bool {
        isScreenLockedOrAsleep || isUserIdle
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
        manualMode: ManualPresentationMode,
        idleInspector: (any UserIdleInspecting)? = nil,
        screenSession: (any ScreenSessionInspecting)? = nil,
        idleFreezeThresholdSeconds: TimeInterval = BreakSettings.default.idleFreezeAfter.seconds
    ) {
        self.signals = signals
        self.manualMode = manualMode
        self.idleInspector = idleInspector
        self.screenSession = screenSession
        self.idleFreezeThresholdSeconds = idleFreezeThresholdSeconds
    }

    /// Production wiring — no Screen Recording / Accessibility permission.
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
            manualMode: manual,
            idleInspector: CGEventUserIdleInspector(),
            screenSession: screen
        )
    }
}
