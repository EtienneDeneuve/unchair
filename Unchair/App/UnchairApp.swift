import AppKit
import SwiftUI

@main
struct UnchairApp: App {
    @NSApplicationDelegateAdaptor(UnchairAppDelegate.self) private var appDelegate
    @State private var shell = MenuBarShell()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(shell: shell)
        } label: {
            // Keep this short: icon + remaining time live in the menu bar itself.
            Label {
                Text(shell.menuBarTitleText)
                    .monospacedDigit()
            } icon: {
                Image(systemName: shell.menuBarSymbolName)
            }
            .labelStyle(.titleAndIcon)
        }

        Settings {
            SettingsView(shell: shell)
        }
    }
}

final class UnchairAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(AppConfiguration.activationPolicy)
    }
}
