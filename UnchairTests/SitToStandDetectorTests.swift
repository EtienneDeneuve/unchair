import XCTest
@testable import Unchair

final class SitToStandDetectorTests: XCTestCase {
    func testRequiresStableFramesBeforePublishingSeated() {
        var detector = SitToStandDetector(
            stabilization: PostureStabilizerConfig(
                requiredStableFrames: 3,
                fastTrackConfidence: 0.99,
                fastTrackFrames: 3,
                occlusionGraceFrames: 5
            )
        )

        XCTAssertEqual(detector.process(PoseFixtures.seated()).state, .unknown)
        XCTAssertEqual(detector.process(PoseFixtures.seated()).state, .unknown)
        XCTAssertEqual(detector.process(PoseFixtures.seated()).state, .seatedLike)
        XCTAssertGreaterThan(detector.estimate.confidence, 0.5)
    }

    func testDetectsSeatedToStandingTransition() {
        var detector = SitToStandDetector(
            stabilization: PostureStabilizerConfig(
                requiredStableFrames: 2,
                fastTrackConfidence: 0.99,
                fastTrackFrames: 2,
                occlusionGraceFrames: 5
            ),
            smoother: PoseJointSmoother(alpha: 0.85, holdDecay: 0.3)
        )

        for _ in 0..<3 {
            _ = detector.process(PoseFixtures.seated())
        }
        XCTAssertEqual(detector.posture, .seatedLike)

        var last = PostureEstimate.unknown
        for _ in 0..<6 {
            last = detector.process(PoseFixtures.standing())
        }
        XCTAssertEqual(last.state, .standingLike)
        XCTAssertNotNil(detector.lastSitToStand)
    }

    func testBriefOcclusionDoesNotInstantlyReset() {
        var detector = SitToStandDetector(
            stabilization: PostureStabilizerConfig(
                requiredStableFrames: 2,
                fastTrackConfidence: 0.99,
                fastTrackFrames: 2,
                occlusionGraceFrames: 3
            ),
            smoother: PoseJointSmoother(alpha: 0.9, holdDecay: 0.2)
        )

        _ = detector.process(PoseFixtures.seated())
        _ = detector.process(PoseFixtures.seated())
        XCTAssertEqual(detector.posture, .seatedLike)

        let blank = PoseSample(joints: [:])
        XCTAssertEqual(detector.process(blank).state, .seatedLike)
        XCTAssertEqual(detector.process(blank).state, .seatedLike)
        XCTAssertEqual(detector.process(blank).state, .seatedLike)
        // Beyond grace, held joints are gone → unknown.
        XCTAssertEqual(detector.process(blank).state, .unknown)
    }
}
