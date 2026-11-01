import Foundation

/// Allowlisted Home Assistant / MQTT commands (contract v1, issue #18).
enum MQTTCommandName: String, Sendable, CaseIterable {
    case startBreak = "start_break"
    case postpone = "postpone"
    case skip = "skip"
    case presentationOn = "presentation_on"
    case presentationOff = "presentation_off"
}

/// Validated command ready for domain execution.
enum MQTTAcceptedCommand: Equatable, Sendable {
    case startBreak
    case postpone(minutes: Int)
    case skip
    /// `minutes == nil` means until manually disabled.
    case presentationOn(minutes: Int?)
    case presentationOff
}

enum MQTTCommandRejection: Equatable, Sendable {
    case invalidJSON
    case unsupportedContractVersion(Int)
    case missingCommand
    case unknownCommand(String)
    case missingMinutes
    case invalidMinutes(Int)
    case forbidden(String)
}

enum MQTTCommandParseResult: Equatable, Sendable {
    case accepted(MQTTAcceptedCommand, id: String?)
    case rejected(MQTTCommandRejection)
}

enum MQTTCommandParser {
    static let supportedContractVersion = 1
    static let postponeMinutesAllowlist: Set<Int> = [15, 30, 45, 60]
    static let presentationMinutesAllowlist: Set<Int> = [30, 45, 60]

    /// Explicit denylist — must never be executable over MQTT.
    static let forbiddenCommands: Set<String> = [
        "complete",
        "complete_break",
        "break.complete",
        "mark_completed",
        "verify_movement",
        "fake_movement",
        "camera_on",
        "camera_off",
    ]

    static func parse(_ data: Data) -> MQTTCommandParseResult {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dict = object as? [String: Any]
        else {
            return .rejected(.invalidJSON)
        }

        let version = (dict["contractVersion"] as? Int)
            ?? (dict["contractVersion"] as? NSNumber)?.intValue
            ?? -1
        guard version == supportedContractVersion else {
            return .rejected(.unsupportedContractVersion(version))
        }

        guard let rawCommand = dict["command"] as? String else {
            return .rejected(.missingCommand)
        }
        let normalized = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if forbiddenCommands.contains(normalized) {
            return .rejected(.forbidden(normalized))
        }
        guard let name = MQTTCommandName(rawValue: normalized) else {
            return .rejected(.unknownCommand(normalized))
        }

        let id = (dict["id"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let commandID = (id?.isEmpty == false) ? id : nil

        let minutes = intValue(dict["minutes"])

        switch name {
        case .startBreak:
            return .accepted(.startBreak, id: commandID)
        case .skip:
            return .accepted(.skip, id: commandID)
        case .presentationOff:
            return .accepted(.presentationOff, id: commandID)
        case .postpone:
            guard let minutes else {
                return .rejected(.missingMinutes)
            }
            guard postponeMinutesAllowlist.contains(minutes) else {
                return .rejected(.invalidMinutes(minutes))
            }
            return .accepted(.postpone(minutes: minutes), id: commandID)
        case .presentationOn:
            if let minutes {
                guard presentationMinutesAllowlist.contains(minutes) else {
                    return .rejected(.invalidMinutes(minutes))
                }
                return .accepted(.presentationOn(minutes: minutes), id: commandID)
            }
            return .accepted(.presentationOn(minutes: nil), id: commandID)
        }
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        return nil
    }
}
