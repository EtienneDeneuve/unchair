import XCTest
@testable import Unchair

@MainActor
final class CameraPermissionPromptTests: XCTestCase {
    func testLaunchSyncDoesNotPromptWhenNotDetermined() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .notDetermined, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        let status = await coordinator.syncCameraAuthorizationAtLaunch()

        XCTAssertEqual(status, .notDetermined)
        XCTAssertEqual(authorizer.requestCount, 0, "first-run onboarding owns the camera prompt")
        XCTAssertFalse(capture.isRunning)
    }

    func testLaunchSyncDoesNotRepromptWhenAlreadyAuthorized() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        _ = await coordinator.syncCameraAuthorizationAtLaunch()

        XCTAssertEqual(authorizer.requestCount, 0)
    }

    func testEnableCameraAccessPromptsWhenNotDetermined() async {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .notDetermined, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        let status = await coordinator.enableCameraAccess()

        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(authorizer.requestCount, 1)
    }

    func testBreakDoesNotPromptForCameraAccess() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 1)
        let authorizer = FakeCameraAuthorizer(initial: .notDetermined, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.handlePhaseChange(.onBreak(endsAt: Date().addingTimeInterval(90), verification: .awaitingStand))

        XCTAssertEqual(authorizer.requestCount, 0)
        XCTAssertFalse(capture.isRunning)
    }

    func testSettingsPreviewDoesNotPromptWhenNotDetermined() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 2)
        let authorizer = FakeCameraAuthorizer(initial: .notDetermined, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.startSettingsPreview()

        XCTAssertEqual(authorizer.requestCount, 0)
        XCTAssertFalse(capture.isRunning)
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testSettingsPreviewStartsSilentlyWhenAlreadyAuthorized() async {
        let capture = FakeCameraCapture(emitsFramesOnStart: 2)
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)

        await coordinator.startSettingsPreview()

        XCTAssertEqual(authorizer.requestCount, 0)
        XCTAssertTrue(capture.isRunning)
    }
}
