import Foundation

/// Verification progress while a timed break (`.onBreak`) is active.
///
/// Maps to issue #7: `active -> standingDetected -> movementVerified`
/// (plus `failedVerification` when the camera cannot prove movement).
enum BreakVerificationPhase: Equatable, Sendable {
    case awaitingStand
    case standingDetected
    case movementVerified
    case failedVerification
}

/// Explicit break lifecycle phases — single source of truth for the scheduler.
///
/// Issue #7 vocabulary maps as:
/// `working` ≈ scheduled, `breakDue` ≈ prompted, `onBreak` ≈ active.
enum BreakPhase: Equatable, Sendable {
    case idle
    case working(until: Date)
    case breakDue
    case onBreak(endsAt: Date, verification: BreakVerificationPhase)
    case postponed(until: Date)
    case deferredForPresentation(pendingSince: Date)
    case paused

    var isOnBreak: Bool {
        if case .onBreak = self { return true }
        return false
    }

    var onBreakEndsAt: Date? {
        if case .onBreak(let endsAt, _) = self { return endsAt }
        return nil
    }

    var verification: BreakVerificationPhase? {
        if case .onBreak(_, let verification) = self { return verification }
        return nil
    }
}

struct BreakSnapshot: Equatable, Sendable {
    var phase: BreakPhase
    var settings: BreakSettings
    /// Stable id for the current owed break; preserved across postpone/defer.
    var breakID: UUID?
    var sittingStartedAt: Date?
    var sittingDuration: BreakDuration?
    /// Convenience mirror of `movementDebt.isActive` for existing call sites.
    var hasMovementDebt: Bool
    /// First-class accrued debt metrics (issue #20).
    var movementDebt: MovementDebt
    var remainingWork: BreakDuration?
    var remainingBreak: BreakDuration?
}
