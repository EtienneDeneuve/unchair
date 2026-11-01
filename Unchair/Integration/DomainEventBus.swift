import Foundation

/// Receives derived domain events. Adapters implement this; BreakEngine does not.
protocol DomainEventSink: AnyObject {
    func receive(_ event: DomainEvent)
}

/// Fan-out bus. Disabling all sinks leaves core behavior unchanged.
final class DomainEventBus: DomainEventPublishing {
    private var sinks: [ObjectIdentifier: any DomainEventSink] = [:]

    func addSink(_ sink: any DomainEventSink) {
        sinks[ObjectIdentifier(sink)] = sink
    }

    func removeSink(_ sink: any DomainEventSink) {
        sinks.removeValue(forKey: ObjectIdentifier(sink))
    }

    var sinkCount: Int { sinks.count }

    func publish(_ event: DomainEvent) {
        for sink in sinks.values {
            sink.receive(event)
        }
    }
}

/// Test / diagnostics sink that records events in order.
final class RecordingDomainEventSink: DomainEventSink {
    private(set) var events: [DomainEvent] = []

    func receive(_ event: DomainEvent) {
        events.append(event)
    }

    func reset() {
        events.removeAll()
    }

    func names() -> [DomainEventName] {
        events.map(\.name)
    }
}
