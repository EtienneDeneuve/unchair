import SwiftUI

struct TodayView: View {
    @Bindable var shell: MenuBarShell

    var body: some View {
        let _ = shell.statusRevision
        let stats = shell.todayStats

        VStack(alignment: .leading, spacing: 20) {
            Text("Today")
                .font(.largeTitle.weight(.semibold))

            Text(dayLabel(stats.dayStart))
                .foregroundStyle(.secondary)

            if stats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No breaks logged yet today.")
                        .font(.title3)
                    Text("The schedule is running. When you complete, skip, or postpone, it shows up here — locally only.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            } else {
                metricsGrid(stats)
            }

            Divider()

            LabeledContent("Next break") {
                Text(stats.nextBreakSummary)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }

            Text("Numbers come from local break history on this Mac. No streaks. No health scores.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 420, height: 420, alignment: .topLeading)
    }

    @ViewBuilder
    private func metricsGrid(_ stats: TodayStats) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
            GridRow {
                metric("Completed", value: "\(stats.completedCount)")
                metric("Skipped", value: "\(stats.skippedCount)")
            }
            GridRow {
                metric("Movement", value: "\(stats.movementMinutesRounded) min")
                metric("Longest desk", value: "\(stats.longestDeskMinutesRounded) min")
            }
        }
        .padding(.top, 4)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
