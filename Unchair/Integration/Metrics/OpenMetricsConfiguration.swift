import Foundation

/// Opt-in OpenMetrics HTTP exporter. Disabled by default; localhost bind only unless LAN is explicitly allowed.
struct OpenMetricsConfiguration: Equatable, Sendable, Codable {
    var isEnabled: Bool
    /// TCP port for `GET /metrics`.
    var port: UInt16
    /// When false (default), bind `127.0.0.1` only. When true, bind `0.0.0.0` (LAN exposure — document threat model).
    var allowLANExposure: Bool

    static let `default` = OpenMetricsConfiguration(
        isEnabled: false,
        port: 9108,
        allowLANExposure: false
    )

    static let userDefaultsKey = "unchair.openMetrics.configuration.v1"

    static func load(defaults: UserDefaults = .standard) -> OpenMetricsConfiguration {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(OpenMetricsConfiguration.self, from: data)
        else {
            return .default
        }
        return decoded.sanitized
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(sanitized) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    var sanitized: OpenMetricsConfiguration {
        var copy = self
        if copy.port == 0 { copy.port = Self.default.port }
        return copy
    }

    var bindHost: String {
        allowLANExposure ? "0.0.0.0" : "127.0.0.1"
    }
}
