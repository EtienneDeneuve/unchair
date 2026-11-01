import Foundation

/// Daily adherence snapshot derived only from local break history + live schedule.
/// No streaks, no health claims, no cloud.
struct TodayStats: Equatable, Sendable {
    var dayStart: Date
    var completedCount: Int
    var skippedCount: Int
    var postponedCount: Int
    /// Sum of timed-break durations for completed breaks today.
    var movementSeconds: TimeInterval
    /// Longest sitting stretch inferred for today (seconds).
    var longestDeskSeconds: TimeInterval
    /// Live remaining work / next break countdown text from the shell.
    var nextBreakSummary: String
    var isEmpty: Bool

    var movementMinutesRounded: Int {
        Int((movementSeconds / 60).rounded())
    }

    var longestDeskMinutesRounded: Int {
        Int((longestDeskSeconds / 60).rounded())
    }
}

enum TodayStatsCalculator {
    static func make(
        records: [BreakHistoryRecord],
        now: Date,
        calendar: Calendar = .current,
        sittingStartedAt: Date?,
        nextBreakSummary: String
    ) -> TodayStats {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)
        let todays = records.filter { $0.endedAt >= dayStart && $0.endedAt < dayEnd }

        let completed = todays.filter { $0.result == .completed }
        let skipped = todays.filter { $0.result == .skipped }
        let postponed = todays.filter { $0.result == .postponed }

        let movementSeconds = completed.reduce(0.0) { $0 + max(0, $1.durationSeconds) }
        let longestDesk = longestDeskIntervalSeconds(
            completed: completed,
            dayStart: dayStart,
            now: now,
            sittingStartedAt: sittingStartedAt
        )

        return TodayStats(
            dayStart: dayStart,
            completedCount: completed.count,
            skippedCount: skipped.count,
            postponedCount: postponed.count,
            movementSeconds: movementSeconds,
            longestDeskSeconds: longestDesk,
            nextBreakSummary: nextBreakSummary,
            isEmpty: todays.isEmpty
        )
    }

    /// Longest uninterrupted desk stretch today:
    /// - day start → first completed end
    /// - gaps between consecutive completed ends
    /// - last completed end → now (or sittingStartedAt → now when no completes)
    static func longestDeskIntervalSeconds(
        completed: [BreakHistoryRecord],
        dayStart: Date,
        now: Date,
        sittingStartedAt: Date?
    ) -> TimeInterval {
        let ends = completed.map(\.endedAt).sorted()
        var longest: TimeInterval = 0

        if ends.isEmpty {
            let origin = max(dayStart, sittingStartedAt ?? dayStart)
            return max(0, now.timeIntervalSince(origin))
        }

        longest = max(longest, ends[0].timeIntervalSince(dayStart))
        for index in 1..<ends.count {
            longest = max(longest, ends[index].timeIntervalSince(ends[index - 1]))
        }
        longest = max(longest, now.timeIntervalSince(ends[ends.count - 1]))
        return max(0, longest)
    }
}
