import XCTest
@testable import Unchair

final class DomainEventTests: XCTestCase {
    private var clock: ControllableClock!
    private var presentation: ControllablePresentationGuard!
    private var bus: DomainEventBus!
    private var sink: RecordingDomainEventSink!
    private var machine: BreakStateMachine!

    override func setUp() {
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        presentation = ControllablePresentationGuard()
        bus = DomainEventBus()
        sink = RecordingDomainEventSink()
        bus.addSink(sink)
        machine = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            eventPublisher: bus,
            restoreOnInit: false
        )
    }

    func testFixtureListsEveryDomainEventName() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/domain-events.json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, DomainEvent.schemaVersion)

        let events = try XCTUnwrap(json?["events"] as? [[String: Any]])
        let names = Set(events.compactMap { $0["name"] as? String })
        for name in DomainEventName.allCases {
            XCTAssertTrue(names.contains(name.rawValue), "fixture missing \(name.rawValue)")
        }

        let forbidden = try XCTUnwrap(json?["forbiddenPayloadFields"] as? [String])
        XCTAssertTrue(forbidden.contains("landmarks"))
        XCTAssertTrue(forbidden.contains("frame"))
    }

    func testMainPathEmitsScheduledDueStartedCompleted() {
        machine.apply(.start)
        XCTAssertEqual(sink.names(), [.breakScheduled])

        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(sink.names().last, .breakDue)

        machine.apply(.beginTimedBreak)
        XCTAssertEqual(sink.names().last, .breakStarted)

        machine.apply(.movementVerified)
        machine.apply(.complete)
        XCTAssertEqual(
            Array(sink.names().suffix(2)),
            [.breakCompleted, .breakScheduled]
        )
        if case .breakCompleted(_, _, let failedOpen) = sink.events.dropLast().last?.payload {
            XCTAssertFalse(failedOpen)
        } else {
            XCTFail("expected completed payload")
        }
    }

    func testPostponeAndPresentationDeferEmitDomainEvents() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        sink.reset()

        let until = clock.now.addingTimeInterval(15 * 60)
        machine.apply(.postpone(until: until))
        XCTAssertEqual(sink.names(), [.breakPostponed])

        presentation.isBlocking = true
        clock.advance(by: 15 * 60)
        machine.apply(.evaluate)
        XCTAssertEqual(sink.names().last, .breakDeferredForPresentation)

        presentation.isBlocking = false
        machine.apply(.evaluate)
        XCTAssertEqual(sink.names().last, .breakDue)
    }

    func testSkipEmitsSkippedAndReschedules() {
        machine.apply(.start)
        clock.advance(by: 50 * 60)
        machine.apply(.evaluate)
        sink.reset()

        machine.apply(.skip)
        XCTAssertEqual(sink.names(), [.breakSkipped, .breakScheduled])
    }

    func testDisabledBusLeavesCoreBehaviorUnchanged() {
        let silent = BreakStateMachine(
            clock: clock,
            presentationGuard: presentation,
            eventPublisher: nil,
            restoreOnInit: false
        )
        silent.apply(.start)
        clock.advance(by: 50 * 60)
        silent.apply(.evaluate)
        XCTAssertEqual(silent.snapshot.phase, .breakDue)
        XCTAssertTrue(sink.events.isEmpty)
    }

    func testFakeAdapterRequiresNoBreakEngineChanges() {
        final class FakeMQTTAdapter: DomainEventSink {
            var received: [DomainEventName] = []
            func receive(_ event: DomainEvent) {
                received.append(event.name)
            }
        }

        let adapter = FakeMQTTAdapter()
        bus.addSink(adapter)
        machine.apply(.start)
        XCTAssertEqual(adapter.received, [.breakScheduled])
        bus.removeSink(adapter)
        machine.apply(.startBreakNow)
        XCTAssertEqual(adapter.received, [.breakScheduled], "removed adapter gets nothing new")
    }

    func testPayloadRoundTripOmitsForbiddenSensorFields() throws {
        let event = DomainEvent(
            name: .breakCompleted,
            occurredAt: clock.now,
            breakID: UUID(),
            payload: .breakCompleted(
                stoodForSeconds: 12,
                motionScore: 0.4,
                failedOpen: false
            )
        )
        let data = try JSONEncoder().encode(event)
        let text = String(decoding: data, as: UTF8.self)
        for banned in ["landmarks", "joints", "pixelBuffer", "meetingApp", "frame"] {
            XCTAssertFalse(text.contains(banned))
        }
        let decoded = try JSONDecoder().decode(DomainEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }

    func testBreakEngineDoesNotImportMQTTOrNetworking() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Unchair/BreakEngine", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        let banned = ["MQTT", "CocoaMQTT", "NWConnection", "HomeAssistant", "URLSession"]
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in banned {
                XCTAssertFalse(
                    source.contains(token),
                    "\(file.lastPathComponent) must not reference \(token)"
                )
            }
        }
    }
}
