import AppKit
import SwiftUI

/// First-run window for LSUIElement agents — same pattern as Settings / Today.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private weak var shell: MenuBarShell?

    func show(shell: MenuBarShell) {
        self.shell = shell
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let hosting = NSHostingController(rootView: OnboardingView(shell: shell))
        if window == nil {
            let window = NSWindow(contentViewController: hosting)
            window.title = "Welcome to Unchair"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 520, height: 560))
            window.contentMinSize = NSSize(width: 480, height: 420)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            self.window = window
        } else {
            window?.contentViewController = hosting
            window?.setContentSize(NSSize(width: 520, height: 560))
        }

        if let hosting = window?.contentViewController as? NSHostingController<OnboardingView> {
            let fitting = hosting.sizeThatFits(in: NSSize(width: 520, height: 2000))
            let height = min(720, max(fitting.height, 1))
            window?.setContentSize(NSSize(width: 520, height: height))
        }

        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing without finishing still leaves onboarding incomplete so it returns next launch.
        restoreAccessoryPolicyIfIdle()
    }

    static var isVisible: Bool {
        NSApp.windows.contains { $0.title == "Welcome to Unchair" && $0.isVisible }
    }
}
