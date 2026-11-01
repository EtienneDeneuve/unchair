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
                .pauseResume,
                .settings,
                .quit,
            ]
        )
    }

    func testNextBreakStatusShowsCountdownAfterStart() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController()
        )

        XCTAssertEqual(shell.nextBreakStatusText, "Next break: 50:00")
    }

    func testStartBreakNowIsInvokableWithoutThrowing() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController()
        )
        XCTAssertNoThrow(shell.startBreakNow())
        XCTAssertEqual(shell.nextBreakStatusText, "Break due now")
    }

    func testSettingsPresentationStartsClosedAndCanOpen() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController()
        )
        XCTAssertFalse(shell.isSettingsPresented)
        shell.openSettings()
        XCTAssertTrue(shell.isSettingsPresented)
    }
}
