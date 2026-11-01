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
}
