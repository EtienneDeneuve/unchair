import Foundation

/// Stable integration event names. Adapters map these — they do not redefine them.
enum DomainEventName: String, Codable, Sendable, CaseIterable {
    case breakScheduled = "break.scheduled"
    case breakDue = "break.due"
    case breakPostponed = "break.postponed"
    case breakDeferredForPresentation = "break.deferredForPresentation"
    case breakStarted = "break.started"
    case breakCompleted = "break.completed"
    case breakSkipped = "break.skipped"
    case presentationEnabled = "presentation.enabled"
    case presentationDisabled = "presentation.disabled"
}

/// Typed payloads for integration events.
///
/// Privacy invariant: never include camera frames, Vision landmarks,
/// app/meeting process names, or other raw sensor streams.
enum DomainEventPayload: Equatable, Sendable, Codable {
    case breakScheduled(until: Date)
    case breakDue(sittingSeconds: TimeInterval?)
    case breakPostponed(until: Date)
    case breakDeferredForPresentation(pendingSince: Date)
    case breakStarted(endsAt: Date)
    case breakCompleted(
        stoodForSeconds: TimeInterval?,
        motionScore: Double?,
        failedOpen: Bool
    )
    case breakSkipped
    case presentationEnabled(until: Date?)
    case presentationDisabled
}

/// Derived domain event consumed by History, UI, and optional integration adapters.
struct DomainEvent: Equatable, Sendable, Codable {
    var name: DomainEventName
    var occurredAt: Date
    var breakID: UUID?
    var payload: DomainEventPayload

    /// Contract version for adapters (bump when payloads change incompatibly).
    static let schemaVersion = 1
}

/// Optional publisher injected into BreakEngine. Adapters hang off the bus — not the machine.
protocol DomainEventPublishing: AnyObject {
    func publish(_ event: DomainEvent)
}
