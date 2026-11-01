import XCTest
@testable import Unchair

final class PostureClassifierTests: XCTestCase {
    func testStandingPoseReportsStandingWithHighConfidence() {
        let estimate = PostureClassifier().classify(PoseFixtures.standing())
        XCTAssertEqual(estimate.state, .standingLike)
        XCTAssertGreaterThan(estimate.confidence, 0.55)
        XCTAssertTrue(estimate.statusText.hasPrefix("Standing"))
    }

    func testSeatedPoseReportsSittingWithConfidence() {
        let estimate = PostureClassifier().classify(PoseFixtures.seated())
        XCTAssertEqual(estimate.state, .seatedLike)
        XCTAssertGreaterThan(estimate.confidence, 0.55)
        XCTAssertEqual(estimate.displayLabel, "Sitting")
    }

    func testLidCameraStandingWithoutLegs() {
        let estimate = PostureClassifier().classify(PoseFixtures.lidStanding())
        XCTAssertEqual(estimate.state, .standingLike)
        XCTAssertGreaterThan(estimate.confidence, 0.5)
    }

    func testLidCameraSittingWithoutLegs() {
        let estimate = PostureClassifier().classify(PoseFixtures.lidSitting())
        XCTAssertEqual(estimate.state, .seatedLike)
        XCTAssertGreaterThan(estimate.confidence, 0.5)
    }

    func testUpperBodyOnlyDeskCropCountsAsSitting() {
        let shouldersOnly = PoseSample(joints: [
            .leftShoulder: .init(x: 0.4, y: 0.3, confidence: 0.55),
            .rightShoulder: .init(x: 0.6, y: 0.3, confidence: 0.55),
        ])
        let estimate = PostureClassifier().classify(shouldersOnly)
        XCTAssertEqual(estimate.state, .seatedLike)
        // Must not report Vision's middling joint score as ~25% posture confidence.
        XCTAssertGreaterThan(estimate.confidence, 0.65)

        let withHips = PostureClassifier().classify(PoseFixtures.torsoOnly())
        XCTAssertEqual(withHips.state, .seatedLike)
        XCTAssertGreaterThan(withHips.confidence, 0.65)
    }

    func testLidSittingConfidenceIsNotTiny() {
        let estimate = PostureClassifier().classify(PoseFixtures.lidSitting())
        XCTAssertEqual(estimate.state, .seatedLike)
        XCTAssertGreaterThanOrEqual(estimate.confidencePercent, 65)
    }

    func testDeskHipPlacementWithoutKnees() {
        let seatedDesk = PoseSample(joints: [
            .leftShoulder: .init(x: 0.32, y: 0.34, confidence: 0.9),
            .rightShoulder: .init(x: 0.68, y: 0.34, confidence: 0.9),
            .leftHip: .init(x: 0.40, y: 0.82, confidence: 0.8),
            .rightHip: .init(x: 0.60, y: 0.82, confidence: 0.8),
        ])
        let estimate = PostureClassifier().classify(seatedDesk)
        XCTAssertEqual(estimate.state, .seatedLike)
        XCTAssertGreaterThan(estimate.confidence, 0.3)
    }

    func testLowerJointConfidenceReducesEstimateConfidence() {
        let strong = PostureClassifier().classify(PoseFixtures.standing(confidence: 0.95))
        let weak = PostureClassifier().classify(PoseFixtures.standing(confidence: 0.2))
        XCTAssertEqual(strong.state, .standingLike)
        XCTAssertEqual(weak.state, .standingLike)
        XCTAssertGreaterThan(strong.confidence, weak.confidence)
    }

    func testBentKneesPreferSittingEvenWithVisibleAnkles() {
        let bent = PoseSample(joints: [
            .leftShoulder: .init(x: 0.4, y: 0.22, confidence: 0.9),
            .rightShoulder: .init(x: 0.6, y: 0.22, confidence: 0.9),
            .leftHip: .init(x: 0.42, y: 0.48, confidence: 0.9),
            .rightHip: .init(x: 0.58, y: 0.48, confidence: 0.9),
            .leftKnee: .init(x: 0.45, y: 0.62, confidence: 0.9),
            .rightKnee: .init(x: 0.55, y: 0.62, confidence: 0.9),
            .leftAnkle: .init(x: 0.40, y: 0.58, confidence: 0.85),
            .rightAnkle: .init(x: 0.60, y: 0.58, confidence: 0.85),
        ])
        let estimate = PostureClassifier().classify(bent)
        XCTAssertEqual(estimate.state, .seatedLike)
    }
}
