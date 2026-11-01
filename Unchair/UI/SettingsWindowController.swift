import AppKit
import SwiftUI

/// Menu-bar agents (`LSUIElement` / `.accessory`) often fail to surface SwiftUI
/// `Settings` scenes. This controller owns an explicit titled window instead.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private weak var shell: MenuBarShell?

    func show(shell: MenuBarShell) {
        self.shell = shell
        // Accessory apps need a temporary regular policy or windows never key.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(shell: shell))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Unchair Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 480, height: 720))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        } else {
            window?.contentViewController = NSHostingController(rootView: SettingsView(shell: shell))
        }

        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        // Resume preview only when already authorized — never auto-prompt.
        if shell.cameraAuthorizationStatus == .authorized {
            shell.startPosturePreview()
        }
    }

    func windowWillClose(_ notification: Notification) {
        shell?.stopPosturePreview()
        // Return to menu-bar-only mode when Settings is dismissed.
        NSApp.setActivationPolicy(AppConfiguration.activationPolicy)
    }
}
