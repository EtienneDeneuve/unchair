import AppKit
import Foundation

protocol ScreenSessionInspecting: AnyObject {
    var isScreenLockedOrAsleep: Bool { get }
}

/// Tracks screen lock / sleep via distributed + workspace notifications.
final class WorkspaceScreenSessionInspector: ScreenSessionInspecting, @unchecked Sendable {
    private let lock = NSLock()
    private var lockedOrAsleep = false
    private var observers: [NSObjectProtocol] = []

    var isScreenLockedOrAsleep: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lockedOrAsleep
    }

    init() {
        let dnc = DistributedNotificationCenter.default()
        observers.append(
            dnc.addObserver(
                forName: NSNotification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setLockedOrAsleep(true)
            }
        )
        observers.append(
            dnc.addObserver(
                forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setLockedOrAsleep(false)
            }
        )

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setLockedOrAsleep(true)
            }
        )
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setLockedOrAsleep(false)
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

    private func setLockedOrAsleep(_ value: Bool) {
        lock.lock()
        lockedOrAsleep = value
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
