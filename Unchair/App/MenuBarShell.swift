import Foundation
import Observation

enum MenuBarCommand: Equatable, Hashable {
    case nextBreakStatus
    case startBreakNow
    case postponeMenu
    case pauseResume
    case settings
    case quit
}

@MainActor
@Observable
final class MenuBarShell {
    static let commands: [MenuBarCommand] = [
        .nextBreakStatus,
        .startBreakNow,
        .postponeMenu,
        .pauseResume,
        .settings,
        .quit,
    ]

    private let scheduler: BreakScheduler
    private let overlayController: any BreakOverlayPresenting
    private let cameraCoordinator: BreakCameraCoordinator

    private(set) var isSettingsPresented = false
    private(set) var statusRevision = 0
    private(set) var cameraProbeStatusText = "Not tested yet"
    private(set) var isCameraProbeRunning = false

    init(
        scheduler: BreakScheduler,
        overlayController: any BreakOverlayPresenting = BreakOverlayController(),
        cameraCoordinator: BreakCameraCoordinator? = nil
    ) {
        self.scheduler = scheduler
        self.overlayController = overlayController
        self.cameraCoordinator = cameraCoordinator ?? BreakCameraCoordinator(
            authorizer: AVCameraAuthorizer(),
            capture: AVCameraCapture()
        )
        overlayController.attach(shell: self)
        scheduler.start()
        startTicking()
        syncOverlay()
    }

    convenience init() {
        let clock = SystemBreakClock()
        self.init(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: PermissivePresentationGuard()
            )
        )
    }

    var phase: BreakPhase {
        _ = statusRevision
        scheduler.evaluate()
        return scheduler.snapshot.phase
    }

    var nextBreakStatusText: String {
        switch phase {
        case .idle:
            return "Next break: —"
        case .working:
            if let remaining = scheduler.snapshot.remainingWork {
                return "Next break: \(Self.formatCountdown(remaining.seconds))"
            }
            return "Next break: —"
        case .breakDue:
            return "Break due now"
        case .onBreak:
            if let remaining = scheduler.snapshot.remainingBreak {
                return "On break: \(Self.formatCountdown(remaining.seconds))"
            }
            return "On break"
        case .postponed:
            if let remaining = scheduler.snapshot.remainingWork {
                return "Postponed: \(Self.formatCountdown(remaining.seconds))"
            }
            return "Postponed"
        case .deferredForPresentation:
            return "Deferred (presentation)"
        case .paused:
            if let remaining = scheduler.snapshot.remainingWork {
                return "Paused (\(Self.formatCountdown(remaining.seconds)) left)"
            }
            return "Paused"
        }
    }

    /// Compact title shown directly in the macOS menu bar item.
    var menuBarTitleText: String {
        switch phase {
        case .idle:
            return "—"
        case .working:
            if let remaining = scheduler.snapshot.remainingWork {
                return Self.formatCountdown(remaining.seconds)
            }
            return "—"
        case .breakDue:
            return "DUE"
        case .onBreak:
            if let remaining = scheduler.snapshot.remainingBreak {
                return Self.formatCountdown(remaining.seconds)
            }
            return "0:00"
        case .postponed:
            if let remaining = scheduler.snapshot.remainingWork {
                return Self.formatCountdown(remaining.seconds)
            }
            return "…"
        case .deferredForPresentation:
            return "HOLD"
        case .paused:
            if let remaining = scheduler.snapshot.remainingWork {
                return Self.formatCountdown(remaining.seconds)
            }
            return "⏸"
        }
    }

    var menuBarSymbolName: String {
        switch phase {
        case .breakDue, .onBreak:
            return "figure.stand"
        case .postponed, .deferredForPresentation:
            return "clock.badge.exclamationmark"
        case .paused:
            return "pause.fill"
        case .idle, .working:
            return "timer"
        }
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var canPostpone: Bool {
        switch phase {
        case .breakDue, .onBreak, .postponed, .deferredForPresentation:
            return true
        case .idle, .working, .paused:
            return false
        }
    }

    var postponePresets: [BreakDuration] {
        BreakScheduler.postponePresets
    }

    var settings: BreakSettings {
        scheduler.settings
    }

    var overlayModel: BreakOverlayModel {
        let snapshot = scheduler.snapshot
        switch snapshot.phase {
        case .onBreak:
            return .active(
                remaining: snapshot.remainingBreak ?? .seconds(0),
                verificationStatus: verificationStatus(for: cameraCoordinator.state)
            )
        case .breakDue:
            return .due(
                sittingSeconds: snapshot.sittingDuration?.seconds
                    ?? snapshot.settings.workInterval.seconds,
                breakDuration: snapshot.settings.breakDuration,
                verificationStatus: .waitingToStart
            )
        default:
            return .due(
                sittingSeconds: snapshot.settings.workInterval.seconds,
                breakDuration: snapshot.settings.breakDuration,
                verificationStatus: .waitingToStart
            )
        }
    }

    func startBreakNow() {
        scheduler.startBreakNow()
        bumpStatus()
    }

    func beginTimedBreak() {
        scheduler.beginTimedBreak()
        bumpStatus()
    }

    func skipBreak() {
        scheduler.skipBreak()
        bumpStatus()
    }

    func completeBreak() {
        scheduler.completeBreak()
        bumpStatus()
    }

    func handleOverlayPrimary() {
        switch phase {
        case .breakDue:
            beginTimedBreak()
        case .onBreak:
            // Movement proof arrives in later issues; complete is explicit for now.
            completeBreak()
        default:
            break
        }
    }

    func postpone(by duration: BreakDuration) {
        scheduler.postpone(by: duration)
        bumpStatus()
    }

    func postpone(until date: Date) {
        scheduler.postpone(until: date)
        bumpStatus()
    }

    func togglePause() {
        if isPaused {
            scheduler.resume()
        } else {
            scheduler.pause()
        }
        bumpStatus()
    }

    func updateSettings(_ settings: BreakSettings) {
        scheduler.updateSettings(settings)
        bumpStatus()
    }

    func openSettings() {
        isSettingsPresented = true
        SettingsWindowController.shared.show(shell: self)
    }

    func runCameraProbe() {
        guard !isCameraProbeRunning else { return }
        isCameraProbeRunning = true
        cameraProbeStatusText = "Testing camera…"
        statusRevision &+= 1

        Task { [weak self] in
            guard let self else { return }
            let result = await self.cameraCoordinator.runProbe(timeoutSeconds: 6)
            self.cameraProbeStatusText = Self.describe(probe: result)
            self.isCameraProbeRunning = false
            self.statusRevision &+= 1
            self.syncOverlay()
        }
    }

    private static func describe(probe: CameraProbeResult) -> String {
        switch probe {
        case .ok(let frames):
            return "OK · \(frames) in-memory frame\(frames == 1 ? "" : "s") received · camera stopped"
        case .permissionDenied:
            return "Permission denied · enable Camera for Unchair in System Settings"
        case .unavailable(let reason):
            return "Unavailable · \(reason)"
        case .timeout:
            return "Timeout · no frames received (check that another app isn’t holding the camera)"
        }
    }

    private func startTicking() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await self.bumpStatus()
            }
        }
    }

    private func bumpStatus() {
        scheduler.evaluate()
        let currentPhase = scheduler.snapshot.phase
        statusRevision &+= 1
        syncOverlay()
        Task { [weak self] in
            guard let self else { return }
            await self.cameraCoordinator.handlePhaseChange(currentPhase)
            self.statusRevision &+= 1
            self.syncOverlay()
        }
    }

    private func syncOverlay() {
        overlayController.sync(with: self)
    }

    private func verificationStatus(for cameraState: BreakCameraState) -> BreakVerificationStatus {
        switch cameraState {
        case .idle:
            return .pendingMovement
        case .running:
            return .capturing
        case .permissionDenied:
            return .permissionDenied
        case .unavailable:
            return .cameraUnavailable
        }
    }

    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
