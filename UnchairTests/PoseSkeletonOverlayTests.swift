import XCTest
@testable import Unchair

final class PoseSkeletonOverlayTests: XCTestCase {
    func testPoseSampleExposesOnlyBodyJointsNeverFace() {
        let joints = PoseFixtures.standing().joints
        let allowed = Set(BodyJoint.allCases)
        XCTAssertEqual(Set(joints.keys), Set(joints.keys).intersection(allowed))
        XCTAssertFalse(joints.keys.contains { $0.rawValue.lowercased().contains("nose") })
        XCTAssertFalse(joints.keys.contains { $0.rawValue.lowercased().contains("eye") })
        XCTAssertFalse(joints.keys.contains { $0.rawValue.lowercased().contains("ear") })
    }

    func testOverlayMappingDoesNotStretchJointsAcrossLetterboxBars() {
        let view = CGSize(width: 400, height: 400)
        let content = PosePreviewCoordinateMapping.aspectFitContentRect(
            in: view,
            contentAspect: PosePreviewCoordinateMapping.defaultContentAspect
        )
        let ankle = PoseFixtures.standing().joints[.leftAnkle]!
        let mapped = PosePreviewCoordinateMapping.viewPoint(
            for: ankle,
            contentRect: content,
            mirrored: true
        )
        XCTAssertGreaterThanOrEqual(mapped.y, content.minY - 0.001)
        XCTAssertLessThanOrEqual(mapped.y, content.maxY + 0.001)
        // Naïve full-view mapping would place y at ankle.y * 400; aspect-fit must differ
        // whenever the content rect is letterboxed.
        let naiveY = CGFloat(ankle.y) * view.height
        XCTAssertNotEqual(mapped.y, naiveY, accuracy: 0.5)
    }
}
