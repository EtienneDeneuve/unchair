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
            case .presentationModeMenu:
                Menu {
                    if shell.isPresentationModeEnabled {
                        Button("Turn Off Presentation Mode") {
                            shell.disablePresentationMode()
                        }
                        Divider()
                    }
                    ForEach(shell.presentationModePresets, id: \.seconds) { preset in
                        Button("\(Int(preset.seconds / 60)) minutes") {
                            shell.enablePresentationMode(for: preset)
                        }
                    }
                    Divider()
                    Button("Until next round hour") {
                        shell.enablePresentationMode(until: Self.nextRoundHour(from: Date()))
                    }
                    Button("Until I turn it off") {
                        shell.enablePresentationModeUntilDisabled()
                    }
                } label: {
                    Label(
                        shell.isPresentationModeEnabled
                            ? "Presentation Mode · On"
                            : "Presentation Mode",
                        systemImage: shell.isPresentationModeEnabled
                            ? "person.wave.2.fill"
                            : "person.wave.2"
                    )
                }
            case .pauseResume:
                Button {
                    shell.togglePause()
                } label: {
                    Label(
                        shell.isPaused ? "Resume Schedule" : "Pause Schedule",
                        systemImage: shell.isPaused ? "play.fill" : "pause.fill"
                    )
                }
            case .today:
                Divider()
                Button {
                    shell.openToday()
                } label: {
                    Label(shell.todayMenuSummary, systemImage: "calendar")
                }
            case .settings:
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
