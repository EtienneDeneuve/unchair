import Foundation

protocol BreakClock: AnyObject {
    var now: Date { get }
}

protocol PresentationGuarding: AnyObject {
    var isBlocking: Bool { get }
    /// Debt accrual freezes while asleep / screen-locked — not for other presentation blocks.
    var isScreenLockedOrAsleep: Bool { get }
}

extension PresentationGuarding {
    var isScreenLockedOrAsleep: Bool { false }
}

final class SystemBreakClock: BreakClock {
    var now: Date { Date() }
}

/// Always-open guard for tests and diagnostics that must ignore presentation signals.
final class PermissivePresentationGuard: PresentationGuarding {
    var isBlocking: Bool { false }
}
