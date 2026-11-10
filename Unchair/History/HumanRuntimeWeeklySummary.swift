import Foundation

/// Privacy-safe weekly Human Runtime card model.
/// Derived only from local break history — never camera, landmarks, health, or identity.
struct HumanRuntimeWeeklySummary: Equatable, Sendable {
    /// ISO week number in the summary calendar (1…53).
    var weekNumber: Int
    /// Inclusive start of the ISO week (start of day).
    var weekStart: Date
    /// Exclusive end of the ISO week (start of day + 7).
    var weekEndExclusive: Date

    var completedCount: Int
    var postponedCount: Int
    var skippedCount: Int
    /// Peak unfinished-break gap between consecutive completions in the week (seconds).
    var movementDebtPeakSeconds: TimeInterval
    /// Mean time from break start → completion for completed rows that have `startedAt`.
    var meanTimeToButtOffSeconds: TimeInterval?
    /// Completed / (completed + skipped). Postpones are debt, not scored as failures here.
    var sittingSLOPercent: Double

    var isEmpty: Bool {
        completedCount + postponedCount + skippedCount == 0
    }

    var movementDebtPeakMinutesRounded: Int {
        Int((movementDebtPeakSeconds / 60).rounded())
    }

    /// Deadpan incident line when debt peak exceeds one hour (requires in-week activity).
    var sevLine: String? {
        guard !isEmpty, movementDebtPeakSeconds >= 3600 else { return nil }
        return "SEV-2: Glute Availability Degradation"
    }
}

enum HumanRuntimeWeeklySummaryCalculator {
    /// Builds a weekly summary from local history only.
    static func make(
        records: [BreakHistoryRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> HumanRuntimeWeeklySummary {
        var cal = calendar
        cal.firstWeekday = 2 // Monday — ISO-ish week boundaries for the card.

        let weekStart = startOfWeek(containing: now, calendar: cal)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? now.addingTimeInterval(7 * 86_400)
        let weekRecords = records.filter { $0.endedAt >= weekStart && $0.endedAt < weekEnd }

        let completed = weekRecords.filter { $0.result == .completed }.sorted { $0.endedAt < $1.endedAt }
        let postponed = weekRecords.filter { $0.result == .postponed }
        let skipped = weekRecords.filter { $0.result == .skipped }

        let scored = completed.count + skipped.count
        let slo: Double
        if scored == 0 {
            slo = 100
        } else {
            slo = (Double(completed.count) / Double(scored)) * 100
        }

        // Debt peak is only meaningful between completions. Skips/postpones alone
        // must not invent a multi-day "SEV-2" gap from week start → now.
        let debtPeak: TimeInterval
        if completed.isEmpty {
            debtPeak = 0
        } else {
            debtPeak = movementDebtPeakSeconds(
                completedEnds: completed.map(\.endedAt),
                weekStart: weekStart,
                now: min(now, weekEnd),
                calendar: cal
            )
        }

        let durations: [TimeInterval] = completed.compactMap { row in
            guard let started = row.startedAt else { return nil }
            return max(0, row.endedAt.timeIntervalSince(started))
        }
        let mttb: TimeInterval? = durations.isEmpty
            ? nil
            : durations.reduce(0, +) / Double(durations.count)

        let weekNumber = cal.component(.weekOfYear, from: weekStart)

        return HumanRuntimeWeeklySummary(
            weekNumber: weekNumber,
            weekStart: weekStart,
            weekEndExclusive: weekEnd,
            completedCount: completed.count,
            postponedCount: postponed.count,
            skippedCount: skipped.count,
            movementDebtPeakSeconds: debtPeak,
            meanTimeToButtOffSeconds: mttb,
            sittingSLOPercent: slo
        )
    }

    /// Longest gap between completions (and weekStart → first / last → now) as a local debt proxy.
    static func movementDebtPeakSeconds(
        completedEnds: [Date],
        weekStart: Date,
        now: Date,
        calendar _: Calendar
    ) -> TimeInterval {
        let ends = completedEnds.sorted()
        guard !ends.isEmpty else {
            return max(0, now.timeIntervalSince(weekStart))
        }
        var peak = ends[0].timeIntervalSince(weekStart)
        for index in 1..<ends.count {
            peak = max(peak, ends[index].timeIntervalSince(ends[index - 1]))
        }
        peak = max(peak, now.timeIntervalSince(ends[ends.count - 1]))
        return max(0, peak)
    }

    static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart)
        // weekday: 1=Sun … 7=Sat. firstWeekday=2 → Monday.
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: dayStart) ?? dayStart
    }
}

enum HumanRuntimeWeeklySummaryFormatting {
    static func sittingSLO(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        if minutes > 0 {
            return "\(minutes)m\(String(format: "%02d", secs))s"
        }
        return "\(secs)s"
    }

    static func cardLines(_ summary: HumanRuntimeWeeklySummary) -> [String] {
        var lines = [
            "HUMAN RUNTIME — WEEK \(summary.weekNumber)",
            "",
            "Sitting SLO            \(sittingSLO(summary.sittingSLOPercent))",
            "Movement debt peak       \(summary.movementDebtPeakMinutesRounded)m",
            "Breaks completed          \(summary.completedCount)",
            "Breaks postponed           \(summary.postponedCount)",
        ]
        if let mttb = summary.meanTimeToButtOffSeconds {
            lines.append("MTTB                    \(duration(mttb))")
        }
        if let sev = summary.sevLine {
            lines.append("")
            lines.append(sev)
        }
        return lines
    }
}
