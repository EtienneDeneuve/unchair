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

/// PresentationGuard lands fully in issue #13. Until then the scheduler only
/// needs a blocking signal so postpone/due evaluation stays testable.
final class PermissivePresentationGuard: PresentationGuarding {
    var isBlocking: Bool { false }
}
