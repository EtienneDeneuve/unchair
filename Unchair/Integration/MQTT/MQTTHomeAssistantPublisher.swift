import Foundation
import OSLog

/// Translates domain events + periodic snapshots into MQTT topics (issue #17).
/// Never imports BreakEngine sensor APIs; failures are swallowed.
@MainActor
final class MQTTHomeAssistantPublisher: DomainEventSink {
    private let client: MQTTClientController
    private let deviceId: String
    private let softwareVersion: String
    private let log = Logger(subsystem: "com.etiennedeneuve.unchair", category: "MQTTPublish")
    private var lastEventName: String?
    private var discoveryPublished = false

    /// Supplies live snapshot/stats when publishing state.
    var stateProvider: (() -> (snapshot: BreakSnapshot, today: TodayStats, presentationMode: Bool))?

    init(
        client: MQTTClientController,
        deviceId: String = MQTTDeviceID.make(),
        softwareVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    ) {
        self.client = client
        self.deviceId = deviceId
        self.softwareVersion = softwareVersion
    }

    var topics: MQTTTopicNames {
        MQTTTopicNames(deviceId: deviceId)
    }

    nonisolated func receive(_ event: DomainEvent) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastEventName = event.name.rawValue
            await self.publishEvent(event)
            await self.publishStateIfPossible()
        }
    }

    func publishStateIfPossible() async {
        guard client.configuration.isEnabled, client.connectionState == .connected else { return }
        guard let provider = stateProvider else { return }
        let (snapshot, today, presentationMode) = provider()
        do {
            if !discoveryPublished, client.configuration.homeAssistantDiscoveryEnabled {
                try await publishDiscovery()
                discoveryPublished = true
            }
            let payload = MQTTPayloadBuilder.state(
                deviceId: deviceId,
                snapshot: snapshot,
                today: today,
                presentationMode: presentationMode,
                lastEventName: lastEventName,
                now: Date()
            )
            let data = try MQTTPayloadBuilder.encodeJSON(payload)
            try await client.publish(
                topic: topics.state,
                payload: data,
                retain: true
            )
        } catch {
            log.error("mqtt_state_publish_failed")
        }
    }

    func noteConnected() async {
        discoveryPublished = false
        do {
            try await client.publish(
                topic: topics.availability,
                payload: Data("online".utf8),
                retain: true
            )
            if client.configuration.homeAssistantDiscoveryEnabled {
                try await publishDiscovery()
                discoveryPublished = true
            }
            await publishStateIfPossible()
        } catch {
            log.error("mqtt_post_connect_publish_failed")
        }
    }

    func noteStopped() {
        discoveryPublished = false
    }

    // MARK: - Private

    private func publishEvent(_ event: DomainEvent) async {
        guard client.configuration.isEnabled, client.connectionState == .connected else { return }
        do {
            let payload = MQTTPayloadBuilder.event(deviceId: deviceId, domain: event)
            let data = try MQTTPayloadBuilder.encodeJSON(payload)
            assertPrivacy(data)
            try await client.publish(
                topic: topics.event,
                payload: data,
                retain: false
            )
        } catch {
            log.error("mqtt_event_publish_failed")
        }
    }

    private func publishDiscovery() async throws {
        for entity in MQTTDiscovery.entities {
            let topic = MQTTDiscovery.configTopic(deviceId: deviceId, entity: entity)
            let data = try MQTTDiscovery.configJSON(
                deviceId: deviceId,
                entity: entity,
                softwareVersion: softwareVersion
            )
            try await client.publish(topic: topic, payload: data, retain: true)
        }
    }

    private func assertPrivacy(_ data: Data) {
        let text = String(decoding: data, as: UTF8.self).lowercased()
        for banned in ["landmarks", "joints", "pixelbuffer", "image", "video", "meetingapp"] {
            assert(!text.contains(banned), "forbidden field \(banned) in MQTT payload")
        }
    }
}

struct MQTTTopicNames: Equatable, Sendable {
    var deviceId: String

    var availability: String { "unchair/\(deviceId)/availability" }
    var state: String { "unchair/\(deviceId)/state" }
    var event: String { "unchair/\(deviceId)/event" }
    var command: String { "unchair/\(deviceId)/command" }
}
