import Foundation

/// Narrow local control protocol (Unix socket JSON lines). Shared by app + CLI.
enum ControlCommandName: String, Codable, Sendable {
    case status
    case debt
    case breakStart = "break.start"
    case postpone
    case presentationOn = "presentation.on"
    case presentationOff = "presentation.off"
    case historyToday = "history.today"
    case doctor
}

struct ControlRequest: Codable, Equatable, Sendable {
    var command: ControlCommandName
    /// Postpone / presentation duration in minutes when required.
    var minutes: Int?
}

struct ControlResponse: Codable, Equatable, Sendable {
    var ok: Bool
    var text: String
    var error: String?

    static func success(_ text: String) -> ControlResponse {
        ControlResponse(ok: true, text: text, error: nil)
    }

    static func failure(_ message: String) -> ControlResponse {
        ControlResponse(ok: false, text: "", error: message)
    }
}

enum ControlSocket {
    static let fileName = "control.sock"

    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Unchair", isDirectory: true)
    }

    static var path: String {
        applicationSupportDirectory().appendingPathComponent(fileName).path
    }
}

/// Parse outcome for `unchair` argv — help is not an error.
enum ControlCLIParseResult: Equatable {
    case request(ControlRequest)
    case help(String)
    case failure(String)
}

enum ControlCLIParser {
    /// Pure parser for `unchair …` argv (without the process name).
    static func parse(_ args: [String]) -> ControlCLIParseResult {
        guard let head = args.first else {
            return .help(usage)
        }
        switch head {
        case "status":
            return .request(ControlRequest(command: .status, minutes: nil))
        case "debt":
            return .request(ControlRequest(command: .debt, minutes: nil))
        case "doctor":
            return .request(ControlRequest(command: .doctor, minutes: nil))
        case "history":
            guard args.count >= 2, args[1] == "today" else {
                return .failure("usage: unchair history today")
            }
            return .request(ControlRequest(command: .historyToday, minutes: nil))
        case "break":
            guard args.count >= 2, args[1] == "start" else {
                return .failure("usage: unchair break start")
            }
            return .request(ControlRequest(command: .breakStart, minutes: nil))
        case "postpone":
            guard args.count >= 2, let minutes = parseDurationMinutes(args[1]) else {
                return .failure("usage: unchair postpone <Nm|Nh>  (example: 15m)")
            }
            return .request(ControlRequest(command: .postpone, minutes: minutes))
        case "presentation":
            guard args.count >= 2 else {
                return .failure("usage: unchair presentation <Nm|Nh|off>")
            }
            if args[1] == "off" {
                return .request(ControlRequest(command: .presentationOff, minutes: nil))
            }
            guard let minutes = parseDurationMinutes(args[1]) else {
                return .failure("usage: unchair presentation <Nm|Nh|off>")
            }
            return .request(ControlRequest(command: .presentationOn, minutes: minutes))
        case "help", "-h", "--help":
            return .help(usage)
        default:
            return .failure("unknown command \(head)\n\n\(usage)")
        }
    }

    static let usage = """
    unchair — talk to the running Unchair menu-bar app (local Unix socket).

    Usage:
      unchair status
      unchair debt
      unchair break start
      unchair postpone <Nm|Nh>          # e.g. 15m, 1h
      unchair presentation <Nm|Nh|off>
      unchair history today
      unchair doctor
      unchair help

    The app must be running. Socket:
      ~/Library/Application Support/Unchair/control.sock
    """

    static func parseDurationMinutes(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let last = trimmed.last else { return nil }
        let numberPart = String(trimmed.dropLast())
        guard let value = Int(numberPart), value > 0 else { return nil }
        switch last {
        case "m": return value
        case "h": return value * 60
        default: return nil
        }
    }
}
