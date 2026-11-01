import XCTest
@testable import Unchair

@MainActor
final class MenuBarShellTests: XCTestCase {
    func testMenuCommandsExposeRequiredActionsInOrder() {
        XCTAssertEqual(
            MenuBarShell.commands,
            [
                .nextBreakStatus,
                .startBreakNow,
                .postponeMenu,
                .presentationModeMenu,
                .pauseResume,
                .settings,
                .quit,
            ]
        )
    }

    private func makeShell(
        clock: ControllableClock,
        observesMenuTracking: Bool = true,
        startsPeriodicTicker: Bool = true,
        primesCameraAtLaunch: Bool = true
    ) -> MenuBarShell {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        return MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(authorizer: authorizer, capture: capture),
            observesMenuTracking: observesMenuTracking,
            startsPeriodicTicker: startsPeriodicTicker,
            primesCameraAtLaunch: primesCameraAtLaunch
        )
    }

    func testNextBreakStatusShowsCountdownAfterStart() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let shell = makeShell(clock: clock)

        XCTAssertEqual(shell.nextBreakStatusText, "Next break: 50:00")
        XCTAssertEqual(shell.menuBarTitleText, "50:00")
        XCTAssertEqual(shell.menuBarSymbolName, "timer")
    }

    func testMenuBarTitleShowsDueWhenBreakIsDue() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = makeShell(clock: clock)
        shell.startBreakNow()
        XCTAssertEqual(shell.menuBarTitleText, "DUE")
        XCTAssertEqual(shell.menuBarSymbolName, "figure.stand")
    }

    func testStartBreakNowIsInvokableWithoutThrowing() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = makeShell(clock: clock)
        XCTAssertNoThrow(shell.startBreakNow())
        XCTAssertEqual(shell.nextBreakStatusText, "Break due now")
    }

    func testSettingsPresentationStartsClosedAndCanOpen() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = makeShell(clock: clock)
        XCTAssertFalse(shell.isSettingsPresented)
        shell.openSettings()
        XCTAssertTrue(shell.isSettingsPresented)
    }

    func testPeriodicTickDoesNotPublishWhileStatusMenuIsTracking() async {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = makeShell(
            clock: clock,
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false
        )
        XCTAssertEqual(shell.statusRevision, 0)

        shell.setStatusMenuTracking(true)
        shell.performPeriodicTick()
        // Flush the camera follow-up task inside bumpStatus.
        await Task.yield()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(
            shell.statusRevision,
            0,
            "Countdown ticks must not rebuild MenuBarExtra while the menu is open"
        )

        shell.setStatusMenuTracking(false)
        XCTAssertEqual(shell.statusRevision, 1)
    }
}
