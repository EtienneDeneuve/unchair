import SwiftUI

/// Compact native status dashboard for local break history (issue #85).
/// Hierarchy: hero → next action → Today → Human Runtime → export footer.
struct TodayView: View {
    @Bindable var shell: MenuBarShell

    var body: some View {
        let _ = shell.statusRevision
        TodayDashboardLayout(
            model: TodayDashboardModel.make(
                stats: shell.todayStats,
                week: shell.weeklyHumanRuntimeSummary,
                snap: shell.statusSnapshot
            )
        )
    }
}

/// Presentation model — metrics only, no new aggregation.
struct TodayDashboardModel: Equatable {
    var heroEyebrow: String
    var heroValue: String
    var heroCaption: String
    var nextAction: String
    var todayCompleted: Int
    var todaySkipped: Int
    var todayMovedMinutes: Int
    var todayLongest: String
    var week: HumanRuntimeWeeklySummary
    var dayLabel: String

    static func make(stats: TodayStats, week: HumanRuntimeWeeklySummary, snap: TodayStatusSnapshot) -> TodayDashboardModel {
        let primary = PrimaryState.resolve(stats: stats, snap: snap)
        return TodayDashboardModel(
            heroEyebrow: primary.eyebrow,
            heroValue: primary.value,
            heroCaption: primary.caption,
            nextAction: NextActionLine.resolve(snap: snap, heroShowsDebt: primary.showsDebt),
            todayCompleted: stats.completedCount,
            todaySkipped: stats.skippedCount,
            todayMovedMinutes: stats.movementMinutesRounded,
            todayLongest: HumanStatusFormatting.friendlyDuration(
                TimeInterval(stats.longestDeskMinutesRounded * 60)
            ),
            week: week,
            dayLabel: stats.dayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        )
    }
}

/// Pure layout — intentional ~420×560, no Form chrome, one elevated week surface.
struct TodayDashboardLayout: View {
    let model: TodayDashboardModel
    var onCopyImage: (() -> String?)? = nil
    var onSavePNG: (() -> String?)? = nil

    @State private var exportStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
                .padding(.bottom, 14)

            Text(model.nextAction)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)

            todayBlock
                .padding(.bottom, 18)

            HumanRuntimeWeeklyPanel(
                summary: model.week,
                showsExport: false
            )

            footer
                .padding(.top, 12)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: 420, alignment: .topLeading)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.heroEyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(model.heroValue)
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(model.heroCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                todayChip("\(model.todayCompleted)", "done")
                todaySep
                todayChip("\(model.todaySkipped)", "skipped")
                todaySep
                todayChip("\(model.todayMovedMinutes)m", "moved")
                todaySep
                todayChip(model.todayLongest, "longest")
            }
        }
    }

    private var todaySep: some View {
        Text("·")
            .font(.caption)
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 8)
    }

    private func todayChip(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Copy Image") {
                exportStatus = (onCopyImage ?? defaultCopy)()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .disabled(model.week.isEmpty)

            Button("Save PNG…") {
                exportStatus = (onSavePNG ?? defaultSave)()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .disabled(model.week.isEmpty)

            if let exportStatus {
                Text(exportStatus)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Text(model.dayLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func defaultCopy() -> String? {
        HumanRuntimeWeeklyExportActions.copyPNG(summary: model.week) ? "Copied" : "Failed"
    }

    private func defaultSave() -> String? {
        HumanRuntimeWeeklyExportActions.savePNG(summary: model.week) ? "Saved" : "Cancelled"
    }
}

// MARK: - Copy / state helpers

private enum PrimaryState {
    static func resolve(stats: TodayStats, snap: TodayStatusSnapshot) -> (eyebrow: String, value: String, caption: String, showsDebt: Bool) {
        switch snap.phase {
        case .onBreak:
            return (
                "On break",
                HumanStatusFormatting.friendlyDuration(snap.remainingBreakSeconds ?? 0),
                "Local movement check — frames stay on this Mac.",
                false
            )
        case .breakDue:
            if snap.debtActive, snap.debtSeconds > 0 {
                return (
                    "Break due",
                    HumanStatusFormatting.friendlyDuration(snap.debtSeconds),
                    "Debt stays open until a break completes.",
                    true
                )
            }
            return ("Break due", "Now", "Stand up when you can. Verification is local.", false)
        case .idle, .working, .postponed, .deferredForPresentation, .paused:
            if snap.debtActive, snap.debtSeconds > 0 {
                return (
                    "Movement debt",
                    HumanStatusFormatting.friendlyDuration(snap.debtSeconds),
                    "Postpone keeps debt. Complete clears it.",
                    true
                )
            }
            let sitting = snap.sittingSeconds ?? TimeInterval(stats.longestDeskMinutesRounded * 60)
            return (
                "At desk",
                HumanStatusFormatting.friendlyDuration(sitting),
                stats.isEmpty
                    ? "Schedule running — no breaks logged yet."
                    : HumanStatusFormatting.longestSessionLine(minutes: stats.longestDeskMinutesRounded),
                false
            )
        }
    }
}

private enum NextActionLine {
    static func resolve(snap: TodayStatusSnapshot, heroShowsDebt: Bool) -> String {
        switch snap.phase {
        case .onBreak:
            return "Finish the movement check to clear this break"
        case .breakDue:
            return heroShowsDebt ? "Break owed now — stand when you can" : "Break owed now"
        case .idle, .working, .postponed, .deferredForPresentation, .paused:
            return HumanStatusFormatting.nextBreakLine(
                remainingSeconds: snap.remainingWorkSeconds,
                debtSeconds: snap.debtSeconds,
                debtActive: snap.debtActive && !heroShowsDebt
            )
        }
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
