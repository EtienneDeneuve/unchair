import Foundation

/// Absolute-deadline scheduler for movement breaks.
///
/// Time is injected so sleep/wake and repeated `evaluate()` calls cannot create
/// duplicate due events: once due, the phase stays `.breakDue` until an explicit
/// complete / skip / postpone transition.
final class BreakScheduler {
    static let postponePresets: [BreakDuration] = [
        .minutes(15),
        .minutes(30),
        .minutes(45),
        .minutes(60),
    ]

    private let clock: BreakClock
    private let presentationGuard: PresentationGuarding

    private(set) var settings: BreakSettings
    private var phase: BreakPhase = .idle
    private var sittingStartedAt: Date?
    private var hasMovementDebt = false
    private var remainingWhenPaused: TimeInterval?

    init(
        clock: BreakClock,
        presentationGuard: PresentationGuarding,
        settings: BreakSettings = .default
    ) {
        self.clock = clock
        self.presentationGuard = presentationGuard
        self.settings = settings
    }

    var snapshot: BreakSnapshot {
        BreakSnapshot(
            phase: phase,
            settings: settings,
            sittingStartedAt: sittingStartedAt,
            hasMovementDebt: hasMovementDebt,
            remainingWork: remainingWorkDuration()
        )
    }

    func start() {
        beginWorking(from: clock.now, preserveDebt: false)
    }

    func evaluate() {
        switch phase {
        case .working(let until), .postponed(let until):
            guard clock.now >= until else { return }
            becomeDueOrDefer(pendingSince: until)
        case .deferredForPresentation:
            guard !presentationGuard.isBlocking else { return }
            phase = .breakDue
            hasMovementDebt = true
        case .breakDue, .paused, .idle:
            break
        }
    }

    func startBreakNow() {
        becomeDueOrDefer(pendingSince: clock.now)
    }

    func completeBreak() {
        hasMovementDebt = false
        beginWorking(from: clock.now, preserveDebt: false)
    }

    /// Skip keeps movement debt and starts a fresh work interval from now.
    func skipBreak() {
        hasMovementDebt = true
        beginWorking(from: clock.now, preserveDebt: true)
    }

    func postpone(by duration: BreakDuration) {
        postpone(until: clock.now.addingTimeInterval(duration.seconds))
    }

    func postpone(until date: Date) {
        // Postpone never clears debt or the sitting origin timestamp.
        hasMovementDebt = true
        if sittingStartedAt == nil {
            sittingStartedAt = clock.now
        }
        phase = .postponed(until: date)
        remainingWhenPaused = nil
    }

    func pause() {
        guard case .working(let until) = phase else { return }
        remainingWhenPaused = max(0, until.timeIntervalSince(clock.now))
        phase = .paused
    }

    func resume() {
        guard phase == .paused, let remaining = remainingWhenPaused else { return }
        remainingWhenPaused = nil
        phase = .working(until: clock.now.addingTimeInterval(remaining))
    }

    func updateSettings(_ newSettings: BreakSettings) {
        settings = newSettings
    }

    private func beginWorking(from date: Date, preserveDebt: Bool) {
        if !preserveDebt {
            sittingStartedAt = date
            hasMovementDebt = false
        } else if sittingStartedAt == nil {
            sittingStartedAt = date
        }
        remainingWhenPaused = nil
        phase = .working(until: date.addingTimeInterval(settings.workInterval.seconds))
    }

    private func becomeDueOrDefer(pendingSince: Date) {
        hasMovementDebt = true
        if sittingStartedAt == nil {
            sittingStartedAt = pendingSince
        }
        if presentationGuard.isBlocking {
            phase = .deferredForPresentation(pendingSince: clock.now)
        } else {
            phase = .breakDue
        }
        remainingWhenPaused = nil
    }

    private func remainingWorkDuration() -> BreakDuration? {
        switch phase {
        case .working(let until):
            return .seconds(max(0, until.timeIntervalSince(clock.now)))
        case .postponed(let until):
            return .seconds(max(0, until.timeIntervalSince(clock.now)))
        case .paused:
            if let remaining = remainingWhenPaused {
                return .seconds(remaining)
            }
            return nil
        case .breakDue, .deferredForPresentation, .idle:
            return nil
        }
    }
}
