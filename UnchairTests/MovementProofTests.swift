import XCTest
@testable import Unchair

final class MovementProofTests: XCTestCase {
    func testCannotVerifyImmediatelyAfterStanding() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 5,
                minimumMotionScore: 0.05,
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
        _ = tracker.process(
            sample: moving,
            posture: .standingLike,
            sitToStand: SitToStandEvent(detectedAt: standAt)
        )

        moving = shifted(moving, dx: 0.2, dy: 0.2, at: standAt.addingTimeInterval(0.5))
        let early = tracker.process(sample: moving, posture: .standingLike, sitToStand: nil)
        XCTAssertFalse(early.isVerified)
        if case .standing(let elapsed, _) = early {
            XCTAssertLessThan(elapsed, 5)
        } else {
            XCTFail("expected standing, got \(early)")
        }
    }

    func testStandingStillDoesNotVerify() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 3,
                minimumMotionScore: 0.15,
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
            let sample = PoseFixtures.lidStanding(timestamp: t0.addingTimeInterval(Double(second)))
            last = tracker.process(sample: sample, posture: .standingLike, sitToStand: nil)
        }

        XCTAssertFalse(last.isVerified)
        if case .standing(_, let motion) = last {
            XCTAssertLessThan(motion, 0.15)
        } else {
            XCTFail("expected standing-still status, got \(last)")
        }
    }

    func testMotionStillCountsWhenPostureFlickersToSeated() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 2,
                minimumMotionScore: 0.08,
                jointMotionFloor: 0.001
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
        for step in 1...10 {
            let t = t0.addingTimeInterval(Double(step) * 0.4)
            pose = shifted(pose, dx: 0.015, dy: -0.01, at: t)
            // Lid cams often mislabel standing as seated — motion must still count.
            last = tracker.process(sample: pose, posture: .seatedLike, sitToStand: nil)
        }

        XCTAssertTrue(last.isVerified, "got \(last)")
    }

    func testLidGeometryStandWithoutStandingLabel() {
        var tracker = MovementProofTracker(
            config: MovementProofConfig(
                minimumStandingSeconds: 2,
                minimumMotionScore: 0.05,
                jointMotionFloor: 0.001,
                standHipRise: 0.04,
                standWidthShrink: 0.03
            )
        )
        tracker.beginBreak()

        let t0 = Date(timeIntervalSince1970: 4_000)
        let seated = PoseFixtures.lidSitting(timestamp: t0)
        _ = tracker.process(sample: seated, posture: .seatedLike, sitToStand: nil)

        // Step back / stand: hips rise (smaller y), shoulders narrower.
        var stood = PoseFixtures.lidStanding(timestamp: t0.addingTimeInterval(1))
        var last = tracker.process(sample: stood, posture: .seatedLike, sitToStand: nil)
        XCTAssertNotEqual(last, .awaitingStand)

        for step in 2...8 {
            stood = shifted(stood, dx: 0.02, dy: 0.01, at: t0.addingTimeInterval(Double(step)))
            last = tracker.process(sample: stood, posture: .seatedLike, sitToStand: nil)
        }
        XCTAssertTrue(last.isVerified, "got \(last)")
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
