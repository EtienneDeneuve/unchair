import XCTest
@testable import Unchair

/// #110 — fixture + relaunch contracts for the Mac-only scheduler.
final class BreakSchedulerContractTests: XCTestCase {
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

    func testFixtureScenariosAreDocumented() throws {
        let json = try loadFixture()
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["issue"] as? Int, 110)
        let scenarios = try XCTUnwrap(json["scenarios"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(scenarios.count, 8)
        let ids = Set(scenarios.compactMap { $0["id"] as? String })
        for required in [
            "main-path-complete",
            "skip-keeps-debt",
            "postpone-keeps-debt",
            "presentation-defer-resumes-due",
            "sleep-does-not-invent-sitting",
            "relaunch-mid-break-becomes-due",
            "relaunch-while-locked-keeps-freeze",
            "relaunch-deferred-preserves-debt",
        ] {
            XCTAssertTrue(ids.contains(required), "fixture missing \(required)")
        }
    }

    func testFixtureScenariosExecuteDeterministically() throws {
        let json = try loadFixture()
        let scenarios = try XCTUnwrap(json["scenarios"] as? [[String: Any]])
        for scenario in scenarios {
            setUp()
            let id = try XCTUnwrap(scenario["id"] as? String)
            let steps = try XCTUnwrap(scenario["steps"] as? [String])
            for step in steps {
                try apply(step: step)
            }
            if let phaseName = scenario["expectPhase"] as? String {
                assertPhase(phaseName, scenario: id)
            }
            if let expectDebt = scenario["expectDebt"] as? Bool {
                XCTAssertEqual(
                    machine.snapshot.hasMovementDebt,
                    expectDebt,
                    "\(id): debt mismatch"
                )
            }
            if let sitting = scenario["expectSittingSeconds"] as? Double {
                XCTAssertEqual(
                    machine.snapshot.sittingDuration?.seconds ?? -1,
                    sitting,
                    accuracy: 0.001,
                    "\(id): sitting mismatch"
                )
            }
        }
    }

    func testRelaunchWhileLockedDoesNotInventSitting() {
        machine.apply(.start)
        clock.advance(by: 10 * 60)
        machine.apply(.evaluate)
        presentation.isScreenLockedOrAsleep = true
        machine.apply(.evaluate)

        clock.advance(by: 45 * 60)
        let restored = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            restoreOnInit: true
        )
        clock.advance(by: 15 * 60)
        restored.apply(.evaluate)

        XCTAssertEqual(
            restored.snapshot.sittingDuration?.seconds ?? -1,
            10 * 60,
            accuracy: 0.001,
            "relaunch while locked must not invent sitting time"
        )
        if case .working = restored.snapshot.phase {
            // expected
        } else {
            XCTFail("expected working while still locked, got \(restored.snapshot.phase)")
        }
    }

    func testRelaunchDeferredPreservesDebtThenReturnsDue() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        let breakID = machine.snapshot.breakID
        presentation.isBlocking = true
        machine.apply(.evaluate)
        XCTAssertTrue(machine.snapshot.hasMovementDebt)
        if case .deferredForPresentation = machine.snapshot.phase {
            // expected
        } else {
            XCTFail("expected deferred, got \(machine.snapshot.phase)")
        }

        let restored = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            store: store,
            restoreOnInit: true
        )
        XCTAssertTrue(restored.snapshot.hasMovementDebt)
        XCTAssertEqual(restored.snapshot.breakID, breakID)
        if case .deferredForPresentation = restored.snapshot.phase {
            // expected
        } else {
            XCTFail("expected deferred after relaunch, got \(restored.snapshot.phase)")
        }

        presentation.isBlocking = false
        restored.apply(.evaluate)
        XCTAssertEqual(restored.snapshot.phase, .breakDue)
        XCTAssertTrue(restored.snapshot.hasMovementDebt)
        XCTAssertEqual(restored.snapshot.breakID, breakID)
    }

    // MARK: - Fixture driver

    private func loadFixture() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/break-scheduler-transitions.json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(json)
    }

    private func apply(step: String) throws {
        switch step {
        case "start":
            machine.apply(.start)
        case "advance_work_interval":
            clock.advance(by: machine.settings.workInterval.seconds)
        case "advance_10m":
            clock.advance(by: 10 * 60)
        case "advance_1h":
            clock.advance(by: 60 * 60)
        case "advance_2h":
            clock.advance(by: 2 * 60 * 60)
        case "evaluate":
            machine.apply(.evaluate)
        case "beginTimedBreak":
            machine.apply(.beginTimedBreak)
        case "movementVerified":
            machine.apply(.movementVerified)
        case "complete":
            machine.apply(.complete)
        case "skip":
            machine.apply(.skip)
        case "postpone_15m":
            machine.apply(.postpone(until: clock.now.addingTimeInterval(15 * 60)))
        case "block_presentation":
            presentation.isBlocking = true
        case "unblock_presentation":
            presentation.isBlocking = false
        case "lock_screen":
            presentation.isScreenLockedOrAsleep = true
        case "unlock_screen":
            presentation.isScreenLockedOrAsleep = false
        case "relaunch":
            machine = BreakStateMachine(
                clock: clock,
                presentationGuard: presentation,
                store: store,
                restoreOnInit: true
            )
        default:
            XCTFail("unknown fixture step \(step)")
        }
    }

    private func assertPhase(_ name: String, scenario: String) {
        switch name {
        case "working":
            if case .working = machine.snapshot.phase { return }
        case "breakDue":
            XCTAssertEqual(machine.snapshot.phase, .breakDue, scenario)
            return
        case "postponed":
            if case .postponed = machine.snapshot.phase { return }
        case "deferredForPresentation":
            if case .deferredForPresentation = machine.snapshot.phase { return }
        default:
            XCTFail("\(scenario): unknown expectPhase \(name)")
            return
        }
        XCTFail("\(scenario): expected \(name), got \(machine.snapshot.phase)")
    }
}
