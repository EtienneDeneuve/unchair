import Foundation
import Network

/// Minimal `GET /metrics` server. Failures are swallowed — BreakEngine must not care.
final class OpenMetricsHTTPServer: @unchecked Sendable {
    private let registry: OpenMetricsRegistry
    private let lock = NSLock()
    private var listener: NWListener?
    private(set) var isRunning = false
    private(set) var lastErrorDescription: String?

    init(registry: OpenMetricsRegistry) {
        self.registry = registry
    }

    func start(configuration: OpenMetricsConfiguration) {
        stop()
        guard configuration.isEnabled else { return }
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            lock.lock()
            lastErrorDescription = "Invalid port \(configuration.port)"
            lock.unlock()
            return
        }

        do {
            let params = NWParameters.tcp
            if !configuration.allowLANExposure {
                params.requiredLocalEndpoint = NWEndpoint.hostPort(
                    host: NWEndpoint.Host("127.0.0.1"),
                    port: port
                )
            }
            let listener = try NWListener(using: params, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                self.lock.lock()
                defer { self.lock.unlock() }
                switch state {
                case .ready:
                    self.isRunning = true
                    self.lastErrorDescription = nil
                case let .failed(error):
                    self.isRunning = false
                    self.lastErrorDescription = String(describing: error)
                case .cancelled:
                    self.isRunning = false
                default:
                    break
                }
            }
            self.listener = listener
            listener.start(queue: .global(qos: .utility))
        } catch {
            lock.lock()
            isRunning = false
            lastErrorDescription = error.localizedDescription
            lock.unlock()
        }
    }

    func stop() {
        lock.lock()
        listener?.cancel()
        listener = nil
        isRunning = false
        lock.unlock()
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }
            if error != nil {
                connection.cancel()
                return
            }
            let request = String(data: data ?? Data(), encoding: .utf8) ?? ""
            let response: Data
            if Self.isMetricsGET(request) {
                let body = OpenMetricsTextEncoder.encode(self.registry.snapshot())
                response = Self.httpResponse(
                    status: "200 OK",
                    contentType: OpenMetricsTextEncoder.contentType,
                    body: body
                )
            } else {
                response = Self.httpResponse(
                    status: "404 Not Found",
                    contentType: "text/plain; charset=utf-8",
                    body: "not found\n"
                )
            }
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private static func isMetricsGET(_ request: String) -> Bool {
        let first = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? request
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return false }
        let method = parts[0].uppercased()
        let path = String(parts[1]).split(separator: "?").first.map(String.init) ?? String(parts[1])
        return method == "GET" && (path == "/metrics" || path == "/")
    }

    private static func httpResponse(status: String, contentType: String, body: String) -> Data {
        let payload = body.data(using: .utf8) ?? Data()
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(payload.count)\r
        Connection: close\r
        \r

        """
        var data = Data(header.utf8)
        data.append(payload)
        return data
    }
}
