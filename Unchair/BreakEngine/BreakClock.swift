import Foundation

protocol BreakClock: AnyObject {
    var now: Date { get }
}

protocol PresentationGuarding: AnyObject {
    var isBlocking: Bool { get }
    /// Strong sleep/lock latch (also drives presentation deferral via ScreenLockSignal).
    var isScreenLockedOrAsleep: Bool { get }
    /// True when HID input has been idle long enough (unlocked Mac, user away).
    var isUserIdle: Bool { get }
    /// Desk clock freeze: sleep/lock **or** HID idle. Not meeting/camera presentation blocks.
    var shouldFreezeDeskClock: Bool { get }
    /// Mutate the HID idle threshold (seconds). `<= 0` disables idle freeze.
    var idleFreezeThresholdSeconds: TimeInterval { get set }
}

extension PresentationGuarding {
    var isScreenLockedOrAsleep: Bool { false }
    var isUserIdle: Bool { false }
    var shouldFreezeDeskClock: Bool { isScreenLockedOrAsleep || isUserIdle }
    var idleFreezeThresholdSeconds: TimeInterval {
        get { 0 }
        set { _ = newValue }
    }
}

final class SystemBreakClock: BreakClock {
    var now: Date { Date() }
}

/// Always-open guard for tests and diagnostics that must ignore presentation signals.
final class PermissivePresentationGuard: PresentationGuarding {
    var isBlocking: Bool { false }
    var idleFreezeThresholdSeconds: TimeInterval = 0
}
