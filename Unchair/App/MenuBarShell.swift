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

    private(set) var isSettingsPresented = false
    private(set) var statusRevision = 0

    init(scheduler: BreakScheduler) {
        self.scheduler = scheduler
        scheduler.start()
        startTicking()
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

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var canPostpone: Bool {
        switch phase {
        case .breakDue, .postponed, .deferredForPresentation:
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

    func startBreakNow() {
        scheduler.startBreakNow()
        bumpStatus()
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
    }

    private func startTicking() {
        // Weak self ends the loop when the shell is released; avoids deinit/MainActor clashes.
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await self.bumpStatus()
            }
        }
    }

    private func bumpStatus() {
        statusRevision &+= 1
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
