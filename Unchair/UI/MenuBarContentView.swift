import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Bindable var shell: MenuBarShell

    var body: some View {
        ForEach(MenuBarShell.commands, id: \.self) { command in
            switch command {
            case .nextBreakStatus:
                Text(shell.nextBreakStatusText)
            case .startBreakNow:
                Button {
                    shell.startBreakNow()
                } label: {
                    Label("Start Break Now", systemImage: "figure.stand")
                }
            case .postponeMenu:
                Menu {
                    ForEach(shell.postponePresets, id: \.seconds) { preset in
                        Button("\(Int(preset.seconds / 60)) minutes") {
                            shell.postpone(by: preset)
                        }
                    }
                    Divider()
                    Button("Until next round hour") {
                        shell.postpone(until: Self.nextRoundHour(from: Date()))
                    }
                } label: {
                    Label("Postpone", systemImage: "clock.badge.exclamationmark")
                }
                .disabled(!shell.canPostpone)
            case .pauseResume:
                Button {
                    shell.togglePause()
                } label: {
                    Label(
                        shell.isPaused ? "Resume Schedule" : "Pause Schedule",
                        systemImage: shell.isPaused ? "play.fill" : "pause.fill"
                    )
                }
            case .settings:
                Divider()
                Button {
                    shell.openSettings()
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
            case .quit:
                Divider()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Unchair", systemImage: "xmark.circle")
                }
            }
        }
    }

    static func nextRoundHour(from date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let currentHourStart = calendar.date(from: components) ?? date
        let candidate = calendar.date(byAdding: .hour, value: 1, to: currentHourStart)
            ?? date.addingTimeInterval(3600)
        if candidate <= date {
            return calendar.date(byAdding: .hour, value: 1, to: candidate)
                ?? candidate.addingTimeInterval(3600)
        }
        return candidate
    }
}
