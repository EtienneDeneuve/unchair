import AppKit
import SwiftUI

/// Presents a non-hostile, high-visibility break panel on every connected display.
///
/// Uses floating panels (not a system lockout): the user can still quit the app,
/// postpone, or skip. Panels are created once per presentation and updated in
/// place — tearing them down every tick caused visible flicker.
@MainActor
final class BreakOverlayController: BreakOverlayPresenting {
    private struct PanelEntry {
        var panel: NSPanel
        var hosting: NSHostingView<BreakOverlayView>
    }

    private var entries: [PanelEntry] = []
    private var screenObserver: NSObjectProtocol?
    private weak var shell: MenuBarShell?
    private var isPresented = false
    private var lastModel: BreakOverlayModel?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildForScreenChange()
            }
        }
    }

    func attach(shell: MenuBarShell) {
        self.shell = shell
    }

    func sync(with shell: MenuBarShell) {
        self.shell = shell
        if BreakOverlayModel.shouldPresent(phase: shell.phase) {
            let model = shell.overlayModel
            if isPresented {
                // Always refresh rootView while presented so the live camera /
                // skeleton keep moving — panels themselves stay put (no flicker).
                updateContent(model: model, shell: shell)
            } else {
                present(using: shell, model: model)
            }
            lastModel = model
        } else {
            dismiss()
        }
    }

    private func rebuildForScreenChange() {
        guard isPresented, let shell else { return }
        let model = shell.overlayModel
        dismissPanelsOnly()
        present(using: shell, model: model)
        lastModel = model
    }

    private func present(using shell: MenuBarShell, model: BreakOverlayModel) {
        dismissPanelsOnly()

        for screen in NSScreen.screens {
            let panel = makePanel(for: screen)
            let hosting = NSHostingView(rootView: makeView(model: model, shell: shell))
            panel.contentView = hosting
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            entries.append(PanelEntry(panel: panel, hosting: hosting))
        }

        isPresented = true
        // Activate once when the overlay appears — not on every countdown tick.
        NSApp.activate(ignoringOtherApps: true)
        entries.first?.panel.makeKey()
    }

    private func updateContent(model: BreakOverlayModel, shell: MenuBarShell) {
        let view = makeView(model: model, shell: shell)
        for index in entries.indices {
            entries[index].hosting.rootView = view
        }
    }

    private func makeView(model: BreakOverlayModel, shell: MenuBarShell) -> BreakOverlayView {
        BreakOverlayView(
            model: model,
            previewSession: model.showsCameraPreview ? shell.posturePreviewSession : nil,
            previewJoints: model.showsCameraPreview ? shell.posturePreviewJoints : [:],
            onPrimary: { shell.handleOverlayPrimary() },
            onSkip: { shell.skipBreak() },
            onPostpone15: { shell.postpone(by: .minutes(15)) },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
    }

    private func dismiss() {
        dismissPanelsOnly()
        isPresented = false
        lastModel = nil
    }

    private func dismissPanelsOnly() {
        for entry in entries {
            entry.panel.orderOut(nil)
            entry.panel.contentView = nil
        }
        entries.removeAll(keepingCapacity: true)
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
