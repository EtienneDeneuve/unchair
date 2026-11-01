import XCTest
@testable import Unchair

final class MenuBarShellTests: XCTestCase {
    func testMenuCommandsExposeRequiredActionsInOrder() {
        XCTAssertEqual(
            MenuBarShell.commands,
            [
                .nextBreakStatus,
                .startBreakNow,
                .settings,
                .quit,
            ]
        )
    }

    func testNextBreakStatusUsesUnavailablePlaceholderUntilSchedulerExists() {
        let shell = MenuBarShell()
        XCTAssertEqual(shell.nextBreakStatusText, "Next break: —")
    }

    func testStartBreakNowIsInvokableWithoutThrowing() {
        let shell = MenuBarShell()
        XCTAssertNoThrow(shell.startBreakNow())
    }

    func testSettingsPresentationStartsClosedAndCanOpen() {
        let shell = MenuBarShell()
        XCTAssertFalse(shell.isSettingsPresented)
        shell.openSettings()
        XCTAssertTrue(shell.isSettingsPresented)
    }
}
