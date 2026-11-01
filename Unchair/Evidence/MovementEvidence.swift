import Foundation

/// Where derived movement evidence came from. Never carries raw sensor payloads.
enum EvidenceSource: String, Codable, Sendable, CaseIterable, Hashable {
    case macVision
    case appleWatchLive
    case healthKitRecent
    case chairOccupancy
    case macActivityIdle
    case manualBreakContext
}

/// Derived observation kind — not a raw sample type.
enum EvidenceKind: String, Codable, Sendable, Hashable {
    case standing
    case moving
    case seated
    case absent
    case recentActivity
}

/// Source-agnostic movement evidence. Prefer this over landmarks / HealthKit samples.
struct MovementEvidence: Equatable, Sendable {
    var source: EvidenceSource
    var kind: EvidenceKind
    var timestamp: Date
    /// Seconds after `timestamp` during which this evidence remains usable.
    var timeToLive: TimeInterval
    /// 0...1 confidence in the derived claim.
    var confidence: Double
    var standingLikely: Bool
    var movingLikely: Bool
    var stoodForSeconds: TimeInterval?
    var motionScore: Double?

    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(timestamp) <= timeToLive
    }
}

/// Outcome fed to BreakEngine events — never `break.completed`.
enum VerificationOutcome: Equatable, Sendable {
    case insufficient
    case standingDetected
    case movementVerified
    /// Camera / primary verifier unavailable — domain may fail-open.
    case failedOpen
}
