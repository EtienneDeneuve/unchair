import XCTest
@testable import Unchair

@MainActor
final class BreakMovementProofIntegrationTests: XCTestCase {
    func testAuthorizedBreakCannotCompleteBeforeProof() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 1)
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))

        XCTAssertEqual(coordinator.movementProofStatus, .awaitingStand)
        XCTAssertFalse(coordinator.canCompleteBreak)
    }

    func testPermissionDeniedAllowsCompletionWithoutProof() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .denied, grantOnRequest: .denied)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))

        XCTAssertEqual(coordinator.state, .permissionDenied)
        XCTAssertTrue(coordinator.canCompleteBreak)
        XCTAssertFalse(coordinator.movementProofStatus.isVerified)
    }
}
