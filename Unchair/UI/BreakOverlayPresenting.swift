import Foundation

@MainActor
protocol BreakOverlayPresenting: AnyObject {
    func attach(shell: MenuBarShell)
    func sync(with shell: MenuBarShell)
}

@MainActor
final class NullBreakOverlayController: BreakOverlayPresenting {
    func attach(shell: MenuBarShell) {}
    func sync(with shell: MenuBarShell) {}
}
