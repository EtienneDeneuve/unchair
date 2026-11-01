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
}
