import Foundation

/// Derived movement-debt metrics. Adapters read this; they do not recalculate it.
///
/// Issue #20: postponed/deferred immobility is first-class debt, not a hidden timer.
struct MovementDebt: Equatable, Sendable {
    /// True while an owed break has not been successfully completed.
    var isActive: Bool
    /// Accrued debt duration for the current episode (excludes sleep/lock freezes).
    var currentDuration: BreakDuration
    /// Peak `currentDuration` observed today.
    var peakDurationToday: BreakDuration
    /// Total time spent in debt today (closed episodes + current).
    var accumulatedDurationToday: BreakDuration
    /// How many debt episodes started today (continuing overnight counts as one).
    var episodeCountToday: Int

    static let cleared = MovementDebt(
        isActive: false,
        currentDuration: .seconds(0),
        peakDurationToday: .seconds(0),
        accumulatedDurationToday: .seconds(0),
        episodeCountToday: 0
    )
}

/// Persisted accrual state. All transitions are deterministic given `(now, isFrozen, calendar)`.
struct MovementDebtState: Equatable, Codable, Sendable {
    var isActive: Bool
    /// Wall-clock start of the current episode (diagnostics / restart).
    var episodeStartedAt: Date?
    /// Accrued seconds in the current episode, excluding an open freeze interval.
    var accruedSeconds: TimeInterval
    /// When non-nil, accrual is frozen (screen locked / asleep) since this instant.
    var freezeStartedAt: Date?
    /// Calendar day key `yyyy-MM-dd` for daily aggregates.
    var dayKey: String
    /// Accrued seconds from episodes that already cleared today.
    var closedAccumulatedToday: TimeInterval
    var peakToday: TimeInterval
    var episodeCountToday: Int
    var lastEvaluatedAt: Date?

    static func empty(at now: Date, calendar: Calendar) -> MovementDebtState {
        MovementDebtState(
            isActive: false,
            episodeStartedAt: nil,
            accruedSeconds: 0,
            freezeStartedAt: nil,
            dayKey: dayKey(for: now, calendar: calendar),
            closedAccumulatedToday: 0,
            peakToday: 0,
            episodeCountToday: 0,
            lastEvaluatedAt: now
        )
    }

    /// Rebuild from the v0.1 boolean flag after upgrade.
    static func synthesized(
        hasDebt: Bool,
        sittingStartedAt: Date?,
        at now: Date,
        calendar: Calendar
    ) -> MovementDebtState {
        var state = empty(at: now, calendar: calendar)
        guard hasDebt else { return state }
        let origin = sittingStartedAt ?? now
        state.isActive = true
        state.episodeStartedAt = origin
        state.accruedSeconds = max(0, now.timeIntervalSince(origin))
        state.episodeCountToday = 1
        state.peakToday = state.accruedSeconds
        state.lastEvaluatedAt = now
        return state
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Pure functions over `MovementDebtState`. No wall-clock sleeps.
enum MovementDebtEngine {
    /// Begin accruing debt if not already active (idempotent).
    static func activate(
        _ state: inout MovementDebtState,
        at now: Date,
        isFrozen: Bool,
        calendar: Calendar
    ) {
        rolloverDayIfNeeded(&state, at: now, calendar: calendar)
        flush(&state, at: now)
        if state.isActive {
            applyFreezeLatch(&state, isFrozen: isFrozen, at: now)
            state.lastEvaluatedAt = now
            updatePeak(&state)
            return
        }
        state.isActive = true
        state.episodeStartedAt = now
        state.accruedSeconds = 0
        state.freezeStartedAt = isFrozen ? now : nil
        state.episodeCountToday += 1
        state.lastEvaluatedAt = now
        updatePeak(&state)
    }

    /// Ensure debt is active (due / postpone / defer / skip paths).
    static func ensureActive(
        _ state: inout MovementDebtState,
        at now: Date,
        isFrozen: Bool,
        calendar: Calendar
    ) {
        if state.isActive {
            evaluate(&state, at: now, isFrozen: isFrozen, calendar: calendar)
        } else {
            activate(&state, at: now, isFrozen: isFrozen, calendar: calendar)
        }
    }

    /// Successful break completion — only path that clears debt.
    static func clear(
        _ state: inout MovementDebtState,
        at now: Date,
        calendar: Calendar
    ) {
        rolloverDayIfNeeded(&state, at: now, calendar: calendar)
        flush(&state, at: now)
        if state.isActive {
            state.closedAccumulatedToday += state.accruedSeconds
            state.isActive = false
            state.episodeStartedAt = nil
            state.accruedSeconds = 0
            state.freezeStartedAt = nil
        }
        state.lastEvaluatedAt = now
    }

    /// Advance accrual / freeze latch to `now`.
    static func evaluate(
        _ state: inout MovementDebtState,
        at now: Date,
        isFrozen: Bool,
        calendar: Calendar
    ) {
        rolloverDayIfNeeded(&state, at: now, calendar: calendar)
        flush(&state, at: now)
        if state.isActive {
            applyFreezeLatch(&state, isFrozen: isFrozen, at: now)
        } else {
            state.freezeStartedAt = nil
        }
        state.lastEvaluatedAt = now
        updatePeak(&state)
    }

    static func snapshot(
        _ state: MovementDebtState,
        at now: Date,
        isFrozen: Bool,
        calendar: Calendar
    ) -> MovementDebt {
        var copy = state
        evaluate(&copy, at: now, isFrozen: isFrozen, calendar: calendar)
        let current = copy.isActive ? copy.accruedSeconds : 0
        let accumulated = copy.closedAccumulatedToday + (copy.isActive ? copy.accruedSeconds : 0)
        return MovementDebt(
            isActive: copy.isActive,
            currentDuration: .seconds(current),
            peakDurationToday: .seconds(copy.peakToday),
            accumulatedDurationToday: .seconds(accumulated),
            episodeCountToday: copy.episodeCountToday
        )
    }

    // MARK: - Internals

    private static func flush(_ state: inout MovementDebtState, at now: Date) {
        guard let last = state.lastEvaluatedAt else {
            state.lastEvaluatedAt = now
            return
        }
        let delta = max(0, now.timeIntervalSince(last))
        guard state.isActive, state.freezeStartedAt == nil, delta > 0 else { return }
        state.accruedSeconds += delta
    }

    private static func applyFreezeLatch(
        _ state: inout MovementDebtState,
        isFrozen: Bool,
        at now: Date
    ) {
        if isFrozen {
            if state.freezeStartedAt == nil {
                state.freezeStartedAt = now
            }
        } else if state.freezeStartedAt != nil {
            state.freezeStartedAt = nil
        }
    }

    private static func updatePeak(_ state: inout MovementDebtState) {
        guard state.isActive else { return }
        state.peakToday = max(state.peakToday, state.accruedSeconds)
    }

    private static func rolloverDayIfNeeded(
        _ state: inout MovementDebtState,
        at now: Date,
        calendar: Calendar
    ) {
        let key = MovementDebtState.dayKey(for: now, calendar: calendar)
        guard key != state.dayKey else { return }
        // Catch up accrual on the previous day before resetting daily counters.
        flush(&state, at: now)
        state.dayKey = key
        state.closedAccumulatedToday = 0
        state.peakToday = state.isActive ? state.accruedSeconds : 0
        state.episodeCountToday = state.isActive ? 1 : 0
        state.lastEvaluatedAt = now
    }
}
