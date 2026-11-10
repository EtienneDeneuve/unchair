import SwiftUI

/// Status-style window: grouped Form sections per Apple HIG (same pattern as Settings).
struct TodayView: View {
    @Bindable var shell: MenuBarShell

    var body: some View {
        let _ = shell.statusRevision
        let stats = shell.todayStats
        let week = shell.weeklyHumanRuntimeSummary

        Form {
            Section {
                if stats.isEmpty {
                    Text("No breaks logged yet today. Completions, skips, and postpones show up here — locally only.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LabeledContent("Completed") {
                        Text("\(stats.completedCount)")
                            .monospacedDigit()
                    }
                    LabeledContent("Skipped") {
                        Text("\(stats.skippedCount)")
                            .monospacedDigit()
                    }
                    LabeledContent("Movement") {
                        Text("\(stats.movementMinutesRounded) min")
                            .monospacedDigit()
                    }
                    LabeledContent("Longest desk") {
                        Text("\(stats.longestDeskMinutesRounded) min")
                            .monospacedDigit()
                    }
                }
            } header: {
                Text(dayLabel(stats.dayStart))
            } footer: {
                Text("Local break history on this Mac. No streaks. No health scores.")
            }

            Section("Schedule") {
                LabeledContent("Next break") {
                    Text(nextBreakValue(stats.nextBreakSummary))
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }

            Section {
                HumanRuntimeWeeklySection(summary: week)
            } header: {
                Text("Human Runtime · Week \(week.weekNumber)")
            } footer: {
                Text("Derived only from local history. Export is optional and never automatic.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
    }

    /// `nextBreakStatusText` already includes a "Next break:" prefix — don't double it.
    private func nextBreakValue(_ summary: String) -> String {
        let prefix = "Next break:"
        if summary.hasPrefix(prefix) {
            return String(summary.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return summary
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
