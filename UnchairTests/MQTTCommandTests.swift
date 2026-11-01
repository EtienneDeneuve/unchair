import XCTest
@testable import Unchair

@MainActor
final class MQTTCommandTests: XCTestCase {
    private final class RecordingPerformer: MQTTCommandPerforming {
        private(set) var commands: [MQTTAcceptedCommand] = []
        func performMQTTCommand(_ command: MQTTAcceptedCommand) {
            commands.append(command)
        }
    }

    // MARK: - Parser table

    func testParserAllowlistAndRejections() {
        struct Case {
            var name: String
            var json: String
            var expected: MQTTCommandParseResult
        }

        let cases: [Case] = [
            Case(
                name: "start_break",
                json: #"{"contractVersion":1,"command":"start_break"}"#,
                expected: .accepted(.startBreak, id: nil)
            ),
            Case(
                name: "postpone_15",
                json: #"{"contractVersion":1,"command":"postpone","minutes":15,"id":"p1"}"#,
                expected: .accepted(.postpone(minutes: 15), id: "p1")
            ),
            Case(
                name: "postpone_invalid_minutes",
                json: #"{"contractVersion":1,"command":"postpone","minutes":10}"#,
                expected: .rejected(.invalidMinutes(10))
            ),
            Case(
                name: "postpone_missing_minutes",
                json: #"{"contractVersion":1,"command":"postpone"}"#,
                expected: .rejected(.missingMinutes)
            ),
            Case(
                name: "skip",
                json: #"{"contractVersion":1,"command":"skip"}"#,
                expected: .accepted(.skip, id: nil)
            ),
            Case(
                name: "presentation_on_bounded",
                json: #"{"contractVersion":1,"command":"presentation_on","minutes":30}"#,
                expected: .accepted(.presentationOn(minutes: 30), id: nil)
            ),
            Case(
                name: "presentation_on_until_disabled",
                json: #"{"contractVersion":1,"command":"presentation_on"}"#,
                expected: .accepted(.presentationOn(minutes: nil), id: nil)
            ),
            Case(
                name: "presentation_off",
                json: #"{"contractVersion":1,"command":"presentation_off"}"#,
                expected: .accepted(.presentationOff, id: nil)
            ),
            Case(
                name: "unknown_command",
                json: #"{"contractVersion":1,"command":"dance"}"#,
                expected: .rejected(.unknownCommand("dance"))
            ),
            Case(
                name: "forbidden_complete",
                json: #"{"contractVersion":1,"command":"complete"}"#,
                expected: .rejected(.forbidden("complete"))
            ),
            Case(
                name: "forbidden_fake_movement",
                json: #"{"contractVersion":1,"command":"fake_movement"}"#,
                expected: .rejected(.forbidden("fake_movement"))
            ),
            Case(
                name: "bad_contract_version",
                json: #"{"contractVersion":2,"command":"skip"}"#,
                expected: .rejected(.unsupportedContractVersion(2))
            ),
            Case(
                name: "invalid_json",
                json: #"not-json"#,
                expected: .rejected(.invalidJSON)
            ),
        ]

        for testCase in cases {
            let result = MQTTCommandParser.parse(Data(testCase.json.utf8))
            XCTAssertEqual(result, testCase.expected, testCase.name)
        }
    }

    func testRouterDedupesByIdAndDispatches() {
        let performer = RecordingPerformer()
        let router = MQTTCommandRouter()
        router.performer = performer

        let first = Data(#"{"contractVersion":1,"command":"skip","id":"dup-1"}"#.utf8)
        let second = Data(#"{"contractVersion":1,"command":"skip","id":"dup-1"}"#.utf8)
        let third = Data(#"{"contractVersion":1,"command":"start_break","id":"other"}"#.utf8)

        router.handle(payload: first)
        router.handle(payload: second)
        router.handle(payload: third)

        XCTAssertEqual(performer.commands, [.skip, .startBreak])
        XCTAssertEqual(router.acceptedCount, 2)
        XCTAssertEqual(router.ignoredDuplicateCount, 1)
        XCTAssertEqual(router.rejectedCount, 0)
    }

    func testRouterIgnoresRejectedWithoutDispatch() {
        let performer = RecordingPerformer()
        let router = MQTTCommandRouter()
        router.performer = performer
        router.handle(payload: Data(#"{"contractVersion":1,"command":"complete"}"#.utf8))
        XCTAssertTrue(performer.commands.isEmpty)
        XCTAssertEqual(router.rejectedCount, 1)
        XCTAssertEqual(router.lastRejection, .forbidden("complete"))
    }

    // MARK: - Domain transition matrix via shell

    func testCommandStateCombinations() {
        struct Case {
            var name: String
            var setup: (MenuBarShell) -> Void
            var command: MQTTAcceptedCommand
            var assert: (MenuBarShell) -> Void
        }

        let cases: [Case] = [
            Case(
                name: "postpone while break due -> postponed",
                setup: { shell in
                    shell.startBreakNow()
                    XCTAssertEqual(shell.phase, .breakDue)
                },
                command: .postpone(minutes: 15),
                assert: { shell in
                    guard case .postponed = shell.phase else {
                        return XCTFail("expected postponed, got \(shell.phase)")
                    }
                }
            ),
            Case(
                name: "postpone while working -> ignored by state machine",
                setup: { _ in },
                command: .postpone(minutes: 15),
                assert: { shell in
                    if case .postponed = shell.phase {
                        XCTFail("postpone must not apply from working/idle")
                    }
                }
            ),
            Case(
                name: "skip while break due -> working with debt path",
                setup: { shell in
                    shell.startBreakNow()
                },
                command: .skip,
                assert: { shell in
                    switch shell.phase {
                    case .working, .idle:
                        break
                    default:
                        XCTFail("expected working/idle after skip, got \(shell.phase)")
                    }
                }
            ),
            Case(
                name: "presentation_on during break due is deterministic",
                setup: { shell in
                    shell.startBreakNow()
                },
                command: .presentationOn(minutes: 30),
                assert: { shell in
                    XCTAssertTrue(shell.isPresentationModeEnabled)
                }
            ),
            Case(
                name: "presentation_off clears mode",
                setup: { shell in
                    shell.enablePresentationModeUntilDisabled()
                    XCTAssertTrue(shell.isPresentationModeEnabled)
                },
                command: .presentationOff,
                assert: { shell in
                    XCTAssertFalse(shell.isPresentationModeEnabled)
                }
            ),
            Case(
                name: "start_break from working -> breakDue",
                setup: { _ in },
                command: .startBreak,
                assert: { shell in
                    XCTAssertEqual(shell.phase, .breakDue)
                }
            ),
        ]

        for testCase in cases {
            let shell = makeShell()
            testCase.setup(shell)
            shell.performMQTTCommand(testCase.command)
            testCase.assert(shell)
        }
    }

    func testInboundTransportDeliversCommandToRouter() async throws {
        let transport = FakeMQTTTransport()
        let config = InMemoryMQTTConfigurationStore(
            configuration: MQTTConfiguration(
                isEnabled: true,
                host: "broker.local",
                port: 1883,
                useTLS: false,
                username: "",
                homeAssistantDiscoveryEnabled: false
            )
        )
        let client = MQTTClientController(
            configurationStore: config,
            credentials: InMemoryMQTTCredentialStore(),
            transport: transport,
            deviceId: "uch_cmd01"
        )
        let performer = RecordingPerformer()
        let router = MQTTCommandRouter()
        router.performer = performer
        client.onCommandPayload = { data in
            router.handle(payload: data)
        }

        client.startIfEnabled()
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(client.connectionState, .connected)
        XCTAssertEqual(transport.subscribedTopics, ["unchair/uch_cmd01/command"])

        let payload = Data(#"{"contractVersion":1,"command":"start_break","id":"t1"}"#.utf8)
        transport.deliver(
            MQTTPublishMessage(
                topic: "unchair/uch_cmd01/command",
                payload: payload,
                retain: false
            )
        )
        XCTAssertEqual(performer.commands, [.startBreak])
        client.stop()
        try await Task.sleep(nanoseconds: 20_000_000)
    }

    func testDiscoveryButtonsPublishCommandConfigs() async throws {
        let transport = FakeMQTTTransport()
        let client = MQTTClientController(
            configurationStore: InMemoryMQTTConfigurationStore(
                configuration: MQTTConfiguration(
                    isEnabled: true,
                    host: "broker.local",
                    port: 1883,
                    useTLS: false,
                    username: "",
                    homeAssistantDiscoveryEnabled: true
                )
            ),
            credentials: InMemoryMQTTCredentialStore(),
            transport: transport,
            deviceId: "uch_btn01"
        )
        let publisher = MQTTHomeAssistantPublisher(
            client: client,
            deviceId: "uch_btn01",
            softwareVersion: "0.2.1"
        )
        publisher.stateProvider = {
            (
                BreakStateMachine(
                    clock: ControllableClock(now: Date()),
                    presentationGuard: ControllablePresentationGuard(),
                    restoreOnInit: false
                ).snapshot,
                TodayStats(
                    dayStart: Date(),
                    completedCount: 0,
                    skippedCount: 0,
                    postponedCount: 0,
                    movementSeconds: 0,
                    longestDeskSeconds: 0,
                    nextBreakSummary: "",
                    isEmpty: true
                ),
                false
            )
        }
        client.startIfEnabled()
        try await Task.sleep(nanoseconds: 50_000_000)
        await publisher.noteConnected()

        let buttonTopics = transport.published.map(\.topic).filter {
            $0.hasPrefix("homeassistant/button/unchair_uch_btn01_")
        }
        XCTAssertFalse(buttonTopics.isEmpty)
        XCTAssertTrue(buttonTopics.contains { $0.contains("start_break") })
        XCTAssertTrue(buttonTopics.contains { $0.contains("postpone_15") })
        XCTAssertTrue(buttonTopics.contains { $0.contains("presentation_off") })

        let start = try XCTUnwrap(transport.published.first {
            $0.topic == "homeassistant/button/unchair_uch_btn01_start_break/config"
        })
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: start.payload) as? [String: Any]
        )
        XCTAssertEqual(object["cmd_t"] as? String, "unchair/uch_btn01/command")
        let press = try XCTUnwrap(object["payload_press"] as? String)
        XCTAssertTrue(press.contains("start_break"))
        client.stop()
        try await Task.sleep(nanoseconds: 20_000_000)
    }

    func testPacketsSubscribeAndPublishParse() {
        let sub = MQTTPackets.subscribe(topic: "unchair/x/command", packetID: 7, qos: 0)
        XCTAssertEqual(sub[0], 0x82)

        var buffer = MQTTPackets.publish(
            topic: "unchair/x/command",
            payload: Data(#"{"command":"skip"}"#.utf8),
            retain: false
        )
        let inbound = MQTTPackets.consumeInboundPacket(from: &buffer)
        guard case .publish(let topic, let payload, let retain)? = inbound else {
            return XCTFail("expected publish")
        }
        XCTAssertEqual(topic, "unchair/x/command")
        XCTAssertEqual(String(data: payload, encoding: .utf8), #"{"command":"skip"}"#)
        XCTAssertFalse(retain)
        XCTAssertTrue(buffer.isEmpty)
    }

    private func makeShell() -> MenuBarShell {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let manual = ManualPresentationMode(clock: clock)
        return MenuBarShell(
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
            manualPresentationMode: manual,
            history: BreakHistoryRecorder(
                store: InMemoryBreakHistoryStore(),
                clock: clock
            ),
            mqttClient: MQTTClientController(
                configurationStore: InMemoryMQTTConfigurationStore(
                    configuration: MQTTConfiguration(
                        isEnabled: false,
                        host: "",
                        port: 1883,
                        useTLS: false,
                        username: "",
                        homeAssistantDiscoveryEnabled: false
                    )
                ),
                credentials: InMemoryMQTTCredentialStore(),
                transport: FakeMQTTTransport()
            ),
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false
        )
    }
}
