import XCTest
@testable import Unchair

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testOpenSettingsMarksSettingsPresented() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(authorizer: authorizer, capture: capture)
        )

        XCTAssertFalse(shell.isSettingsPresented)
        shell.openSettings()
        XCTAssertTrue(shell.isSettingsPresented)
    }
}
