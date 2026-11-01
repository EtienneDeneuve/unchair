import Foundation

/// Fuses derived `MovementEvidence` into a verification outcome for BreakEngine.
///
/// Rules (issue #35):
/// - Mac Vision alone is sufficient
/// - No source can set break completion — only verification outcomes
/// - Stale evidence is ignored
/// - Conflicts resolve by confidence, then source priority; ties opposing → insufficient
/// - Sources may appear/disappear mid-break via ingest/remove
final class EvidenceEngine {
    private(set) var policy: EvidenceFusionPolicy
    private var bySource: [EvidenceSource: MovementEvidence] = [:]
    private var failedOpen = false

    init(policy: EvidenceFusionPolicy = .default) {
        self.policy = policy
    }

    func updatePolicy(_ policy: EvidenceFusionPolicy) {
        self.policy = policy
    }

    func reset() {
        bySource.removeAll()
        failedOpen = false
    }

    func noteFailedOpen(_ value: Bool) {
        failedOpen = value
    }

    func ingest(_ evidence: MovementEvidence) {
        bySource[evidence.source] = evidence
    }

    func removeSource(_ source: EvidenceSource) {
        bySource.removeValue(forKey: source)
    }

    func freshEvidence(at now: Date) -> [MovementEvidence] {
        bySource.values.filter {
            $0.isFresh(at: now) && $0.confidence >= policy.minimumConfidence
        }
    }

    func evaluate(at now: Date) -> VerificationOutcome {
        if failedOpen {
            return .failedOpen
        }

        let fresh = freshEvidence(at: now)
        guard !fresh.isEmpty else { return .insufficient }

        if let conflict = unresolvedStandingConflict(in: fresh) {
            return conflict
        }

        let vision = fresh.first(where: { $0.source == .macVision })
        let nonVision = fresh.filter { $0.source != .macVision }

        // Vision alone remains the primary Mac Standalone path.
        if let vision {
            if vision.movingLikely || vision.kind == .moving {
                return .movementVerified
            }
            if vision.standingLikely || vision.kind == .standing {
                // Agreement boost: Vision standing + Watch/sensor moving → verified.
                if nonVision.contains(where: { $0.movingLikely || $0.kind == .moving }) {
                    return .movementVerified
                }
                return .standingDetected
            }
        }

        // Non-Vision verification only when policy explicitly allows (Sensors Only).
        if policy.allowNonVisionVerification {
            if nonVision.contains(where: { $0.movingLikely || $0.kind == .moving }) {
                return .movementVerified
            }
            if nonVision.contains(where: { $0.standingLikely || $0.kind == .standing }) {
                return .standingDetected
            }
        } else if vision == nil {
            // Companions present but Vision missing and policy forbids solo verify.
            if nonVision.contains(where: { $0.standingLikely || $0.movingLikely
                || $0.kind == .standing || $0.kind == .moving }) {
                return .standingDetected
            }
        }

        return .insufficient
    }

    // MARK: - Conflict resolution

    /// Standing vs seated conflict with no clear winner → `.insufficient`.
    private func unresolvedStandingConflict(in fresh: [MovementEvidence]) -> VerificationOutcome? {
        let standing = fresh.filter {
            $0.standingLikely || $0.kind == .standing || $0.kind == .moving
        }
        let seated = fresh.filter { $0.kind == .seated && !$0.standingLikely }
        guard !standing.isEmpty, !seated.isEmpty else { return nil }

        let bestStanding = standing.max(by: compareEvidence)
        let bestSeated = seated.max(by: compareEvidence)
        guard let bestStanding, let bestSeated else { return nil }

        let standingWins = isBetter(bestStanding, than: bestSeated)
        let seatedWins = isBetter(bestSeated, than: bestStanding)
        if standingWins == seatedWins {
            // True tie — do not verify.
            return .insufficient
        }
        if seatedWins {
            return .insufficient
        }
        return nil
    }

    private func compareEvidence(_ lhs: MovementEvidence, _ rhs: MovementEvidence) -> Bool {
        // max(by:) wants "isOrderedBefore" — return true when lhs < rhs.
        if lhs.confidence != rhs.confidence {
            return lhs.confidence < rhs.confidence
        }
        return policy.priority(of: lhs.source) < policy.priority(of: rhs.source)
    }

    private func isBetter(_ lhs: MovementEvidence, than rhs: MovementEvidence) -> Bool {
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return policy.priority(of: lhs.source) > policy.priority(of: rhs.source)
    }
}

/// Maps local Vision proof status into derived evidence (no landmarks).
enum VisionEvidenceMapper {
    static func evidence(
        from status: MovementProofStatus,
        at timestamp: Date,
        timeToLive: TimeInterval = 2
    ) -> MovementEvidence? {
        switch status {
        case .inactive:
            return nil
        case .awaitingStand:
            return MovementEvidence(
                source: .macVision,
                kind: .seated,
                timestamp: timestamp,
                timeToLive: timeToLive,
                confidence: 0.6,
                standingLikely: false,
                movingLikely: false,
                stoodForSeconds: nil,
                motionScore: nil
            )
        case .standing(let elapsed, let motion):
            return MovementEvidence(
                source: .macVision,
                kind: .standing,
                timestamp: timestamp,
                timeToLive: timeToLive,
                confidence: 0.85,
                standingLikely: true,
                movingLikely: false,
                stoodForSeconds: elapsed,
                motionScore: motion
            )
        case .verified(let stoodFor, let motion):
            return MovementEvidence(
                source: .macVision,
                kind: .moving,
                timestamp: timestamp,
                timeToLive: timeToLive,
                confidence: 0.95,
                standingLikely: true,
                movingLikely: true,
                stoodForSeconds: stoodFor,
                motionScore: motion
            )
        }
    }
}
