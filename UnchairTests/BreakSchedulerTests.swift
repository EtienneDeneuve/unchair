import XCTest
@testable import Unchair

final class BreakSchedulerTests: XCTestCase {
    private var clock: ControllableClock!
    private var presentation: ControllablePresentationGuard!
    private var scheduler: BreakScheduler!

    override func setUp() {
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        presentation = ControllablePresentationGuard()
        scheduler = BreakScheduler(
            clock: clock,
            presentationGuard: presentation,
            restoreOnInit: false
        )
    }

    func testDefaultsAreFiftyMinutesWorkAndNinetySecondsBreak() {
        XCTAssertEqual(scheduler.settings.workInterval, .seconds(50 * 60))
        XCTAssertEqual(scheduler.settings.breakDuration, .seconds(90))
    }

    func testStartingSchedulesNextBreakFromNow() {
        scheduler.start()

        XCTAssertEqual(
            scheduler.snapshot.phase,
            .working(until: clock.now.addingTimeInterval(50 * 60))
        )
        XCTAssertFalse(scheduler.snapshot.hasMovementDebt)
    }

    func testCountdownBecomesDueExactlyAtDeadline() {
        scheduler.start()
        clock.advance(by: 50 * 60)

        scheduler.evaluate()

        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)
        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
    }

    func testEvaluateIsIdempotentAcrossSleepWakeStyleReentry() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        scheduler.evaluate()
        clock.advance(by: 5)
        scheduler.evaluate()

        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)
    }

    func testStartBreakNowMakesBreakDueImmediately() {
        scheduler.start()
        clock.advance(by: 10 * 60)

        scheduler.startBreakNow()

        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)
        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
    }

    func testBeginTimedBreakTracksRemainingWithoutAutoCompleting() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()

        scheduler.beginTimedBreak()
        XCTAssertEqual(
            scheduler.snapshot.phase,
            .onBreak(endsAt: clock.now.addingTimeInterval(90), verification: .awaitingStand)
        )
        XCTAssertEqual(scheduler.snapshot.remainingBreak, .seconds(90))

        clock.advance(by: 90)
        scheduler.evaluate()

        // Timer may hit zero, but completion stays explicit (verification pending).
        XCTAssertEqual(scheduler.snapshot.phase, .onBreak(endsAt: clock.now, verification: .awaitingStand))
        XCTAssertEqual(scheduler.snapshot.remainingBreak, .seconds(0))
        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
    }

    func testCompletedBreakClearsDebtAndRestartsCadence() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        scheduler.beginTimedBreak()
        scheduler.noteStandDetected()
        scheduler.noteMovementVerified()
        let completedAt = clock.now

        scheduler.completeBreak()

        XCTAssertFalse(scheduler.snapshot.hasMovementDebt)
        XCTAssertNil(scheduler.snapshot.breakID)
        XCTAssertEqual(
            scheduler.snapshot.phase,
            .working(until: completedAt.addingTimeInterval(50 * 60))
        )
    }

    func testSkippedBreakKeepsDebtAndSchedulesNextInterval() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        let skippedAt = clock.now

        scheduler.skipBreak()

        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
        XCTAssertEqual(
            scheduler.snapshot.phase,
            .working(until: skippedAt.addingTimeInterval(50 * 60))
        )
    }

    func testPostponePresetsIncludeFifteenThirtyFortyFiveSixty() {
        XCTAssertEqual(
            BreakScheduler.postponePresets,
            [
                .minutes(15),
                .minutes(30),
                .minutes(45),
                .minutes(60),
            ]
        )
    }

    func testPostponeKeepsDebtAndDefersUntilDeadline() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        let debtSittingStartedAt = scheduler.snapshot.sittingStartedAt

        scheduler.postpone(by: .minutes(45))

        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
        XCTAssertEqual(scheduler.snapshot.sittingStartedAt, debtSittingStartedAt)
        XCTAssertEqual(
            scheduler.snapshot.phase,
            .postponed(until: clock.now.addingTimeInterval(45 * 60))
        )

        clock.advance(by: 45 * 60)
        scheduler.evaluate()

        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)
        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
        XCTAssertEqual(scheduler.snapshot.sittingStartedAt, debtSittingStartedAt)
    }

    func testPostponeUntilExactTime() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        let until = clock.now.addingTimeInterval(20 * 60)

        scheduler.postpone(until: until)

        XCTAssertEqual(scheduler.snapshot.phase, .postponed(until: until))
    }

    func testPostponeWhilePresentationBlocksStaysDeferredUntilGuardClears() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        scheduler.postpone(by: .minutes(15))
        presentation.isBlocking = true

        clock.advance(by: 15 * 60)
        scheduler.evaluate()
        XCTAssertEqual(
            scheduler.snapshot.phase,
            .deferredForPresentation(pendingSince: clock.now)
        )

        presentation.isBlocking = false
        scheduler.evaluate()
        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)
    }

    func testPauseAndResumePreserveRemainingWork() {
        scheduler.start()
        clock.advance(by: 10 * 60)
        scheduler.pause()
        XCTAssertEqual(scheduler.snapshot.phase, .paused)

        clock.advance(by: 30 * 60)
        scheduler.resume()

        XCTAssertEqual(
            scheduler.snapshot.phase,
            .working(until: clock.now.addingTimeInterval(40 * 60))
        )
    }

    func testSettingsChangesApplyToNextScheduleAfterCompletion() {
        scheduler.updateSettings(
            BreakSettings(workInterval: .seconds(30 * 60), breakDuration: .seconds(120))
        )
        scheduler.start()
        clock.advance(by: 30 * 60)
        scheduler.evaluate()
        scheduler.beginTimedBreak()
        scheduler.noteMovementVerified()
        scheduler.completeBreak()

        XCTAssertEqual(
            scheduler.snapshot.phase,
            .working(until: clock.now.addingTimeInterval(30 * 60))
        )
        XCTAssertEqual(scheduler.settings.breakDuration, .seconds(120))
    }

    func testPostponePreservesBreakIdentityAcrossDeferral() {
        scheduler.start()
        clock.advance(by: 50 * 60)
        scheduler.evaluate()
        let originalID = scheduler.snapshot.breakID
        XCTAssertNotNil(originalID)

        scheduler.postpone(by: .minutes(45))
        XCTAssertEqual(scheduler.snapshot.breakID, originalID)

        presentation.isBlocking = true
        clock.advance(by: 45 * 60)
        scheduler.evaluate()
        XCTAssertEqual(scheduler.snapshot.breakID, originalID)
        XCTAssertEqual(
            scheduler.snapshot.phase,
            .deferredForPresentation(pendingSince: clock.now)
        )

        presentation.isBlocking = false
        scheduler.evaluate()
        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)
        XCTAssertEqual(scheduler.snapshot.breakID, originalID)
    }
}
