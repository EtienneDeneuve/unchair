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

    private(set) var configuration: MQTTConfiguration
    private(set) var connectionState: MQTTConnectionState = .disabled
    private var reconnectTask: Task<Void, Never>?
    private var attempt = 0

    init(
        configurationStore: any MQTTConfigurationStoring = UserDefaultsMQTTConfigurationStore(),
        credentials: any MQTTCredentialStoring = KeychainMQTTCredentialStore(),
        transport: any MQTTTransporting = TCPProbeMQTTTransport(),
        policy: MQTTReconnectPolicy = MQTTReconnectPolicy()
    ) {
        self.configurationStore = configurationStore
        self.credentials = credentials
        self.transport = transport
        self.policy = policy
        self.configuration = configurationStore.load()
        connectionState = configuration.isEnabled ? .disconnected : .disabled
    }

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
        } else {
            try credentials.savePassword(trimmed)
        }
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        attempt = 0
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
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            await self?.runReconnectLoop()
        }
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
                try await transport.connect(makeRequest(password: password))
                connectionState = .connected
                attempt = 0
                log.info("mqtt_connected host=\(self.redactedHost, privacy: .public)")
                return
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

    private func makeRequest(password: String?) -> MQTTConnectRequest {
        MQTTConnectRequest(
            host: configuration.host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: configuration.port,
            useTLS: configuration.useTLS,
            username: configuration.username.isEmpty ? nil : configuration.username,
            password: password,
            clientID: "unchair-\(UUID().uuidString.prefix(8))"
        )
    }

    private func loadPasswordIfNeeded() throws -> String? {
        if configuration.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        do {
            return try credentials.loadPassword()
        } catch MQTTCredentialStoreError.notFound {
            throw MQTTCredentialStoreError.notFound
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
            case .underlying(let detail):
                return sanitize(detail)
            }
        }
        return "connection error"
    }

    private func sanitize(_ raw: String) -> String {
        var text = raw
        if let password = try? credentials.loadPassword(), !password.isEmpty {
            text = text.replacingOccurrences(of: password, with: "***")
        }
        if !configuration.username.isEmpty {
            text = text.replacingOccurrences(of: configuration.username, with: "***")
        }
        return text
    }
}
