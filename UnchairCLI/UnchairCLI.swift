import Foundation

@main
enum UnchairCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        switch ControlCLIParser.parse(args) {
        case let .failure(parseError):
            fputs(parseError.message + "\n", stderr)
            exit(parseError.message.contains("usage:") ? 0 : 2)
        case let .success(request):
            do {
                let response = try send(request)
                if response.ok {
                    print(response.text)
                    exit(0)
                } else {
                    fputs((response.error ?? "error") + "\n", stderr)
                    exit(1)
                }
            } catch {
                fputs(
                    """
                    cannot reach Unchair (\(error.localizedDescription))
                    Is the menu-bar app running?
                    Socket: \(ControlSocket.path)
                    """,
                    stderr
                )
                fputs("\n", stderr)
                exit(1)
            }
        }
    }

    private static func send(_ request: ControlRequest) throws -> ControlResponse {
        let payload = try JSONEncoder().encode(request)
        var line = payload
        line.append(0x0A)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw CLIError.socket }

        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = ControlSocket.path
        let pathBytes = Array(path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw CLIError.pathTooLong
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { dest in
            pathBytes.withUnsafeBytes { src in
                dest.copyMemory(from: src)
            }
        }

        let connected: Bool = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
        guard connected else { throw CLIError.connect }

        let written = line.withUnsafeBytes { raw in
            write(fd, raw.baseAddress, line.count)
        }
        guard written == line.count else { throw CLIError.write }

        var buffer = [UInt8](repeating: 0, count: 16_384)
        let n = read(fd, &buffer, buffer.count)
        guard n > 0 else { throw CLIError.read }
        let data = Data(buffer.prefix(n)).split(separator: 0x0A, maxSplits: 1).first.map(Data.init) ?? Data(buffer.prefix(n))
        return try JSONDecoder().decode(ControlResponse.self, from: data)
    }
}

private enum CLIError: LocalizedError {
    case socket, pathTooLong, connect, write, read

    var errorDescription: String? {
        switch self {
        case .socket: return "socket()"
        case .pathTooLong: return "socket path too long"
        case .connect: return "connect failed"
        case .write: return "write failed"
        case .read: return "empty response"
        }
    }
}
