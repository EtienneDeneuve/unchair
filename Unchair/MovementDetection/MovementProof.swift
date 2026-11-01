import Foundation
import OSLog

/// Tunables for break completion proof. Not user-facing yet.
struct MovementProofConfig: Equatable, Sendable {
    /// Must remain standing-like at least this long after the sit→stand event.
    var minimumStandingSeconds: TimeInterval = 8
    /// Accumulated landmark motion while standing (normalized units).
    var minimumMotionScore: Double = 0.45
    /// Ignore per-frame joint jitter below this mean displacement.
    var jointMotionFloor: Double = 0.0035

    static let `default` = MovementProofConfig()
}

enum MovementProofStatus: Equatable, Sendable {
    case inactive
    case awaitingStand
    case standing(elapsed: TimeInterval, motionScore: Double)
    case verified(stoodFor: TimeInterval, motionScore: Double)

    var isVerified: Bool {
        if case .verified = self { return true }
        return false
    }
}

/// Proves a break from: sit→stand, time spent standing, and landmark motion.
/// Motion is derived only from pose joint deltas — never from stored frames.
struct MovementProofTracker: Sendable {
    private let config: MovementProofConfig
    private let log = Logger(subsystem: "com.etiennedeneuve.unchair", category: "MovementProof")

    private var active = false
    private var standStartedAt: Date?
    private var previousJoints: [BodyJoint: PoseJoint] = [:]
    private var motionScore = 0.0
    private(set) var status: MovementProofStatus = .inactive

    init(config: MovementProofConfig = .default) {
        self.config = config
    }

    mutating func reset() {
        active = false
        standStartedAt = nil
        previousJoints = [:]
        motionScore = 0
        status = .inactive
        log.debug("reset")
    }

    mutating func beginBreak() {
        active = true
        standStartedAt = nil
        previousJoints = [:]
        motionScore = 0
        status = .awaitingStand
        log.info("break_started awaiting_stand")
    }

    @discardableResult
    mutating func process(
        sample: PoseSample,
        posture: PostureState,
        sitToStand: SitToStandEvent?
    ) -> MovementProofStatus {
        guard active else {
            status = .inactive
            return status
        }

        if case .verified = status {
            return status
        }

        if standStartedAt == nil {
            if let sitToStand {
                standStartedAt = sitToStand.detectedAt
                log.info("stand_detected at=\(sitToStand.detectedAt.timeIntervalSince1970, format: .fixed(precision: 1))")
            } else if posture == .standingLike {
                standStartedAt = sample.timestamp
                log.info("stand_inferred_from_posture")
            } else {
                status = .awaitingStand
                previousJoints = sample.joints
                return status
            }
        }

        // Accumulate motion only while standing-like (stillness while standing fails proof).
        if posture == .standingLike {
            motionScore += Self.frameMotion(
                from: previousJoints,
                to: sample.joints,
                floor: config.jointMotionFloor
            )
        }
        previousJoints = sample.joints

        let elapsed = sample.timestamp.timeIntervalSince(standStartedAt ?? sample.timestamp)
        let score = motionScore
        if elapsed >= config.minimumStandingSeconds, score >= config.minimumMotionScore {
            status = .verified(stoodFor: elapsed, motionScore: score)
            log.info("verified stood=\(elapsed, privacy: .public)s motion=\(score, privacy: .public)")
        } else {
            status = .standing(elapsed: max(0, elapsed), motionScore: score)
            log.debug("standing elapsed=\(elapsed, privacy: .public)s motion=\(score, privacy: .public)")
        }
        return status
    }

    /// Mean |Δx|+|Δy| across joints present in both frames, ignoring sub-floor jitter.
    static func frameMotion(
        from previous: [BodyJoint: PoseJoint],
        to current: [BodyJoint: PoseJoint],
        floor: Double
    ) -> Double {
        guard !previous.isEmpty, !current.isEmpty else { return 0 }
        var total = 0.0
        var count = 0
        for (joint, now) in current {
            guard let before = previous[joint] else { continue }
            let delta = abs(now.x - before.x) + abs(now.y - before.y)
            total += delta
            count += 1
        }
        guard count > 0 else { return 0 }
        let mean = total / Double(count)
        return mean >= floor ? mean : 0
    }
}
