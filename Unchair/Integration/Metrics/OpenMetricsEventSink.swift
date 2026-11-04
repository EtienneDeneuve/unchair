import Foundation

/// Increments counters from domain events. Never touches camera / PII.
final class OpenMetricsEventSink: DomainEventSink {
    private let registry: OpenMetricsRegistry

    init(registry: OpenMetricsRegistry) {
        self.registry = registry
    }

    func receive(_ event: DomainEvent) {
        switch event.name {
        case .breakCompleted:
            registry.increment(.breaksCompletedTotal)
            if case let .breakCompleted(stoodForSeconds, _, _) = event.payload,
               let stood = stoodForSeconds, stood > 0
            {
                registry.increment(.movementSecondsTotal, by: stood)
            }
        case .breakSkipped:
            registry.increment(.breaksSkippedTotal)
        case .breakPostponed:
            registry.increment(.breaksPostponedTotal)
        case .breakScheduled, .breakDue, .breakDeferredForPresentation,
             .breakStarted, .presentationEnabled, .presentationDisabled:
            break
        }
    }
}
