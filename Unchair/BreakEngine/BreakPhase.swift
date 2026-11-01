import Foundation

enum BreakPhase: Equatable, Sendable {
    case idle
    case working(until: Date)
    case breakDue
    case onBreak(endsAt: Date)
    case postponed(until: Date)
    case deferredForPresentation(pendingSince: Date)
    case paused
}

struct BreakSnapshot: Equatable, Sendable {
    var phase: BreakPhase
    var settings: BreakSettings
    var sittingStartedAt: Date?
    var sittingDuration: BreakDuration?
    var hasMovementDebt: Bool
    var remainingWork: BreakDuration?
    var remainingBreak: BreakDuration?
}
