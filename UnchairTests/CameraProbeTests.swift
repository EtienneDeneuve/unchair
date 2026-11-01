import XCTest
@testable import Unchair

@MainActor
final class CameraProbeTests: XCTestCase {
    func testProbeSucceedsWhenFramesArrive() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 3)
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        let result = await coordinator.runProbe(timeoutSeconds: 1)

        XCTAssertEqual(result, .ok(framesReceived: 3))
        XCTAssertFalse(capture.isRunning)
    }

    func testProbeReportsDeniedWithoutStartingCapture() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 5)
        let authorizer = FakeCameraAuthorizer(initial: .denied, grantOnRequest: .denied)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        let result = await coordinator.runProbe(timeoutSeconds: 1)

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertEqual(capture.startCount, 0)
        XCTAssertFalse(capture.isRunning)
    }

    func testProbeLeavesCaptureRunningIfBreakAlreadyActive() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 2)
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90)))
        XCTAssertTrue(capture.isRunning)

        let result = await coordinator.runProbe(timeoutSeconds: 1)
        XCTAssertEqual(result, .ok(framesReceived: 2))
        XCTAssertTrue(capture.isRunning)

        await coordinator.handlePhaseChange(.working(until: Date().addingTimeInterval(50 * 60)))
        XCTAssertFalse(capture.isRunning)
    }
}
