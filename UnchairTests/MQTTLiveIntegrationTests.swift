import XCTest
@testable import Unchair

/// Optional live broker tests (issue #19). Skipped unless UNCHAIR_MQTT_INTEGRATION=1.
/// Default CI / `xcodebuild test` remains broker-free.
@MainActor
final class MQTTLiveIntegrationTests: XCTestCase {
    private var host: String = "127.0.0.1"
    private var port: Int = 1883
    private var username: String = ""
    private var password: String = ""

    override func setUp() async throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(
            env["UNCHAIR_MQTT_INTEGRATION"] == "1",
            "Set UNCHAIR_MQTT_INTEGRATION=1 against a disposable broker (see scripts/mqtt-integration-smoke.sh)"
        )
        host = env["UNCHAIR_MQTT_HOST"] ?? "127.0.0.1"
        port = Int(env["UNCHAIR_MQTT_PORT"] ?? "1883") ?? 1883
        username = env["UNCHAIR_MQTT_USERNAME"] ?? ""
        password = env["UNCHAIR_MQTT_PASSWORD"] ?? ""
    }

    func testConnectSubscribePublishStateAndCommandRoundTrip() async throws {
        let deviceId = "uch_live01"
        let transport = MQTTNetworkTransport(timeout: 5)
        let credentials = InMemoryMQTTCredentialStore()
        if !password.isEmpty {
            try credentials.savePassword(password)
        }
        let store = InMemoryMQTTConfigurationStore(
            configuration: MQTTConfiguration(
                isEnabled: true,
                host: host,
                port: port,
                useTLS: false,
                username: username,
                homeAssistantDiscoveryEnabled: true
            )
        )
        let client = MQTTClientController(
            configurationStore: store,
            credentials: credentials,
            transport: transport,
            deviceId: deviceId
        )
        let publisher = MQTTHomeAssistantPublisher(
            client: client,
            deviceId: deviceId,
            softwareVersion: "0.2.1"
        )
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let machine = BreakStateMachine(
            clock: clock,
            presentationGuard: ControllablePresentationGuard(),
            restoreOnInit: false
        )
        machine.apply(.start)
        publisher.stateProvider = {
            (
                machine.snapshot,
                TodayStats(
                    dayStart: clock.now,
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

        let performer = RecordingCommandPerformer()
        let router = MQTTCommandRouter()
        router.performer = performer
        client.onCommandPayload = { data in
            router.handle(payload: data)
        }
        client.onConnected = {
            await publisher.noteConnected()
        }

        client.startIfEnabled()
        try await waitUntil(timeout: 8) { client.connectionState == .connected }

        // Second session publishes a command to the subscribed topic.
        let injector = MQTTNetworkTransport(timeout: 5)
        try await injector.connect(
            MQTTConnectRequest(
                host: host,
                port: port,
                useTLS: false,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password,
                clientID: "unchair-live-injector",
                willTopic: nil,
                willMessage: nil
            )
        )
        let command = Data(#"{"contractVersion":1,"command":"start_break","id":"live-1"}"#.utf8)
        try await injector.publish(
            MQTTPublishMessage(
                topic: "unchair/\(deviceId)/command",
                payload: command,
                retain: false
            )
        )
        try await waitUntil(timeout: 5) { !performer.commands.isEmpty }
        XCTAssertEqual(performer.commands, [.startBreak])

        injector.disconnect()
        client.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    func testSecondDevicePrefixDoesNotReceiveFirstDeviceCommand() async throws {
        let transportA = MQTTNetworkTransport(timeout: 5)
        let clientA = MQTTClientController(
            configurationStore: InMemoryMQTTConfigurationStore(
                configuration: MQTTConfiguration(
                    isEnabled: true,
                    host: host,
                    port: port,
                    useTLS: false,
                    username: username,
                    homeAssistantDiscoveryEnabled: false
                )
            ),
            credentials: InMemoryMQTTCredentialStore(),
            transport: transportA,
            deviceId: "uch_iso_a"
        )
        let performerA = RecordingCommandPerformer()
        let routerA = MQTTCommandRouter()
        routerA.performer = performerA
        clientA.onCommandPayload = { routerA.handle(payload: $0) }
        clientA.startIfEnabled()
        try await waitUntil(timeout: 8) { clientA.connectionState == .connected }

        let injector = MQTTNetworkTransport(timeout: 5)
        try await injector.connect(
            MQTTConnectRequest(
                host: host,
                port: port,
                useTLS: false,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password,
                clientID: "unchair-live-iso",
                willTopic: nil,
                willMessage: nil
            )
        )
        try await injector.publish(
            MQTTPublishMessage(
                topic: "unchair/uch_iso_b/command",
                payload: Data(#"{"contractVersion":1,"command":"skip","id":"iso"}"#.utf8),
                retain: false
            )
        )
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(performerA.commands.isEmpty, "device A must ignore commands for device B")

        injector.disconnect()
        clientA.stop()
    }

    private func waitUntil(timeout: TimeInterval, predicate: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("condition not met within \(timeout)s")
    }
}

@MainActor
private final class RecordingCommandPerformer: MQTTCommandPerforming {
    private(set) var commands: [MQTTAcceptedCommand] = []
    func performMQTTCommand(_ command: MQTTAcceptedCommand) {
        commands.append(command)
    }
}
