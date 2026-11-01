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
                Button("Start Break Now") {
                    shell.startBreakNow()
                }
            case .postponeMenu:
                Menu("Postpone") {
                    ForEach(shell.postponePresets, id: \.seconds) { preset in
                        Button("\(Int(preset.seconds / 60)) minutes") {
                            shell.postpone(by: preset)
                        }
                    }
                    Divider()
                    Button("Until next round hour") {
                        shell.postpone(until: Self.nextRoundHour(from: Date()))
                    }
                }
                .disabled(!shell.canPostpone)
            case .pauseResume:
                Button(shell.isPaused ? "Resume Schedule" : "Pause Schedule") {
                    shell.togglePause()
                }
            case .settings:
                Divider()
                Button("Settings…") {
                    shell.openSettings()
                    openSettingsWindow()
                }
            case .quit:
                Divider()
                Button("Quit Unchair") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static func nextRoundHour(from date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let currentHourStart = calendar.date(from: components) ?? date
        let candidate = calendar.date(byAdding: .hour, value: 1, to: currentHourStart) ?? date.addingTimeInterval(3600)
        // If we are exactly on the hour, jump one more hour ahead.
        if candidate <= date {
            return calendar.date(byAdding: .hour, value: 1, to: candidate) ?? candidate.addingTimeInterval(3600)
        }
        return candidate
    }
}
