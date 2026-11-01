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
}
