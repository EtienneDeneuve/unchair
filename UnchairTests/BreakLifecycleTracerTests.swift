import XCTest
@testable import Unchair

final class BreakLifecycleTracerTests: XCTestCase {
    func testLifecycleSpansReconstructDuePostponeComplete() {
        let exporter = InMemoryBreakTraceExporter()
        let tracer = BreakLifecycleTracer(exporter: exporter)
        let breakID = UUID()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        tracer.receive(
            DomainEvent(
                name: .breakDue,
                occurredAt: t0,
                breakID: breakID,
                payload: .breakDue(sittingSeconds: 3000)
            )
        )
        tracer.receive(
            DomainEvent(
                name: .breakPostponed,
                occurredAt: t0.addingTimeInterval(60),
                breakID: breakID,
                payload: .breakPostponed(until: t0.addingTimeInterval(960))
            )
        )
        tracer.receive(
            DomainEvent(
                name: .breakStarted,
                occurredAt: t0.addingTimeInterval(120),
                breakID: breakID,
                payload: .breakStarted(endsAt: t0.addingTimeInterval(210))
            )
        )
        tracer.receive(
            DomainEvent(
                name: .breakCompleted,
                occurredAt: t0.addingTimeInterval(210),
                breakID: breakID,
                payload: .breakCompleted(stoodForSeconds: 90, motionScore: 0.9, failedOpen: false)
            )
        )

        let names = exporter.spans.map(\.name)
        XCTAssertEqual(
            names,
            [
                "break.due",
                "break.postponed",
                "movement.started",
                "movement.verified",
                "break.completed",
                "break.lifecycle",
            ]
        )
        let lifecycle = exporter.spans.last!
        XCTAssertEqual(lifecycle.name, "break.lifecycle")
        XCTAssertEqual(lifecycle.attributes[BreakTraceAttributeKey.breakID.rawValue], breakID.uuidString)
        XCTAssertEqual(lifecycle.start, t0)
        XCTAssertEqual(lifecycle.end, t0.addingTimeInterval(210))
    }

    func testAttributesStayOnAllowlist() {
        let event = DomainEvent(
            name: .breakCompleted,
            occurredAt: Date(),
            breakID: UUID(),
            payload: .breakCompleted(stoodForSeconds: 30, motionScore: 0.5, failedOpen: true)
        )
        let attrs = BreakLifecycleTracer.allowlistedAttributes(for: event)
        let allowed = Set(BreakTraceAttributeKey.allCases.map(\.rawValue))
        XCTAssertTrue(Set(attrs.keys).isSubset(of: allowed))
        XCTAssertFalse(attrs.values.contains(where: { $0.contains("camera") }))
        XCTAssertEqual(attrs[BreakTraceAttributeKey.failedOpen.rawValue], "true")
    }
}
