import XCTest
@testable import Unchair

final class MovementProofTests: XCTestCase {
    func testCannotVerifyImmediatelyAfterStanding() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 8,
                minimumMotionScore: 0.1,
                jointMotionFloor: 0.001
            )
        )
        tracker.beginBreak()

        let t0 = Date(timeIntervalSince1970: 1_000)
        _ = tracker.process(
            sample: PoseFixtures.seated(timestamp: t0),
            posture: .seatedLike,
            sitToStand: nil
        )
        let standAt = t0.addingTimeInterval(1)
        var moving = PoseFixtures.lidStanding(timestamp: standAt)
        let status = tracker.process(
            sample: moving,
            posture: .standingLike,
            sitToStand: SitToStandEvent(detectedAt: standAt)
        )

        // Huge instantaneous motion still blocked by standing duration.
        moving = shifted(moving, dx: 0.2, dy: 0.2, at: standAt.addingTimeInterval(0.5))
        let early = tracker.process(sample: moving, posture: .standingLike, sitToStand: nil)
        XCTAssertFalse(status.isVerified)
        XCTAssertFalse(early.isVerified)
        if case .standing(let elapsed, _) = early {
            XCTAssertLessThan(elapsed, 8)
        } else {
            XCTFail("expected standing, got \(early)")
        }
    }

    func testStandingStillDoesNotVerify() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 3,
                minimumMotionScore: 0.2,
                jointMotionFloor: 0.003
            )
        )
        tracker.beginBreak()

        let t0 = Date(timeIntervalSince1970: 2_000)
        let stand = PoseFixtures.lidStanding(timestamp: t0)
        _ = tracker.process(
            sample: stand,
            posture: .standingLike,
            sitToStand: SitToStandEvent(detectedAt: t0)
        )

        var last = MovementProofStatus.awaitingStand
        for second in 1...6 {
            // Identical joints → no motion credit.
            let sample = PoseFixtures.lidStanding(timestamp: t0.addingTimeInterval(Double(second)))
            last = tracker.process(sample: sample, posture: .standingLike, sitToStand: nil)
        }

        XCTAssertFalse(last.isVerified)
        if case .standing(_, let motion) = last {
            XCTAssertLessThan(motion, 0.2)
        } else {
            XCTFail("expected standing-still status, got \(last)")
        }
    }

    func testStandingWithMotionVerifies() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 3,
                minimumMotionScore: 0.15,
                jointMotionFloor: 0.002
            )
        )
        tracker.beginBreak()

        let t0 = Date(timeIntervalSince1970: 3_000)
        var pose = PoseFixtures.lidStanding(timestamp: t0)
        _ = tracker.process(
            sample: pose,
            posture: .standingLike,
            sitToStand: SitToStandEvent(detectedAt: t0)
        )

        var last = MovementProofStatus.awaitingStand
        for step in 1...8 {
            let t = t0.addingTimeInterval(Double(step) * 0.5)
            pose = shifted(pose, dx: 0.02, dy: -0.015, at: t)
            last = tracker.process(sample: pose, posture: .standingLike, sitToStand: nil)
        }

        XCTAssertTrue(last.isVerified)
    }

    func testFrameMotionIgnoresSubFloorJitter() {
        let a: [BodyJoint: PoseJoint] = [
            .leftShoulder: .init(x: 0.4, y: 0.2, confidence: 1),
            .rightShoulder: .init(x: 0.6, y: 0.2, confidence: 1),
        ]
        let b: [BodyJoint: PoseJoint] = [
            .leftShoulder: .init(x: 0.4005, y: 0.2005, confidence: 1),
            .rightShoulder: .init(x: 0.6005, y: 0.2005, confidence: 1),
        ]
        let motion = MovementProofTracker.frameMotion(from: a, to: b, floor: 0.003)
        XCTAssertEqual(motion, 0)
    }

    private func shifted(_ sample: PoseSample, dx: Double, dy: Double, at timestamp: Date) -> PoseSample {
        var joints: [BodyJoint: PoseJoint] = [:]
        for (key, joint) in sample.joints {
            joints[key] = PoseJoint(x: joint.x + dx, y: joint.y + dy, confidence: joint.confidence)
        }
        return PoseSample(joints: joints, timestamp: timestamp)
    }
}
