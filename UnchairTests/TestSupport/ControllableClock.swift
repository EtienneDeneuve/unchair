import Foundation
@testable import Unchair

final class ControllableClock: BreakClock {
    private(set) var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

final class ControllablePresentationGuard: PresentationGuarding {
    var isBlocking = false
    var isScreenLockedOrAsleep = false
}

final class ControllableLaunchAtLogin: LaunchAtLoginControlling {
    var isEnabled: Bool
    var lastSetEnabled: Bool?
    var errorToThrow: Error?

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        lastSetEnabled = enabled
        isEnabled = enabled
    }
}
