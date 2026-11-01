import Foundation
import OSLog

/// Tunables for break completion proof. Not user-facing yet.
struct MovementProofConfig: Equatable, Sendable {
    /// Must stay in the post-stand window at least this long.
    var minimumStandingSeconds: TimeInterval = 5
    /// Accumulated landmark path length (sum of per-frame joint travel).
    var minimumMotionScore: Double = 0.18
    /// Ignore tiny per-joint jitter below this displacement.
    var jointMotionFloor: Double = 0.002
    /// Hip rises (y decreases) by this much vs break baseline → count as stand on lid cams.
    var standHipRise: Double = 0.045
    /// Shoulder width shrink vs baseline → stepped back / stood up.
    var standWidthShrink: Double = 0.04

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

    /// Short overlay line with live progress.
    func progressText(motionTarget: Double = MovementProofConfig.default.minimumMotionScore) -> String {
        switch self {
        case .inactive:
            return "Movement verification: idle"
        case .awaitingStand:
            return "Stand up to start verification"
        case .standing(let elapsed, let motion):
            // Quantize to 5% steps so the overlay model doesn't churn every frame.
            let raw = min(99, max(0, (motion / max(motionTarget, 0.001)) * 100))
            let pct = Int(raw / 5) * 5
            return "Standing \(Int(elapsed))s · motion \(pct)%"
        case .verified:
            return "Movement verified · you can complete"
        }
    }
}

/// Proves a break from: stand signal, time after stand, and landmark motion.
/// Motion uses pose joint deltas only — never stored frames.
struct MovementProofTracker: Sendable {
    private let config: MovementProofConfig
    private let log = Logger(subsystem: "com.etiennedeneuve.unchair", category: "MovementProof")

    private var active = false
    private var standStartedAt: Date?
    private var previousJoints: [BodyJoint: PoseJoint] = [:]
    private var motionScore = 0.0
    private var baselineHipY: Double?
    private var baselineShoulderWidth: Double?
    private(set) var status: MovementProofStatus = .inactive

    init(config: MovementProofConfig = .default) {
        self.config = config
    }

    mutating func reset() {
        active = false
        standStartedAt = nil
        previousJoints = [:]
        motionScore = 0
        baselineHipY = nil
        baselineShoulderWidth = nil
        status = .inactive
        log.debug("reset")
    }

    mutating func beginBreak() {
        active = true
        standStartedAt = nil
        previousJoints = [:]
        motionScore = 0
        baselineHipY = nil
        baselineShoulderWidth = nil
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

        captureBaselineIfNeeded(sample)

        if standStartedAt == nil {
            if let sitToStand {
                standStartedAt = sitToStand.detectedAt
                log.info("stand_from_sit_to_stand")
            } else if posture == .standingLike {
                standStartedAt = sample.timestamp
                log.info("stand_from_posture")
            } else if lidCameraStandDetected(sample) {
                standStartedAt = sample.timestamp
                log.info("stand_from_lid_geometry")
            } else {
                // Still track joints so the first post-stand delta is meaningful.
                previousJoints = sample.joints
                status = .awaitingStand
                return status
            }
        }

        // After stand is latched, keep scoring motion even if posture flickers back
        // to seated-like (common on Mac lid cameras).
        motionScore += Self.frameMotion(
            from: previousJoints,
            to: sample.joints,
            floor: config.jointMotionFloor
        )
        previousJoints = sample.joints

        let elapsed = sample.timestamp.timeIntervalSince(standStartedAt ?? sample.timestamp)
        let score = motionScore
        if elapsed >= config.minimumStandingSeconds, score >= config.minimumMotionScore {
            status = .verified(stoodFor: elapsed, motionScore: score)
            log.info("verified stood=\(elapsed, privacy: .public)s motion=\(score, privacy: .public)")
        } else {
            status = .standing(elapsed: max(0, elapsed), motionScore: score)
        }
        return status
    }

    private mutating func captureBaselineIfNeeded(_ sample: PoseSample) {
        if baselineHipY == nil, let hipY = averageY(sample, [.leftHip, .rightHip]) {
            baselineHipY = hipY
        }
        if baselineShoulderWidth == nil, let width = sample.shoulderWidth {
            baselineShoulderWidth = width
        }
    }

    private func lidCameraStandDetected(_ sample: PoseSample) -> Bool {
        if let base = baselineHipY, let hipY = averageY(sample, [.leftHip, .rightHip]), hipY < base - config.standHipRise {
            return true
        }
        if let base = baselineShoulderWidth, let width = sample.shoulderWidth, width < base - config.standWidthShrink {
            return true
        }
        return false
    }

    private func averageY(_ sample: PoseSample, _ joints: [BodyJoint]) -> Double? {
        let values = joints.compactMap { sample.joint($0, minimumConfidence: 0.1)?.y }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Sum of per-joint |Δx|+|Δy| above the jitter floor (path length, not mean).
    static func frameMotion(
        from previous: [BodyJoint: PoseJoint],
        to current: [BodyJoint: PoseJoint],
        floor: Double
    ) -> Double {
        guard !previous.isEmpty, !current.isEmpty else { return 0 }
        var total = 0.0
        for (joint, now) in current {
            guard let before = previous[joint] else { continue }
            let delta = abs(now.x - before.x) + abs(now.y - before.y)
            if delta >= floor {
                total += delta
            }
        }
        return total
    }
}
