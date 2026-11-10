import AppKit
import SwiftUI

/// Same LSUIElement window pattern as Settings — Today must be a real NSWindow.
@MainActor
final class TodayWindowController: NSObject, NSWindowDelegate {
    static let shared = TodayWindowController()

    private var window: NSWindow?

    func show(shell: MenuBarShell) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if window == nil {
            let hosting = NSHostingController(rootView: TodayView(shell: shell))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Unchair Today"
            // Settings-style utility window (HIG): fixed pane size, no zoom.
            window.styleMask = [.titled, .closable, .miniaturizable]
            // Utility pane: width fixed; height follows content (cap avoids rare scroll).
            window.setContentSize(NSSize(width: 420, height: 500))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            self.window = window
        } else {
            window?.contentViewController = NSHostingController(rootView: TodayView(shell: shell))
        }

        if let hosting = window?.contentViewController as? NSHostingController<TodayView> {
            let fitting = hosting.sizeThatFits(in: NSSize(width: 420, height: 2000))
            let height = min(600, max(fitting.height, 1))
            window?.setContentSize(NSSize(width: 420, height: height))
        } else {
            window?.setContentSize(NSSize(width: 420, height: 500))
        }

        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        restoreAccessoryPolicyIfIdle()
    }

    static var isVisible: Bool {
        NSApp.windows.contains { $0.title == "Unchair Today" && $0.isVisible }
    }
}

@MainActor
func restoreAccessoryPolicyIfIdle() {
    let settingsOpen = NSApp.windows.contains { $0.title == "Unchair Settings" && $0.isVisible }
    let todayOpen = TodayWindowController.isVisible
    if settingsOpen || todayOpen { return }
    NSApp.setActivationPolicy(AppConfiguration.activationPolicy)
}
