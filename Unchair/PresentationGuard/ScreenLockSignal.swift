import AppKit
import Foundation

protocol ScreenSessionInspecting: AnyObject {
    var isScreenLockedOrAsleep: Bool { get }
}

/// Tracks screen lock / sleep via distributed + workspace notifications.
///
/// Lock and sleep are latched independently and OR'd — a display wake to the
/// login screen must not clear inactivity while the session is still locked.
final class WorkspaceScreenSessionInspector: ScreenSessionInspecting, @unchecked Sendable {
    private let lock = NSLock()
    private var isLocked = false
    private var isAsleep = false
    private var observers: [NSObjectProtocol] = []

    var isScreenLockedOrAsleep: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isLocked || isAsleep
    }

    init() {
        let dnc = DistributedNotificationCenter.default()
        observers.append(
            dnc.addObserver(
                forName: NSNotification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setLocked(true)
            }
        )
        observers.append(
            dnc.addObserver(
                forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setLocked(false)
            }
        )

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setAsleep(true)
            }
        )
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setAsleep(false)
            }
        )
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setAsleep(true)
            }
        )
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setAsleep(false)
            }
        )
    }

    deinit {
        let dnc = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in observers {
            dnc.removeObserver(observer)
            workspace.removeObserver(observer)
        }
    }

    private func setLocked(_ value: Bool) {
        lock.lock()
        isLocked = value
        lock.unlock()
    }

    private func setAsleep(_ value: Bool) {
        lock.lock()
        isAsleep = value
        lock.unlock()
    }
}

final class ScreenLockSignal: PresentationSignalSource {
    private let inspector: any ScreenSessionInspecting
    var reason: PresentationBlockReason { .screenLockedOrAsleep }
    var isActive: Bool { inspector.isScreenLockedOrAsleep }

    init(inspector: any ScreenSessionInspecting) {
        self.inspector = inspector
    }
}
