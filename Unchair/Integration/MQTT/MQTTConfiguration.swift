import Foundation

/// Non-secret MQTT settings. Passwords live in Keychain only (issue #16).
struct MQTTConfiguration: Equatable, Codable, Sendable {
    var isEnabled: Bool
    var host: String
    var port: Int
    var useTLS: Bool
    var username: String
    var homeAssistantDiscoveryEnabled: Bool

    static let `default` = MQTTConfiguration(
        isEnabled: false,
        host: "",
        port: 8883,
        useTLS: true,
        username: "",
        homeAssistantDiscoveryEnabled: true
    )

    var isConfiguredForConnect: Bool {
        isEnabled && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...65535).contains(port)
    }
}

enum MQTTConfigurationValidator {
    enum Issue: Equatable, Sendable {
        case disabled
        case emptyHost
        case invalidPort
    }

    static func validate(_ config: MQTTConfiguration) -> [Issue] {
        var issues: [Issue] = []
        if !config.isEnabled {
            issues.append(.disabled)
        }
        if config.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyHost)
        }
        if !(1...65535).contains(config.port) {
            issues.append(.invalidPort)
        }
        return issues
    }

    static func canAttemptConnection(_ config: MQTTConfiguration) -> Bool {
        validate(config).filter { $0 != .disabled }.isEmpty && config.isEnabled
    }
}

protocol MQTTConfigurationStoring: AnyObject {
    func load() -> MQTTConfiguration
    func save(_ configuration: MQTTConfiguration)
}

final class UserDefaultsMQTTConfigurationStore: MQTTConfigurationStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "unchair.mqtt.configuration.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> MQTTConfiguration {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(MQTTConfiguration.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    func save(_ configuration: MQTTConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: key)
    }
}

final class InMemoryMQTTConfigurationStore: MQTTConfigurationStoring {
    private var configuration: MQTTConfiguration

    init(configuration: MQTTConfiguration = .default) {
        self.configuration = configuration
    }

    func load() -> MQTTConfiguration { configuration }
    func save(_ configuration: MQTTConfiguration) { self.configuration = configuration }
}
