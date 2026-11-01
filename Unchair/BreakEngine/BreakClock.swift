import Foundation

protocol BreakClock: AnyObject {
    var now: Date { get }
}

protocol PresentationGuarding: AnyObject {
    var isBlocking: Bool { get }
}

final class SystemBreakClock: BreakClock {
    var now: Date { Date() }
}

/// Always-open guard for tests and diagnostics that must ignore presentation signals.
final class PermissivePresentationGuard: PresentationGuarding {
    var isBlocking: Bool { false }
}
