import Foundation
import OSLog

/// Executes allowlisted MQTT commands through the same domain entry points as the UI.
@MainActor
protocol MQTTCommandPerforming: AnyObject {
    func performMQTTCommand(_ command: MQTTAcceptedCommand)
}

/// Parses inbound command payloads, dedupes by `id`, and dispatches to the performer.
/// Invalid / stale / unknown commands are ignored and logged without payload dumps.
@MainActor
final class MQTTCommandRouter {
    private let log = Logger(subsystem: "com.etiennedeneuve.unchair", category: "MQTTCommand")
    private let maxRecentIDs: Int
    private var recentIDs: [String] = []
    private(set) var lastRejection: MQTTCommandRejection?
    private(set) var acceptedCount = 0
    private(set) var ignoredDuplicateCount = 0
    private(set) var rejectedCount = 0

    weak var performer: (any MQTTCommandPerforming)?

    init(maxRecentIDs: Int = 64) {
        self.maxRecentIDs = max(1, maxRecentIDs)
    }

    func handle(payload: Data) {
        switch MQTTCommandParser.parse(payload) {
        case .accepted(let command, let id):
            if let id, recentIDs.contains(id) {
                ignoredDuplicateCount += 1
                log.info("mqtt_command_duplicate")
                return
            }
            if let id {
                remember(id)
            }
            lastRejection = nil
            acceptedCount += 1
            log.info("mqtt_command_accepted name=\(String(describing: command), privacy: .public)")
            performer?.performMQTTCommand(command)
        case .rejected(let reason):
            lastRejection = reason
            rejectedCount += 1
            log.info("mqtt_command_rejected reason=\(String(describing: reason), privacy: .public)")
        }
    }

    private func remember(_ id: String) {
        recentIDs.append(id)
        if recentIDs.count > maxRecentIDs {
            recentIDs.removeFirst(recentIDs.count - maxRecentIDs)
        }
    }
}
