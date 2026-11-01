import XCTest
@testable import Unchair

@MainActor
final class MQTTPublishTests: XCTestCase {
    private var transport: FakeMQTTTransport!
    private var client: MQTTClientController!
    private var publisher: MQTTHomeAssistantPublisher!
    private var clock: ControllableClock!

    override func setUp() async throws {
        transport = FakeMQTTTransport()
        let config = InMemoryMQTTConfigurationStore(
            configuration: MQTTConfiguration(
                isEnabled: true,
                host: "broker.local",
                port: 1883,
                useTLS: false,
                username: "",
                homeAssistantDiscoveryEnabled: true
            )
        )
        client = MQTTClientController(
            configurationStore: config,
            credentials: InMemoryMQTTCredentialStore(),
            transport: transport,
            deviceId: "uch_test01"
        )
        publisher = MQTTHomeAssistantPublisher(
            client: client,
            deviceId: "uch_test01",
            softwareVersion: "0.2.0"
        )
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))

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
                    dayStart: self.clock.now,
                    completedCount: 2,
                    skippedCount: 1,
                    postponedCount: 0,
                    movementSeconds: 180,
                    longestDeskSeconds: 3200,
                    nextBreakSummary: "Next break: 20:00",
                    isEmpty: false
                ),
                false
            )
        }
    }

    func testStatePayloadMatchesContractAndOmitsForbiddenFields() throws {
        let snapshot = BreakStateMachine(
            clock: clock,
            presentationGuard: ControllablePresentationGuard(),
            restoreOnInit: false
        ).snapshot
        let today = TodayStats(
            dayStart: clock.now,
            completedCount: 1,
            skippedCount: 0,
            postponedCount: 0,
            movementSeconds: 90,
            longestDeskSeconds: 1000,
            nextBreakSummary: "x",
            isEmpty: false
        )
        let state = MQTTPayloadBuilder.state(
            deviceId: "uch_test01",
            snapshot: snapshot,
            today: today,
            presentationMode: true,
            lastEventName: "break.completed",
            now: clock.now
        )
        let data = try MQTTPayloadBuilder.encodeJSON(state)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"contractVersion\":1"))
        XCTAssertTrue(text.contains("\"deviceId\":\"uch_test01\""))
        XCTAssertTrue(text.contains("\"presentationMode\":true"))
        XCTAssertTrue(text.contains("\"lastEventName\":\"break.completed\""))
        for banned in ["landmarks", "joints", "pixelBuffer", "image", "video", "meetingApp"] {
            XCTAssertFalse(text.contains(banned))
        }
    }

    func testConnectPublishesAvailabilityDiscoveryAndState() async throws {
        client.startIfEnabled()
        // Allow reconnect task to connect.
        try await Task.sleep(nanoseconds: 50_000_000)
        await publisher.noteConnected()

        let topics = transport.published.map(\.topic)
        XCTAssertTrue(topics.contains("unchair/uch_test01/availability"))
        XCTAssertTrue(topics.contains("unchair/uch_test01/state"))
        XCTAssertTrue(topics.contains { $0.hasPrefix("homeassistant/sensor/unchair_uch_test01_") })
        XCTAssertTrue(topics.contains { $0.hasPrefix("homeassistant/binary_sensor/unchair_uch_test01_") })

        let availability = transport.published.first { $0.topic.hasSuffix("/availability") }
        XCTAssertEqual(String(data: availability!.payload, encoding: .utf8), "online")
        XCTAssertTrue(availability!.retain)

        let state = transport.published.last { $0.topic.hasSuffix("/state") }
        XCTAssertTrue(state!.retain)
        let stateText = String(data: state!.payload, encoding: .utf8)!
        XCTAssertTrue(stateText.contains("\"completed\":2"))
        XCTAssertTrue(stateText.contains("\"movementMinutes\":3"))
    }

    func testDomainEventPublishesNonRetainedEventAndRefreshesState() async throws {
        try await transport.connect(
            MQTTConnectRequest(
                host: "broker.local",
                port: 1883,
                useTLS: false,
                username: nil,
                password: nil,
                clientID: "t",
                willTopic: nil,
                willMessage: nil
            )
        )
        // Force connected state for publisher guard.
        client.startIfEnabled()
        try await Task.sleep(nanoseconds: 20_000_000)

        // Directly mark connected by connecting via start path already done;
        // publish via receive after ensuring connected.
        await publisher.noteConnected()
        transport.resetPublished()

        let event = DomainEvent(
            name: .breakCompleted,
            occurredAt: clock.now,
            breakID: UUID(),
            payload: .breakCompleted(stoodForSeconds: 12, motionScore: 0.4, failedOpen: false)
        )
        // Simulate connected: Fake transport is connected; set state via startIfEnabled.
        // noteConnected already set discovery; force connectionState by connecting again.
        // Use internal path: call receive which checks connectionState == .connected
        // Ensure client thinks it's connected — startIfEnabled + successful fake connect returns.
        XCTAssertEqual(client.connectionState, .connected)

        publisher.receive(event)
        try await Task.sleep(nanoseconds: 50_000_000)

        let eventMsg = transport.published.first { $0.topic.hasSuffix("/event") }
        XCTAssertNotNil(eventMsg)
        XCTAssertFalse(eventMsg!.retain)
        let text = String(data: eventMsg!.payload, encoding: .utf8)!
        XCTAssertTrue(text.contains("break.completed"))
        XCTAssertTrue(text.contains("stoodForSeconds"))
        XCTAssertFalse(text.lowercased().contains("landmark"))

        XCTAssertTrue(transport.published.contains { $0.topic.hasSuffix("/state") && $0.retain })
    }

    func testConnectRequestIncludesAvailabilityWill() async {
        client.startIfEnabled()
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(transport.lastRequest?.willTopic, "unchair/uch_test01/availability")
        XCTAssertEqual(transport.lastRequest?.willMessage, "offline")
    }

    func testDeviceIdIsStableAnonymizedPrefix() {
        let id = MQTTDeviceID.make(platformUUID: "FIXED-UUID-VALUE")
        XCTAssertTrue(id.hasPrefix("uch_"))
        XCTAssertEqual(id.count, 12) // uch_ + 8 hex
        XCTAssertEqual(id, MQTTDeviceID.make(platformUUID: "FIXED-UUID-VALUE"))
    }

    func testPacketsConnectAndPublishRoundTripShape() {
        let connect = MQTTPackets.connect(
            clientID: "c1",
            username: "u",
            password: "p",
            keepAliveSeconds: 60,
            willTopic: "will",
            willMessage: "offline",
            willRetain: true
        )
        XCTAssertEqual(connect[0], 0x10)

        let publish = MQTTPackets.publish(
            topic: "unchair/x/state",
            payload: Data(#"{"a":1}"#.utf8),
            retain: true
        )
        XCTAssertEqual(publish[0] & 0xf0, 0x30)
        XCTAssertEqual(publish[0] & 0x01, 0x01)
    }
}
