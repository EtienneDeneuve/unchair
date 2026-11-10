import SwiftUI

/// Compact native status dashboard for local break history (issue #85).
/// Hierarchy: hero → next action → Today → Human Runtime → export footer.
struct TodayView: View {
    @Bindable var shell: MenuBarShell

    var body: some View {
        let _ = shell.statusRevision
        VStack(alignment: .leading, spacing: 0) {
            if shell.showsCameraSetupRecovery {
                cameraRecoveryBanner
            }
            TodayDashboardLayout(
                model: TodayDashboardModel.make(
                    stats: shell.todayStats,
                    week: shell.weeklyHumanRuntimeSummary,
                    snap: shell.statusSnapshot
                )
            )
        }
    }

    private var cameraRecoveryBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shell.cameraSetupRecoverySummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(shell.cameraSetupRecoverySummary)
            HStack(spacing: 8) {
                if shell.cameraAuthorizationStatus == .denied
                    || shell.cameraAuthorizationStatus == .restricted
                {
                    Button("Open Camera Privacy Settings") {
                        shell.openCameraPrivacySettings()
                    }
                    .accessibilityHint("Opens System Settings Privacy and Security Camera")
                } else if shell.cameraAuthorizationStatus == .authorized {
                    Button("Open Camera Settings") {
                        shell.openCameraPrivacySettings()
                    }
                    .accessibilityHint("Opens System Settings Privacy and Security Camera")
                } else {
                    Button("Enable camera verification") {
                        shell.preferCameraVerification(true)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Requests camera access for sit to stand verification")
                }
                Button("Settings…") {
                    shell.openSettings(pane: .camera)
                }
                .accessibilityHint("Opens Unchair Settings on the Camera pane")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
        .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera setup")
        .accessibilitySortPriority(120)
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

    var heroAccessibilityLabel: String {
        "\(heroEyebrow), \(heroValue). \(heroCaption)"
    }

    var todayMovedDisplay: String {
        todayMovedMinutes == 0 ? "0 min" : "\(todayMovedMinutes) min"
    }

    /// Labels VoiceOver should always be able to speak on the Today surface.
    var requiredAccessibilityLabels: [String] {
        [
            heroAccessibilityLabel,
            nextAction,
            "\(todayCompleted) completed",
            "\(todaySkipped) skipped",
            "\(todayMovedDisplay) moved",
            "Longest session \(todayLongest)",
            "Unchair",
        ]
    }

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

/// Pure layout — native utility density, one Human Runtime grouping surface.
struct TodayDashboardLayout: View {
    let model: TodayDashboardModel
    var onCopyImage: (() -> String?)? = nil
    var onSavePNG: (() -> String?)? = nil

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 36
    @State private var exportStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero

            Text(model.nextAction)
                .font(.callout)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(model.nextAction)
                .accessibilitySortPriority(110)

            todayBlock

            HumanRuntimeWeeklyPanel(
                summary: model.week,
                showsExport: false
            )

            footer
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(minWidth: 420, maxWidth: 520, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today dashboard")
    }

    private var secondaryInk: Color {
        contrast == .increased ? Color.primary.opacity(0.85) : Color.secondary
    }

    private var tertiaryInk: Color {
        contrast == .increased ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.8)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.heroEyebrow)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(secondaryInk)
                Text(model.heroValue)
                    .font(.system(size: heroValueSize, weight: .semibold).monospacedDigit())
                    .minimumScaleFactor(0.55)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.heroCaption)
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.heroAccessibilityLabel)
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(100)

            VStack(alignment: .trailing, spacing: 6) {
                UnchairAppIcon(side: 40)
                Text("Unchair")
                    .font(.headline.weight(.semibold))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Unchair")
            .padding(.top, 2)
        }
    }

    private var todayBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 12) {
                todayMetric(
                    value: "\(model.todayCompleted)",
                    label: "Completed",
                    accessibility: "\(model.todayCompleted) completed"
                )
                todayMetric(
                    value: "\(model.todaySkipped)",
                    label: "Skipped",
                    accessibility: "\(model.todaySkipped) skipped"
                )
                todayMetric(
                    value: model.todayMovedDisplay,
                    label: "Moved",
                    accessibility: "\(model.todayMovedDisplay) moved"
                )
                todayMetric(
                    value: model.todayLongest,
                    label: "Longest",
                    accessibility: "Longest session \(model.todayLongest)"
                )
            }
        }
    }

    private func todayMetric(value: String, label: String, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(secondaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            Button("Copy Image") {
                exportStatus = (onCopyImage ?? defaultCopy)()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(model.week.isEmpty)
            .help(model.week.isEmpty ? "No week history to export" : "Copy branded Human Runtime card")
            .accessibilityLabel("Copy Image")
            .accessibilityHint(model.week.isEmpty ? "Unavailable until break history exists" : "Copies the weekly card to the clipboard")

            Button("Save PNG…") {
                exportStatus = (onSavePNG ?? defaultSave)()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(model.week.isEmpty)
            .help(model.week.isEmpty ? "No week history to export" : "Save branded Human Runtime card as PNG")
            .accessibilityLabel("Save PNG")
            .accessibilityHint(model.week.isEmpty ? "Unavailable until break history exists" : "Opens a save panel for the weekly card")

            if let exportStatus {
                Text(exportStatus)
                    .font(.caption2)
                    .foregroundStyle(tertiaryInk)
                    .accessibilityLabel("Export \(exportStatus.lowercased())")
            }

            Spacer(minLength: 8)

            Text(model.dayLabel)
                .font(.caption2)
                .foregroundStyle(tertiaryInk)
                .accessibilityLabel("Today is \(model.dayLabel)")
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
