import XCTest
@testable import Unchair

final class BreakStateMachineTests: XCTestCase {
    private var clock: ControllableClock!
    private var presentation: ControllablePresentationGuard!
    private var store: InMemoryBreakLifecycleStore!
    private var machine: BreakStateMachine!

    override func setUp() {
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        presentation = ControllablePresentationGuard()
        store = InMemoryBreakLifecycleStore()
        machine = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            restoreOnInit: false
        )
    }

    func testInvalidTransitionsAreRejected() {
        machine.apply(.start)

        XCTAssertEqual(
            machine.apply(.complete),
            .failure(.invalidTransition(from: machine.snapshot.phase, event: .complete))
        )
        XCTAssertEqual(
            machine.apply(.beginTimedBreak),
            .failure(.invalidTransition(from: machine.snapshot.phase, event: .beginTimedBreak))
        )
        XCTAssertEqual(
            machine.apply(.standDetected),
            .failure(.invalidTransition(from: machine.snapshot.phase, event: .standDetected))
        )
        XCTAssertEqual(
            machine.apply(.skip),
            .failure(.invalidTransition(from: machine.snapshot.phase, event: .skip))
        )
    }

    func testMainVerificationPathToCompleted() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.phase, .breakDue)

        machine.apply(.beginTimedBreak)
        XCTAssertEqual(
            machine.snapshot.phase,
            .onBreak(
                endsAt: clock.now.addingTimeInterval(90),
                verification: .awaitingStand
            )
        )

        machine.apply(.standDetected)
        XCTAssertEqual(machine.snapshot.phase.verification, .standingDetected)

        machine.apply(.movementVerified)
        XCTAssertEqual(machine.snapshot.phase.verification, .movementVerified)

        let completedAt = clock.now
        XCTAssertEqual(machine.apply(.complete), .success(machine.snapshot))
        XCTAssertEqual(
            machine.snapshot.phase,
            .working(until: completedAt.addingTimeInterval(50 * 60))
        )
        XCTAssertFalse(machine.snapshot.hasMovementDebt)
    }

    func testCannotCompleteBeforeVerification() {
        machine.apply(.start)
        machine.apply(.startBreakNow)
        machine.apply(.beginTimedBreak)

        let result = machine.apply(.complete)
        XCTAssertEqual(
            result,
            .failure(.invalidTransition(from: machine.snapshot.phase, event: .complete))
        )
        XCTAssertTrue(machine.snapshot.phase.isOnBreak)
    }

    func testFailedVerificationAllowsComplete() {
        machine.apply(.start)
        machine.apply(.startBreakNow)
        machine.apply(.beginTimedBreak)
        machine.apply(.verificationFailed)

        XCTAssertEqual(machine.snapshot.phase.verification, .failedVerification)
        XCTAssertNoThrow(try machine.apply(.complete).get())
        XCTAssertFalse(machine.snapshot.hasMovementDebt)
    }

    func testPresentationDeferralSurvivesMissedPostponeDeadline() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        let debtOrigin = machine.snapshot.sittingStartedAt
        let breakID = machine.snapshot.breakID

        machine.apply(.postpone(until: clock.now.addingTimeInterval(15 * 60)))
        presentation.isBlocking = true
        clock.advance(by: 15 * 60)
        machine.apply(.evaluate)

        XCTAssertEqual(
            machine.snapshot.phase,
            .deferredForPresentation(pendingSince: clock.now)
        )
        XCTAssertEqual(machine.snapshot.sittingStartedAt, debtOrigin)
        XCTAssertEqual(machine.snapshot.breakID, breakID)

        clock.advance(by: 7 * 60)
        presentation.isBlocking = false
        machine.apply(.evaluate)

        XCTAssertEqual(machine.snapshot.phase, .breakDue)
        XCTAssertEqual(machine.snapshot.breakID, breakID)
        XCTAssertTrue(machine.snapshot.hasMovementDebt)
    }

    func testRestartRestoresPostponeWithoutActiveCameraSession() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        machine.apply(.beginTimedBreak)
        XCTAssertTrue(machine.snapshot.phase.isOnBreak)
        let breakID = machine.snapshot.breakID
        let sitting = machine.snapshot.sittingStartedAt

        // Persistence maps on-break → breakDue (no camera resurrect).
        let restored = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            restoreOnInit: true
        )

        XCTAssertEqual(restored.snapshot.phase, .breakDue)
        XCTAssertEqual(restored.snapshot.breakID, breakID)
        XCTAssertEqual(restored.snapshot.sittingStartedAt, sitting)
        XCTAssertTrue(restored.snapshot.hasMovementDebt)
    }

    func testRestartRestoresPostponedDeadline() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        let until = clock.now.addingTimeInterval(45 * 60)
        machine.apply(.postpone(until: until))

        let restored = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            restoreOnInit: true
        )

        XCTAssertEqual(restored.snapshot.phase, .postponed(until: until))
        XCTAssertTrue(restored.snapshot.hasMovementDebt)
    }

    func testTableDrivenTransitions() {
        let cases: [(BreakEvent, BreakPhase?, Bool)] = [
            // from idle
            (.complete, .idle, false),
            (.start, .idle, true),
        ]

        for (event, from, shouldSucceed) in cases {
            let local = BreakStateMachine(
                clock: clock,
                presentationGuard: presentation,
                restoreOnInit: false
            )
            if from != .idle {
                local.apply(.start)
            }
            let result = local.apply(event)
            if shouldSucceed {
                XCTAssertNoThrow(try result.get(), "expected success for \(event)")
            } else {
                XCTAssertThrowsError(try result.get(), "expected failure for \(event)")
            }
        }
    }

    func testSleepFreezesSittingCounterAndWorkDeadline() {
        machine.apply(.start)
        clock.advance(by: 10 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.sittingDuration!.seconds, 10 * 60, accuracy: 0.001)

        let remainingBeforeLock = machine.snapshot.remainingWork!.seconds
        XCTAssertEqual(remainingBeforeLock, 40 * 60, accuracy: 0.001)

        presentation.isScreenLockedOrAsleep = true
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.sittingDuration!.seconds, 10 * 60, accuracy: 0.001)

        clock.advance(by: 2 * 60 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(
            machine.snapshot.sittingDuration!.seconds,
            10 * 60,
            accuracy: 0.001,
            "sleep must not inflate sitting time"
        )
        XCTAssertEqual(
            machine.snapshot.remainingWork!.seconds,
            remainingBeforeLock,
            accuracy: 0.001,
            "work deadline must pause while locked/asleep"
        )
        if case .working = machine.snapshot.phase {
            // expected
        } else {
            XCTFail("expected working during sleep, got \(machine.snapshot.phase)")
        }

        presentation.isScreenLockedOrAsleep = false
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.sittingDuration!.seconds, 10 * 60, accuracy: 0.001)
        XCTAssertEqual(machine.snapshot.remainingWork!.seconds, remainingBeforeLock, accuracy: 0.001)

        clock.advance(by: 5 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.sittingDuration!.seconds, 15 * 60, accuracy: 0.001)
        XCTAssertEqual(machine.snapshot.remainingWork!.seconds, 35 * 60, accuracy: 0.001)
    }

    func testHIDIdleFreezesSittingCounterLikeSleep() {
        machine.apply(.start)
        clock.advance(by: 8 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.sittingDuration!.seconds, 8 * 60, accuracy: 0.001)

        presentation.isUserIdle = true
        machine.apply(.evaluate)
        clock.advance(by: 20 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(
            machine.snapshot.sittingDuration!.seconds,
            8 * 60,
            accuracy: 0.001,
            "HID idle must freeze sitting without screen lock"
        )
        if case .working = machine.snapshot.phase {
            // expected
        } else {
            XCTFail("work deadline must pause while HID-idle, got \(machine.snapshot.phase)")
        }

        presentation.isUserIdle = false
        machine.apply(.evaluate)
        clock.advance(by: 2 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.sittingDuration!.seconds, 10 * 60, accuracy: 0.001)
    }

    func testSleepDoesNotFireBreakDueUntilThawedDeadlineElapses() {
        machine.apply(.start)
        clock.advance(by: 45 * 60)
        machine.apply(.evaluate)

        presentation.isScreenLockedOrAsleep = true
        machine.apply(.evaluate)
        clock.advance(by: 30 * 60)
        machine.apply(.evaluate)
        if case .working = machine.snapshot.phase {
            // expected — deadline must not expire during sleep
        } else {
            XCTFail("deadline must not expire during sleep, got \(machine.snapshot.phase)")
        }

        presentation.isScreenLockedOrAsleep = false
        machine.apply(.evaluate)
        if case .working = machine.snapshot.phase {
            // still working; 5 minutes remain after thaw
        } else {
            XCTFail("expected working right after thaw, got \(machine.snapshot.phase)")
        }
        clock.advance(by: 5 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.phase, .breakDue)
    }
}
