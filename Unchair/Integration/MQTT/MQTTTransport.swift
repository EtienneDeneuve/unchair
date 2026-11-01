import Foundation
import Network

enum MQTTTransportError: Error, Equatable, Sendable {
    case disabled
    case invalidConfiguration
    case credentialLookupFailed
    case unreachable(String)
    case timedOut
    case disconnected
    case underlying(String)
}

enum MQTTConnectionState: Equatable, Sendable {
    case disabled
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(String)
}

struct MQTTConnectRequest: Equatable, Sendable {
    var host: String
    var port: Int
    var useTLS: Bool
    var username: String?
    var password: String?
    var clientID: String
}

/// Abstraction over a broker connection. Unit tests inject a fake; production probes TCP/TLS.
@MainActor
protocol MQTTTransporting: AnyObject {
    func connect(_ request: MQTTConnectRequest) async throws
    func disconnect()
    var isConnected: Bool { get }
}

/// Deterministic fake for unit tests — never talks to a real broker.
@MainActor
final class FakeMQTTTransport: MQTTTransporting {
    var shouldFailWith: MQTTTransportError?
    var connectDelayNanoseconds: UInt64 = 0
    private(set) var isConnected = false
    private(set) var lastRequest: MQTTConnectRequest?
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    func connect(_ request: MQTTConnectRequest) async throws {
        connectCount += 1
        lastRequest = request
        if connectDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: connectDelayNanoseconds)
        }
        if let shouldFailWith {
            isConnected = false
            throw shouldFailWith
        }
        isConnected = true
    }

    func disconnect() {
        disconnectCount += 1
        isConnected = false
    }
}

/// TCP(/TLS) reachability probe used for Settings → Test Connection without a full MQTT stack.
@MainActor
final class TCPProbeMQTTTransport: MQTTTransporting {
    private let timeout: TimeInterval
    private(set) var isConnected = false

    init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    func connect(_ request: MQTTConnectRequest) async throws {
        isConnected = false
        let host = request.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, (1...65535).contains(request.port) else {
            throw MQTTTransportError.invalidConfiguration
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "com.etiennedeneuve.unchair.mqtt.probe")
            let connection = NWProbe.makeConnection(
                host: host,
                port: request.port,
                useTLS: request.useTLS
            )
            let bridge = ProbeContinuationBridge(continuation: continuation, connection: connection)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    bridge.resume(.success(()))
                case .failed(let error):
                    bridge.resume(.failure(MQTTTransportError.unreachable(error.localizedDescription)))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + self.timeout) {
                bridge.resume(.failure(MQTTTransportError.timedOut))
            }
        }
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }
}

enum NWProbe {
    static func makeConnection(host: String, port: Int, useTLS: Bool) -> NWConnection {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        let tls = useTLS ? NWProtocolTLS.Options() : nil
        let tcp = NWProtocolTCP.Options()
        let params = NWParameters(tls: tls, tcp: tcp)
        return NWConnection(host: nwHost, port: nwPort, using: params)
    }
}

/// Settles a probe continuation exactly once from NWConnection callbacks.
private final class ProbeContinuationBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private let connection: NWConnection

    init(continuation: CheckedContinuation<Void, Error>, connection: NWConnection) {
        self.continuation = continuation
        self.connection = connection
    }

    func resume(_ result: Result<Void, Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        guard let cont else { return }
        connection.cancel()
        cont.resume(with: result)
    }
}
