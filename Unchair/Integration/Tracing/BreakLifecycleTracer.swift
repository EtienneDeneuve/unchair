import Foundation

/// Allowlisted OTel-style span attributes. Anything else is rejected in tests / encoding.
enum BreakTraceAttributeKey: String, CaseIterable, Sendable {
    case breakID = "unchair.break_id"
    case state = "unchair.state"
    case sittingSeconds = "unchair.sitting_seconds"
    case postponeUntilEpoch = "unchair.postpone_until_epoch"
    case presentationPendingSinceEpoch = "unchair.presentation_pending_since_epoch"
    case breakEndsAtEpoch = "unchair.break_ends_at_epoch"
    case stoodForSeconds = "unchair.stood_for_seconds"
    case motionScore = "unchair.motion_score"
    case failedOpen = "unchair.failed_open"
    case presentationUntilEpoch = "unchair.presentation_until_epoch"
}

struct BreakTraceSpan: Equatable, Sendable {
    var name: String
    var start: Date
    var end: Date?
    var attributes: [String: String]
}

protocol BreakTraceExporting: AnyObject {
    func export(_ span: BreakTraceSpan)
}

/// In-memory exporter for tests / local diagnostics.
final class InMemoryBreakTraceExporter: BreakTraceExporting {
    private(set) var spans: [BreakTraceSpan] = []

    func export(_ span: BreakTraceSpan) {
        spans.append(span)
    }

    func reset() { spans.removeAll() }
}

final class NoOpBreakTraceExporter: BreakTraceExporting {
    func export(_ span: BreakTraceSpan) {}
}

/// Reconstructs a break lifecycle from domain events into nested-ish sequential spans.
/// No OpenTelemetry SDK dependency — concepts only, optional exporter.
final class BreakLifecycleTracer: DomainEventSink {
    private let exporter: any BreakTraceExporting
    private var lifecycleStart: Date?
    private var lifecycleBreakID: UUID?
    private var openChild: (name: String, start: Date, attributes: [String: String])?

    init(exporter: any BreakTraceExporting = NoOpBreakTraceExporter()) {
        self.exporter = exporter
    }

    func receive(_ event: DomainEvent) {
        let attrs = Self.allowlistedAttributes(for: event)
        switch event.name {
        case .breakDue:
            closeChild(at: event.occurredAt)
            lifecycleStart = event.occurredAt
            lifecycleBreakID = event.breakID
            openChild = ("break.due", event.occurredAt, attrs)
        case .breakPostponed:
            closeChild(at: event.occurredAt)
            openChild = ("break.postponed", event.occurredAt, attrs)
        case .breakDeferredForPresentation:
            closeChild(at: event.occurredAt)
            openChild = ("presentation.deferred", event.occurredAt, attrs)
        case .breakStarted:
            closeChild(at: event.occurredAt)
            openChild = ("movement.started", event.occurredAt, attrs)
        case .breakCompleted:
            closeChild(at: event.occurredAt)
            exporter.export(
                BreakTraceSpan(
                    name: "movement.verified",
                    start: event.occurredAt,
                    end: event.occurredAt,
                    attributes: attrs
                )
            )
            finishLifecycle(at: event.occurredAt, terminal: "break.completed", attributes: attrs)
        case .breakSkipped:
            closeChild(at: event.occurredAt)
            finishLifecycle(at: event.occurredAt, terminal: "break.skipped", attributes: attrs)
        case .presentationEnabled:
            exporter.export(
                BreakTraceSpan(
                    name: "presentation.enabled",
                    start: event.occurredAt,
                    end: event.occurredAt,
                    attributes: attrs
                )
            )
        case .presentationDisabled:
            exporter.export(
                BreakTraceSpan(
                    name: "presentation.disabled",
                    start: event.occurredAt,
                    end: event.occurredAt,
                    attributes: attrs
                )
            )
        case .breakScheduled:
            break
        }
    }

    private func closeChild(at date: Date) {
        guard let child = openChild else { return }
        exporter.export(
            BreakTraceSpan(
                name: child.name,
                start: child.start,
                end: date,
                attributes: child.attributes
            )
        )
        openChild = nil
    }

    private func finishLifecycle(at date: Date, terminal: String, attributes: [String: String]) {
        exporter.export(
            BreakTraceSpan(
                name: terminal,
                start: date,
                end: date,
                attributes: attributes
            )
        )
        if let start = lifecycleStart {
            var rootAttrs = attributes
            if let id = lifecycleBreakID {
                rootAttrs[BreakTraceAttributeKey.breakID.rawValue] = id.uuidString
            }
            exporter.export(
                BreakTraceSpan(
                    name: "break.lifecycle",
                    start: start,
                    end: date,
                    attributes: rootAttrs
                )
            )
        }
        lifecycleStart = nil
        lifecycleBreakID = nil
    }

    static func allowlistedAttributes(for event: DomainEvent) -> [String: String] {
        var out: [String: String] = [
            BreakTraceAttributeKey.state.rawValue: event.name.rawValue,
        ]
        if let id = event.breakID {
            out[BreakTraceAttributeKey.breakID.rawValue] = id.uuidString
        }
        switch event.payload {
        case let .breakDue(sittingSeconds):
            if let sittingSeconds {
                out[BreakTraceAttributeKey.sittingSeconds.rawValue] = String(sittingSeconds)
            }
        case let .breakPostponed(until):
            out[BreakTraceAttributeKey.postponeUntilEpoch.rawValue] = String(until.timeIntervalSince1970)
        case let .breakDeferredForPresentation(pendingSince):
            out[BreakTraceAttributeKey.presentationPendingSinceEpoch.rawValue] =
                String(pendingSince.timeIntervalSince1970)
        case let .breakStarted(endsAt):
            out[BreakTraceAttributeKey.breakEndsAtEpoch.rawValue] = String(endsAt.timeIntervalSince1970)
        case let .breakCompleted(stoodForSeconds, motionScore, failedOpen):
            if let stoodForSeconds {
                out[BreakTraceAttributeKey.stoodForSeconds.rawValue] = String(stoodForSeconds)
            }
            if let motionScore {
                out[BreakTraceAttributeKey.motionScore.rawValue] = String(motionScore)
            }
            out[BreakTraceAttributeKey.failedOpen.rawValue] = failedOpen ? "true" : "false"
        case let .presentationEnabled(until):
            if let until {
                out[BreakTraceAttributeKey.presentationUntilEpoch.rawValue] =
                    String(until.timeIntervalSince1970)
            }
        case .breakScheduled, .breakSkipped, .presentationDisabled:
            break
        }
        // Drop anything not on the allowlist (defense in depth).
        let allowed = Set(BreakTraceAttributeKey.allCases.map(\.rawValue))
        return out.filter { allowed.contains($0.key) }
    }
}
