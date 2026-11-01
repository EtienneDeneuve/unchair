import Foundation

/// Writes privacy-safe break outcomes into a local store.
final class BreakHistoryRecorder {
    private let store: any BreakHistoryStoring
    private let clock: BreakClock

    /// Captured when a timed break starts so duration/verification can be attributed.
    private var activeStartedAt: Date?
    private var activeBreakID: UUID?
    private var activeScheduledAt: Date?

    init(store: any BreakHistoryStoring, clock: BreakClock) {
        self.store = store
        self.clock = clock
    }

    var records: [BreakHistoryRecord] { store.records }

    func noteBreakPrompted(breakID: UUID?, scheduledAt: Date?) {
        // Remember prompt context for the next complete/skip/postpone.
        activeBreakID = breakID
        activeScheduledAt = scheduledAt ?? clock.now
        activeStartedAt = nil
    }

    func noteTimedBreakStarted(breakID: UUID?, scheduledAt: Date?) {
        activeBreakID = breakID ?? activeBreakID
        activeScheduledAt = scheduledAt ?? activeScheduledAt ?? clock.now
        activeStartedAt = clock.now
    }

    func recordCompleted(verification: BreakHistoryVerification) {
        append(
            result: .completed,
            verification: verification,
            durationSeconds: activeDuration()
        )
        resetActive()
    }

    func recordSkipped() {
        append(
            result: .skipped,
            verification: nil,
            durationSeconds: activeDuration()
        )
        resetActive()
    }

    func recordCancelled() {
        append(
            result: .cancelled,
            verification: nil,
            durationSeconds: activeDuration()
        )
        resetActive()
    }

    func recordPostponed() {
        append(
            result: .postponed,
            verification: nil,
            durationSeconds: 0
        )
        // Postpone keeps the owed break — keep breakID/scheduledAt, clear start.
        activeStartedAt = nil
    }

    func clearAll() {
        store.clearAll()
        resetActive()
    }

    private func append(
        result: BreakHistoryResult,
        verification: BreakHistoryVerification?,
        durationSeconds: TimeInterval
    ) {
        let record = BreakHistoryRecord(
            id: UUID(),
            recordedAt: clock.now,
            breakID: activeBreakID,
            scheduledAt: activeScheduledAt,
            startedAt: activeStartedAt,
            endedAt: clock.now,
            result: result,
            durationSeconds: durationSeconds,
            verification: verification
        )
        store.append(record)
    }

    private func activeDuration() -> TimeInterval {
        guard let started = activeStartedAt else { return 0 }
        return max(0, clock.now.timeIntervalSince(started))
    }

    private func resetActive() {
        activeStartedAt = nil
        activeBreakID = nil
        activeScheduledAt = nil
    }
}
