import XCTest
@testable import Unchair

@MainActor
final class MQTTClientTests: XCTestCase {
    private var configStore: InMemoryMQTTConfigurationStore!
    private var credentials: InMemoryMQTTCredentialStore!
    private var transport: FakeMQTTTransport!
    private var client: MQTTClientController!

    override func setUp() {
        configStore = InMemoryMQTTConfigurationStore()
        credentials = InMemoryMQTTCredentialStore()
        transport = FakeMQTTTransport()
        client = MQTTClientController(
            configurationStore: configStore,
            credentials: credentials,
            transport: transport,
            policy: MQTTReconnectPolicy(baseDelaySeconds: 0.01, maxDelaySeconds: 0.05, maxAttempts: 3)
        )
    }

    func testConfigurationValidation() {
        XCTAssertEqual(
            MQTTConfigurationValidator.validate(.default),
            [.disabled, .emptyHost]
        )
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "broker.local"
        config.port = 8883
        XCTAssertTrue(MQTTConfigurationValidator.canAttemptConnection(config))

        config.port = 0
        XCTAssertEqual(MQTTConfigurationValidator.validate(config), [.invalidPort])
    }

    func testReconnectBackoffIsBounded() {
        let policy = MQTTReconnectPolicy(baseDelaySeconds: 1, maxDelaySeconds: 30, maxAttempts: 10)
        XCTAssertEqual(policy.delay(forAttempt: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4)
        XCTAssertEqual(policy.delay(forAttempt: 10), 30)
    }

    func testDisabledIntegrationDoesNotConnect() async {
        var config = MQTTConfiguration.default
        config.isEnabled = false
        config.host = "broker.local"
        client.updateConfiguration(config)
        client.startIfEnabled()
        let status = await client.testConnection()
        XCTAssertEqual(status, .disabled)
        XCTAssertEqual(transport.connectCount, 0)
        XCTAssertEqual(client.connectionState, .disabled)
    }

    func testUnavailableBrokerSurfacesFailureWithoutCrashing() async {
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "broker.local"
        client.updateConfiguration(config)
        transport.shouldFailWith = .unreachable("connection refused")

        let status = await client.testConnection()
        if case .failure(let message) = status {
            XCTAssertTrue(message.contains("unreachable"))
            XCTAssertFalse(message.contains("secret"))
        } else {
            XCTFail("expected failure, got \(status)")
        }
        XCTAssertFalse(transport.isConnected)
    }

    func testCredentialLookupFailureWhenUsernameWithoutPassword() async {
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "broker.local"
        config.username = "ha"
        client.updateConfiguration(config)

        let status = await client.testConnection()
        XCTAssertEqual(status, .missingCredentials)
        XCTAssertEqual(transport.connectCount, 0)
    }

    func testSuccessfulTestConnectionUsesKeychainPassword() async throws {
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "broker.local"
        config.port = 1883
        config.useTLS = false
        config.username = "ha"
        client.updateConfiguration(config)
        try client.savePassword("s3cret-token")

        let status = await client.testConnection()
        XCTAssertEqual(
            status,
            .success(host: "broker.local", port: 1883, usedTLS: false)
        )
        XCTAssertEqual(transport.lastRequest?.password, "s3cret-token")
        XCTAssertEqual(transport.lastRequest?.username, "ha")
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func testRedactedLoggingHelpersDoNotEmbedSecrets() async throws {
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "mqtt.example.com"
        config.username = "alice"
        client.updateConfiguration(config)
        try client.savePassword("super-secret-password")
        transport.shouldFailWith = .unreachable("auth failed for alice super-secret-password")

        let status = await client.testConnection()
        let message = status.userMessage
        XCTAssertFalse(message.contains("super-secret-password"))
        XCTAssertFalse(message.contains("alice"), "username should be sanitized when present in error text")
    }

    func testConfigurationPersistsWithoutPassword() throws {
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "broker.local"
        config.username = "ha"
        client.updateConfiguration(config)
        try client.savePassword("nope")

        let reloaded = configStore.load()
        let encoded = try JSONEncoder().encode(reloaded)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains("nope"))
        XCTAssertTrue(text.contains("broker.local"))
    }

    func testBreakEngineStillFreeOfMQTTTypes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Unchair/BreakEngine", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(source.contains("MQTTClient"), file.lastPathComponent)
            XCTAssertFalse(source.contains("CocoaMQTT"), file.lastPathComponent)
            XCTAssertFalse(source.contains("KeychainMQTT"), file.lastPathComponent)
        }
    }
}
