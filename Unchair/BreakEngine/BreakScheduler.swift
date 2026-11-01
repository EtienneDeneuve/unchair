import Foundation

/// Absolute-deadline scheduler for movement breaks.
///
/// Thin façade over `BreakStateMachine` so existing call sites keep a familiar API
/// while every transition is validated by the explicit lifecycle.
final class BreakScheduler {
    static let postponePresets: [BreakDuration] = [
        .minutes(15),
        .minutes(30),
        .minutes(45),
        .minutes(60),
    ]

    private let clock: BreakClock
    private let machine: BreakStateMachine

    init(
        clock: BreakClock,
        presentationGuard: PresentationGuarding,
        settings: BreakSettings = .default,
        store: (any BreakLifecycleStoring)? = nil,
        eventPublisher: (any DomainEventPublishing)? = nil,
        restoreOnInit: Bool = true
    ) {
        self.clock = clock
        machine = BreakStateMachine(
            clock: clock,
            presentationGuard: presentationGuard,
            settings: settings,
            store: store,
            eventPublisher: eventPublisher,
            restoreOnInit: restoreOnInit
        )
    }

    /// Test / advanced access to the underlying lifecycle.
    var stateMachine: BreakStateMachine { machine }

    var snapshot: BreakSnapshot { machine.snapshot }

    var settings: BreakSettings { machine.settings }

    @discardableResult
    func apply(_ event: BreakEvent) -> BreakTransitionResult {
        machine.apply(event)
    }

    func start() {
        _ = machine.apply(.start)
    }

    func evaluate() {
        _ = machine.apply(.evaluate)
    }

    func startBreakNow() {
        _ = machine.apply(.startBreakNow)
    }

    /// Begin the timed movement break from a due prompt.
    func beginTimedBreak() {
        _ = machine.apply(.beginTimedBreak)
    }

    func completeBreak() {
        _ = machine.apply(.complete)
    }

    /// Skip keeps movement debt and starts a fresh work interval from now.
    func skipBreak() {
        _ = machine.apply(.skip)
    }

    func postpone(by duration: BreakDuration) {
        postpone(until: clock.now.addingTimeInterval(duration.seconds))
    }

    func postpone(until date: Date) {
        _ = machine.apply(.postpone(until: date))
    }

    func pause() {
        _ = machine.apply(.pause)
    }

    func resume() {
        _ = machine.apply(.resume)
    }

    func updateSettings(_ newSettings: BreakSettings) {
        _ = machine.apply(.updateSettings(newSettings))
    }

    func noteStandDetected() {
        _ = machine.apply(.standDetected)
    }

    func noteMovementVerified() {
        _ = machine.apply(.movementVerified)
    }

    func noteVerificationFailed() {
        _ = machine.apply(.verificationFailed)
    }
}
