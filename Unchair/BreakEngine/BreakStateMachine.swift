import Foundation

/// Explicit break lifecycle. All phase changes go through `apply(_:)`.
///
/// Main path: working → breakDue → onBreak(awaitingStand → standingDetected →
/// movementVerified) → working (completed).
/// Deferral: breakDue → postponed → breakDue.
/// Presentation: working|postponed|breakDue → deferredForPresentation → breakDue.
final class BreakStateMachine {
    private let clock: BreakClock
    private let presentationGuard: PresentationGuarding
    private let store: (any BreakLifecycleStoring)?
    private let calendar: Calendar
    private let eventPublisher: (any DomainEventPublishing)?

    private(set) var settings: BreakSettings
    private var phase: BreakPhase = .idle
    private var sittingStartedAt: Date?
    /// Wall-clock instant when sleep/lock freeze began; nil while accruing.
    private var sittingFreezeStartedAt: Date?
    private var debtState: MovementDebtState
    private var remainingWhenPaused: TimeInterval?
    private var breakID: UUID?

    init(
        clock: BreakClock,
        presentationGuard: PresentationGuarding,
        settings: BreakSettings = .default,
        store: (any BreakLifecycleStoring)? = nil,
        calendar: Calendar = .current,
        eventPublisher: (any DomainEventPublishing)? = nil,
        restoreOnInit: Bool = true
    ) {
        self.clock = clock
        self.presentationGuard = presentationGuard
        self.settings = settings
        self.store = store
        self.calendar = calendar
        self.eventPublisher = eventPublisher
        self.debtState = .empty(at: clock.now, calendar: calendar)
        if restoreOnInit {
            restoreIfNeeded()
        }
        syncIdleFreezeThreshold()
    }

    /// Lock / sleep / HID-idle freeze — also drives Vision power suspension (#112).
    var shouldFreezeDeskClock: Bool {
        presentationGuard.shouldFreezeDeskClock
    }

    var snapshot: BreakSnapshot {
        syncInactivityFreeze()
        refreshDebt()
        let debt = MovementDebtEngine.snapshot(
            debtState,
            at: clock.now,
            isFrozen: presentationGuard.shouldFreezeDeskClock,
            calendar: calendar
        )
        return BreakSnapshot(
            phase: phase,
            settings: settings,
            breakID: breakID,
            sittingStartedAt: sittingStartedAt,
            sittingDuration: sittingDuration(),
            hasMovementDebt: debt.isActive,
            movementDebt: debt,
            remainingWork: remainingWorkDuration(),
            remainingBreak: remainingBreakDuration()
        )
    }

    @discardableResult
    func apply(_ event: BreakEvent) -> BreakTransitionResult {
        let result: BreakTransitionResult
        switch event {
        case .start:
            result = applyStart()
        case .evaluate:
            result = applyEvaluate()
        case .startBreakNow:
            result = applyStartBreakNow()
        case .beginTimedBreak:
            result = applyBeginTimedBreak()
        case .complete:
            result = applyComplete()
        case .skip:
            result = applySkip()
        case .postpone(let until):
            result = applyPostpone(until: until)
        case .pause:
            result = applyPause()
        case .resume:
            result = applyResume()
        case .standDetected:
            result = applyStandDetected()
        case .movementVerified:
            result = applyMovementVerified()
        case .verificationFailed:
            result = applyVerificationFailed()
        case .updateSettings(let newSettings):
            settings = newSettings
            syncIdleFreezeThreshold()
            result = .success(snapshot)
        }

        if case .success = result {
            persist()
        }
        return result
    }

    // MARK: - Transitions

    private func applyStart() -> BreakTransitionResult {
        switch phase {
        case .idle:
            beginWorking(from: clock.now, preserveDebt: false)
            emitScheduledIfWorking()
            return .success(snapshot)
        case .working, .breakDue, .onBreak, .postponed, .deferredForPresentation, .paused:
            // Idempotent when already running (e.g. restored state).
            return .success(snapshot)
        }
    }

    private func applyEvaluate() -> BreakTransitionResult {
        syncInactivityFreeze()
        refreshDebt()
        switch phase {
        case .working(let until), .postponed(let until):
            // Sleep/lock pauses the work clock — don't fire due while inactive.
            if sittingFreezeStartedAt != nil {
                return .success(snapshot)
            }
            guard clock.now >= until else { return .success(snapshot) }
            becomeDueOrDefer(pendingSince: until)
            return .success(snapshot)
        case .deferredForPresentation:
            guard !presentationGuard.isBlocking else { return .success(snapshot) }
            phase = .breakDue
            markDebtActive()
            ensureBreakIdentity()
            emitDue()
            return .success(snapshot)
        case .onBreak(let endsAt, let verification):
            if presentationGuard.isBlocking {
                // Mid-break call/share — drop overlay/camera, keep the owed break.
                phase = .deferredForPresentation(pendingSince: clock.now)
                markDebtActive()
                ensureBreakIdentity()
                emitDeferred(pendingSince: clock.now)
                return .success(snapshot)
            }
            if sittingFreezeStartedAt != nil {
                return .success(snapshot)
            }
            if clock.now >= endsAt, endsAt != clock.now {
                phase = .onBreak(endsAt: clock.now, verification: verification)
            }
            return .success(snapshot)
        case .breakDue:
            if presentationGuard.isBlocking {
                phase = .deferredForPresentation(pendingSince: clock.now)
                markDebtActive()
                ensureBreakIdentity()
                emitDeferred(pendingSince: clock.now)
            }
            return .success(snapshot)
        case .paused, .idle:
            return .success(snapshot)
        }
    }

    private func applyStartBreakNow() -> BreakTransitionResult {
        switch phase {
        case .idle, .working, .paused, .postponed, .deferredForPresentation, .breakDue:
            becomeDueOrDefer(pendingSince: clock.now)
            return .success(snapshot)
        case .onBreak:
            return .failure(.invalidTransition(from: phase, event: .startBreakNow))
        }
    }

    private func applyBeginTimedBreak() -> BreakTransitionResult {
        guard case .breakDue = phase else {
            return .failure(.invalidTransition(from: phase, event: .beginTimedBreak))
        }
        let endsAt = clock.now.addingTimeInterval(settings.breakDuration.seconds)
        phase = .onBreak(
            endsAt: endsAt,
            verification: .awaitingStand
        )
        remainingWhenPaused = nil
        emit(
            .breakStarted,
            payload: .breakStarted(endsAt: endsAt)
        )
        return .success(snapshot)
    }

    private func applyComplete() -> BreakTransitionResult {
        guard case .onBreak(_, let verification) = phase else {
            return .failure(.invalidTransition(from: phase, event: .complete))
        }
        switch verification {
        case .movementVerified, .failedVerification:
            break
        case .awaitingStand, .standingDetected:
            return .failure(.invalidTransition(from: phase, event: .complete))
        }
        let failedOpen = verification == .failedVerification
        let completedID = breakID
        emit(
            .breakCompleted,
            breakID: completedID,
            payload: .breakCompleted(
                stoodForSeconds: nil,
                motionScore: nil,
                failedOpen: failedOpen
            )
        )
        MovementDebtEngine.clear(&debtState, at: clock.now, calendar: calendar)
        breakID = nil
        beginWorking(from: clock.now, preserveDebt: false)
        emitScheduledIfWorking()
        return .success(snapshot)
    }

    private func applySkip() -> BreakTransitionResult {
        switch phase {
        case .breakDue, .onBreak, .deferredForPresentation, .postponed:
            markDebtActive()
            emit(.breakSkipped, payload: .breakSkipped)
            breakID = nil
            beginWorking(from: clock.now, preserveDebt: true)
            emitScheduledIfWorking()
            return .success(snapshot)
        case .idle, .working, .paused:
            return .failure(.invalidTransition(from: phase, event: .skip))
        }
    }

    private func applyPostpone(until date: Date) -> BreakTransitionResult {
        switch phase {
        case .breakDue, .onBreak, .postponed, .deferredForPresentation:
            markDebtActive()
            ensureBreakIdentity()
            if sittingStartedAt == nil {
                sittingStartedAt = clock.now
            }
            phase = .postponed(until: date)
            remainingWhenPaused = nil
            emit(.breakPostponed, payload: .breakPostponed(until: date))
            return .success(snapshot)
        case .idle, .working, .paused:
            return .failure(.invalidTransition(from: phase, event: .postpone(until: date)))
        }
    }

    private func applyPause() -> BreakTransitionResult {
        guard case .working(let until) = phase else {
            return .failure(.invalidTransition(from: phase, event: .pause))
        }
        remainingWhenPaused = max(0, until.timeIntervalSince(clock.now))
        phase = .paused
        return .success(snapshot)
    }

    private func applyResume() -> BreakTransitionResult {
        guard phase == .paused, let remaining = remainingWhenPaused else {
            return .failure(.invalidTransition(from: phase, event: .resume))
        }
        remainingWhenPaused = nil
        phase = .working(until: clock.now.addingTimeInterval(remaining))
        return .success(snapshot)
    }

    private func applyStandDetected() -> BreakTransitionResult {
        guard case .onBreak(let endsAt, let verification) = phase else {
            return .failure(.invalidTransition(from: phase, event: .standDetected))
        }
        switch verification {
        case .awaitingStand:
            phase = .onBreak(endsAt: endsAt, verification: .standingDetected)
            return .success(snapshot)
        case .standingDetected, .movementVerified, .failedVerification:
            // Idempotent once standing (or past it).
            return .success(snapshot)
        }
    }

    private func applyMovementVerified() -> BreakTransitionResult {
        guard case .onBreak(let endsAt, let verification) = phase else {
            return .failure(.invalidTransition(from: phase, event: .movementVerified))
        }
        switch verification {
        case .standingDetected, .awaitingStand:
            // Allow direct verify if proof tracker races past stand in one tick.
            phase = .onBreak(endsAt: endsAt, verification: .movementVerified)
            return .success(snapshot)
        case .movementVerified, .failedVerification:
            return .success(snapshot)
        }
    }

    private func applyVerificationFailed() -> BreakTransitionResult {
        guard case .onBreak(let endsAt, _) = phase else {
            return .failure(.invalidTransition(from: phase, event: .verificationFailed))
        }
        phase = .onBreak(endsAt: endsAt, verification: .failedVerification)
        return .success(snapshot)
    }

    // MARK: - Helpers

    private func beginWorking(from date: Date, preserveDebt: Bool) {
        if !preserveDebt {
            sittingStartedAt = date
            sittingFreezeStartedAt = nil
            MovementDebtEngine.clear(&debtState, at: date, calendar: calendar)
        } else if sittingStartedAt == nil {
            sittingStartedAt = date
        }
        remainingWhenPaused = nil
        phase = .working(until: date.addingTimeInterval(settings.workInterval.seconds))
    }

    private func syncIdleFreezeThreshold() {
        presentationGuard.idleFreezeThresholdSeconds = settings.idleFreezeAfter.seconds
    }

    /// Freeze sitting + schedule clocks while locked, asleep, or HID-idle.
    /// Meeting / presentation blocks still accrue — only desk-inactivity freezes.
    private func syncInactivityFreeze() {
        let frozen = presentationGuard.shouldFreezeDeskClock
        if frozen {
            if sittingFreezeStartedAt == nil {
                sittingFreezeStartedAt = clock.now
            }
            return
        }
        guard let freezeStart = sittingFreezeStartedAt else { return }
        let delta = max(0, clock.now.timeIntervalSince(freezeStart))
        sittingFreezeStartedAt = nil
        guard delta > 0 else { return }
        if let start = sittingStartedAt {
            sittingStartedAt = start.addingTimeInterval(delta)
        }
        shiftScheduleDeadlines(by: delta)
    }

    private func shiftScheduleDeadlines(by delta: TimeInterval) {
        switch phase {
        case .working(let until):
            phase = .working(until: until.addingTimeInterval(delta))
        case .postponed(let until):
            phase = .postponed(until: until.addingTimeInterval(delta))
        case .onBreak(let endsAt, let verification):
            phase = .onBreak(endsAt: endsAt.addingTimeInterval(delta), verification: verification)
        case .idle, .breakDue, .deferredForPresentation, .paused:
            break
        }
    }

    private func becomeDueOrDefer(pendingSince: Date) {
        markDebtActive()
        ensureBreakIdentity()
        if sittingStartedAt == nil {
            sittingStartedAt = pendingSince
        }
        if presentationGuard.isBlocking {
            phase = .deferredForPresentation(pendingSince: clock.now)
            emitDeferred(pendingSince: clock.now)
        } else {
            phase = .breakDue
            emitDue()
        }
        remainingWhenPaused = nil
    }

    // MARK: - Domain events

    private func emit(
        _ name: DomainEventName,
        breakID overrideBreakID: UUID? = nil,
        payload: DomainEventPayload
    ) {
        guard let eventPublisher else { return }
        eventPublisher.publish(
            DomainEvent(
                name: name,
                occurredAt: clock.now,
                breakID: overrideBreakID ?? breakID,
                payload: payload
            )
        )
    }

    private func emitScheduledIfWorking() {
        guard case .working(let until) = phase else { return }
        emit(.breakScheduled, payload: .breakScheduled(until: until))
    }

    private func emitDue() {
        emit(.breakDue, payload: .breakDue(sittingSeconds: sittingDuration()?.seconds))
    }

    private func emitDeferred(pendingSince: Date) {
        emit(
            .breakDeferredForPresentation,
            payload: .breakDeferredForPresentation(pendingSince: pendingSince)
        )
    }

    private func markDebtActive() {
        MovementDebtEngine.ensureActive(
            &debtState,
            at: clock.now,
            isFrozen: presentationGuard.shouldFreezeDeskClock,
            calendar: calendar
        )
    }

    private func refreshDebt() {
        MovementDebtEngine.evaluate(
            &debtState,
            at: clock.now,
            isFrozen: presentationGuard.shouldFreezeDeskClock,
            calendar: calendar
        )
    }

    private func ensureBreakIdentity() {
        if breakID == nil {
            breakID = UUID()
        }
    }

    private func remainingWorkDuration() -> BreakDuration? {
        let reference = sittingFreezeStartedAt ?? clock.now
        switch phase {
        case .working(let until):
            return .seconds(max(0, until.timeIntervalSince(reference)))
        case .postponed(let until):
            return .seconds(max(0, until.timeIntervalSince(reference)))
        case .paused:
            if let remaining = remainingWhenPaused {
                return .seconds(remaining)
            }
            return nil
        case .breakDue, .deferredForPresentation, .idle, .onBreak:
            return nil
        }
    }

    private func remainingBreakDuration() -> BreakDuration? {
        guard case .onBreak(let endsAt, _) = phase else { return nil }
        let reference = sittingFreezeStartedAt ?? clock.now
        return .seconds(max(0, endsAt.timeIntervalSince(reference)))
    }

    private func sittingDuration() -> BreakDuration? {
        guard let sittingStartedAt else { return nil }
        // While frozen, stop the clock at freeze start so sleep doesn't inflate desk time.
        let end = sittingFreezeStartedAt ?? clock.now
        return .seconds(max(0, end.timeIntervalSince(sittingStartedAt)))
    }

    // MARK: - Persistence

    private func persist() {
        guard let store else { return }
        guard let persisted = makePersistedState() else {
            store.clear()
            return
        }
        store.save(persisted)
    }

    private func makePersistedState() -> BreakPersistedState? {
        refreshDebt()
        let base = BreakPersistedState(
            kind: .working,
            until: nil,
            pendingSince: nil,
            remainingWhenPaused: nil,
            sittingStartedAt: sittingStartedAt,
            sittingFreezeStartedAt: sittingFreezeStartedAt,
            hasMovementDebt: debtState.isActive,
            movementDebt: debtState,
            breakID: breakID,
            workIntervalSeconds: settings.workInterval.seconds,
            breakDurationSeconds: settings.breakDuration.seconds,
            idleFreezeAfterSeconds: settings.idleFreezeAfter.seconds
        )

        switch phase {
        case .idle:
            return nil
        case .working(let until):
            var state = base
            state.kind = .working
            state.until = until
            return state
        case .breakDue:
            var state = base
            state.kind = .breakDue
            return state
        case .postponed(let until):
            var state = base
            state.kind = .postponed
            state.until = until
            return state
        case .deferredForPresentation(let pendingSince):
            var state = base
            state.kind = .deferredForPresentation
            state.pendingSince = pendingSince
            return state
        case .paused:
            var state = base
            state.kind = .paused
            state.remainingWhenPaused = remainingWhenPaused
            return state
        case .onBreak:
            // Never restore an active camera session — land on prompted.
            var state = base
            state.kind = .breakDue
            state.hasMovementDebt = true
            MovementDebtEngine.ensureActive(
                &debtState,
                at: clock.now,
                isFrozen: presentationGuard.shouldFreezeDeskClock,
                calendar: calendar
            )
            state.movementDebt = debtState
            state.hasMovementDebt = debtState.isActive
            return state
        }
    }

    private func restoreIfNeeded() {
        guard let store, let saved = store.load() else { return }
        settings = BreakSettings(
            workInterval: .seconds(saved.workIntervalSeconds),
            breakDuration: .seconds(saved.breakDurationSeconds),
            idleFreezeAfter: .seconds(
                saved.idleFreezeAfterSeconds ?? BreakSettings.default.idleFreezeAfter.seconds
            )
        )
        sittingStartedAt = saved.sittingStartedAt
        sittingFreezeStartedAt = saved.sittingFreezeStartedAt
        breakID = saved.breakID
        remainingWhenPaused = saved.remainingWhenPaused

        if let persistedDebt = saved.movementDebt {
            debtState = persistedDebt
            MovementDebtEngine.evaluate(
                &debtState,
                at: clock.now,
                isFrozen: presentationGuard.shouldFreezeDeskClock,
                calendar: calendar
            )
        } else {
            debtState = .synthesized(
                hasDebt: saved.hasMovementDebt,
                sittingStartedAt: saved.sittingStartedAt,
                at: clock.now,
                calendar: calendar
            )
        }

        switch saved.kind {
        case .working:
            if let until = saved.until {
                phase = .working(until: until)
            } else {
                beginWorking(from: clock.now, preserveDebt: debtState.isActive)
            }
        case .breakDue:
            phase = .breakDue
            markDebtActive()
            ensureBreakIdentity()
        case .postponed:
            if let until = saved.until {
                phase = .postponed(until: until)
            } else {
                phase = .breakDue
                markDebtActive()
            }
            ensureBreakIdentity()
        case .deferredForPresentation:
            phase = .deferredForPresentation(pendingSince: saved.pendingSince ?? clock.now)
            markDebtActive()
            ensureBreakIdentity()
        case .paused:
            phase = .paused
        }

        syncIdleFreezeThreshold()
        // After phase restore: thaw freeze against current inactivity and shift deadlines.
        syncInactivityFreeze()
    }
}
