import Foundation

enum MQTTDiscovery {
    struct Entity: Equatable, Sendable {
        var component: String // sensor | binary_sensor
        var objectId: String
        var name: String
        var valueTemplate: String
        var deviceClass: String?
        var unit: String?
        var stateClass: String?
    }

    static let entities: [Entity] = [
        .init(component: "sensor", objectId: "phase", name: "Phase",
              valueTemplate: "{{ value_json.phase }}", deviceClass: nil, unit: nil, stateClass: nil),
        .init(component: "sensor", objectId: "completed_today", name: "Completed today",
              valueTemplate: "{{ value_json.today.completed }}", deviceClass: nil, unit: nil, stateClass: "total_increasing"),
        .init(component: "sensor", objectId: "skipped_today", name: "Skipped today",
              valueTemplate: "{{ value_json.today.skipped }}", deviceClass: nil, unit: nil, stateClass: "total_increasing"),
        .init(component: "sensor", objectId: "postponed_today", name: "Postponed today",
              valueTemplate: "{{ value_json.today.postponed }}", deviceClass: nil, unit: nil, stateClass: "total_increasing"),
        .init(component: "sensor", objectId: "movement_minutes_today", name: "Movement minutes today",
              valueTemplate: "{{ value_json.today.movementMinutes }}", deviceClass: nil, unit: "min", stateClass: "total_increasing"),
        .init(component: "sensor", objectId: "longest_sitting", name: "Longest sitting",
              valueTemplate: "{{ value_json.today.longestSittingSeconds }}", deviceClass: "duration", unit: "s", stateClass: "measurement"),
        .init(component: "sensor", objectId: "current_sitting", name: "Current sitting",
              valueTemplate: "{{ value_json.today.currentSittingSeconds }}", deviceClass: "duration", unit: "s", stateClass: "measurement"),
        .init(component: "sensor", objectId: "next_break", name: "Next break",
              valueTemplate: "{{ value_json.nextBreakAt }}", deviceClass: "timestamp", unit: nil, stateClass: nil),
        .init(component: "binary_sensor", objectId: "break_due", name: "Break due",
              valueTemplate: "{{ 'ON' if value_json.breakDue else 'OFF' }}", deviceClass: nil, unit: nil, stateClass: nil),
        .init(component: "binary_sensor", objectId: "presentation_mode", name: "Presentation mode",
              valueTemplate: "{{ 'ON' if value_json.presentationMode else 'OFF' }}", deviceClass: nil, unit: nil, stateClass: nil),
        .init(component: "sensor", objectId: "last_break_event", name: "Last break event",
              valueTemplate: "{{ value_json.lastEventName }}", deviceClass: nil, unit: nil, stateClass: nil),
    ]

    static func configTopic(deviceId: String, entity: Entity) -> String {
        "homeassistant/\(entity.component)/unchair_\(deviceId)_\(entity.objectId)/config"
    }

    static func configJSON(
        deviceId: String,
        entity: Entity,
        softwareVersion: String
    ) throws -> Data {
        let stateTopic = "unchair/\(deviceId)/state"
        let availabilityTopic = "unchair/\(deviceId)/availability"
        var dict: [String: Any] = [
            "name": entity.name,
            "uniq_id": "unchair_\(deviceId)_\(entity.objectId)",
            "stat_t": stateTopic,
            "val_tpl": entity.valueTemplate,
            "avty_t": availabilityTopic,
            "payload_available": "online",
            "payload_not_available": "offline",
            "dev": [
                "ids": [deviceId],
                "name": "Unchair",
                "mf": "Unchair",
                "mdl": "Mac Standalone",
                "sw": softwareVersion,
            ],
            "o": [
                "name": "Unchair",
                "sw": softwareVersion,
            ],
        ]
        if entity.component == "binary_sensor" {
            dict["payload_on"] = "ON"
            dict["payload_off"] = "OFF"
        }
        if let deviceClass = entity.deviceClass {
            dict["dev_cla"] = deviceClass
        }
        if let unit = entity.unit {
            dict["unit_of_meas"] = unit
        }
        if let stateClass = entity.stateClass {
            dict["stat_cla"] = stateClass
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }
}
