import Foundation

/// Outcome of a break interaction. Never includes media or landmarks.
enum BreakHistoryResult: String, Codable, Sendable, CaseIterable {
    case completed
    case skipped
    case cancelled
    case postponed
}

/// Minimal derived verification metrics — numbers only, never pose streams.
struct BreakHistoryVerification: Equatable, Codable, Sendable {
    /// Seconds spent standing after stand was detected (when verified).
    var stoodForSeconds: TimeInterval?
    /// Accumulated landmark path-length score at completion (derived).
    var motionScore: Double?
    /// True when completion was allowed without camera proof (permission/unavailable).
    var failedOpen: Bool
}

/// One local history row. Schema versioned via `BreakHistoryStore.schemaVersion`.
struct BreakHistoryRecord: Equatable, Codable, Sendable, Identifiable {
    var id: UUID
    /// When this row was written.
    var recordedAt: Date
    /// Stable id of the owed break from the lifecycle machine, when known.
    var breakID: UUID?
    /// When the break became due / was prompted (best effort).
    var scheduledAt: Date?
    /// When the timed movement break began (nil for postpone-from-due).
    var startedAt: Date?
    /// When the interaction ended (complete / skip / postpone / cancel).
    var endedAt: Date
    var result: BreakHistoryResult
    /// Wall duration of the timed break when applicable; else 0.
    var durationSeconds: TimeInterval
    var verification: BreakHistoryVerification?
}
