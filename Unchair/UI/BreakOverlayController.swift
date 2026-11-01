import AppKit
import SwiftUI

/// Presents a non-hostile, high-visibility break panel on every connected display.
///
/// Uses floating panels (not a system lockout): the user can still quit the app,
/// postpone, or skip. Panels are rebuilt when the screen configuration changes.
@MainActor
final class BreakOverlayController: BreakOverlayPresenting {
    private var panels: [NSPanel] = []
    private var screenObserver: NSObjectProtocol?
    private weak var shell: MenuBarShell?
    private var isPresented = false

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIfNeeded()
            }
        }
    }

    func attach(shell: MenuBarShell) {
        self.shell = shell
    }

    func sync(with shell: MenuBarShell) {
        self.shell = shell
        if BreakOverlayModel.shouldPresent(phase: shell.phase) {
            present(using: shell)
        } else {
            dismiss()
        }
    }

    private func refreshIfNeeded() {
        guard isPresented, let shell else { return }
        present(using: shell)
    }

    private func present(using shell: MenuBarShell) {
        let model = shell.overlayModel
        dismissPanelsOnly()

        for screen in NSScreen.screens {
            let panel = makePanel(for: screen)
            panel.contentView = NSHostingView(
                rootView: BreakOverlayView(
                    model: model,
                    onPrimary: { shell.handleOverlayPrimary() },
                    onSkip: { shell.skipBreak() },
                    onPostpone15: { shell.postpone(by: .minutes(15)) },
                    onQuit: { NSApplication.shared.terminate(nil) }
                )
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        isPresented = true
        NSApp.activate(ignoringOtherApps: true)
        panels.first?.makeKey()
    }

    private func dismiss() {
        dismissPanelsOnly()
        isPresented = false
    }

    private func dismissPanelsOnly() {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panels.removeAll(keepingCapacity: true)
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        // Key window so Return / Esc / ⌘Q shortcuts remain reachable.
        panel.becomesKeyOnlyIfNeeded = false
        return panel
    }
}
