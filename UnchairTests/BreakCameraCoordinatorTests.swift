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
        XCTAssertTrue(coordinator.allowsUnverifiedCompletion)
    }

    func testBusyCameraSurfacesFailOpenState() async {
        let capture = FakeCameraCapture(availability: .busy(reason: "FaceTime"))
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))

        XCTAssertFalse(capture.isRunning)
        if case .busy(let reason) = coordinator.state {
            XCTAssertEqual(reason, "FaceTime")
        } else {
            XCTFail("Expected busy state")
        }
        XCTAssertTrue(coordinator.allowsUnverifiedCompletion)
        XCTAssertTrue(coordinator.canCompleteBreak)
    }

    func testForegroundRefreshResumesCaptureAfterPermissionGranted() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .denied, grantOnRequest: .denied)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertEqual(coordinator.state, .permissionDenied)
        XCTAssertFalse(capture.isRunning)

        authorizer.setStatus(.authorized)
        let status = await coordinator.refreshAfterForeground()

        XCTAssertEqual(status, .authorized)
        XCTAssertTrue(capture.isRunning)
        XCTAssertEqual(coordinator.state, .running)
        XCTAssertFalse(coordinator.allowsUnverifiedCompletion)
    }

    func testForegroundRefreshRetriesBusyCamera() async {
        let capture = FakeCameraCapture(availability: .busy(reason: "Zoom"))
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertEqual(coordinator.state, .busy("Zoom"))

        capture.availability = .available
        _ = await coordinator.refreshAfterForeground()

        XCTAssertTrue(capture.isRunning)
        XCTAssertEqual(coordinator.state, .running)
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

    func testPowerSuspendStopsCaptureDuringBreakAndResumes() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertTrue(capture.isRunning)

        await coordinator.setPowerSuspended(true)
        XCTAssertFalse(capture.isRunning)
        XCTAssertTrue(coordinator.isPowerSuspended)
        XCTAssertTrue(coordinator.allowsUnverifiedCompletion)
        XCTAssertTrue(coordinator.canCompleteBreak)

        await coordinator.setPowerSuspended(false)
        XCTAssertTrue(capture.isRunning)
        XCTAssertFalse(coordinator.isPowerSuspended)
        XCTAssertFalse(coordinator.allowsUnverifiedCompletion)
    }

    func testRequestCameraAccessDoesNotStartCapture() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .notDetermined, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        let status = await coordinator.requestCameraAccess()

        XCTAssertEqual(status, .authorized)
        XCTAssertFalse(capture.isRunning)
        XCTAssertEqual(capture.startCount, 0)
    }

    func testCompletedBreakStopsCaptureEvenIfPreviewWasArmed() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        coordinator.armSettingsPreview()
        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))
        XCTAssertTrue(capture.isRunning)

        coordinator.stopSettingsPreview()
        await coordinator.handlePhaseChange(.working(until: Date().addingTimeInterval(50 * 60)))
        XCTAssertFalse(capture.isRunning)
    }
}
