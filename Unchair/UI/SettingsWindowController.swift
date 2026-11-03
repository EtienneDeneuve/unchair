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
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 700, height: 480))
            window.contentMinSize = NSSize(width: 640, height: 420)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        } else {
            window?.contentViewController = NSHostingController(rootView: SettingsView(shell: shell))
            window?.setContentSize(NSSize(width: 700, height: 480))
        }

        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        // Camera preview starts only when the Camera tab is selected.
    }

    func windowWillClose(_ notification: Notification) {
        shell?.stopPosturePreview()
        restoreAccessoryPolicyIfIdle()
    }
}
