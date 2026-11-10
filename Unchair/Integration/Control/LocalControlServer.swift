import Foundation

/// Local-only Unix domain control socket (`~/Library/Application Support/Unchair/control.sock`).
/// Owner-only (`0600`). No remote bind. Secrets never appear in responses.
///
/// Accept/read/write run off the main actor; routing hops to `@MainActor` for `MenuBarShell`.
final class LocalControlServer: @unchecked Sendable {
    private weak var shell: MenuBarShell?
    private let stateLock = NSLock()
    private var acceptSource: DispatchSourceRead?
    private var serverFD: Int32 = -1
    private(set) var isRunning = false

    @MainActor
    func start(shell: MenuBarShell) {
        stateLock.lock()
        self.shell = shell
        stateLock.unlock()
        stop()

        let dir = ControlSocket.applicationSupportDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = ControlSocket.path
        try? FileManager.default.removeItem(atPath: path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            return
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { dest in
            pathBytes.withUnsafeBytes { src in
                dest.copyMemory(from: src)
            }
        }

        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound: Bool = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(fd, sockPtr, len) == 0
            }
        }
        guard bound else {
            close(fd)
            return
        }
        guard listen(fd, 4) == 0 else {
            close(fd)
            return
        }
        chmod(path, 0o600)

        serverFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue.global(qos: .userInitiated))
        source.setEventHandler { [weak self] in
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                defer { close(client) }
                var buffer = [UInt8](repeating: 0, count: 8_192)
                let n = read(client, &buffer, buffer.count)
                guard n > 0, let self else { return }
                let requestData = Data(buffer.prefix(n))
                let response = self.handleBlocking(requestData)
                response.withUnsafeBytes { raw in
                    _ = write(client, raw.baseAddress, response.count)
                }
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        acceptSource = source
        source.resume()
        isRunning = true
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        isRunning = false
        try? FileManager.default.removeItem(atPath: ControlSocket.path)
    }


    private func handleBlocking(_ data: Data) -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var data = Data() }
        let box = Box()
        Task { @MainActor in
            let response = self.routeOnMain(data)
            var encoded = (try? JSONEncoder().encode(response))
                ?? Data("{\"ok\":false,\"text\":\"\",\"error\":\"encode\"}".utf8)
            encoded.append(0x0A)
            box.data = encoded
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        return box.data
    }

    nonisolated static func firstLine(in data: Data) -> Data {
        guard let newlineIndex = data.firstIndex(of: 0x0A) else {
            return data
        }
        return Data(data[..<newlineIndex])
    }

    @MainActor
    private func routeOnMain(_ data: Data) -> ControlResponse {
        let line = Self.firstLine(in: data)
        guard let request = try? JSONDecoder().decode(ControlRequest.self, from: line) else {
            return .failure("invalid request JSON")
        }
        stateLock.lock()
        let shell = self.shell
        stateLock.unlock()
        guard let shell else {
            return .failure("Unchair is not ready")
        }
        return shell.handleControlRequest(request)
    }
}
