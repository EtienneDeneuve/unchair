import Foundation

/// Inputs that may advance the break lifecycle. Invalid combinations are rejected.
enum BreakEvent: Equatable, Sendable {
    case start
    case evaluate
    case startBreakNow
    case beginTimedBreak
    case complete
    case skip
    case postpone(until: Date)
    case pause
    case resume
    case standDetected
    case movementVerified
    case verificationFailed
    case updateSettings(BreakSettings)
}

enum BreakTransitionError: Error, Equatable, Sendable {
    case invalidTransition(from: BreakPhase, event: BreakEvent)
}

typealias BreakTransitionResult = Result<BreakSnapshot, BreakTransitionError>
