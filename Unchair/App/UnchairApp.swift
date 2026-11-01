import AppKit
import SwiftUI

@main
struct UnchairApp: App {
    @NSApplicationDelegateAdaptor(UnchairAppDelegate.self) private var appDelegate
    @State private var shell = MenuBarShell()

    var body: some Scene {
        MenuBarExtra("Unchair", systemImage: "figure.stand") {
            MenuBarContentView(shell: shell)
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
