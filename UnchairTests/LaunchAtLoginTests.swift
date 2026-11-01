import XCTest
@testable import Unchair

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    func testToggleReflectsControllerState() {
        let launch = ControllableLaunchAtLogin(isEnabled: false)
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard(),
                restoreOnInit: false
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(
                authorizer: FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized),
                capture: FakeCameraCapture()
            ),
            launchAtLogin: launch,
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false
        )

        XCTAssertFalse(shell.isLaunchAtLoginEnabled)
        shell.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(launch.lastSetEnabled, true)
        XCTAssertTrue(shell.isLaunchAtLoginEnabled)
        XCTAssertNil(shell.launchAtLoginError)

        shell.setLaunchAtLoginEnabled(false)
        XCTAssertEqual(launch.lastSetEnabled, false)
        XCTAssertFalse(shell.isLaunchAtLoginEnabled)
    }

    func testToggleSurfacesRegistrationErrors() {
        struct Boom: LocalizedError {
            var errorDescription: String? { "registration failed" }
        }
        let launch = ControllableLaunchAtLogin(isEnabled: false)
        launch.errorToThrow = Boom()
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard(),
                restoreOnInit: false
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(
                authorizer: FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized),
                capture: FakeCameraCapture()
            ),
            launchAtLogin: launch,
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false
        )

        shell.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(shell.launchAtLoginError, "registration failed")
        XCTAssertFalse(shell.isLaunchAtLoginEnabled)
    }
}
