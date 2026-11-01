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
                .today,
                .settings,
                .quit,
            ]
        )
    }

    private func makeShell(
        clock: ControllableClock,
        historyStore: (any BreakHistoryStoring)? = nil,
        observesMenuTracking: Bool = true,
        startsPeriodicTicker: Bool = true,
        primesCameraAtLaunch: Bool = true
    ) -> MenuBarShell {
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let history = BreakHistoryRecorder(
            store: historyStore ?? InMemoryBreakHistoryStore(),
            clock: clock
        )
        return MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(authorizer: authorizer, capture: capture),
            history: history,
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

    func testCompleteSkipAndPostponeAreRecordedInLocalHistory() async {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let store = InMemoryBreakHistoryStore()
        let capture = FakeCameraCapture()
        // Denied camera → failed-open completion is allowed.
        let authorizer = FakeCameraAuthorizer(initial: .denied, grantOnRequest: .denied)
        let coordinator = BreakCameraCoordinator(authorizer: authorizer, capture: capture)
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: coordinator,
            history: BreakHistoryRecorder(store: store, clock: clock),
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false
        )

        shell.startBreakNow()
        shell.beginTimedBreak()
        await coordinator.handlePhaseChange(shell.phase)
        shell.completeBreak()
        XCTAssertEqual(store.records.last?.result, .completed)
        XCTAssertEqual(store.records.last?.verification?.failedOpen, true)

        shell.startBreakNow()
        shell.skipBreak()
        XCTAssertEqual(store.records.last?.result, .skipped)

        shell.startBreakNow()
        shell.postpone(by: .minutes(15))
        XCTAssertEqual(store.records.last?.result, .postponed)
        XCTAssertEqual(store.records.count, 3)

        shell.clearBreakHistory()
        XCTAssertEqual(shell.historyEntryCount, 0)
    }
}
