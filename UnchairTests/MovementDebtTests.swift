import XCTest
@testable import Unchair

final class MovementDebtTests: XCTestCase {
    private var clock: ControllableClock!
    private var presentation: ControllablePresentationGuard!
    private var store: InMemoryBreakLifecycleStore!
    private var calendar: Calendar!
    private var machine: BreakStateMachine!

    override func setUp() {
        // Fixed UTC calendar so day-rollover tests stay deterministic.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        presentation = ControllablePresentationGuard()
        store = InMemoryBreakLifecycleStore()
        machine = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            calendar: calendar,
            restoreOnInit: false
        )
    }

    // MARK: - Engine unit

    func testEngineSleepFreezeDoesNotAccrue() {
        var state = MovementDebtState.empty(at: clock.now, calendar: calendar)
        MovementDebtEngine.activate(&state, at: clock.now, isFrozen: false, calendar: calendar)

        clock.advance(by: 120)
        MovementDebtEngine.evaluate(&state, at: clock.now, isFrozen: false, calendar: calendar)
        XCTAssertEqual(state.accruedSeconds, 120)

        presentation.isScreenLockedOrAsleep = true
        MovementDebtEngine.evaluate(&state, at: clock.now, isFrozen: true, calendar: calendar)
        clock.advance(by: 600)
        MovementDebtEngine.evaluate(&state, at: clock.now, isFrozen: true, calendar: calendar)
        XCTAssertEqual(state.accruedSeconds, 120, "sleep must freeze accrual")

        MovementDebtEngine.evaluate(&state, at: clock.now, isFrozen: false, calendar: calendar)
        clock.advance(by: 30)
        let snap = MovementDebtEngine.snapshot(
            state,
            at: clock.now,
            isFrozen: false,
            calendar: calendar
        )
        XCTAssertEqual(snap.currentDuration.seconds, 150)
        XCTAssertEqual(snap.peakDurationToday.seconds, 150)
    }

    // MARK: - Table-driven lifecycle scenarios (issue #20)

    func testTableDrivenDebtScenarios() {
        struct Scenario {
            let name: String
            let steps: [(action: (BreakStateMachine) -> Void, advance: TimeInterval)]
            let expectActive: Bool
            let expectCurrent: TimeInterval
            let expectEpisodes: Int
            let lockDuring: TimeInterval?
        }

        let scenarios: [Scenario] = [
            Scenario(
                name: "due -> completed",
                steps: [
                    ({ $0.apply(.start) }, 50 * 60),
                    ({ $0.apply(.evaluate) }, 90),
                    ({
                        $0.apply(.beginTimedBreak)
                        $0.apply(.standDetected)
                        $0.apply(.movementVerified)
                        $0.apply(.complete)
                    }, 0),
                ],
                expectActive: false,
                expectCurrent: 0,
                expectEpisodes: 1,
                lockDuring: nil
            ),
            Scenario(
                name: "due -> postpone -> completed",
                steps: [
                    ({ $0.apply(.start) }, 50 * 60),
                    ({ $0.apply(.evaluate) }, 0),
                    ({ $0.apply(.postpone(until: self.clock.now.addingTimeInterval(15 * 60))) }, 15 * 60),
                    ({ $0.apply(.evaluate) }, 60),
                    ({
                        $0.apply(.beginTimedBreak)
                        $0.apply(.movementVerified)
                        $0.apply(.complete)
                    }, 0),
                ],
                expectActive: false,
                expectCurrent: 0,
                expectEpisodes: 1,
                lockDuring: nil
            ),
            Scenario(
                name: "postpone -> presentation defer -> completed",
                steps: [
                    ({ $0.apply(.start) }, 50 * 60),
                    ({ $0.apply(.evaluate) }, 0),
                    ({ $0.apply(.postpone(until: self.clock.now.addingTimeInterval(10 * 60))) }, 10 * 60),
                    ({
                        self.presentation.isBlocking = true
                        $0.apply(.evaluate)
                    }, 5 * 60),
                    ({
                        self.presentation.isBlocking = false
                        $0.apply(.evaluate)
                    }, 30),
                    ({
                        $0.apply(.beginTimedBreak)
                        $0.apply(.movementVerified)
                        $0.apply(.complete)
                    }, 0),
                ],
                expectActive: false,
                expectCurrent: 0,
                expectEpisodes: 1,
                lockDuring: nil
            ),
            Scenario(
                name: "manual skip keeps debt accruing",
                steps: [
                    ({ $0.apply(.start) }, 50 * 60),
                    ({ $0.apply(.evaluate) }, 120),
                    ({ $0.apply(.skip) }, 180),
                ],
                expectActive: true,
                expectCurrent: 300,
                expectEpisodes: 1,
                lockDuring: nil
            ),
        ]

        for scenario in scenarios {
            setUp()
            for step in scenario.steps {
                step.action(machine)
                if step.advance > 0 {
                    if let lock = scenario.lockDuring, lock > 0, lock <= step.advance {
                        clock.advance(by: lock)
                        presentation.isScreenLockedOrAsleep = true
                        machine.apply(.evaluate)
                        clock.advance(by: step.advance - lock)
                        presentation.isScreenLockedOrAsleep = false
                        machine.apply(.evaluate)
                    } else {
                        clock.advance(by: step.advance)
                        machine.apply(.evaluate)
                    }
                }
            }

            let debt = machine.snapshot.movementDebt
            XCTAssertEqual(
                debt.isActive,
                scenario.expectActive,
                "\(scenario.name): isActive"
            )
            XCTAssertEqual(
                debt.currentDuration.seconds,
                scenario.expectCurrent,
                accuracy: 0.001,
                "\(scenario.name): currentDuration"
            )
            XCTAssertEqual(
                debt.episodeCountToday,
                scenario.expectEpisodes,
                "\(scenario.name): episodeCountToday"
            )
            XCTAssertEqual(machine.snapshot.hasMovementDebt, debt.isActive, scenario.name)
        }
    }

    func testSleepWakeFreezesDebtDuringDue() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        XCTAssertTrue(machine.snapshot.movementDebt.isActive)

        clock.advance(by: 60)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.movementDebt.currentDuration.seconds, 60)

        presentation.isScreenLockedOrAsleep = true
        machine.apply(.evaluate)
        clock.advance(by: 20 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(
            machine.snapshot.movementDebt.currentDuration.seconds,
            60,
            "locked/asleep must not grow debt"
        )

        presentation.isScreenLockedOrAsleep = false
        machine.apply(.evaluate)
        clock.advance(by: 40)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.movementDebt.currentDuration.seconds, 100)
    }

    func testPresentationBlockStillAccruesDebt() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        presentation.isBlocking = true
        machine.apply(.evaluate)
        XCTAssertEqual(
            machine.snapshot.phase,
            .deferredForPresentation(pendingSince: clock.now)
        )

        clock.advance(by: 180)
        machine.apply(.evaluate)
        XCTAssertEqual(
            machine.snapshot.movementDebt.currentDuration.seconds,
            180,
            "presentation defer must keep accruing (only sleep/lock freezes)"
        )
    }

    func testAppRestartPersistsDebtAccrual() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        clock.advance(by: 240)
        machine.apply(.evaluate)
        let before = machine.snapshot.movementDebt
        XCTAssertEqual(before.currentDuration.seconds, 240)

        let restored = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            calendar: calendar,
            restoreOnInit: true
        )
        clock.advance(by: 60)
        restored.apply(.evaluate)

        XCTAssertTrue(restored.snapshot.movementDebt.isActive)
        XCTAssertEqual(restored.snapshot.movementDebt.currentDuration.seconds, 300)
        XCTAssertEqual(restored.snapshot.movementDebt.episodeCountToday, 1)
    }

    func testLegacyBooleanDebtSynthesizesOnRestore() {
        let legacy = BreakPersistedState(
            kind: .breakDue,
            until: nil,
            pendingSince: nil,
            remainingWhenPaused: nil,
            sittingStartedAt: clock.now.addingTimeInterval(-600),
            hasMovementDebt: true,
            movementDebt: nil,
            breakID: UUID(),
            workIntervalSeconds: 50 * 60,
            breakDurationSeconds: 90
        )
        store.save(legacy)

        let restored = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            calendar: calendar,
            restoreOnInit: true
        )

        XCTAssertTrue(restored.snapshot.hasMovementDebt)
        XCTAssertEqual(restored.snapshot.movementDebt.currentDuration.seconds, 600)
        XCTAssertEqual(restored.snapshot.movementDebt.episodeCountToday, 1)
    }

    func testPeakAndAccumulatedAcrossTwoEpisodes() {
        // Episode 1: due for 100s then complete.
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        clock.advance(by: 100)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.movementDebt.peakDurationToday.seconds, 100)

        machine.apply(.beginTimedBreak)
        machine.apply(.movementVerified)
        machine.apply(.complete)
        XCTAssertFalse(machine.snapshot.movementDebt.isActive)
        XCTAssertEqual(machine.snapshot.movementDebt.accumulatedDurationToday.seconds, 100)
        XCTAssertEqual(machine.snapshot.movementDebt.episodeCountToday, 1)

        // Episode 2: due for 50s.
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        clock.advance(by: 50)
        machine.apply(.evaluate)

        let debt = machine.snapshot.movementDebt
        XCTAssertTrue(debt.isActive)
        XCTAssertEqual(debt.currentDuration.seconds, 50)
        XCTAssertEqual(debt.peakDurationToday.seconds, 100)
        XCTAssertEqual(debt.accumulatedDurationToday.seconds, 150)
        XCTAssertEqual(debt.episodeCountToday, 2)
    }

    func testSkipDoesNotClearDebt() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        clock.advance(by: 45)
        machine.apply(.skip)

        XCTAssertTrue(machine.snapshot.hasMovementDebt)
        clock.advance(by: 15)
        machine.apply(.evaluate)
        XCTAssertEqual(machine.snapshot.movementDebt.currentDuration.seconds, 60)
        XCTAssertEqual(machine.snapshot.movementDebt.episodeCountToday, 1)
    }
}
