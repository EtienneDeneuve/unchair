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

struct ControlCLIParseError: Error, Equatable, CustomStringConvertible {
    var message: String
    var description: String { message }
}

enum ControlCLIParser {
    /// Pure parser for `unchair …` argv (without the process name).
    static func parse(_ args: [String]) -> Result<ControlRequest, ControlCLIParseError> {
        guard let head = args.first else {
            return .failure(ControlCLIParseError(message: usage))
        }
        switch head {
        case "status":
            return .success(ControlRequest(command: .status, minutes: nil))
        case "debt":
            return .success(ControlRequest(command: .debt, minutes: nil))
        case "doctor":
            return .success(ControlRequest(command: .doctor, minutes: nil))
        case "history":
            guard args.count >= 2, args[1] == "today" else {
                return .failure(ControlCLIParseError(message: "usage: unchair history today"))
            }
            return .success(ControlRequest(command: .historyToday, minutes: nil))
        case "break":
            guard args.count >= 2, args[1] == "start" else {
                return .failure(ControlCLIParseError(message: "usage: unchair break start"))
            }
            return .success(ControlRequest(command: .breakStart, minutes: nil))
        case "postpone":
            guard args.count >= 2, let minutes = parseDurationMinutes(args[1]) else {
                return .failure(ControlCLIParseError(message: "usage: unchair postpone <Nm|Nh>  (example: 15m)"))
            }
            return .success(ControlRequest(command: .postpone, minutes: minutes))
        case "presentation":
            guard args.count >= 2 else {
                return .failure(ControlCLIParseError(message: "usage: unchair presentation <Nm|Nh|off>"))
            }
            if args[1] == "off" {
                return .success(ControlRequest(command: .presentationOff, minutes: nil))
            }
            guard let minutes = parseDurationMinutes(args[1]) else {
                return .failure(ControlCLIParseError(message: "usage: unchair presentation <Nm|Nh|off>"))
            }
            return .success(ControlRequest(command: .presentationOn, minutes: minutes))
        case "help", "-h", "--help":
            return .failure(ControlCLIParseError(message: usage))
        default:
            return .failure(ControlCLIParseError(message: "unknown command \(head)\n\(usage)"))
        }
    }

    static let usage = """
    usage:
      unchair status
      unchair debt
      unchair break start
      unchair postpone 15m
      unchair presentation 1h
      unchair presentation off
      unchair history today
      unchair doctor
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
