import Foundation

/// In-process counters + gauges. No label cardinality — privacy allowlist only.
final class OpenMetricsRegistry: @unchecked Sendable {
    /// Canonical metric names (contract / tests).
    enum Name: String, CaseIterable {
        case breaksCompletedTotal = "unchair_breaks_completed_total"
        case breaksSkippedTotal = "unchair_breaks_skipped_total"
        case breaksPostponedTotal = "unchair_breaks_postponed_total"
        case movementSecondsTotal = "unchair_movement_seconds_total"
        case movementDebtSeconds = "unchair_movement_debt_seconds"
        case currentSittingSeconds = "unchair_current_sitting_seconds"
        case sittingSLORatio = "unchair_sitting_slo_ratio"
        case presentationMode = "unchair_presentation_mode"
    }

    private let lock = NSLock()
    private var counters: [Name: Double] = [
        .breaksCompletedTotal: 0,
        .breaksSkippedTotal: 0,
        .breaksPostponedTotal: 0,
        .movementSecondsTotal: 0,
    ]
    private var gauges: [Name: Double] = [
        .movementDebtSeconds: 0,
        .currentSittingSeconds: 0,
        .sittingSLORatio: 1,
        .presentationMode: 0,
    ]

    func increment(_ name: Name, by amount: Double = 1) {
        guard amount >= 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        counters[name, default: 0] += amount
    }

    func setGauge(_ name: Name, value: Double) {
        lock.lock()
        defer { lock.unlock() }
        gauges[name] = value
    }

    func counterValue(_ name: Name) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return counters[name] ?? 0
    }

    func gaugeValue(_ name: Name) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return gauges[name] ?? 0
    }

    func snapshot() -> OpenMetricsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return OpenMetricsSnapshot(counters: counters, gauges: gauges)
    }
}

struct OpenMetricsSnapshot: Equatable, Sendable {
    var counters: [OpenMetricsRegistry.Name: Double]
    var gauges: [OpenMetricsRegistry.Name: Double]
}

enum OpenMetricsTextEncoder {
    static let contentType = "application/openmetrics-text; version=1.0.0; charset=utf-8"

    static func encode(_ snapshot: OpenMetricsSnapshot) -> String {
        var lines: [String] = []

        func help(_ name: OpenMetricsRegistry.Name, _ text: String, type: String) {
            lines.append("# HELP \(name.rawValue) \(text)")
            lines.append("# TYPE \(name.rawValue) \(type)")
        }

        help(.breaksCompletedTotal, "Completed movement breaks (process lifetime).", type: "counter")
        lines.append("\(OpenMetricsRegistry.Name.breaksCompletedTotal.rawValue) \(format(snapshot.counters[.breaksCompletedTotal] ?? 0))")

        help(.breaksSkippedTotal, "Skipped owed breaks (process lifetime).", type: "counter")
        lines.append("\(OpenMetricsRegistry.Name.breaksSkippedTotal.rawValue) \(format(snapshot.counters[.breaksSkippedTotal] ?? 0))")

        help(.breaksPostponedTotal, "Postponed owed breaks (process lifetime).", type: "counter")
        lines.append("\(OpenMetricsRegistry.Name.breaksPostponedTotal.rawValue) \(format(snapshot.counters[.breaksPostponedTotal] ?? 0))")

        help(.movementSecondsTotal, "Verified standing/movement seconds from completed breaks.", type: "counter")
        lines.append("\(OpenMetricsRegistry.Name.movementSecondsTotal.rawValue) \(format(snapshot.counters[.movementSecondsTotal] ?? 0))")

        help(.movementDebtSeconds, "Current movement debt in seconds.", type: "gauge")
        lines.append("\(OpenMetricsRegistry.Name.movementDebtSeconds.rawValue) \(format(snapshot.gauges[.movementDebtSeconds] ?? 0))")

        help(.currentSittingSeconds, "Current freeze-aware sitting stretch in seconds.", type: "gauge")
        lines.append("\(OpenMetricsRegistry.Name.currentSittingSeconds.rawValue) \(format(snapshot.gauges[.currentSittingSeconds] ?? 0))")

        help(
            .sittingSLORatio,
            "Today break completion ratio completed/(completed+skipped); 1 when no outcomes yet.",
            type: "gauge"
        )
        lines.append("\(OpenMetricsRegistry.Name.sittingSLORatio.rawValue) \(format(snapshot.gauges[.sittingSLORatio] ?? 1))")

        help(.presentationMode, "1 when Presentation Mode is on, else 0.", type: "gauge")
        lines.append("\(OpenMetricsRegistry.Name.presentationMode.rawValue) \(format(snapshot.gauges[.presentationMode] ?? 0))")

        lines.append("# EOF")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value, value >= 0, value < Double(Int64.max) {
            return String(Int64(value))
        }
        return String(format: "%.6g", value)
    }
}
