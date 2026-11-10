import SwiftUI

/// Compact native status dashboard for local break history (issue #85).
struct TodayView: View {
    @Bindable var shell: MenuBarShell

    var body: some View {
        let _ = shell.statusRevision
        let stats = shell.todayStats
        let week = shell.weeklyHumanRuntimeSummary
        let snap = shell.statusSnapshot

        VStack(alignment: .leading, spacing: 16) {
            primaryCard(stats: stats, snap: snap)

            Text(nextBreakLine(snap: snap))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            todayStrip(stats)

            HumanRuntimeWeeklyPanel(summary: week)

            Text(dayLabel(stats.dayStart))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 400, height: 480, alignment: .topLeading)
    }

    // MARK: - Primary

    @ViewBuilder
    private func primaryCard(stats: TodayStats, snap: TodayStatusSnapshot) -> some View {
        let primary = primaryState(stats: stats, snap: snap)
        VStack(alignment: .leading, spacing: 6) {
            Text(primary.eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(primary.value)
                .font(.largeTitle.weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(primary.caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func primaryState(stats: TodayStats, snap: TodayStatusSnapshot) -> (eyebrow: String, value: String, caption: String) {
        switch snap.phase {
        case .onBreak:
            let remaining = snap.remainingBreakSeconds ?? 0
            return (
                "On break",
                HumanStatusFormatting.friendlyDuration(remaining),
                "Movement check in progress — frames stay on this Mac."
            )
        case .breakDue:
            let debt = snap.debtSeconds
            if snap.debtActive, debt > 0 {
                return (
                    "Break due",
                    HumanStatusFormatting.friendlyDuration(debt),
                    "Movement debt is open until a break is completed."
                )
            }
            return ("Break due", "Now", "Stand up when you can. Verification is local.")
        case .idle, .working, .postponed, .deferredForPresentation, .paused:
            if snap.debtActive, snap.debtSeconds > 0 {
                return (
                    "Movement debt",
                    HumanStatusFormatting.friendlyDuration(snap.debtSeconds),
                    "Postponing preserves debt. Completing clears it."
                )
            }
            let sitting = snap.sittingSeconds ?? TimeInterval(stats.longestDeskMinutesRounded * 60)
            return (
                "At desk",
                HumanStatusFormatting.friendlyDuration(sitting),
                stats.isEmpty
                    ? "No breaks logged yet today — schedule is running."
                    : HumanStatusFormatting.longestSessionLine(minutes: stats.longestDeskMinutesRounded)
            )
        }
    }

    private func nextBreakLine(snap: TodayStatusSnapshot) -> String {
        switch snap.phase {
        case .onBreak:
            return "On break · \(HumanStatusFormatting.friendlyDuration(snap.remainingBreakSeconds ?? 0)) left"
        case .breakDue:
            if snap.debtActive, snap.debtSeconds > 0 {
                return "Break due now · Movement debt \(HumanStatusFormatting.friendlyDuration(snap.debtSeconds))"
            }
            return "Break due now"
        case .idle, .working, .postponed, .deferredForPresentation, .paused:
            return HumanStatusFormatting.nextBreakLine(
                remainingSeconds: snap.remainingWorkSeconds,
                debtSeconds: snap.debtSeconds,
                debtActive: snap.debtActive
            )
        }
    }

    // MARK: - Today strip

    private func todayStrip(_ stats: TodayStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                miniMetric("Completed", "\(stats.completedCount)")
                miniMetric("Skipped", "\(stats.skippedCount)")
                miniMetric("Moved", "\(stats.movementMinutesRounded) min")
                miniMetric("Longest", HumanStatusFormatting.friendlyDuration(TimeInterval(stats.longestDeskMinutesRounded * 60)))
            }
        }
    }

    private func miniMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

/// Thin UI projection of live scheduler fields already on `MenuBarShell`.
struct TodayStatusSnapshot: Equatable {
    var phase: BreakPhase
    var sittingSeconds: TimeInterval?
    var remainingWorkSeconds: TimeInterval?
    var remainingBreakSeconds: TimeInterval?
    var debtActive: Bool
    var debtSeconds: TimeInterval
}
