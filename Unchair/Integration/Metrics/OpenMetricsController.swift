import Foundation

/// Owns registry, event sink, and optional HTTP server. Adapter failure must not affect BreakEngine.
@MainActor
final class OpenMetricsController {
    let registry = OpenMetricsRegistry()
    private let eventSink: OpenMetricsEventSink
    private let server: OpenMetricsHTTPServer
    private(set) var configuration: OpenMetricsConfiguration

    init(configuration: OpenMetricsConfiguration = .load()) {
        self.configuration = configuration.sanitized
        self.eventSink = OpenMetricsEventSink(registry: registry)
        self.server = OpenMetricsHTTPServer(registry: registry)
    }

    var eventSinkAsDomainSink: any DomainEventSink { eventSink }

    var statusText: String {
        guard configuration.isEnabled else { return "Off" }
        if server.isRunning {
            let host = configuration.allowLANExposure ? "*" : "127.0.0.1"
            return "Listening \(host):\(configuration.port)/metrics"
        }
        if let err = server.lastErrorDescription {
            return "Error: \(err)"
        }
        return "Starting…"
    }

    func startIfEnabled() {
        server.start(configuration: configuration)
    }

    func updateConfiguration(_ configuration: OpenMetricsConfiguration) {
        self.configuration = configuration.sanitized
        self.configuration.save()
        server.start(configuration: self.configuration)
    }

    /// Refresh gauges from live domain snapshot. Safe to call from the menu-bar ticker.
    func refreshGauges(
        debtSeconds: TimeInterval,
        sittingSeconds: TimeInterval,
        presentationEnabled: Bool,
        todayCompleted: Int,
        todaySkipped: Int
    ) {
        registry.setGauge(.movementDebtSeconds, value: max(0, debtSeconds))
        registry.setGauge(.currentSittingSeconds, value: max(0, sittingSeconds))
        registry.setGauge(.presentationMode, value: presentationEnabled ? 1 : 0)
        let denom = todayCompleted + todaySkipped
        let ratio: Double
        if denom == 0 {
            ratio = 1
        } else {
            ratio = Double(todayCompleted) / Double(denom)
        }
        registry.setGauge(.sittingSLORatio, value: ratio)
    }

    func stop() {
        server.stop()
    }
}
