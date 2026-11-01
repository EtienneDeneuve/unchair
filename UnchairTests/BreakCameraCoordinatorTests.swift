import XCTest
@testable import Unchair

@MainActor
final class BreakCameraCoordinatorTests: XCTestCase {
    func testCameraStartsOnlyWhileTimedBreakIsActive() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.breakDue)
        XCTAssertFalse(capture.isRunning)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertTrue(capture.isRunning)
        XCTAssertEqual(capture.startCount, 1)

        await coordinator.handlePhaseChange(.working(until: Date().addingTimeInterval(50 * 60)))
        XCTAssertFalse(capture.isRunning)
        XCTAssertEqual(capture.stopCount, 1)
    }

    func testDeniedPermissionDoesNotCrashAndLeavesCaptureStopped() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .denied, grantOnRequest: .denied)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))

        XCTAssertFalse(capture.isRunning)
        XCTAssertEqual(coordinator.state, .permissionDenied)
        XCTAssertEqual(capture.startCount, 0)
    }

    func testUnavailableCameraSurfacesErrorState() async {
        let capture = FakeCameraCapture(availability: .unavailable(reason: "No camera"))
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))

        XCTAssertFalse(capture.isRunning)
        if case .unavailable(let reason) = coordinator.state {
            XCTAssertEqual(reason, "No camera")
        } else {
            XCTFail("Expected unavailable state")
        }
    }

    func testStoppingOnSkipAndPostponeClearsCameraIndicator() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertTrue(capture.isRunning)

        await coordinator.handlePhaseChange(.postponed(until: Date().addingTimeInterval(15 * 60)))
        XCTAssertFalse(capture.isRunning)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertTrue(capture.isRunning)

        await coordinator.handlePhaseChange(.working(until: Date().addingTimeInterval(50 * 60)))
        XCTAssertFalse(capture.isRunning)
        XCTAssertEqual(capture.stopCount, 2)
    }
}
