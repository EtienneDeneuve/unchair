import AppKit
import SwiftUI

@main
struct UnchairApp: App {
    @NSApplicationDelegateAdaptor(UnchairAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(shell: appDelegate.shell)
        } label: {
            // Keep this short: icon + remaining time live in the menu bar itself.
            Label {
                Text(appDelegate.shell.menuBarTitleText)
                    .monospacedDigit()
            } icon: {
                Image(systemName: appDelegate.shell.menuBarSymbolName)
            }
            .labelStyle(.titleAndIcon)
        }
        // Settings opens via SettingsWindowController (explicit NSWindow).
        // SwiftUI `Settings` scenes often never appear for LSUIElement agents.
    }
}

@MainActor
final class UnchairAppDelegate: NSObject, NSApplicationDelegate {
    /// Eager shell so control socket / MQTT / history start before the menu is opened.
    let shell = MenuBarShell()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(AppConfiguration.activationPolicy)

        // One-shot QA/dev hook: `defaults write … UnchairOpenTodayOnLaunch -bool true`
        if UserDefaults.standard.bool(forKey: "UnchairOpenTodayOnLaunch") {
            UserDefaults.standard.set(false, forKey: "UnchairOpenTodayOnLaunch")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [shell] in
                shell.openToday()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // User may have toggled Camera in System Settings while Unchair was inactive.
        shell.refreshCameraAuthorizationAfterForeground()
    }
}
