import Foundation

/// Retained state snapshot — matches `docs/mqtt-contract.md`.
struct MQTTStatePayload: Equatable, Codable, Sendable {
    var contractVersion: Int
    var deviceId: String
    var updatedAt: String
    var phase: String
    var breakDue: Bool
    var presentationMode: Bool
    var hasMovementDebt: Bool
    var movementDebtSeconds: Int
    var sittingSeconds: Int
    var nextBreakAt: String?
    /// Latest domain event name (additive; for HA `last_break_event` sensor).
    var lastEventName: String?
    var today: MQTTTodayPayload

    struct MQTTTodayPayload: Equatable, Codable, Sendable {
        var completed: Int
        var skipped: Int
        var postponed: Int
        var movementMinutes: Int
        var longestSittingSeconds: Int
        var currentSittingSeconds: Int
    }
}

/// Non-retained domain event wire format.
struct MQTTEventPayload: Equatable, Codable, Sendable {
    var contractVersion: Int
    var deviceId: String
    var name: String
    var occurredAt: String
    var breakId: String?
    var payload: [String: MQTTJSONValue]
}

/// Minimal JSON value for event payloads without leaking arbitrary objects.
enum MQTTJSONValue: Equatable, Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}

enum MQTTISO8601 {
    static func string(from date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateTimeSeparator(.standard).time(includingFractionalSeconds: false))
    }
}

enum MQTTPayloadBuilder {
    static let contractVersion = 1

    static func phaseString(_ phase: BreakPhase) -> String {
        switch phase {
        case .idle: return "idle"
        case .working: return "working"
        case .breakDue: return "breakDue"
        case .onBreak: return "onBreak"
        case .postponed: return "postponed"
        case .deferredForPresentation: return "deferredForPresentation"
        case .paused: return "paused"
        }
    }

    static func state(
        deviceId: String,
        snapshot: BreakSnapshot,
        today: TodayStats,
        presentationMode: Bool,
        lastEventName: String?,
        now: Date
    ) -> MQTTStatePayload {
        let sitting = Int(snapshot.sittingDuration?.seconds.rounded() ?? 0)
        let debt = Int(snapshot.movementDebt.currentDuration.seconds.rounded())
        let nextBreakAt: String? = {
            switch snapshot.phase {
            case .working(let until), .postponed(let until):
                return MQTTISO8601.string(from: until)
            default:
                return nil
            }
        }()

        return MQTTStatePayload(
            contractVersion: contractVersion,
            deviceId: deviceId,
            updatedAt: MQTTISO8601.string(from: now),
            phase: phaseString(snapshot.phase),
            breakDue: {
                if case .breakDue = snapshot.phase { return true }
                return false
            }(),
            presentationMode: presentationMode,
            hasMovementDebt: snapshot.hasMovementDebt,
            movementDebtSeconds: debt,
            sittingSeconds: sitting,
            nextBreakAt: nextBreakAt,
            lastEventName: lastEventName,
            today: .init(
                completed: today.completedCount,
                skipped: today.skippedCount,
                postponed: today.postponedCount,
                movementMinutes: today.movementMinutesRounded,
                longestSittingSeconds: Int(today.longestDeskSeconds.rounded()),
                currentSittingSeconds: sitting
            )
        )
    }

    static func event(deviceId: String, domain: DomainEvent) -> MQTTEventPayload {
        MQTTEventPayload(
            contractVersion: contractVersion,
            deviceId: deviceId,
            name: domain.name.rawValue,
            occurredAt: MQTTISO8601.string(from: domain.occurredAt),
            breakId: domain.breakID?.uuidString,
            payload: payloadDictionary(domain.payload)
        )
    }

    private static func payloadDictionary(_ payload: DomainEventPayload) -> [String: MQTTJSONValue] {
        switch payload {
        case .breakScheduled(let until):
            return ["until": .string(MQTTISO8601.string(from: until))]
        case .breakDue(let sitting):
            if let sitting {
                return ["sittingSeconds": .number(sitting)]
            }
            return [:]
        case .breakPostponed(let until):
            return ["until": .string(MQTTISO8601.string(from: until))]
        case .breakDeferredForPresentation(let pendingSince):
            return ["pendingSince": .string(MQTTISO8601.string(from: pendingSince))]
        case .breakStarted(let endsAt):
            return ["endsAt": .string(MQTTISO8601.string(from: endsAt))]
        case .breakCompleted(let stood, let motion, let failedOpen):
            var dict: [String: MQTTJSONValue] = ["failedOpen": .bool(failedOpen)]
            if let stood { dict["stoodForSeconds"] = .number(stood) }
            if let motion { dict["motionScore"] = .number(motion) }
            return dict
        case .breakSkipped:
            return [:]
        case .presentationEnabled(let until):
            if let until {
                return ["until": .string(MQTTISO8601.string(from: until))]
            }
            return [:]
        case .presentationDisabled:
            return [:]
        }
    }

    static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
