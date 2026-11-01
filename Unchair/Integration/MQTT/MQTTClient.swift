import Foundation
import OSLog

struct MQTTReconnectPolicy: Equatable, Sendable {
    /// Seconds for attempt n (1-based), capped by `maxDelaySeconds`.
    var baseDelaySeconds: TimeInterval = 1
    var maxDelaySeconds: TimeInterval = 60
    var maxAttempts: Int = 8

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let exp = min(Double(max(attempt - 1, 0)), 6)
        let raw = baseDelaySeconds * pow(2, exp)
        return min(maxDelaySeconds, raw)
    }
}

enum MQTTTestConnectionStatus: Equatable, Sendable {
    case disabled
    case invalidConfiguration([MQTTConfigurationValidator.Issue])
    case missingCredentials
    case success(host: String, port: Int, usedTLS: Bool)
    case failure(String)

    var userMessage: String {
        switch self {
        case .disabled:
            return "MQTT is disabled."
        case .invalidConfiguration(let issues):
            let parts = issues.map { issue -> String in
                switch issue {
                case .disabled: return "disabled"
                case .emptyHost: return "hostname required"
                case .invalidPort: return "port must be 1…65535"
                }
            }
            return "Invalid configuration: \(parts.joined(separator: ", "))."
        case .missingCredentials:
            return "Username set but no password in Keychain."
        case .success(let host, let port, let tls):
            return "Reached \(host):\(port) (\(tls ? "TLS" : "plain"))."
        case .failure(let message):
            return "Connection failed: \(message)"
        }
    }
}

/// Optional MQTT adapter. Failures never propagate into BreakEngine.
@MainActor
final class MQTTClientController {
    private let configurationStore: any MQTTConfigurationStoring
    private let credentials: any MQTTCredentialStoring
    private let transport: any MQTTTransporting
    private let policy: MQTTReconnectPolicy
    private let log = Logger(subsystem: "com.etiennedeneuve.unchair", category: "MQTT")
    let deviceId: String

    private(set) var configuration: MQTTConfiguration
    private(set) var connectionState: MQTTConnectionState = .disabled
    private var reconnectTask: Task<Void, Never>?
    private var attempt = 0
    /// Process-lifetime cache so Keychain is touched once (reconnects must not re-prompt).
    private var cachedPassword: CachedMQTTPassword = .unloaded

    /// Called after a successful session connect (publish discovery/state).
    var onConnected: (() async -> Void)?
    /// Inbound payloads on the device command topic (issue #18).
    var onCommandPayload: ((Data) -> Void)?

    init(
        configurationStore: any MQTTConfigurationStoring = UserDefaultsMQTTConfigurationStore(),
        credentials: any MQTTCredentialStoring = KeychainMQTTCredentialStore(),
        transport: any MQTTTransporting = MQTTNetworkTransport(),
        policy: MQTTReconnectPolicy = MQTTReconnectPolicy(),
        deviceId: String = MQTTDeviceID.make()
    ) {
        self.configurationStore = configurationStore
        self.credentials = credentials
        self.transport = transport
        self.policy = policy
        self.deviceId = deviceId
        self.configuration = configurationStore.load()
        connectionState = configuration.isEnabled ? .disconnected : .disabled
    }

    var topics: MQTTTopicNames { MQTTTopicNames(deviceId: deviceId) }

    func updateConfiguration(_ configuration: MQTTConfiguration) {
        self.configuration = configuration
        configurationStore.save(configuration)
        if !configuration.isEnabled {
            stop()
            connectionState = .disabled
        }
    }

    func savePassword(_ password: String) throws {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try credentials.deletePassword()
            cachedPassword = .absent
        } else {
            try credentials.savePassword(trimmed)
            cachedPassword = .present(trimmed)
        }
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        attempt = 0
        transport.onMessage = nil
        transport.onDisconnect = nil
        transport.disconnect()
        if configuration.isEnabled {
            connectionState = .disconnected
        } else {
            connectionState = .disabled
        }
        log.info("mqtt_stopped")
    }

    /// Start background reconnect loop when enabled.
    func startIfEnabled() {
        guard configuration.isEnabled else {
            connectionState = .disabled
            return
        }
        // Warm Keychain once up front — reconnect / publish / sanitize reuse the cache.
        _ = try? loadPasswordIfNeeded()
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            await self?.runReconnectLoop()
        }
    }

    func publish(topic: String, payload: Data, retain: Bool) async throws {
        guard connectionState == .connected else {
            throw MQTTTransportError.disconnected
        }
        try await transport.publish(
            MQTTPublishMessage(topic: topic, payload: payload, retain: retain)
        )
    }

    func testConnection() async -> MQTTTestConnectionStatus {
        let issues = MQTTConfigurationValidator.validate(configuration)
            .filter { $0 != .disabled }
        if !configuration.isEnabled {
            return .disabled
        }
        if !issues.isEmpty {
            return .invalidConfiguration(issues)
        }

        let password: String?
        do {
            password = try loadPasswordIfNeeded()
        } catch {
            return .missingCredentials
        }

        let request = makeRequest(password: password)
        do {
            try await transport.connect(request)
            transport.disconnect()
            log.info("mqtt_test_ok host=\(self.redactedHost, privacy: .public)")
            return .success(
                host: configuration.host,
                port: configuration.port,
                usedTLS: configuration.useTLS
            )
        } catch let error as MQTTTransportError {
            log.error("mqtt_test_failed reason=\(self.redacted(error), privacy: .public)")
            return .failure(userFacing(error))
        } catch {
            log.error("mqtt_test_failed reason=unknown")
            return .failure("unexpected error")
        }
    }

    // MARK: - Internals

    private func runReconnectLoop() async {
        attempt = 0
        while !Task.isCancelled {
            guard configuration.isEnabled else {
                connectionState = .disabled
                return
            }
            attempt += 1
            connectionState = attempt == 1
                ? .connecting
                : .reconnecting(attempt: attempt)

            let password: String?
            do {
                password = try loadPasswordIfNeeded()
            } catch {
                connectionState = .failed("Keychain credential lookup failed")
                log.error("mqtt_keychain_lookup_failed")
                return
            }

            do {
                bindTransportCallbacks()
                try await transport.connect(makeRequest(password: password))
                try await transport.subscribe(topic: topics.command)
                connectionState = .connected
                attempt = 0
                log.info("mqtt_connected host=\(self.redactedHost, privacy: .public)")
                await onConnected?()
                await waitWhileTransportConnected()
                guard configuration.isEnabled, !Task.isCancelled else {
                    connectionState = configuration.isEnabled ? .disconnected : .disabled
                    return
                }
                connectionState = .disconnected
                log.info("mqtt_session_ended_reconnecting")
            } catch {
                transport.disconnect()
                let message = userFacing(error)
                connectionState = .failed(message)
                log.error("mqtt_connect_failed attempt=\(self.attempt, privacy: .public) reason=\(message, privacy: .public)")
                if attempt >= policy.maxAttempts {
                    return
                }
                let delay = policy.delay(forAttempt: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func bindTransportCallbacks() {
        transport.onMessage = { [weak self] message in
            guard let self else { return }
            guard message.topic == self.topics.command else { return }
            self.onCommandPayload?(message.payload)
        }
        transport.onDisconnect = nil
    }

    /// Poll transport liveness so cancellation/`stop()` cannot double-resume a continuation.
    private func waitWhileTransportConnected() async {
        while transport.isConnected && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func makeRequest(password: String?) -> MQTTConnectRequest {
        let topics = self.topics
        return MQTTConnectRequest(
            host: configuration.host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: configuration.port,
            useTLS: configuration.useTLS,
            username: configuration.username.isEmpty ? nil : configuration.username,
            password: password,
            clientID: "unchair-\(deviceId)-\(UUID().uuidString.prefix(4))",
            willTopic: topics.availability,
            willMessage: "offline"
        )
    }

    private func loadPasswordIfNeeded() throws -> String? {
        if configuration.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        switch cachedPassword {
        case .present(let password):
            return password
        case .absent:
            throw MQTTCredentialStoreError.notFound
        case .unloaded:
            do {
                let password = try credentials.loadPassword()
                cachedPassword = .present(password)
                return password
            } catch MQTTCredentialStoreError.notFound {
                cachedPassword = .absent
                throw MQTTCredentialStoreError.notFound
            }
        }
    }

    private var redactedHost: String {
        let host = configuration.host
        guard host.count > 4 else { return "***" }
        return String(host.prefix(2)) + "***" + String(host.suffix(2))
    }

    private func redacted(_ error: MQTTTransportError) -> String {
        switch error {
        case .disabled: return "disabled"
        case .invalidConfiguration: return "invalid_configuration"
        case .credentialLookupFailed: return "credential_lookup_failed"
        case .unreachable: return "unreachable"
        case .timedOut: return "timed_out"
        case .disconnected: return "disconnected"
        case .brokerRefused: return "broker_refused"
        case .underlying: return "underlying"
        }
    }

    private func userFacing(_ error: Error) -> String {
        if let transport = error as? MQTTTransportError {
            switch transport {
            case .disabled: return "disabled"
            case .invalidConfiguration: return "invalid configuration"
            case .credentialLookupFailed: return "credential lookup failed"
            case .unreachable(let detail):
                return "unreachable (\(sanitize(detail)))"
            case .timedOut: return "timed out"
            case .disconnected: return "disconnected"
            case .brokerRefused(let code):
                return "broker refused (code \(code))"
            case .underlying(let detail):
                return sanitize(detail)
            }
        }
        return "connection error"
    }

    private func sanitize(_ raw: String) -> String {
        var text = raw
        if case .present(let password) = cachedPassword, !password.isEmpty {
            text = text.replacingOccurrences(of: password, with: "***")
        }
        if !configuration.username.isEmpty {
            text = text.replacingOccurrences(of: configuration.username, with: "***")
        }
        return text
    }
}

private enum CachedMQTTPassword: Equatable {
    case unloaded
    case absent
    case present(String)
}
