import Foundation
import Network

enum MQTTTransportError: Error, Equatable, Sendable {
    case disabled
    case invalidConfiguration
    case credentialLookupFailed
    case unreachable(String)
    case timedOut
    case disconnected
    case brokerRefused(UInt8)
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
    /// Last-will topic for availability offline (optional).
    var willTopic: String?
    var willMessage: String?
}

struct MQTTPublishMessage: Equatable, Sendable {
    var topic: String
    var payload: Data
    var retain: Bool
}

/// Abstraction over a broker connection. Unit tests inject a fake.
@MainActor
protocol MQTTTransporting: AnyObject {
    var isConnected: Bool { get }
    var onMessage: ((MQTTPublishMessage) -> Void)? { get set }
    var onDisconnect: (() -> Void)? { get set }

    func connect(_ request: MQTTConnectRequest) async throws
    func disconnect()
    func publish(_ message: MQTTPublishMessage) async throws
    func subscribe(topic: String) async throws
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
    private(set) var published: [MQTTPublishMessage] = []
    private(set) var subscribedTopics: [String] = []
    var onMessage: ((MQTTPublishMessage) -> Void)?
    var onDisconnect: (() -> Void)?

    func resetPublished() {
        published.removeAll()
    }

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
        let wasConnected = isConnected
        isConnected = false
        if wasConnected {
            onDisconnect?()
        }
    }

    func publish(_ message: MQTTPublishMessage) async throws {
        guard isConnected else { throw MQTTTransportError.disconnected }
        published.append(message)
    }

    func subscribe(topic: String) async throws {
        guard isConnected else { throw MQTTTransportError.disconnected }
        subscribedTopics.append(topic)
    }

    /// Test seam: deliver a broker PUBLISH to the client callback.
    func deliver(_ message: MQTTPublishMessage) {
        guard isConnected else { return }
        onMessage?(message)
    }
}

/// Real MQTT 3.1.1 session over Network.framework (CONNECT + PUBLISH + SUBSCRIBE + receive).
@MainActor
final class MQTTNetworkTransport: MQTTTransporting {
    private let timeout: TimeInterval
    private let keepAliveSeconds: UInt16
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private(set) var isConnected = false
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var nextPacketID: UInt16 = 1
    private var pendingSuback: CheckedContinuation<Void, Error>?
    var onMessage: ((MQTTPublishMessage) -> Void)?
    var onDisconnect: (() -> Void)?

    init(timeout: TimeInterval = 8, keepAliveSeconds: UInt16 = 60) {
        self.timeout = timeout
        self.keepAliveSeconds = keepAliveSeconds
    }

    func connect(_ request: MQTTConnectRequest) async throws {
        disconnect(notify: false)
        let host = request.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, (1...65535).contains(request.port) else {
            throw MQTTTransportError.invalidConfiguration
        }

        let nw = NWProbe.makeConnection(host: host, port: request.port, useTLS: request.useTLS)
        connection = nw
        try await waitReady(nw)

        let packet = MQTTPackets.connect(
            clientID: request.clientID,
            username: request.username,
            password: request.password,
            keepAliveSeconds: keepAliveSeconds,
            willTopic: request.willTopic,
            willMessage: request.willMessage,
            willRetain: true
        )
        try await send(packet, on: nw)
        let code = try await waitConnack(on: nw)
        guard code == 0 else {
            disconnect(notify: false)
            throw MQTTTransportError.brokerRefused(code)
        }
        isConnected = true
        startReceiveLoop(on: nw)
        startPingLoop(on: nw)
        // Process any bytes that arrived with/after CONNACK before the loop's first read.
        drainReceiveBuffer()
    }

    func disconnect() {
        disconnect(notify: true)
    }

    func publish(_ message: MQTTPublishMessage) async throws {
        guard isConnected, let connection else {
            throw MQTTTransportError.disconnected
        }
        let packet = MQTTPackets.publish(
            topic: message.topic,
            payload: message.payload,
            retain: message.retain
        )
        try await send(packet, on: connection)
    }

    func subscribe(topic: String) async throws {
        guard isConnected, let connection else {
            throw MQTTTransportError.disconnected
        }
        let packetID = nextPacketID
        nextPacketID = nextPacketID &+ 1
        if nextPacketID == 0 { nextPacketID = 1 }
        let packet = MQTTPackets.subscribe(topic: topic, packetID: packetID, qos: 0)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pendingSuback = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout) { [weak self] in
                guard let self, let pending = self.pendingSuback else { return }
                self.pendingSuback = nil
                pending.resume(throwing: MQTTTransportError.timedOut)
            }
            Task { @MainActor in
                do {
                    try await self.send(packet, on: connection)
                } catch {
                    if let pending = self.pendingSuback {
                        self.pendingSuback = nil
                        pending.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Internals

    private func disconnect(notify: Bool) {
        pingTask?.cancel()
        pingTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        if let pending = pendingSuback {
            pendingSuback = nil
            pending.resume(throwing: MQTTTransportError.disconnected)
        }
        let wasConnected = isConnected
        if let connection, wasConnected {
            connection.send(
                content: MQTTPackets.disconnect(),
                completion: .contentProcessed { _ in }
            )
        }
        connection?.cancel()
        connection = nil
        receiveBuffer.removeAll()
        isConnected = false
        if notify, wasConnected {
            onDisconnect?()
        }
    }

    private func waitReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Do not cancel the connection on success — we still need the MQTT session.
            let bridge = SessionReadyBridge(continuation: continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    bridge.resume(.success(()))
                case .failed(let error):
                    bridge.resume(.failure(MQTTTransportError.unreachable(error.localizedDescription)))
                case .cancelled:
                    bridge.resume(.failure(MQTTTransportError.disconnected))
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "com.etiennedeneuve.unchair.mqtt.session"))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                bridge.resume(.failure(MQTTTransportError.timedOut))
            }
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: MQTTTransportError.underlying(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func waitConnack(on connection: NWConnection) async throws -> UInt8 {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let code = MQTTPackets.parseConnack(from: receiveBuffer) {
                // consume 4 bytes
                if receiveBuffer.count >= 4 {
                    receiveBuffer.removeFirst(4)
                }
                return code
            }
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                    if let error {
                        continuation.resume(throwing: MQTTTransportError.underlying(error.localizedDescription))
                        return
                    }
                    if isComplete && (data == nil || data?.isEmpty == true) {
                        continuation.resume(throwing: MQTTTransportError.disconnected)
                        return
                    }
                    continuation.resume(returning: data ?? Data())
                }
            }
            receiveBuffer.append(chunk)
        }
        throw MQTTTransportError.timedOut
    }

    private func startReceiveLoop(on connection: NWConnection) {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isConnected else { return }
                do {
                    let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
                            if let error {
                                continuation.resume(throwing: MQTTTransportError.underlying(error.localizedDescription))
                                return
                            }
                            if isComplete && (data == nil || data?.isEmpty == true) {
                                continuation.resume(throwing: MQTTTransportError.disconnected)
                                return
                            }
                            continuation.resume(returning: data ?? Data())
                        }
                    }
                    await MainActor.run {
                        self.receiveBuffer.append(chunk)
                        self.drainReceiveBuffer()
                    }
                } catch {
                    await MainActor.run {
                        self.handleTransportLoss()
                    }
                    return
                }
            }
        }
    }

    private func drainReceiveBuffer() {
        var guardCounter = 0
        while guardCounter < 256, let packet = MQTTPackets.consumeInboundPacket(from: &receiveBuffer) {
            guardCounter += 1
            switch packet {
            case .publish(let topic, let payload, let retain):
                onMessage?(MQTTPublishMessage(topic: topic, payload: payload, retain: retain))
            case .suback:
                if let pending = pendingSuback {
                    pendingSuback = nil
                    pending.resume()
                }
            case .pingresp, .connack, .ignored:
                break
            }
        }
    }

    private func handleTransportLoss() {
        guard isConnected else { return }
        disconnect(notify: true)
    }

    private func startPingLoop(on connection: NWConnection) {
        let interval = TimeInterval(keepAliveSeconds) * 0.6
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, self.isConnected else { return }
                try? await self.send(MQTTPackets.pingReq(), on: connection)
            }
        }
    }
}

/// TCP(/TLS) reachability-only probe (legacy Test Connection helper).
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

    var onMessage: ((MQTTPublishMessage) -> Void)?
    var onDisconnect: (() -> Void)?

    func disconnect() {
        isConnected = false
    }

    func publish(_ message: MQTTPublishMessage) async throws {
        throw MQTTTransportError.disconnected
    }

    func subscribe(topic: String) async throws {
        throw MQTTTransportError.disconnected
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

private final class SessionReadyBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Void, Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        guard let cont else { return }
        cont.resume(with: result)
    }
}
